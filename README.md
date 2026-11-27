# OneBit Dungeon (Godot 4.3 — Android)

Roguelike por turnos estilo **1-bit** (inspirado en *OneBit Adventure*) con **5 niveles**, **5 tipos de armas**, **efectos de game feel y partículas**, y **audio chiptune procedural**, compilado a Android APK mediante **Godot 4.3 + GitHub Actions**.

## Características
- **Estilo 1-bit pixel art procedural** (`16×16` generado en código, sin assets binarios externos).
- **5 niveles temáticos con dificultad progresiva**:
  1. **Catacumbas** (Slimes, Esqueletos, Daga y Espada)
  2. **Cripta Esmeralda** (Murciélagos y Lanza)
  3. **Forja Carmesí** (Caballeros y Hacha de Guerra)
  4. **Santuario Arcano** (Báculo Arcano y combates tácticos)
  5. **Trono del Abismo** (Jefe final: **Rey Esqueleto**)
- **5 tipos de armas con mecánicas únicas** (y sistema de arsenal con mejoras `+1 ATK`):
  - **Espada**: equilibrada, ataque cuerpo a cuerpo fiable.
  - **Daga**: 35% de probabilidad de **Golpe Crítico ×2**.
  - **Lanza**: **alcance 2** y **empala** a dos enemigos en línea.
  - **Hacha**: gran daño base y **tajo en área (cleave)** contra enemigos adyacentes.
  - **Báculo**: rayo arcano a **distancia (alcance 3)** con probabilidad de crítico.
- **Game feel, juiciness y partículas**:
  - Interpolación con saltos, *squash & stretch*, embestidas direccionales y *hitstop* (freeze frames).
  - *Screen shake* por trauma, *zoom punch* de cámara, destellos de impacto, viñeta de daño/poca vida y caída de luz de antorcha.
  - Partículas 1-bit (polvo al caminar, chispas de impacto, explosiones de píxeles al derrotar enemigos, destellos de objetos/curación y motas ambientales) + VFX propios por arma y sistema de **Combo**.
- **Audio 8-bit procedural (`SfxManager`)**:
  - Efectos de sonido sintetizados en tiempo real (pasos, cada arma, impactos, críticos, muertes con tono ascendente por combo, objetos, curación, victoria y derrota) + música ambiental chiptune en bucle, con botón de silencio (`SFX`/`OFF` o tecla `M`).
- **Controles Android y PC**:
  - **Swipe** en el tablero o **D-Pad táctil**, botones de **Arma** (cambiar sin gastar turno) y **Poción**.
  - PC: **WASD / Flechas**, `Espacio` (esperar), `Q` / `Tab` (cambiar arma), `H` (poción), `M` (audio), `R` (reiniciar).
- **Tests automáticos headless** (`tests/run_tests.gd`) ejecutados en cada push antes de compilar el APK.

## Cómo descargar e instalar el APK desde GitHub Actions
1. Ve a la pestaña **Actions** del repositorio en GitHub.
2. Abre la ejecución más reciente de **Build Android APK (Godot 4.3)**.
3. En la sección **Artifacts**, descarga **`onebit-dungeon-android-apk`**.
4. Descomprime el `.zip`, copia `onebit-dungeon-debug.apk` a tu teléfono Android e instálalo.

## Ejecutar tests locales (Godot 4.3 CLI)
```bash
godot --headless --import --quit --path .
godot --headless --path . --script res://tests/run_tests.gd
```
