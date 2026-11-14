# Instrucciones de NX2navi Hub

> **Fase de pruebas:** este proyecto está en pruebas y puede fallar o cambiar. La compatibilidad con cada juego depende de NX2navi.

## Qué necesitas
- Windows 10 o 11.
- 16 GB de memoria RAM y una tarjeta gráfica compatible con Vulkan 1.3 y mesh shading (requisitos de NX2navi).
- Espacio libre en disco: unos 30 GB por juego y 1,5 GB para el lanzador de NX2navi.
- Tu propio archivo del juego en formato `.nup`, de una copia que hayas obtenido legalmente.
- Conexión a internet solo para el paso 1.

## Primer uso
1. Descomprime la carpeta `nx2navi-hub` en un sitio fijo, por ejemplo `C:\nx2navi-hub`. No la uses desde dentro del zip.
2. Haz doble clic en **Abrir NX2navi Hub.bat**. Verás un destello negro y se abrirá la ventana.
3. Pestaña **1. Instalar**: pulsa **Descargar / actualizar NX2navi**. Espera a que aparezca el aviso "Listo". Son unos 140 MB. Solo se hace una vez.

## Agregar un juego
1. Ve a la pestaña **2. Mis juegos (.nup)**.
2. Pulsa **Agregar archivos .nup...** y elige tus archivos. Puedes elegir varios a la vez: el juego completo, las partes, o el juego base más su actualización.
3. Escribe el nombre del juego y acepta. Aparecerá en la lista.
4. Por defecto los archivos se mueven a la biblioteca. Si quieres conservar también los originales, marca la casilla de abajo antes de agregarlos (ocupa el doble de espacio).

## Convertir a nativo
1. Selecciona el juego en la lista y pulsa **Convertir a nativo**.
2. Se abrirá el instalador de NX2navi. Windows puede avisar de que no está firmado: pulsa "Más información" y "Ejecutar de todos modos". Después NX2navi construye el juego en su propia ventana: tarda de 10 a 25 minutos y solo se hace una vez. No muevas ni borres los .nup hasta que termine.
3. Al terminar, el juego aparece en la pestaña **3. Juegos nativos**. Es el lanzador de NX2navi, que prepara los shaders y arranca el juego.

## Jugar
1. Ve a la pestaña **3. Juegos nativos**.
2. Elige el juego y pulsa **Jugar** (o haz doble clic en él).

## Para saber
- **Fase de pruebas:** la compatibilidad con cada juego depende de NX2navi. Otros `.nup` se pueden guardar en la biblioteca, pero puede que no se puedan convertir.
- **No hacen falta claves:** el `.nup` ya viene descifrado, así que no se usa `prod.keys`.
- **Actualizaciones:** vuelve a pulsar **Descargar / actualizar NX2navi** de vez en cuando. Si hay una versión nueva, la baja y borra la anterior.
- **Ya tengo una conversión hecha:** usa **Agregar uno ya convertido...** en la pestaña 3.
- **Dónde está todo:** el botón **Abrir carpeta** abre la carpeta del juego elegido. Las carpetas principales son `nup\biblioteca` y `nativos`.
- **Lista de juegos:** `indice.md` se actualiza solo con el tamaño y la fecha de cada juego.

## Si algo falla
| Problema | Qué hacer |
|---|---|
| La ventana no se abre | Ejecuta `powershell -NoProfile -STA -ExecutionPolicy Bypass -File NX2navi-Hub.ps1` desde la carpeta y mira si sale un mensaje de error. |
| La descarga parece parada | Es normal que tarde. Mira el tamaño que aparece abajo: si va subiendo, está bajando. |
| "Primero instala NX2navi" | Ve a la pestaña 1 y descárgalo. |
| La conversión termina con error | Comprueba que el juego sea el compatible, que no falten partes y que haya espacio en disco. |
| Windows o el antivirus avisa | Los scripts no tienen firma digital. Comprueba que vienen de tu propio repositorio. |
| Cualquier otro fallo | Mira el archivo `hub.log` de la carpeta. |

## Aviso legal
Este proyecto no incluye juegos, claves ni herramientas para saltarse protecciones. Usa solo archivos de juegos que hayas obtenido legalmente. No compartas tus `.nup` ni las conversiones. No está afiliado a Nintendo ni al autor de NX2navi.
