# NX2navi Hub - interfaz grafica (Windows 10/11, sin instalar nada extra)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic
[System.Windows.Forms.Application]::EnableVisualStyles()
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$Root      = Split-Path -Parent $MyInvocation.MyCommand.Path
$Tools     = Join-Path $Root 'tools'
$NupLib    = Join-Path $Root 'nup\biblioteca'
$NativeLib = Join-Path $Root 'nativos'
$LogFile   = Join-Path $Root 'hub.log'
$Repo      = 'tangerineturtle1/NX2navi'
foreach ($d in @($Tools, $NupLib, $NativeLib)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }

# ---------------- utilidades ----------------
function Msg($text, $title = 'NX2navi Hub', $icon = 'Information') {
    [void][System.Windows.Forms.MessageBox]::Show($text, $title, 'OK', $icon)
}
function Ask($text, $title = 'NX2navi Hub') {
    ([System.Windows.Forms.MessageBox]::Show($text, $title, 'YesNo', 'Question')) -eq 'Yes'
}
function Log($text) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $text
    if ($script:txtLog) { $script:txtLog.AppendText($line + "`r`n") }
    try { Add-Content -LiteralPath $LogFile -Value $line } catch {}
}
function Set-Busy($on, $text = '') {
    $script:progress.Visible = $on
    $script:tabs.Enabled = -not $on
    $script:lblStatus.Text = $text
    [System.Windows.Forms.Application]::DoEvents()
}
function Format-Size($b) {
    $b = [double]$b
    if ($b -ge 1GB) { return ('{0:N2} GB' -f ($b / 1GB)) }
    if ($b -ge 1MB) { return ('{0:N1} MB' -f ($b / 1MB)) }
    return ('{0:N0} KB' -f ($b / 1KB))
}
function Safe($sb) {
    try { & $sb }
    catch {
        Log "ERROR: $($_.Exception.Message)"
        Set-Busy $false
        Msg "Algo salio mal:`n`n$($_.Exception.Message)`n`n(Detalles en hub.log)" 'Error' 'Error'
    }
}
# Espera un trabajo en segundo plano sin congelar la ventana
function Wait-Ui($job, $watchPath = $null) {
    try {
        while ($job.State -eq 'Running') {
            if ($watchPath -and (Test-Path -LiteralPath $watchPath)) {
                $script:lblStatus.Text = 'Descargando... ' + (Format-Size (Get-Item -LiteralPath $watchPath).Length)
            }
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 100
        }
        Receive-Job $job -ErrorAction Stop | Out-Null
    } finally { Remove-Job $job -Force -ErrorAction SilentlyContinue }
}
function Get-Setup {
    Get-ChildItem -LiteralPath $Tools -Filter 'NX2navi-Setup-*.exe' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
function Get-NupFiles($dir, [switch]$Recurse) {
    if (-not (Test-Path -LiteralPath $dir)) { return @() }
    $items = if ($Recurse) { Get-ChildItem -LiteralPath $dir -File -Recurse } else { Get-ChildItem -LiteralPath $dir -File }
    @($items | Where-Object { $_.Name -match '(?i)\.nup(\.(part)?\d+)?$' })
}
function Guess-GameName($fileName) {
    $n = $fileName -replace '(?i)\.nup(\.(part)?\d+)?$', ''
    $n = $n -replace '\[[^\]]*\]', ' '
    $n = $n -replace '(?i)[\s._-]*\(?\b(update|actualizacion|upd)\b\)?', ''
    $n = $n -replace '(?i)[\s._-]*\bv\d+(\.\d+)*\b', ''
    $n = $n -replace '(?i)[\s._-]*\(?\b(part|parte|pt)[\s._-]?\d+\)?\s*$', ''
    $n = ($n -replace '\s+', ' ').Trim(' ', '.', '_', '-')
    $n = $n -replace '[\\/:*?"<>|]', '_'
    if (-not $n) { $n = 'Mi juego' }
    return $n
}
function Find-GameExe($dir) {
    Get-ChildItem -LiteralPath $dir -Filter '*.exe' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch '(?i)setup|unins|crash|redist|vc_redist' } |
        Sort-Object Length -Descending | Select-Object -First 1
}
function Add-Row($lv, $texts, $tag) {
    $it = New-Object System.Windows.Forms.ListViewItem([string]$texts[0])
    for ($i = 1; $i -lt $texts.Count; $i++) { [void]$it.SubItems.Add([string]$texts[$i]) }
    $it.Tag = $tag
    [void]$lv.Items.Add($it)
}

# ---------------- acciones ----------------
function Refresh-All {
    $s = Get-Setup
    if ($s) { $script:lblSetup.Text = "NX2navi instalado: $($s.Name)"; $script:lblSetup.ForeColor = [System.Drawing.Color]::DarkGreen }
    else    { $script:lblSetup.Text = 'NX2navi todavia no esta instalado.'; $script:lblSetup.ForeColor = [System.Drawing.Color]::Firebrick }

    $script:lvNup.Items.Clear()
    $md = New-Object System.Text.StringBuilder
    [void]$md.AppendLine('# Indice'); [void]$md.AppendLine("Generado: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"); [void]$md.AppendLine('')
    [void]$md.AppendLine('## Juegos (.nup)'); [void]$md.AppendLine('| Juego | Archivos | Tamano | Fecha |'); [void]$md.AppendLine('|---|---|---|---|')
    foreach ($d in @(Get-ChildItem -LiteralPath $NupLib -Directory -ErrorAction SilentlyContinue)) {
        $fs = @(Get-ChildItem -LiteralPath $d.FullName -File -Recurse)
        if ($fs.Count -eq 0) { continue }
        $sum = [long]($fs | Measure-Object Length -Sum).Sum
        $date = ($fs | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime.ToString('yyyy-MM-dd HH:mm')
        Add-Row $script:lvNup @($d.Name, $fs.Count, (Format-Size $sum), $date) $d.FullName
        [void]$md.AppendLine("| $($d.Name) | $($fs.Count) | $(Format-Size $sum) | $date |")
    }
    $script:lvNative.Items.Clear()
    [void]$md.AppendLine(''); [void]$md.AppendLine('## Juegos nativos'); [void]$md.AppendLine('| Juego | Tamano | Fecha |'); [void]$md.AppendLine('|---|---|---|')
    foreach ($d in @(Get-ChildItem -LiteralPath $NativeLib -Directory -ErrorAction SilentlyContinue)) {
        $fs = @(Get-ChildItem -LiteralPath $d.FullName -File -Recurse)
        $sum = [long]($fs | Measure-Object Length -Sum).Sum
        $exe = Find-GameExe $d.FullName
        $exeName = if ($exe) { $exe.Name } else { '(sin .exe)' }
        $date = $d.LastWriteTime.ToString('yyyy-MM-dd HH:mm')
        Add-Row $script:lvNative @($d.Name, $exeName, (Format-Size $sum), $date) $d.FullName
        [void]$md.AppendLine("| $($d.Name) | $(Format-Size $sum) | $date |")
    }
    try { Set-Content -LiteralPath (Join-Path $Root 'indice.md') -Value $md.ToString() -Encoding UTF8 } catch {}
}

function Do-Install {
    Set-Busy $true 'Buscando la ultima version...'
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $h = @{ 'User-Agent' = 'nx2navi-hub'; 'Accept' = 'application/vnd.github+json' }
        $rels = @(Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases?per_page=10" -Headers $h)
        $asset = $null
        foreach ($r in $rels) {
            $a = @($r.assets | Where-Object { $_.name -match '^NX2navi-Setup-.*\.exe$' }) | Select-Object -First 1
            if ($a) { $asset = $a; break }
        }
        if (-not $asset) {
            Msg "No encontre el instalador en GitHub.`nDescargalo a mano en:`nhttps://github.com/$Repo/releases`ny copialo a la carpeta 'tools'." 'Aviso' 'Warning'
            return
        }
        $dest = Join-Path $Tools $asset.name
        if (Test-Path -LiteralPath $dest) { Msg "Ya tienes la ultima version:`n$($asset.name)"; return }
        Log "Descargando $($asset.name)"
        $job = Start-Job -ScriptBlock {
            param($u, $d)
            $ProgressPreference = 'SilentlyContinue'
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $u -OutFile ($d + '.part') -UseBasicParsing -Headers @{ 'User-Agent' = 'nx2navi-hub' }
            Move-Item -LiteralPath ($d + '.part') -Destination $d -Force
        } -ArgumentList $asset.browser_download_url, $dest
        Wait-Ui $job ($dest + '.part')
        Get-ChildItem -LiteralPath $Tools -Filter 'NX2navi-Setup-*.exe' | Where-Object { $_.Name -ne $asset.name } | Remove-Item -Force -ErrorAction SilentlyContinue
        Log "Instalado $($asset.name)"
        Msg "Listo. NX2navi descargado:`n$($asset.name)"
    } finally { Set-Busy $false; Refresh-All }
}

function Do-AddNup {
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title = 'Elige los archivos .nup del juego'
    $dlg.Multiselect = $true
    $dlg.Filter = 'Archivos NUP (*.nup;*.nup.*)|*.nup;*.nup.*|Todos los archivos (*.*)|*.*'
    if ($dlg.ShowDialog() -ne 'OK') { return }
    $files = @($dlg.FileNames | Where-Object { (Split-Path -Leaf $_) -match '(?i)\.nup(\.(part)?\d+)?$' })
    if ($files.Count -eq 0) { Msg 'Ninguno de los archivos elegidos es un .nup.' 'Aviso' 'Warning'; return }
    $skipped = $dlg.FileNames.Count - $files.Count
    $guess = Guess-GameName (Split-Path -Leaf $files[0])
    $name = [Microsoft.VisualBasic.Interaction]::InputBox("Nombre del juego (se creara una carpeta con este nombre).`nSi eliges varios archivos (juego base + actualizacion, o partes), quedaran todos juntos.", 'Nombre del juego', $guess)
    $name = ($name -replace '[\\/:*?"<>|]', '_').Trim()
    if (-not $name) { return }
    $dest = Join-Path $NupLib $name
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    $keep = $script:chkKeep.Checked
    Set-Busy $true 'Guardando archivos (puede tardar si son muy grandes)...'
    try {
        $job = Start-Job -ScriptBlock {
            param($files, $dest, $keep)
            foreach ($f in $files) {
                $t = Join-Path $dest (Split-Path -Leaf $f)
                if (Test-Path -LiteralPath $t) { continue }
                if ($keep) { Copy-Item -LiteralPath $f -Destination $t } else { Move-Item -LiteralPath $f -Destination $t }
            }
        } -ArgumentList (, $files), $dest, $keep
        Wait-Ui $job
        Log "Agregados $($files.Count) archivo(s) a '$name'"
        $extra = if ($skipped -gt 0) { "`n($skipped archivo(s) ignorados por no ser .nup)" } else { '' }
        Msg "Listo: $($files.Count) archivo(s) guardados en '$name'.$extra"
    } finally { Set-Busy $false; Refresh-All }
}

function Do-Build {
    if ($script:lvNup.SelectedItems.Count -eq 0) { Msg 'Primero elige un juego de la lista.' 'Aviso' 'Warning'; return }
    $setup = Get-Setup
    if (-not $setup) { Msg "Primero instala NX2navi (pestana 1)." 'Aviso' 'Warning'; return }
    $gdir = [string]$script:lvNup.SelectedItems[0].Tag
    $gname = Split-Path -Leaf $gdir
    if (@(Get-NupFiles $gdir -Recurse).Count -eq 0) { Msg 'Esa carpeta no tiene archivos .nup.' 'Aviso' 'Warning'; return }
    if (-not (Ask "Se va a convertir '$gname'.`n`nSe abrira el instalador de NX2navi: sigue sus pasos y espera a que termine. Puede tardar y ocupar bastante espacio.`n`nContinuar?")) { return }
    $out = Join-Path $NativeLib $gname
    New-Item -ItemType Directory -Force -Path $out | Out-Null
    $tmp = Join-Path $gdir $setup.Name
    Set-Busy $true 'NX2navi esta trabajando... no cierres esta ventana.'
    try {
        Copy-Item -LiteralPath $setup.FullName -Destination $tmp -Force
        Log "Ejecutando $($setup.Name) en $gdir"
        $p = Start-Process -FilePath $tmp -WorkingDirectory $gdir -ArgumentList @('--dest', "`"$out`"", '--no-launch') -PassThru
        while (-not $p.HasExited) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 200 }
        Log "NX2navi termino con codigo $($p.ExitCode)"
        if ($p.ExitCode -ne 0) { Msg "NX2navi termino con un error (codigo $($p.ExitCode)).`nRevisa que el juego sea compatible y que no falten archivos." 'Aviso' 'Warning' }
        else { Msg "Terminado. Mira la pestana 'Juegos nativos'." }
    } finally {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        Set-Busy $false; Refresh-All
    }
}

function Do-Play {
    if ($script:lvNative.SelectedItems.Count -eq 0) { Msg 'Elige un juego de la lista.' 'Aviso' 'Warning'; return }
    $dir = [string]$script:lvNative.SelectedItems[0].Tag
    $exe = Find-GameExe $dir
    if (-not $exe) { Msg "No encuentro el ejecutable (.exe) en esa carpeta.`nUsa 'Abrir carpeta' para buscarlo." 'Aviso' 'Warning'; return }
    Start-Process -FilePath $exe.FullName -WorkingDirectory $exe.DirectoryName
}

function Do-AddNative {
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = 'Elige la carpeta del juego ya convertido'
    if ($dlg.ShowDialog() -ne 'OK') { return }
    $src = $dlg.SelectedPath
    $name = [Microsoft.VisualBasic.Interaction]::InputBox('Nombre del juego:', 'Nombre del juego', (Split-Path -Leaf $src))
    $name = ($name -replace '[\\/:*?"<>|]', '_').Trim()
    if (-not $name) { return }
    $dest = Join-Path $NativeLib $name
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Set-Busy $true 'Copiando...'
    try {
        $job = Start-Job -ScriptBlock { param($s, $d) Copy-Item -Path (Join-Path $s '*') -Destination $d -Recurse -Force } -ArgumentList $src, $dest
        Wait-Ui $job
        Log "Copiado '$name' a nativos"
        Msg "Listo. La carpeta original no se ha tocado."
    } finally { Set-Busy $false; Refresh-All }
}

function Open-Folder($path) { New-Item -ItemType Directory -Force -Path $path | Out-Null; Start-Process explorer.exe -ArgumentList "`"$path`"" }
function Selected-Or($lv, $fallback) { if ($lv.SelectedItems.Count -gt 0) { [string]$lv.SelectedItems[0].Tag } else { $fallback } }

# ---------------- ventana ----------------
function New-Button($text, $x, $y, $w, $h = 40) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text; $b.Location = New-Object System.Drawing.Point($x, $y); $b.Size = New-Object System.Drawing.Size($w, $h)
    $b.Anchor = 'Bottom,Left'; $b.FlatStyle = 'System'
    return $b
}
function New-Label($text, $x, $y, $w, $h) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text; $l.Location = New-Object System.Drawing.Point($x, $y); $l.Size = New-Object System.Drawing.Size($w, $h)
    return $l
}
function New-List($cols) {
    $lv = New-Object System.Windows.Forms.ListView
    $lv.View = 'Details'; $lv.FullRowSelect = $true; $lv.MultiSelect = $false; $lv.GridLines = $true; $lv.HideSelection = $false
    $lv.Location = New-Object System.Drawing.Point(10, 60); $lv.Size = New-Object System.Drawing.Size(690, 215)
    $lv.Anchor = 'Top,Bottom,Left,Right'
    foreach ($c in $cols) { [void]$lv.Columns.Add($c[0], $c[1]) }
    return $lv
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'NX2navi Hub (fase de pruebas)'
$form.Size = New-Object System.Drawing.Size(760, 620)
$form.MinimumSize = New-Object System.Drawing.Size(760, 620)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object System.Drawing.Font('Segoe UI', 10)

$script:tabs = New-Object System.Windows.Forms.TabControl
$tabs.Location = New-Object System.Drawing.Point(10, 10); $tabs.Size = New-Object System.Drawing.Size(725, 410); $tabs.Anchor = 'Top,Bottom,Left,Right'
$t1 = New-Object System.Windows.Forms.TabPage; $t1.Text = '1. Instalar'
$t2 = New-Object System.Windows.Forms.TabPage; $t2.Text = '2. Mis juegos (.nup)'
$t3 = New-Object System.Windows.Forms.TabPage; $t3.Text = '3. Juegos nativos'
[void]$tabs.TabPages.AddRange(@($t1, $t2, $t3))

# Pestana 1
$t1.Controls.Add((New-Label "Este programa descarga NX2navi (la herramienta que convierte el juego a una aplicacion para PC) y organiza tus archivos.`r`n`r`nPaso 1: pulsa el boton para descargar NX2navi. Solo hace falta una vez." 15 15 680 90))
$script:lblSetup = New-Label '' 15 120 680 30
$lblSetup.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
$t1.Controls.Add($lblSetup)
$btnInstall = New-Button 'Descargar / actualizar NX2navi' 15 165 280 50; $btnInstall.Anchor = 'Top,Left'
$t1.Controls.Add($btnInstall)
$t1.Controls.Add((New-Label "Importante: NX2navi no incluye juegos. Necesitas tu propia copia (.nup). EN FASE DE PRUEBAS: puede fallar o cambiar. La compatibilidad con cada juego depende de NX2navi." 15 240 680 70))

# Pestana 2
$t2.Controls.Add((New-Label "Paso 2: agrega los archivos .nup de tu juego (completo o en partes). Luego elige el juego en la lista y pulsa 'Convertir a nativo'." 10 10 690 45))
$script:lvNup = New-List @(@('Juego', 300), @('Archivos', 80), @('Tamano', 100), @('Fecha', 150))
$t2.Controls.Add($lvNup)
$btnAddNup = New-Button 'Agregar archivos .nup...' 10 290 210
$btnBuild  = New-Button 'Convertir a nativo' 230 290 190
$btnOpenNup = New-Button 'Abrir carpeta' 430 290 150
$script:chkKeep = New-Object System.Windows.Forms.CheckBox
$chkKeep.Text = 'Conservar tambien el archivo original (ocupa el doble de espacio)'
$chkKeep.Location = New-Object System.Drawing.Point(10, 338); $chkKeep.Size = New-Object System.Drawing.Size(600, 25); $chkKeep.Anchor = 'Bottom,Left'
$t2.Controls.AddRange(@($btnAddNup, $btnBuild, $btnOpenNup, $chkKeep))

# Pestana 3
$t3.Controls.Add((New-Label "Paso 3: aqui aparecen los juegos ya convertidos. Elige uno y pulsa 'Jugar'." 10 10 690 45))
$script:lvNative = New-List @(@('Juego', 260), @('Ejecutable', 150), @('Tamano', 100), @('Fecha', 130))
$t3.Controls.Add($lvNative)
$btnPlay = New-Button 'Jugar' 10 290 150
$btnAddNative = New-Button 'Agregar uno ya convertido...' 170 290 250
$btnOpenNative = New-Button 'Abrir carpeta' 430 290 150
$t3.Controls.AddRange(@($btnPlay, $btnAddNative, $btnOpenNative))

$script:progress = New-Object System.Windows.Forms.ProgressBar
$progress.Style = 'Marquee'; $progress.Visible = $false
$progress.Location = New-Object System.Drawing.Point(10, 428); $progress.Size = New-Object System.Drawing.Size(725, 16); $progress.Anchor = 'Bottom,Left,Right'
$script:lblStatus = New-Label '' 10 447 725 24; $lblStatus.Anchor = 'Bottom,Left,Right'
$script:txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Multiline = $true; $txtLog.ReadOnly = $true; $txtLog.ScrollBars = 'Vertical'
$txtLog.Location = New-Object System.Drawing.Point(10, 474); $txtLog.Size = New-Object System.Drawing.Size(725, 100); $txtLog.Anchor = 'Bottom,Left,Right'
$txtLog.Font = New-Object System.Drawing.Font('Consolas', 9)
$form.Controls.AddRange(@($tabs, $progress, $lblStatus, $txtLog))

$btnInstall.Add_Click({ Safe { Do-Install } })
$btnAddNup.Add_Click({ Safe { Do-AddNup } })
$btnBuild.Add_Click({ Safe { Do-Build } })
$btnOpenNup.Add_Click({ Safe { Open-Folder (Selected-Or $lvNup $NupLib) } })
$btnPlay.Add_Click({ Safe { Do-Play } })
$btnAddNative.Add_Click({ Safe { Do-AddNative } })
$btnOpenNative.Add_Click({ Safe { Open-Folder (Selected-Or $lvNative $NativeLib) } })
$lvNative.Add_DoubleClick({ Safe { Do-Play } })
$form.Add_Shown({ Safe { Refresh-All; Log 'Listo.' } })

try { [void]$form.ShowDialog() }
catch { Msg "Error inesperado:`n$($_.Exception.Message)" 'Error' 'Error' }
