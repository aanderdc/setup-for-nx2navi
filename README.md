# NX2navi Hub

Instalador y biblioteca para NX2navi (https://github.com/tangerineturtle1/NX2navi).

## Uso
1. Doble clic en `instalar.bat`: descarga el `NX2navi-Setup-<version>.exe` oficial a `tools\`.
2. Copia tus `.nup` (completos o por partes) a `nup\entrada\`.
3. Doble clic en `biblioteca.bat` -> opcion 2: los ordena en `nup\biblioteca\<Juego>\`.
4. Opcion 3: ejecuta el instalador de NX2navi junto a los `.nup` del juego elegido; la salida va a `nativos\<Juego>\`.
5. Opcion 5: lanza el juego nativo. `indice.md` lista tamano y fecha de todo.

## Notas
- NX2navi no usa `prod.keys`: el `.nup` ya viene descifrado.
- Segun su documentacion, solo soporta Ocarina of Time (Switch 2, v1.1.1). Otros juegos se pueden guardar en la biblioteca, pero no compilar.
- Base y actualizacion no se pueden unir concatenando; se guardan en la misma carpeta y se dejan tal cual.
- No incluye archivos de juego: necesitas tu propia copia.
- Si el paso 4 no genera nada, usa la opcion 4 para registrar a mano lo que haya creado NX2navi.
