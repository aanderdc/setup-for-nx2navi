param([ValidateSet('Menu','Install','Organize','Build','Index')][string]$Action = 'Menu')
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$Root      = Split-Path -Parent $MyInvocation.MyCommand.Path
$Tools     = Join-Path $Root 'tools'
$Inbox     = Join-Path $Root 'nup\entrada'
$NupLib    = Join-Path $Root 'nup\biblioteca'
$NativeLib = Join-Path $Root 'nativos'
$Repo      = 'tangerineturtle1/NX2navi'

foreach ($d in @($Tools, $Inbox, $NupLib, $NativeLib)) {
    New-Item -ItemType Directory -Force -Path $d | Out-Null
}

function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }
function Fail($m) { Write-Host "ERROR: $m" -ForegroundColor Red }

function Format-Size($b) {
    $b = [double]$b
    if ($b -ge 1GB) { return ('{0:N2} GB' -f ($b / 1GB)) }
    if ($b -ge 1MB) { return ('{0:N1} MB' -f ($b / 1MB)) }
    return ('{0:N0} KB' -f ($b / 1KB))
}

# ---------- Instalador ----------
function Get-Setup {
    Get-ChildItem -LiteralPath $Tools -Filter 'NX2navi-Setup-*.exe' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

function Install-Setup {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $h = @{ 'User-Agent' = 'nx2navi-hub'; 'Accept' = 'application/vnd.github+json' }
        Say 'Buscando la ultima version en GitHub...'
        $rels = @(Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases?per_page=10" -Headers $h)
        $asset = $null
        foreach ($r in $rels) {
            $a = @($r.assets | Where-Object { $_.name -match '^NX2navi-Setup-.*\.exe$' }) | Select-Object -First 1
            if ($a) { $asset = $a; break }
        }
        if (-not $asset) {
            Fail 'No encontre NX2navi-Setup-*.exe en las versiones publicadas.'
            Say "Revisa https://github.com/$Repo/releases y copia el .exe a: $Tools" 'Yellow'
            return
        }
        $dest = Join-Path $Tools $asset.name
        if (Test-Path -LiteralPath $dest) { Say "Ya tienes $($asset.name)." 'Green'; return }
        Say "Descargando $($asset.name)..."
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $dest -Headers $h -UseBasicParsing
        Say "Listo: $dest" 'Green'
    } catch {
        Fail "No se pudo descargar: $($_.Exception.Message)"
        Say "Bajalo a mano de https://github.com/$Repo/releases y ponlo en: $Tools" 'Yellow'
    }
}

# ---------- Biblioteca de .nup ----------
function Get-NupFiles($dir, [switch]$Recurse) {
    if (-not (Test-Path -LiteralPath $dir)) { return @() }
    $items = if ($Recurse) { Get-ChildItem -LiteralPath $dir -File -Recurse } else { Get-ChildItem -LiteralPath $dir -File }
    @($items | Where-Object { $_.Name -match '(?i)\.nup(\.(part)?\d+)?$' })
}

function Get-GameName($file) {
    $n = $file.Name -replace '(?i)\.nup(\.(part)?\d+)?$', ''
    $n = $n -replace '\[[^\]]*\]', ' '
    $n = $n -replace '(?i)[\s._-]*\(?\b(update|actualizacion|upd)\b\)?', ''
    $n = $n -replace '(?i)[\s._-]*\bv\d+(\.\d+)*\b', ''
    $n = $n -replace '(?i)[\s._-]*\(?\b(part|parte|pt)[\s._-]?\d+\)?\s*$', ''
    $n = ($n -replace '\s+', ' ').Trim(' ', '.', '_', '-')
    $n = $n -replace '[\\/:*?"<>|]', '_'
    if (-not $n) { $n = 'Sin nombre' }
    return $n
}

function Organize-Nup {
    $files = @(Get-NupFiles $Inbox)
    if ($files.Count -eq 0) {
        Fail "No hay archivos .nup en la carpeta de entrada."
        Say "Copia tus .nup (completos o por partes) a: $Inbox" 'Yellow'
        return
    }
    foreach ($f in $files) {
        $g = Get-GameName $f
        $d = Join-Path $NupLib $g
        New-Item -ItemType Directory -Force -Path $d | Out-Null
        $t = Join-Path $d $f.Name
        if (Test-Path -LiteralPath $t) { Say "Omitido (ya existe): $($f.Name)" 'Yellow'; continue }
        Move-Item -LiteralPath $f.FullName -Destination $t
        Say "$($f.Name)  ->  nup\biblioteca\$g" 'Green'
    }
    Write-Index
}

# ---------- Indice ----------
function Write-Index {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('# Indice de la biblioteca')
    [void]$sb.AppendLine("Generado: $(Get-Date -Format 'yyyy-MM-dd HH:mm')")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## Biblioteca de .nup')
    [void]$sb.AppendLine('| Juego | Archivos | Tamano | Ultima modificacion |')
    [void]$sb.AppendLine('|---|---|---|---|')
    foreach ($d in @(Get-ChildItem -LiteralPath $NupLib -Directory -ErrorAction SilentlyContinue)) {
        $fs = @(Get-ChildItem -LiteralPath $d.FullName -File -Recurse)
        if ($fs.Count -eq 0) { continue }
        $sum = [long]($fs | Measure-Object Length -Sum).Sum
        $last = ($fs | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime
        [void]$sb.AppendLine("| $($d.Name) | $($fs.Count) | $(Format-Size $sum) | $($last.ToString('yyyy-MM-dd HH:mm')) |")
    }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## Compilaciones nativas')
    [void]$sb.AppendLine('| Juego | .exe | Tamano | Fecha |')
    [void]$sb.AppendLine('|---|---|---|---|')
    foreach ($d in @(Get-ChildItem -LiteralPath $NativeLib -Directory -ErrorAction SilentlyContinue)) {
        $fs = @(Get-ChildItem -LiteralPath $d.FullName -File -Recurse)
        $sum = [long]($fs | Measure-Object Length -Sum).Sum
        $exes = @($fs | Where-Object { $_.Extension -ieq '.exe' }).Count
        [void]$sb.AppendLine("| $($d.Name) | $exes | $(Format-Size $sum) | $($d.LastWriteTime.ToString('yyyy-MM-dd HH:mm')) |")
    }
    $path = Join-Path $Root 'indice.md'
    Set-Content -LiteralPath $path -Value $sb.ToString() -Encoding UTF8
    Say "Indice actualizado: $path" 'Cyan'
}

# ---------- Compilar con NX2navi ----------
function Pick-Number($prompt, $max) {
    $s = Read-Host $prompt
    $i = 0
    if ([int]::TryParse($s, [ref]$i) -and $i -ge 1 -and $i -le $max) { return $i }
    return 0
}

function Build-Game {
    $setup = Get-Setup
    if (-not $setup) { Fail 'Falta el instalador de NX2navi. Usa la opcion 1 primero.'; return }
    $games = @(Get-ChildItem -LiteralPath $NupLib -Directory -ErrorAction SilentlyContinue |
        Where-Object { @(Get-NupFiles $_.FullName -Recurse).Count -gt 0 })
    if ($games.Count -eq 0) { Fail 'No hay juegos con .nup en la biblioteca. Usa la opcion 2.'; return }
    for ($k = 0; $k -lt $games.Count; $k++) { Say ("  {0}) {1}" -f ($k + 1), $games[$k].Name) }
    $i = Pick-Number 'Juego a compilar (numero)' $games.Count
    if ($i -eq 0) { Fail 'Opcion no valida.'; return }
    $g = $games[$i - 1]
    $out = Join-Path $NativeLib $g.Name
    New-Item -ItemType Directory -Force -Path $out | Out-Null
    # El instalador se ejecuta junto a los .nup; se copia temporalmente y se borra al terminar.
    $tmp = Join-Path $g.FullName $setup.Name
    Copy-Item -LiteralPath $setup.FullName -Destination $tmp -Force
    try {
        Say "Ejecutando $($setup.Name) en $($g.FullName)"
        $p = Start-Process -FilePath $tmp -WorkingDirectory $g.FullName `
            -ArgumentList @('--dest', "`"$out`"", '--no-launch') -Wait -PassThru
        if ($p.ExitCode -ne 0) { Fail "El instalador termino con codigo $($p.ExitCode)." }
        else { Say "Terminado. Resultado en: $out" 'Green' }
    } catch {
        Fail "No se pudo ejecutar el instalador: $($_.Exception.Message)"
    } finally {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
    Write-Index
}

function Register-Native {
    $src = (Read-Host 'Ruta de la carpeta o .exe ya compilado').Trim('"', ' ')
    if (-not (Test-Path -LiteralPath $src)) { Fail 'Esa ruta no existe.'; return }
    $name = (Read-Host 'Nombre del juego').Trim()
    if (-not $name) { Fail 'Falta el nombre.'; return }
    $name = $name -replace '[\\/:*?"<>|]', '_'
    $dest = Join-Path $NativeLib $name
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    if ((Get-Item -LiteralPath $src).PSIsContainer) {
        Copy-Item -Path (Join-Path $src '*') -Destination $dest -Recurse -Force
    } else {
        Copy-Item -LiteralPath $src -Destination $dest -Force
    }
    Say "Copiado a nativos\$name (el original sigue en su sitio)." 'Green'
    Write-Index
}

function Launch-Native {
    $exes = @(Get-ChildItem -LiteralPath $NativeLib -Filter '*.exe' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch '(?i)setup|unins|crash|redist' })
    if ($exes.Count -eq 0) { Fail 'No hay .exe en la biblioteca nativa.'; return }
    for ($k = 0; $k -lt $exes.Count; $k++) {
        Say ("  {0}) {1}" -f ($k + 1), $exes[$k].FullName.Substring($NativeLib.Length + 1))
    }
    $i = Pick-Number 'Ejecutar (numero)' $exes.Count
    if ($i -eq 0) { Fail 'Opcion no valida.'; return }
    Start-Process -FilePath $exes[$i - 1].FullName -WorkingDirectory $exes[$i - 1].DirectoryName
}

# ---------- Menu ----------
switch ($Action) {
    'Install'  { Install-Setup; return }
    'Organize' { Organize-Nup; return }
    'Build'    { Build-Game; return }
    'Index'    { Write-Index; return }
}

while ($true) {
    Write-Host ''
    Say '=== NX2navi Hub ===' 'Cyan'
    Say '1) Instalar / actualizar NX2navi'
    Say '2) Organizar .nup (de nup\entrada a nup\biblioteca)'
    Say '3) Compilar un juego a nativo'
    Say '4) Registrar una compilacion nativa existente'
    Say '5) Ejecutar un juego nativo'
    Say '6) Regenerar indice.md'
    Say '0) Salir'
    switch (Read-Host 'Opcion') {
        '1' { Install-Setup }
        '2' { Organize-Nup }
        '3' { Build-Game }
        '4' { Register-Native }
        '5' { Launch-Native }
        '6' { Write-Index }
        '0' { return }
        default { Fail 'Opcion no valida.' }
    }
}
