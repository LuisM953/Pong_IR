# Pong con controles remotos IR en FPGA (Basys3)

Proyecto final de Electrónica Digital (ELDI) 2026, propuesta #15: **Pong game with IR remotes**.

**Autores:** Luis Andres Molina y Jose Miguel Sedano
**Institución:** Escuela Colombiana de Ingeniería Julio Garavito
**Tarjeta:** Digilent Basys3 (Xilinx Artix-7 `xc7a35tcpg236-1`)
**Lenguaje:** Verilog HDL

## Descripción

Juego de Pong para dos jugadores que se muestra en un monitor VGA de 640x480 a 60 Hz. Cada jugador controla su paleta con su propio control remoto IR (protocolo NEC), a través de un receptor IR conectado a un puerto Pmod de la Basys3.

## Requisitos del proyecto

- [ ] Cada jugador tiene su propio control remoto.
- [ ] Decodificación de las teclas de dos controles IR.
- [ ] Un par de teclas asignado a cada jugador (subir y bajar).
- [ ] El juego se muestra en una pantalla VGA.
- [ ] Testbench por cada módulo, con casos límite (hecho para `vga_sync`, `pixel_gen`, `paddle_move`, `ball_move`, `hitbox` y el módulo superior `top_pong`).

## Hardware

- Digilent Basys3 y cable micro-USB.
- Monitor con entrada VGA y cable VGA.
- Receptor IR **TSOP38238** (Vishay, portadora de 38 kHz, recomendado para el protocolo NEC) conectado a un puerto Pmod. Se alimenta con 2.5 a 5.5 V, así que sirve el 3.3 V del Pmod. Su salida es activa en bajo: en reposo vale 1 y baja a 0 mientras detecta la ráfaga de 38 kHz, y por eso `ir_sync_detector` inicia en 1. Pines (TSOP382, visto de frente): 1 = OUT, 2 = GND, 3 = VS (alimentación). Confirmar el orden con la hoja de datos antes de conectarlo.
- Dos controles remotos IR que usen el protocolo NEC.

## Software

- Vivado (síntesis, implementación y programación de la Basys3).
- Icarus Verilog (`iverilog`, `vvp`) y GTKWave para simular.
- Git.

En Ubuntu / WSL:

```bash
sudo apt install iverilog gtkwave
```

## Estructura del repositorio

```
Pong_IR/
├── src/
│   ├── vga_sync.v      # temporización VGA, tick y frame_tick
│   ├── pixel_gen.v     # color de cada píxel
│   ├── paddle_move.v   # movimiento de una paleta
│   ├── ball_move.v     # movimiento y rebote de la pelota (paredes y paletas)
│   ├── hitbox.v        # detecta el golpe de la pelota contra cada paleta
│   ├── ir_sync_detector.v  # sincroniza la señal del receptor IR y detecta flancos
│   └── top.v           # módulo superior (top_pong)
├── tb/
│   ├── vga_sync_tb.v
│   ├── pixel_gen_tb.v
│   ├── paddle_move_tb.v
│   ├── ball_move_tb.v
│   ├── hitbox_tb.v
│   ├── top_tb.v
│   └── tb_ir_sync_detector.v
├── constraints/
│   └── Basys3.xdc      # asignación de pines de la Basys3
├── docs/           # informe, diagramas y capturas de simulación
├── README.md
└── AI_USAGE.md     # registro del uso de herramientas de IA
```

## Arquitectura

```
Receptor IR -> ir_sync_detector -> Decodificador NEC -> Mapeo de teclas -> up/down de cada jugador
                                                              |
                                                              v
                                          paddle_move (x2) -> posición y de cada paleta
                                                              |
                          +-----------------------------------+
                          v                                   v
        hitbox <--- ball_x, ball_y <--- ball_move        pixel_gen -> rgb -> Monitor
          |  hit_p1, hit_p2 (golpe)         ^                 ^
          +---------------------------------+                 |
Reloj 100 MHz -> vga_sync -> x, y, video_on, frame_tick -------+ (frame_tick también va a paddle_move y ball_move)
```

Por ahora los controles son los botones de la Basys3 (ver tabla de pines). El receptor IR, el decodificador NEC y el mapeo de teclas reemplazarán esas entradas `up`/`down` sin cambiar el resto del diseño. El módulo `top_pong` (`src/top.v`) solo conecta los módulos entre sí y con los pines de la tarjeta.

Todo el diseño trabaja con un solo reloj de 100 MHz. Para obtener la cadencia de píxel de ~25 MHz que necesita el VGA se usa un pulso de habilitación (`tick`) cada 4 ciclos, en vez de generar un reloj dividido. Así hay un único dominio de reloj y se evitan los problemas de temporización y de cruce entre relojes.

### Módulos y estado

| Módulo | Archivo | Estado |
|---|---|---|
| Sincronía VGA | `src/vga_sync.v` | Hecho, con testbench autoverificable (HSYNC y `frame_tick`) |
| Generador de píxeles (paletas, pelota, línea central, borde) | `src/pixel_gen.v` | Hecho, con testbench de bordes y de prioridades. Recibe `p1_y`, `p2_y`, `ball_x` y `ball_y` como entradas |
| Movimiento de una paleta | `src/paddle_move.v` | Hecho, con testbench (límites ajustados al borde) |
| Movimiento de la pelota | `src/ball_move.v` | Hecho, con testbench: rebotes en las paredes superior e inferior y, por ahora, también en las laterales; rebote contra las paletas con las entradas `hit_p1` y `hit_p2` |
| Detección de golpe contra las paletas | `src/hitbox.v` | Hecho, con testbench de bordes (un píxel dentro y uno fuera de cada límite) |
| Puntaje, línea de gol y FSM | por definir | Pendiente: las paredes laterales pasarán a ser la línea de gol |
| Sincronizador y detector de flancos del receptor IR | `src/ir_sync_detector.v` | Hecho (Jose Miguel Sedano). Su testbench (`tb/tb_ir_sync_detector.v`) solo muestra formas de onda: falta la comprobación automática y los casos límite |
| Decodificador NEC | por definir | Pendiente |
| Mapeo de teclas | por definir | Pendiente |
| Módulo superior (top) | `src/top.v` (módulo `top_pong`) | Hecho, con testbench (`tb/top_tb.v`). Probado en la Basys3 con un monitor VGA: las paletas se mueven con los botones (la pelota y la colisión se agregaron después de esa prueba en tarjeta) |

### Parámetros de `vga_sync` (640x480 a 60 Hz)

| | Visible | Front porch | Sync | Back porch | Total |
|---|---|---|---|---|---|
| Horizontal (píxeles) | 640 | 16 | 96 | 48 | 800 |
| Vertical (líneas) | 480 | 10 | 2 | 33 | 525 |

Las dos sincronías tienen polaridad negativa (valen 1 en reposo y 0 durante el pulso).

Valores esperados en simulación: `tick` cada 40 ns, línea de 32 µs, pulso de HSYNC de 3.84 µs, pulso de VSYNC de 64 µs y cuadro de 16.8 ms.

**Salida `frame_tick`:** pulso de un ciclo de reloj (10 ns) una vez por cuadro, cuando `tick = 1`, `h_count = 799` y `v_count = 524` (último píxel del cuadro, dentro del blanking vertical). Es el que habilita el movimiento en `paddle_move` y en `ball_move`. Si no se incluyera `tick` en la condición, el pulso duraría 4 ciclos y la paleta se movería 4 veces por cuadro.

### Diseño de `pixel_gen`

El módulo recibe la posición del píxel (`x`, `y`) y `video_on` desde `vga_sync`, la posición vertical de cada paleta (`p1_y`, `p2_y`, 10 bits) desde `paddle_move`, la posición de la pelota (`ball_x`, `ball_y`, 10 bits) desde `ball_move`, y devuelve el color de 12 bits (4 por canal, en el orden rojo, verde, azul). Cada objeto es un rectángulo definido por comparaciones, y las medidas están en `localparam` para cambiarlas en un solo lugar.

| Objeto | Tamaño | Posición inicial | Color (`rgb`) |
|---|---|---|---|
| Paleta 1 | 10 x 80 | `x` 20 a 29, centrada en `y` (200 a 279) | `FF3` |
| Paleta 2 | 10 x 80 | `x` 610 a 619, centrada en `y` (200 a 279) | `F35` |
| Pelota | 10 x 10 | arranca centrada (`x` 315 a 324, `y` 235 a 244) y se mueve | `E73` |
| Línea central | 2 de ancho, discontinua | `x` 319 a 320 | `667` |
| Borde | 10 de grosor (`BORDER_W`) en los cuatro lados | `x` < 10, `x` >= 630, `y` < 10, `y` >= 470 | `667` |
| Fondo (zona visible) | | | `102` |
| Fuera de la zona visible | | | `000` (siempre negro) |

Decisiones de diseño:

- **Prioridad de colores** (de mayor a menor): fuera de la zona visible, paletas, pelota, línea central, borde, fondo. Así la pelota se ve por encima de la línea y las paletas por encima del borde.
- **Negro en el blanking:** fuera de `video_on` la salida es siempre `000`, porque el monitor VGA calibra su nivel de negro en esas zonas.
- **Línea discontinua:** se obtiene con un bit de la coordenada `y` (tramos de 4 filas). Para que sea simétrica entre arriba y abajo se usa una coordenada "doblada" respecto al centro: `y_fold` vale `y` en la mitad superior y `479 - y` en la inferior.
- **Posición vertical de las paletas como entrada:** `pixel_gen` es puramente combinacional (no guarda nada ni tiene reset); solo lee `p1_y` y `p2_y` (que llegan de `paddle_move`) y `ball_x` y `ball_y` (de `ball_move`). Que esas entradas sean registros en otro módulo no vuelve secuencial a `pixel_gen`: él solo las lee. La posición `x` de cada paleta sigue siendo constante.
- **Borde visible:** el monitor, al pulsar *Auto Adjust*, mide la zona visible buscando los píxeles que no son negros. Como el fondo (`102`) es casi negro, el monitor tomaba las paletas como los extremos de la imagen y las dejaba pegadas a los lados. El borde de `BORDER_W` = 10 píxeles ocupa los extremos de la pantalla para que el monitor detecte la zona completa. Además sirve de pared para los rebotes de la pelota.
- **Márgenes separados:** `MARGIN` (20) es la distancia de las paletas al borde de la pantalla; `BORDER_W` (10) es el grosor del borde. Así quedan 10 píxeles libres entre cada paleta y la pared.

### Diseño de `paddle_move`

Mueve el borde superior (`y`) de una paleta con las entradas `up` y `down`. Se instancia una vez por jugador.

| Parámetro | Valor | Significado |
|---|---|---|
| `SPEED` | 4 | píxeles por cuadro (240 píxeles por segundo a 60 Hz) |
| `BORDER_W` | 10 | grosor del borde (el mismo valor que en `pixel_gen`) |
| `Y_MIN` | 10 | límite de arriba (`BORDER_W`) |
| `Y_MAX` | 390 | límite de abajo (`SCREEN_H - BORDER_W - PADDLE_H`) |
| `Y_INIT` | 200 | posición inicial (centrada) |

Decisiones de diseño:

- **Una actualización por cuadro:** `y` solo cambia cuando `frame_tick` vale 1. Si cambiara en cada ciclo de 100 MHz, la paleta se movería cientos de millones de píxeles por segundo. Actualizar al terminar la zona visible evita además que la imagen se corte a mitad de un cuadro.
- **Saturación:** la paleta se detiene contra el borde, en 10 y en 390, para no dibujarse sobre las paredes. Al subir se compara `y <= Y_MIN + SPEED` **antes** de restar, porque `y` no tiene signo y `2 - 4` daría 1022 (la paleta saltaría al fondo).
- **`up` y `down` a la vez:** la paleta no se mueve.

### Diseño de `ball_move`

Mueve la pelota (esquina superior izquierda, `ball_x` y `ball_y`) y la hace rebotar en el borde y en las paletas. Se puede ver como una **recta**: en cada cuadro la posición suma la velocidad (`x += vx`, `y += vy`), y la pendiente es `vy/vx`. Al rebotar contra una pared solo se invierte una dirección y la pendiente se conserva en valor absoluto.

| Parámetro | Valor | Significado |
|---|---|---|
| `BALL_SPEED` | 2 | píxeles por cuadro en cada eje (diagonal de 45 grados) |
| `X_MIN` / `Y_MIN` | 10 | límite izquierdo y superior (`BORDER_W`) |
| `X_MAX` | 620 | límite derecho (`SCREEN_W - BALL_W - BORDER_W`) |
| `Y_MAX` | 460 | límite inferior (`SCREEN_H - BALL_H - BORDER_W`) |
| Posición inicial | (315, 235) | centro de la pantalla |
| Ajuste al golpear la paleta 1 | `ball_x` = 30 | `P1_X + PADDLE_W`, pegada a la cara derecha de la paleta |
| Ajuste al golpear la paleta 2 | `ball_x` = 600 | `P2_X - BALL_W`, pegada a la cara izquierda de la paleta |

Decisiones de diseño:

- **Secuencial:** `ball_x`, `ball_y`, `dir_x` y `dir_y` son registros. La dirección es memoria que se necesita para saber hacia dónde sigue la pelota. Por eso el módulo es secuencial y no puede ser solo una ecuación.
- **Una actualización por cuadro:** solo se mueve con `frame_tick`, en el blanking, igual que las paletas. Así no se ve a medias dentro de un cuadro.
- **Convención de dirección:** `dir = 0` significa derecha o abajo (se suma) y `dir = 1` izquierda o arriba (se resta). Tras el reset ambas valen 1: la pelota sale hacia arriba y a la izquierda.
- **Rebote sin resta peligrosa:** se compara `ball_x <= X_MIN + BALL_SPEED` **antes** de restar. Si se restara primero, `ball_x - 2` con `ball_x = 1` daría 1023 (los números de 10 bits no tienen signo) y no se detectaría el rebote. Al rebotar se escribe `X_MIN` (o `X_MAX`, `Y_MIN`, `Y_MAX`) directamente, así que la pelota nunca se sale ni queda dentro de la pared.
- **Golpe contra las paletas:** `ball_move` recibe `hit_p1` y `hit_p2` de `hitbox`. El golpe de la paleta 1 solo se evalúa dentro de la rama "va hacia la izquierda" (`dir_x == 1`) y el de la paleta 2 dentro de la rama "va hacia la derecha". Así, aunque `hit_p1` siga valiendo 1 en el cuadro siguiente al rebote, la pelota ya se aleja y no rebota otra vez (la dirección es la memoria que evita el doble rebote). Dentro de cada rama el orden es: golpe, pared, avance normal. Solo una asignación a `ball_x` se ejecuta por cuadro; con dos `if` separados ganaría la última asignación y el ajuste a la cara se perdería.
- **Ajuste a la cara:** al golpear, `ball_x` se escribe directamente en 30 (o 600), igual que se hace con las paredes. La pelota llega a 29 en un cuadro, queda 1 píxel dentro de la paleta durante ese cuadro y al siguiente se coloca en la cara.
- **Sin túnel:** la zona de golpe mide `PADDLE_W` = 10 columnas, así que la velocidad debe cumplir `BALL_SPEED <= PADDLE_W`. Con 2 píxeles por cuadro siempre hay un cuadro dentro de la zona. Con una velocidad mayor que 10 la pelota puede saltarse la zona según en qué columna llegue (error intermitente). Si en el futuro la pelota acelera, habrá que ensanchar la zona o comprobar si el paso cruza la cara de la paleta.
- **Pendiente:** la pelota todavía rebota en las paredes laterales; ahí será el gol y el reinicio de la jugada.

### Diseño de `hitbox`

Combinacional (solo `assign`, sin reloj ni memoria). Recibe `p1_y`, `p2_y`, `ball_x` y `ball_y` y devuelve `hit_p1` y `hit_p2`. Hay golpe cuando la pelota solapa a la paleta en y y su borde de ataque cae dentro del ancho de la paleta en x.

| Señal | Condición |
|---|---|
| `hit_p1` | `ball_x` de 20 a 29 (`P1_X` a `P1_X + PADDLE_W - 1`) y `ball_y` de `p1_y - 9` a `p1_y + 79` |
| `hit_p2` | `ball_x` de 601 a 610 (`P2_X - BALL_W + 1` a `P2_X`) y `ball_y` de `p2_y - 9` a `p2_y + 79` |

Decisiones de diseño:

- **Solape en y con desigualdades estrictas:** dos intervalos se solapan si `ball_y < p_y + PADDLE_H` y `ball_y + BALL_H > p_y`. Con `<=` y `>=` los rectángulos que solo se tocan por el borde contarían como golpe (un error de uno en cada extremo).
- **Zona de golpe recortada a la cara de la paleta:** para la paleta 1 se usa el borde izquierdo de la pelota (`ball_x` de 20 a 29) y para la paleta 2 su borde derecho (`ball_x + BALL_W - 1` de 610 a 619). Así una pelota que ya pasó la paleta y está detrás de ella no da golpe. El solape geométrico completo sería más ancho (11 a 29), pero permitiría rebotar desde atrás de la paleta.
- **Geometría pura:** `hitbox` no sabe hacia dónde va la pelota; eso lo decide `ball_move` con `dir_x`. Por eso `hitbox` no tiene memoria y se prueba con un testbench sin reloj.
- **Sin lazo combinacional:** `hitbox` lee `ball_x` y `ball_y`, que son registros de `ball_move`, y `ball_move` lee `hit_p1` y `hit_p2`. El lazo pasa por los registros, que solo cambian en el flanco de reloj, así que no hay realimentación combinacional.
- **Constantes repetidas:** `PADDLE_W`, `PADDLE_H`, `BALL_W`, `MARGIN` y otras se declaran como `localparam` en `pixel_gen`, `paddle_move`, `ball_move` y `hitbox`. Si se cambia una en un archivo, hay que cambiarla en los demás. Queda pendiente unificarlas (archivo de cabecera o `parameter` desde el top).

## Cómo reproducir

### 1. Clonar el repositorio

```bash
git clone https://github.com/LuisM953/Pong_IR.git
cd Pong_IR
```

### 2. Simular `vga_sync`

```bash
iverilog -o sim src/vga_sync.v tb/vga_sync_tb.v
vvp sim
gtkwave vga_sync_tb.vcd
```

La salida de la terminal debe mostrar, todos en PASS:

- `frame_tick` en 0 durante el reset.
- Ancho de hsync de 3840 ns.
- `frame_tick` en la posición `x` = 799, `y` = 524.
- Ancho de `frame_tick` de 10 ns.
- Periodo de `frame_tick` de 16 800 000 ns.

En GTKWave, agregar las señales `clk`, `reset`, `tick`, `h_count`, `v_count`, `hsync`, `vsync` y `video_on`, y comprobar los tiempos de la tabla de arriba. Los archivos `.vvp` y `.vcd` se generan al simular y no se suben al repositorio.

### 3. Simular `pixel_gen`

```bash
iverilog -o sim_pixel src/pixel_gen.v tb/pixel_gen_tb.v
vvp sim_pixel
```

El testbench comprueba el color de píxeles dentro y justo fuera de cada cara de las paletas, la pelota, la línea central (tramos encendido y apagado, arriba y en el espejo inferior) y el borde (esquina exterior y píxel interior), una paleta desplazada al tope superior (`p1_y` = 10) y otra al tope inferior (`p2_y` = 390, donde el píxel justo debajo ya es borde y no fondo), la pelota en las cuatro esquinas permitidas, las prioridades de dibujo (la pelota tapa a la línea central y la paleta 1 tapa a la pelota) y que `video_on = 0` fuerza negro. La salida debe terminar en `EXITO: TODOS LOS TESTS PASARON (0 ERRORES)`.

### 4. Simular `paddle_move`

```bash
iverilog -o sim_paddle src/paddle_move.v tb/paddle_move_tb.v
vvp sim_paddle
```

El testbench comprueba el reset, que sin `frame_tick` no hay movimiento, un paso arriba y uno abajo, los dos botones a la vez, ningún botón y la saturación en 10 y en 390. La salida debe terminar en `EXITO: TODOS LOS TESTS PASARON (0 ERRORES)`.

### 5. Simular `ball_move`

```bash
iverilog -Wall -o sim_ball src/ball_move.v tb/ball_move_tb.v
vvp sim_ball
```

El testbench comprueba el reset (posición y direcciones), que sin `frame_tick` no hay movimiento, tres pasos en diagonal, el golpe contra cada paleta y los cuatro rebotes en pared. Las entradas `hit_p1` y `hit_p2` las maneja el propio testbench con registros (no instancia `hitbox`), de modo que solo se prueba `ball_move`. Golpe: con la pelota dentro de la zona (`ball_x` = 29 o 601) se espera el ajuste a 30 o a 600 y el cambio de dirección; con `hit_p1` o `hit_p2` activo pero la pelota alejándose no debe haber rebote ni cambio de `dir_x`. Un caso en que el resultado del golpe coincide con el avance normal (por ejemplo desde 32) no sirve, porque no distingue un módulo con colisión de uno sin ella. Cada pared se prueba con aterrizaje exacto (por ejemplo 12 a 10) y con sobrepaso (11 a 10), y se verifica el cambio de dirección y el cuadro siguiente. En los casos forzados `dir_y` es 0, así que la `y` esperada aumenta 2 por cuadro. Termina con 2000 cuadros comprobando que la pelota nunca sale de `x` 10 a 620 ni de `y` 10 a 460. Para fijar casos usa asignaciones jerárquicas a `uut.ball_x` y `uut.dir_x`, solo como preparación. La salida debe terminar en `EXITO: TODOS LOS TESTS PASARON (0 ERRORES)`.

### 6. Simular `hitbox`

```bash
iverilog -Wall -o sim_hitbox src/hitbox.v tb/hitbox_tb.v
vvp sim_hitbox
```

Es combinacional, así que el testbench no necesita reloj. Para cada borde de cada paleta comprueba un píxel dentro y uno fuera (por ejemplo `ball_x` = 20 da golpe y 19 no; `ball_y` = 279 da golpe y 280 no con `p1_y` = 200), y repite el patrón con las dos paletas desplazadas por separado (`p1_y` = 300 con `p2_y` = 200 y al revés), porque si las dos valieran lo mismo no se podría detectar un módulo que lea la `y` de la otra paleta. Un testbench con solo casos que esperan golpe no detecta una zona un píxel más grande. La salida debe terminar en `EXITO: TODOS LOS TESTS PASARON (0 ERRORES)`.

### 7. Simular el sistema completo (`top_pong`)

```bash
iverilog -o sim_top src/vga_sync.v src/paddle_move.v src/pixel_gen.v src/ball_move.v src/hitbox.v src/top.v tb/top_tb.v
vvp sim_top
```

Hay que listar **todos** los archivos fuente: el top instancia a los demás módulos y, si falta alguno, Icarus responde `Unknown module type`. El testbench comprueba que al soltar el reset las dos paletas valen 200, que mantener `up_p1` mueve solo la paleta 1 cuatro píxeles por cuadro, que `down_p2` mueve solo la paleta 2, que la pelota arranca en (315, 235) y avanza (313, 233), (311, 231), (309, 229) cuadro a cuadro, que `rgb` vale `E73` en la esquina de la pelota (integración `ball_x`, `ball_y` con `pixel_gen`) y que `rgb` vale `000` siempre que `video_on = 0`. También prueba la integración de la colisión: asigna la pelota en `ball_x` = 31 hacia la izquierda con la paleta 1 en 200, espera que en el siguiente cuadro llegue a 29 y en el otro rebote a 30 con `dir_x` = 0 (si `hitbox` no estuviera conectado en el top, este caso fallaría). Esos chequeos de `rgb` no tienen carrera con el movimiento de la pelota porque esta solo cambia en el blanking, donde `video_on = 0`. Simula unos 84 ms (cinco cuadros) y tiene un temporizador de seguridad de 100 ms: agregar más cuadros exige subir ese límite. Para fijar el estado de la prueba de colisión usa asignaciones jerárquicas normales (`dut.movimiento_pelota.ball_x = 31`), no `force`, porque `force` bloquea las asignaciones del propio módulo y la pelota no se movería. Las lecturas se hacen 1 ns después del flanco de reloj, porque `y` se actualiza con asignación no bloqueante en ese flanco.

### 8. Simular `ir_sync_detector`

```bash
iverilog -o sim_ir src/ir_sync_detector.v tb/tb_ir_sync_detector.v
vvp sim_ir
gtkwave ondas_detector.vcd
```

El testbench baja `ir_rx` (como si se pulsara un botón del control) y lo vuelve a subir. En las formas de onda se ve que `ir_sync` es `ir_rx` retrasada dos ciclos de reloj, y que `flanco_bajada` y `flanco_subida` son pulsos de un ciclo. Por ahora el testbench no comprueba nada automáticamente.

### 9. Sintetizar y programar la Basys3

1. Crear un proyecto en Vivado para la parte `xc7a35tcpg236-1`.
2. Agregar todos los archivos de `src/` (incluido `hitbox.v`; menos los del receptor IR mientras no estén en el top) como fuentes y `constraints/Basys3.xdc` como restricciones.
3. Verificar que `top_pong` esté como módulo superior (clic derecho, *Set as Top*).
4. Ejecutar *Generate Bitstream* y programar la tarjeta desde *Hardware Manager*.
5. Conectar el monitor al puerto VGA antes de programar.

Asignación de pines (`constraints/Basys3.xdc`, partido del archivo maestro de Digilent, dejando solo los pines usados):

| Puerto | Elemento de la tarjeta | Función |
|---|---|---|
| `clk` | reloj de 100 MHz (W5) | reloj del sistema |
| `reset` | botón central (U18) | reinicio |
| `up_p1` / `down_p1` | botón arriba (T18) / izquierda (W19) | jugador 1 |
| `up_p2` / `down_p2` | botón derecha (T17) / abajo (U17) | jugador 2 |
| `hsync`, `vsync` | conector VGA (P19, R19) | sincronía |
| `rgb[11:8]` | VGA rojo (bit 0 en G19, bit 3 en N19) | rojo |
| `rgb[7:4]` | VGA verde (bit 0 en J17, bit 3 en D17) | verde |
| `rgb[3:0]` | VGA azul (bit 0 en N18, bit 3 en J18) | azul |

En el archivo de Digilent los pines VGA aparecen agrupados rojo, azul, verde, y el primero de cada grupo es el bit menos significativo de ese canal. Hay que respetar ese orden al asignar `rgb`, de lo contrario los colores salen alterados.

### Limitaciones conocidas

- Los botones entran directamente a los registros, sin sincronizar con el reloj ni filtrar rebotes. Para mantenerlos pulsados no afecta, pero queda pendiente agregar una cadena de dos registros (el mismo esquema de `ir_sync_detector` sirve).
- La pelota rebota contra las paletas y en las cuatro paredes, pero no hay línea de gol, marcador ni máquina de estados: una pelota que falla la paleta rebota en la pared lateral. La velocidad debe ser como máximo `PADDLE_W` para que no atraviese las paletas. El control por IR no está integrado: solo existe `ir_sync_detector`, y aún falta el decodificador NEC.
- En la tarjeta solo se probó la imagen y las paletas; el movimiento de la pelota y la colisión están verificados en simulación y falta verlos en el monitor.

## Uso de IA

El uso de herramientas de IA está documentado en [AI_USAGE.md](AI_USAGE.md).
