# OneBit Dungeon (Godot 4.3 — Android)

Prototipo roguelike por turnos estilo **1-bit** (inspirado en *OneBit Adventure*) de **un solo nivel**, creado para probar un flujo de trabajo agéntico con **Godot 4.3 + GitHub Actions → APK**.

## Características
- **Estilo 1-bit pixel art** generado proceduralmente en código (`16×16` sin depender de assets binarios externos).
- **1 nivel completo de mazmorra**: Slimes, Esqueletos, monedas, pociones de curación, mejora de espada (`+1 ATK`), **Llave** y **Salida** bloqueada.
- **Controles pensados para Android**:
  - Gestos **Swipe** (deslizar arriba/abajo/izquierda/derecha) sobre el tablero.
  - **D-Pad táctil** + botón de **Poción** y **Esperar turno**.
  - También jugable en PC con **WASD / Flechas**, `Espacio` (esperar), `H` (poción) y `R` (reiniciar).
- **Tests automáticos headless** (`tests/run_tests.gd`) ejecutados en cada push antes de compilar el APK.

## Cómo descargar e instalar el APK desde GitHub Actions
1. Ve a la pestaña **Actions** del repositorio en GitHub.
2. Abre la ejecución más reciente de **Build Android APK (Godot 4.3)**.
3. En la sección **Artifacts**, descarga **`onebit-dungeon-android-apk`**.
4. Descomprime el `.zip`, copia `onebit-dungeon-debug.apk` a tu teléfono Android e instálalo (permitiendo instalación desde fuentes desconocidas si Android lo solicita).

## Ejecutar tests locales (Godot 4.3 CLI)
```bash
godot --headless --import --quit --path .
godot --headless --path . --script res://tests/run_tests.gd
```
