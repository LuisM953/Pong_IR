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
- [ ] Testbench por cada módulo, con casos límite (hecho para `vga_sync`, `pixel_gen`, `paddle_move`, `ball_move`, `hitbox`, `score`, `calibration`, `game_fsm`, `ir_fsm`, `ir_decoder` y el módulo superior `top_pong`; `ir_shift_register` comprueba una sola trama y `ir_sync_detector` e `ir_contador_tiempo` aún no comprueban resultados automáticamente).

## Hardware

- Digilent Basys3 y cable micro-USB.
- Monitor con entrada VGA y cable VGA.
- Receptor IR **VS1838B** (componente suelto de 3 pines, genérico de 38 kHz, no es de Vishay; Luis lo nombró "VSOP1838B"). Reemplaza al TSOP38238 que se había elegido al principio conectado a un puerto Pmod. Se alimenta con 2.7 a 5.5 V, así que sirve el 3.3 V del Pmod. Su salida es activa en bajo: en reposo vale 1 y baja a 0 mientras detecta la ráfaga de 38 kHz, y por eso `ir_sync_detector` inicia en 1. **Pines:** el orden (OUT, GND, VS) cambia entre modelos; hay que verificarlo en la hoja de datos o en la serigrafía de la pieza exacta antes de conectarlo (en el VS1838B suele ser OUT, GND, VCC visto de frente, pero no lo hemos confirmado en una hoja legible) (conectar mal VS y GND puede dañarlo).
- Dos controles remotos IR que usen el protocolo NEC.
- Control remoto usado en las pruebas: control de TV Hyundai D&PHYUN-30. Sus teclas se leen con los LEDs de la Basys3 (ver "Mapeo de teclas").

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
│   ├── ball_move.v     # movimiento de la pelota: rebotes, golpe contra las paletas y línea de gol
│   ├── hitbox.v        # detecta el golpe de la pelota contra cada paleta
│   ├── score.v         # marcador: cuenta los goles de cada jugador y activa win_p1/win_p2
│   ├── calibration.v   # pantalla blanca de calibración del monitor al arrancar
│   ├── ir_sync_detector.v  # sincroniza la señal del receptor IR y detecta flancos
│   ├── ir_contador_tiempo.v # cronómetro de 20 bits que se reinicia con cada flanco del receptor IR
│   ├── ir_fsm.v        # FSM del protocolo NEC: guía, bits y parada (Jose)
│   ├── ir_shift_register.v # registro de desplazamiento de 32 bits de la trama (Jose)
│   ├── ir_decoder.v    # une los módulos IR, valida la trama y entrega ir_p1_up/down, ir_p2_up/down e ir_start
│   ├── game_fsm.v      # FSM de partida: REPOSO, JUGANDO, GAME_OVER (clear y game_enable)
│   └── top.v           # módulo superior (top_pong)
├── tb/
│   ├── vga_sync_tb.v
│   ├── pixel_gen_tb.v
│   ├── paddle_move_tb.v
│   ├── ball_move_tb.v
│   ├── hitbox_tb.v
│   ├── score_tb.v
│   ├── calibration_tb.v
│   ├── top_tb.v
│   ├── tb_ir_sync_detector.v
│   ├── tb_contador_tiempo.v
│   ├── tb_ir_fsm.v
│   ├── tb_ir_shift_register.v
│   ├── tb_ir_decoder.v
│   └── game_fsm_tb.v
├── constraints/
│   └── Basys3.xdc      # asignación de pines de la Basys3
├── docs/           # esquemático (DigitalJS) y capturas de simulación (`game_fsm_tb.png`, `ir_decoder_tb.png`, `top_tb.png`, etc.)
├── README.md
└── AI_USAGE.md     # registro del uso de herramientas de IA
```

## Arquitectura

```
Receptor IR -> ir_sync_detector -> ir_fsm + ir_shift_register -> ir_decoder (valida y mapea teclas) -> ir_p1_up/down, ir_p2_up/down (se unen con OR a los botones) e ir_start
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

`ball_move` entrega dos pulsos de gol (`goal_p1` y `goal_p2`) que van a `score`; sus contadores `score_p1` y `score_p2` van a `pixel_gen`, que los dibuja como cajas en la parte superior. `score` entrega los niveles `win_p1` y `win_p2` a `game_fsm`. `game_fsm` genera dos señales: `game_enable` (nivel en JUGANDO) que habilita el movimiento en `paddle_move` (x2) y `ball_move`, y `clear` (nivel en REPOSO) que pone el marcador en 0 y devuelve las paletas y la pelota a su posición inicial (`paddle_move` x2 y `ball_move` lo reciben). `ir_decoder` entrega a `game_fsm` el pulso `ir_start` (un ciclo) cuando llega la tecla de inicio. Entre `pixel_gen` y la salida `rgb` hay un multiplexor (`calibration`) que muestra primero la pantalla blanca de calibración. La salida `state` de `game_fsm` todavía no se usa: falta que `pixel_gen` dibuje el menú de REPOSO y la pantalla de GAME_OVER con el ganador.

Los jugadores pueden mover las paletas con los botones de la Basys3 o con el control IR: en el top las dos entradas se unen con OR (`up_p1 | ir_p1_up`, etc.), así que cualquiera de las dos fuentes sirve. Con un solo receptor IR solo se decodifica un comando a la vez. El módulo `top_pong` (`src/top.v`) solo conecta los módulos entre sí y con los pines de la tarjeta (el multiplexor de calibración es el módulo `calibration`, no lógica dentro del top).

Todo el diseño trabaja con un solo reloj de 100 MHz. Para obtener la cadencia de píxel de ~25 MHz que necesita el VGA se usa un pulso de habilitación (`tick`) cada 4 ciclos, en vez de generar un reloj dividido. Así hay un único dominio de reloj y se evitan los problemas de temporización y de cruce entre relojes.

### Módulos y estado

| Módulo | Archivo | Estado |
|---|---|---|
| Sincronía VGA | `src/vga_sync.v` | Hecho, con testbench autoverificable (HSYNC y `frame_tick`) |
| Generador de píxeles (paletas, pelota, línea central, borde, marcador) | `src/pixel_gen.v` | Hecho, con testbench de bordes, prioridades y marcador (0-0, 3-7, 11-11). Recibe `p1_y`, `p2_y`, `ball_x`, `ball_y`, `score_p1` y `score_p2` como entradas |
| Movimiento de una paleta | `src/paddle_move.v` | Hecho, con testbench (límites ajustados al borde) |
| Movimiento de la pelota | `src/ball_move.v` | Hecho, con testbench: rebotes en las paredes superior e inferior, rebote contra las paletas con `hit_p1` y `hit_p2` y línea de gol en las paredes laterales (salidas `goal_p1` y `goal_p2`, reinicio al centro) |
| Detección de golpe contra las paletas | `src/hitbox.v` | Hecho, con testbench de bordes (un píxel dentro y uno fuera de cada límite) |
| Marcador | `src/score.v` | Hecho, con testbench autoverificable (casos límite y pruebas de mutación). Cuenta hasta `MAX_SCORE` (11) y satura; `clear` y `reset` ponen ambos contadores en 0 |
| Pantalla de calibración del monitor | `src/calibration.v` | Hecho, con testbench (`CALIB_FRAMES` = 0, 3 y 180). **Generado por IA** (ver AI_USAGE.md); Luis lo revisó y lo estudia |
| Máquina de estados de partida (REPOSO, JUGANDO, GAME_OVER) | `src/game_fsm.v` | Hecho (Luis), con testbench autoverificable (`tb/game_fsm_tb.v`, 9 pruebas). Entradas `win_p1`, `win_p2`, `ir_start`; salidas `clear`, `game_enable` y `state`. `game_enable` se conectó a `paddle_move` (x2) y `ball_move`, con sus testbenches ampliados |
| Sincronizador y detector de flancos del receptor IR | `src/ir_sync_detector.v` | Hecho (Jose Miguel Sedano). Su testbench (`tb/tb_ir_sync_detector.v`) solo muestra formas de onda: falta la comprobación automática y los casos límite |
| Cronómetro de flancos del receptor IR | `src/ir_contador_tiempo.v` | Escrito por Jose Miguel Sedano. Su testbench (`tb/tb_contador_tiempo.v`) no compila: instancia `contador_tiempo` y el módulo se llama `ir_contador_tiempo`; además solo imprime mensajes, sin comprobaciones |
| Decodificador NEC | `src/ir_decoder.v`, `src/ir_fsm.v`, `src/ir_shift_register.v` | Integrado en `top_pong` y probado en la tarjeta con el receptor y el control reales. La base (`ir_sync_detector`, `ir_contador_tiempo`, `ir_fsm`, `ir_shift_register` y el `ir_decoder` inicial) es de Jose Miguel Sedano; Luis la modificó: en `ir_fsm` el estado `REPEAT_STOP`, `repeat_ready` y los umbrales, y en `ir_decoder` `ir_start`, `CMD_START`, la recarga con repeticiones y los códigos reales, además de los casos nuevos de `tb_ir_decoder` (12 casos) y `tb_ir_fsm` (5 pruebas autoverificables). Valida la trama (`cmd == ~cmd_inv`). **Tramas de repetición NEC:** `ir_fsm` tiene el estado `REPEAT_STOP` y la salida `repeat_ready`; `ir_decoder` recarga `hold_counter` con cada repetición (solo si aún estaba activo), para que la paleta se mueva mientras se mantiene la tecla. Según Luis, con la tecla mantenida la paleta ya se mueve de forma continua en la tarjeta. `tb_ir_shift_register` comprueba una sola trama, y `tb_ir_sync_detector` y `tb_contador_tiempo` aún no comprueban resultados automáticamente |
| Mapeo de teclas | `src/ir_decoder.v` | Hecho dentro del decodificador con `localparam`, con los códigos leídos del control de TV Hyundai D&PHYUN-30 a través de los LEDs: `CMD_P1_UP` = `02` (tecla 2), `CMD_P1_DOWN` = `08` (tecla 8), `CMD_P2_UP` = `19` (flecha arriba), `CMD_P2_DOWN` = `1D` (flecha abajo) y `CMD_START` = `57` (Home). Los testbenches usan estos mismos códigos. Dos controles del mismo modelo mandan los mismos códigos, así que cada jugador necesita teclas distintas |
| Módulo superior (top) | `src/top.v` (módulo `top_pong`) | Hecho, con testbench (`tb/top_tb.v`). Declara las constantes de diseño y las pasa a los módulos con `#(...)`; su parámetro `CALIB_FRAMES` (180 por defecto) se pasa a `calibration`. Probado en la Basys3 con un monitor VGA: paletas, pelota y colisión con las paletas; la línea de gol, el marcador y la pantalla de calibración se verificaron solo en simulación |  
**Actualización:** ahora también conecta `ir_decoder` y `game_fsm`; `top_tb` prueba el arranque por IR, el bloqueo en REPOSO, START ignorado en JUGANDO, victoria de cada jugador, congelamiento en GAME_OVER y regreso a REPOSO (0 errores; la simulación completa tarda unos 5 minutos).

### Constantes y parámetros del diseño

`top_pong` es la **única fuente** de las constantes de diseño: las declara como `localparam` y se las pasa a cada módulo con `#( ... )` en la instancia. Cada módulo las declara como `parameter` en su encabezado, con el mismo valor como valor por defecto. Los valores derivados (por ejemplo `X_MAX` o `P2_X`) son `localparam` dentro de cada módulo, porque se calculan a partir de los `parameter` y nadie debe poder sobrescribirlos desde fuera.

| Constante | Valor | La reciben |
|---|---|---|
| `SCREEN_W` | 640 | `pixel_gen`, `ball_move`, `hitbox` |
| `SCREEN_H` | 480 | `paddle_move`, `pixel_gen`, `ball_move` |
| `PADDLE_W` | 10 | `pixel_gen`, `ball_move`, `hitbox` |
| `PADDLE_H` | 80 | `paddle_move`, `pixel_gen`, `hitbox` |
| `BALL_W`, `BALL_H` | 10 | `pixel_gen`, `ball_move`, `hitbox` |
| `LINE_W` | 2 | `pixel_gen` |
| `MARGIN` | 20 | `pixel_gen`, `ball_move`, `hitbox` |
| `BORDER_W` | 10 | `paddle_move`, `pixel_gen`, `ball_move` |
| `PADDLE_SPEED` | 4 | `paddle_move` (como `SPEED`) |
| `BALL_SPEED` | 2 | `ball_move` |
| `MAX_SCORE` | 11 | `score`, `pixel_gen` (máximo 15 por los 4 bits de los contadores) |
| `BOX_SIZE`, `BOX_MARGIN` | 6 y 2 | `pixel_gen` (`BOX_SIZE + BOX_MARGIN` debe ser potencia de 2) |
| `CALIB_FRAMES` | 180 | `calibration`; es parámetro del propio `top_pong` para poder ponerlo en 0 en `top_tb` |

Decisiones de diseño:

- **`Y_MIN` y `Y_MAX` no se comparten:** aparecen en `paddle_move` (10 y 390) y en `ball_move` (10 y 460) con el mismo nombre pero valores distintos, porque dependen del tamaño del objeto (`PADDLE_H` o `BALL_H`). Por eso son `localparam` derivados dentro de cada módulo y no un `parameter` común. Un valor derivado es una constante calculada una sola vez al compilar, no una variable.
- **La sintaxis de la instancia:** los parámetros van en un bloque `#( ... )` antes del nombre de la instancia; los puertos de señal van en el segundo paréntesis. Un parámetro no es un puerto: `.SCREEN_W(SCREEN_W)` dentro de la lista de puertos da el error `port is not a port of`.
- **`LINE_W` se queda en `top`** para que ningún módulo tenga que modificarse al ajustar el aspecto del juego.
- **Límite conocido:** los testbenches de cada módulo lo instancian sin parámetros, o sea con los valores por defecto, y sus valores esperados están escritos para esos valores. Si se cambia un valor en `top` y no el valor por defecto del módulo, `top_tb` lo detectaría pero los testbenches aislados no. Queda pendiente (etapa de corrección de errores) instanciar cada módulo con parámetros explícitos en su testbench y agregar un caso de prueba con un valor distinto.

### Parámetros de `vga_sync` (640x480 a 60 Hz)

| | Visible | Front porch | Sync | Back porch | Total |
|---|---|---|---|---|---|
| Horizontal (píxeles) | 640 | 16 | 96 | 48 | 800 |
| Vertical (líneas) | 480 | 10 | 2 | 33 | 525 |

Las dos sincronías tienen polaridad negativa (valen 1 en reposo y 0 durante el pulso).

Valores esperados en simulación: `tick` cada 40 ns, línea de 32 µs, pulso de HSYNC de 3.84 µs, pulso de VSYNC de 64 µs y cuadro de 16.8 ms.

**Salida `frame_tick`:** pulso de un ciclo de reloj (10 ns) una vez por cuadro, cuando `tick = 1`, `h_count = 799` y `v_count = 524` (último píxel del cuadro, dentro del blanking vertical). Es el que habilita el movimiento en `paddle_move` y en `ball_move`. Si no se incluyera `tick` en la condición, el pulso duraría 4 ciclos y la paleta se movería 4 veces por cuadro.

### Diseño de `pixel_gen`

El módulo recibe la posición del píxel (`x`, `y`) y `video_on` desde `vga_sync`, la posición vertical de cada paleta (`p1_y`, `p2_y`, 10 bits) desde `paddle_move`, la posición de la pelota (`ball_x`, `ball_y`, 10 bits) desde `ball_move`, el marcador (`score_p1`, `score_p2`, 4 bits) desde `score`, y devuelve el color de 12 bits (4 por canal, en el orden rojo, verde, azul). Cada objeto es un rectángulo definido por comparaciones, y las medidas están en `localparam` para cambiarlas en un solo lugar.

| Objeto | Tamaño | Posición inicial | Color (`rgb`) |
|---|---|---|---|
| Paleta 1 | 10 x 80 | `x` 20 a 29, centrada en `y` (200 a 279) | `FF3` |
| Paleta 2 | 10 x 80 | `x` 610 a 619, centrada en `y` (200 a 279) | `F35` |
| Pelota | 10 x 10 | arranca centrada (`x` 315 a 324, `y` 235 a 244) y se mueve | `E73` |
| Línea central | 2 de ancho, discontinua | `x` 319 a 320 | `667` |
| Borde | 10 de grosor (`BORDER_W`) en los cuatro lados | `x` < 10, `x` >= 630, `y` < 10, `y` >= 470 | `667` |
| Placa del marcador | dentro del borde superior, `y` 1 a 8, `x` 222 a 417 | centrada | `334` |
| Cajas del marcador | 11 por jugador, de 6 x 6 con 2 de separación, `y` 2 a 7 | jugador 1 a la izquierda del centro (se llena hacia la izquierda), jugador 2 a la derecha | encendida `FF3` (J1) o `F35` (J2); apagada `213` |
| Fondo (zona visible) | | | `102` |
| Fuera de la zona visible | | | `000` (siempre negro) |

Decisiones de diseño:

- **Prioridad de colores** (de mayor a menor): fuera de la zona visible, paletas, pelota, cajas encendidas, cajas apagadas, placa del marcador, línea central, borde, fondo. Así la pelota se ve por encima de la línea y las paletas por encima del borde.
- **Negro en el blanking:** fuera de `video_on` la salida es siempre `000`, porque el monitor VGA calibra su nivel de negro en esas zonas.
- **Línea discontinua:** se obtiene con un bit de la coordenada `y` (tramos de 4 filas). Para que sea simétrica entre arriba y abajo se usa una coordenada "doblada" respecto al centro: `y_fold` vale `y` en la mitad superior y `479 - y` en la inferior.
- **Posición vertical de las paletas como entrada:** `pixel_gen` es puramente combinacional (no guarda nada ni tiene reset); solo lee `p1_y` y `p2_y` (que llegan de `paddle_move`) y `ball_x` y `ball_y` (de `ball_move`). Que esas entradas sean registros en otro módulo no vuelve secuencial a `pixel_gen`: él solo las lee. La posición `x` de cada paleta sigue siendo constante.
- **Borde visible:** el monitor, al pulsar *Auto Adjust*, mide la zona visible buscando los píxeles que no son negros. Como el fondo (`102`) es casi negro, el monitor tomaba las paletas como los extremos de la imagen y las dejaba pegadas a los lados. El borde de `BORDER_W` = 10 píxeles ocupa los extremos de la pantalla para que el monitor detecte la zona completa. Además sirve de pared para los rebotes de la pelota.
- **Marcador con cajas, no dígitos:** cada punto es una caja; es más simple de dibujar y de sustentar que unos sprites de números, y queda abierta una mejora futura de diseño. La caja `i` de un jugador está encendida si `distancia al centro < score * BOX_STEP`, con `BOX_STEP = BOX_SIZE + BOX_MARGIN`.
- **`BOX_STEP` potencia de 2:** para saber si un píxel cae en una caja o en el hueco se usa `(distancia & (BOX_STEP - 1)) < BOX_SIZE`. La máscara solo equivale a `distancia % BOX_STEP` si `BOX_STEP` es potencia de 2 (con 10 dejaba de dibujar bien, por eso `BOX_MARGIN` = 2 y `BOX_STEP` = 8). Además es solo cableado, sin la lógica de un módulo. Un bloque `initial` avisa en simulación si no se cumple; Vivado ignora `$display` y `$finish`, así que esa guarda no protege la síntesis.
- **El marcador dentro del borde:** la placa ocupa las filas 1 a 8 del borde superior (la fila 0 y la 9 siguen siendo borde) y tapa la línea central en esa zona. Al ocupar el borde no hace falta mover el área de juego.
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

`SCREEN_H`, `PADDLE_H`, `BORDER_W` y `SPEED` son `parameter` (los pasa `top`); `Y_MIN`, `Y_MAX` y `Y_INIT` son `localparam` derivados.

Decisiones de diseño:

- **Una actualización por cuadro:** `y` solo cambia cuando `frame_tick` vale 1. Si cambiara en cada ciclo de 100 MHz, la paleta se movería cientos de millones de píxeles por segundo. Actualizar al terminar la zona visible evita además que la imagen se corte a mitad de un cuadro.
- **Saturación:** la paleta se detiene contra el borde, en 10 y en 390, para no dibujarse sobre las paredes. Al subir se compara `y <= Y_MIN + SPEED` **antes** de restar, porque `y` no tiene signo y `2 - 4` daría 1022 (la paleta saltaría al fondo).
- **`up` y `down` a la vez:** la paleta no se mueve.

### Diseño de `ball_move`

Mueve la pelota (esquina superior izquierda, `ball_x` y `ball_y`), la hace rebotar en el borde superior e inferior y en las paletas, y detecta el gol en las paredes laterales. Se puede ver como una **recta**: en cada cuadro la posición suma la velocidad (`x += vx`, `y += vy`), y la pendiente es `vy/vx`. Al rebotar contra una pared solo se invierte una dirección y la pendiente se conserva en valor absoluto.

| Parámetro | Valor | Significado |
|---|---|---|
| `BALL_SPEED` | 2 | píxeles por cuadro en cada eje (diagonal de 45 grados) |
| `X_MIN` / `Y_MIN` | 10 | límite izquierdo y superior (`BORDER_W`); en x es la línea de gol |
| `X_MAX` | 620 | límite derecho (`SCREEN_W - BALL_W - BORDER_W`); en x es la línea de gol |
| `Y_MAX` | 460 | límite inferior (`SCREEN_H - BALL_H - BORDER_W`) |
| Posición inicial | (315, 235) | centro de la pantalla |
| Ajuste al golpear la paleta 1 | `ball_x` = 30 | `P1_X + PADDLE_W`, pegada a la cara derecha de la paleta |
| Ajuste al golpear la paleta 2 | `ball_x` = 600 | `P2_X - BALL_W`, pegada a la cara izquierda de la paleta |
| `goal_p1` | pulso de 1 ciclo | el jugador 1 anotó: la pelota llegó a la pared derecha |
| `goal_p2` | pulso de 1 ciclo | el jugador 2 anotó: la pelota llegó a la pared izquierda |

Decisiones de diseño:

- **Secuencial:** `ball_x`, `ball_y`, `dir_x` y `dir_y` son registros. La dirección es memoria que se necesita para saber hacia dónde sigue la pelota. Por eso el módulo es secuencial y no puede ser solo una ecuación.
- **Una actualización por cuadro:** solo se mueve con `frame_tick`, en el blanking, igual que las paletas. Así no se ve a medias dentro de un cuadro.
- **Convención de dirección:** `dir = 0` significa derecha o abajo (se suma) y `dir = 1` izquierda o arriba (se resta). Tras el reset ambas valen 1: la pelota sale hacia arriba y a la izquierda.
- **Rebote sin resta peligrosa:** se compara `ball_x <= X_MIN + BALL_SPEED` **antes** de restar. Si se restara primero, `ball_x - 2` con `ball_x = 1` daría 1023 (los números de 10 bits no tienen signo) y no se detectaría el rebote. Al rebotar arriba o abajo se escribe `Y_MIN` o `Y_MAX` directamente, así que la pelota nunca se sale ni queda dentro de la pared. En la línea de gol se usa la misma comparación antes de restar y la pelota se reinicia al centro.
- **Golpe contra las paletas:** `ball_move` recibe `hit_p1` y `hit_p2` de `hitbox`. El golpe de la paleta 1 solo se evalúa dentro de la rama "va hacia la izquierda" (`dir_x == 1`) y el de la paleta 2 dentro de la rama "va hacia la derecha". Así, aunque `hit_p1` siga valiendo 1 en el cuadro siguiente al rebote, la pelota ya se aleja y no rebota otra vez (la dirección es la memoria que evita el doble rebote). Dentro de cada rama el orden es: golpe, pared, avance normal. Solo una asignación a `ball_x` se ejecuta por cuadro; con dos `if` separados ganaría la última asignación y el ajuste a la cara se perdería.
- **Ajuste a la cara:** al golpear, `ball_x` se escribe directamente en 30 (o 600), igual que se hace con las paredes. La pelota llega a 29 en un cuadro, queda 1 píxel dentro de la paleta durante ese cuadro y al siguiente se coloca en la cara.
- **Sin túnel:** la zona de golpe mide `PADDLE_W` = 10 columnas, así que la velocidad debe cumplir `BALL_SPEED <= PADDLE_W`. Con 2 píxeles por cuadro siempre hay un cuadro dentro de la zona. Con una velocidad mayor que 10 la pelota puede saltarse la zona según en qué columna llegue (error intermitente). Si en el futuro la pelota acelera, habrá que ensanchar la zona o comprobar si el paso cruza la cara de la paleta.
- **Línea de gol:** las paredes laterales ya no rebotan. Si la pelota llega a `x <= X_MIN + BALL_SPEED` hacia la izquierda sin golpe de la paleta 1, anota el jugador 2 (`goal_p2`); si llega a `x >= X_MAX - BALL_SPEED` hacia la derecha sin golpe de la paleta 2, anota el jugador 1 (`goal_p1`). La condición se calcula una sola vez en los cables `gol_izq` y `gol_der`, y las ramas de `x` y el bloque de `y` usan esos mismos cables, para que no se desincronicen.
- **Pulso de gol, no nivel:** `goal_p1` y `goal_p2` valen 1 durante un solo ciclo de reloj. Su valor por defecto (0) está fuera del `if (frame_tick)`, así que se limpia en el ciclo siguiente. Un pulso hace que el marcador sume una vez por gol; un nivel que durara el cuadro (16.8 ms, 1.68 millones de ciclos) sumaría en cada ciclo.
- **Gol y reinicio en el mismo flanco:** en el mismo flanco en que sale el pulso la pelota vuelve al centro (315, 235). Si la pelota se quedara un cuadro más contra la pared, la condición de gol seguiría siendo cierta y saldría un segundo pulso: un solo gol daría dos puntos.
- **Saque hacia quien recibió el gol:** `dir_x` no cambia tras el gol, así que la pelota sale hacia el jugador que concedió el punto. `dir_y` se conserva (la pendiente sigue siendo 45 grados, por lo que el juego es predecible; cambiarla queda como mejora).
- **`ball_y` no se pisa:** el bloque de `y` está dentro de `if (!gol)`. Sin eso, la asignación de `y` (que viene después en el código) ganaría sobre el reinicio a 235 y la pelota reaparecería con la altura del gol.

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
- **Constantes:** `SCREEN_W`, `MARGIN`, `PADDLE_W`, `PADDLE_H`, `BALL_W` y `BALL_H` son `parameter` (los pasa `top`, ver "Constantes y parámetros del diseño"); `P1_X` y `P2_X` son `localparam` derivados.

### Diseño de `game_fsm`

Es una FSM de Moore de tres estados, escrita en tres bloques (registro de estado, lógica del estado siguiente y salidas):

| Estado | Código | `game_enable` | `clear` | Salida de este estado |
|---|---|---|---|---|
| REPOSO | `00` | 0 | 1 | pasa a JUGANDO con `ir_start` |
| JUGANDO | `01` | 1 | 0 | pasa a GAME_OVER con `win_p1` o `win_p2`; ignora `ir_start` |
| GAME_OVER | `10` | 0 | 0 | vuelve a REPOSO con `ir_start` |

Decisiones de diseño (las tomó Luis a partir de las preguntas planteadas):

- Arranca en REPOSO tras el reset; ahí `game_enable` = 0, así que paletas y pelota quedan congeladas. REPOSO será el menú de nueva partida (opciones como la velocidad quedan para más adelante).
- `ir_start` es un **pulso** (un evento); `clear` y `game_enable` son **niveles** que salen directamente del estado.
- `clear` está activo solo en REPOSO: el marcador se conserva en GAME_OVER para que `pixel_gen` pueda mostrar al ganador con `win_p1`/`win_p2`, y se borra al volver a REPOSO.
- `clear` también devuelve las paletas (200) y la pelota (315, 235 con sus direcciones iniciales) a su posición inicial: en `paddle_move` y `ball_move` la condición es `if (reset || clear)` como primera rama, con prioridad sobre `frame_tick` y `game_enable`. Antes solo `reset` lo hacía y una partida nueva empezaba con las paletas donde habían quedado.
- En GAME_OVER las paletas y la pelota se congelan.
- No hay empate: con una sola pelota los goles son de uno u otro jugador.
- Si `win_p1` y `win_p2` llegan a la vez en JUGANDO, la FSM va a GAME_OVER (no puede pasar con una sola pelota, pero queda definido); si `ir_start` y una victoria coinciden en JUGANDO, gana la victoria.
- El estado inválido `2'b11` (posible en hardware por una perturbación) cae por el `default` a REPOSO, el estado seguro: `game_enable` = 0 y `clear` = 1.
- Como `game_enable` entra a `paddle_move` y `ball_move` con `frame_tick && game_enable`, una entrada sin conectar (valor `z`) deja el resultado en `x`, el `if` lo trata como falso y el módulo queda congelado.

### Decodificador NEC (`ir_decoder`)

`ir_decoder` instancia `ir_sync_detector`, `ir_contador_tiempo`, `ir_fsm` e `ir_shift_register`. La trama NEC dura una guía de 9 ms en bajo y 4.5 ms en alto, seguida de 32 bits (ráfaga de 562.5 µs y espacio de 562.5 µs para un 0 o de 1.6875 ms para un 1), con el bit menos significativo primero: `{~cmd, cmd, ~addr, addr}`. El decodificador acepta la trama solo si `cmd == ~cmd_inv`.

- Con una trama válida guarda el comando en `ultimo_comando` (visible en `comando_actual`, que va a los LEDs) y carga `hold_counter` con 12,000,000 ciclos (120 ms).
- Mientras `hold_counter` > 0, las salidas de dirección valen 1 si el último comando era de movimiento. Así la paleta sigue moviéndose 120 ms tras cada trama.
- **Tramas de repetición:** al mantener una tecla el control manda cada 108 ms una repetición (9 ms en bajo, 2.25 ms en alto y una ráfaga de 562.5 µs, sin datos). En `LEADER_HIGH`, `ir_fsm` distingue por la duración del espacio: más de 4 ms (400,000 ciclos) es una trama completa, entre 1.8 ms (180,000) y 4 ms es una repetición (estado `REPEAT_STOP`, que al terminar emite `repeat_ready`), y menos es un error. Con cada `repeat_ready`, `ir_decoder` recarga `hold_counter` (120 ms) sin tocar `ultimo_comando`, y solo si todavía estaba activo. El margen sobre el período de 108 ms es de 12 ms: si la paleta se entrecorta en la tarjeta, hay que alargarlo.
- `ir_start` es un pulso de un ciclo: tiene un valor por defecto de 0 antes del `if`, y solo se pone en 1 cuando llega una trama válida con `cmd == CMD_START`. Sin ese valor por defecto se quedaba en 1; sin comparar con `CMD_START` se disparaba con cualquier tecla.
- Una trama START reemplaza a `ultimo_comando`, por lo que cancela la dirección que estuviera activa.


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

El testbench comprueba el color de píxeles dentro y justo fuera de cada cara de las paletas, la pelota, la línea central (tramos encendido y apagado, arriba y en el espejo inferior) y el borde (esquina exterior y píxel interior), una paleta desplazada al tope superior (`p1_y` = 10) y otra al tope inferior (`p2_y` = 390, donde el píxel justo debajo ya es borde y no fondo), la pelota en las cuatro esquinas permitidas, las prioridades de dibujo (la pelota tapa a la línea central y la paleta 1 tapa a la pelota) y que `video_on = 0` fuerza negro. Para el marcador comprueba la placa y sus bordes (un píxel dentro y uno fuera), las filas 0 y 9 como borde, todas las cajas apagadas en 0-0 con el hueco entre cajas como placa, un marcador asimétrico 3-7 (primera y última caja encendida y la siguiente apagada, para que un cruce de jugadores se note) y el marcador lleno 11-11 con la caja 10 de cada lado. La salida debe terminar en `EXITO: TODOS LOS TESTS PASARON (0 ERRORES)`.

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

El testbench comprueba el reset (posición, direcciones y que los goles empiecen en 0), que sin `frame_tick` no hay movimiento, tres pasos en diagonal, el golpe contra cada paleta, los rebotes superior e inferior y la línea de gol. Las entradas `hit_p1` y `hit_p2` las maneja el propio testbench con registros (no instancia `hitbox`), de modo que solo se prueba `ball_move`. Golpe: con la pelota dentro de la zona (`ball_x` = 29 o 601) se espera el ajuste a 30 o a 600 y el cambio de dirección; con `hit_p1` o `hit_p2` activo pero la pelota alejándose no debe haber rebote ni cambio de `dir_x`. Un caso en que el resultado del golpe coincide con el avance normal (por ejemplo desde 32) no sirve, porque no distingue un módulo con colisión de uno sin ella. Gol: con la pelota en 12 (aterrizaje exacto) y en 11 (sobrepaso) hacia la izquierda se espera `goal_p2` en 1, la pelota en (315, 235), `dir_x` sin cambio y el pulso apagado un ciclo después; lo mismo con 618 y 619 hacia la derecha y `goal_p1`; el cuadro siguiente al gol la pelota sale desde el centro (313 o 317). También hay casos de casi gol (14 pasa a 12 y 616 pasa a 618) sin pulso ni reinicio: sin ellos, un umbral de gol corrido dos píxeles no se detecta. Cada pared superior e inferior se prueba con aterrizaje exacto (por ejemplo 12 a 10) y con sobrepaso (11 a 10), y se verifica el cambio de dirección y el cuadro siguiente. En los casos forzados `dir_y` es 0, así que la `y` esperada aumenta 2 por cuadro. Termina con 2000 cuadros comprobando que la pelota nunca sale de `x` 10 a 620 ni de `y` 10 a 460, contando los pulsos de gol y que nunca haya dos seguidos. Para fijar casos usa asignaciones jerárquicas a `uut.ball_x` y `uut.dir_x`, solo como preparación. La salida debe terminar en `EXITO: TODOS LOS TESTS PASARON (0 ERRORES)`.

### 6. Simular `hitbox`

```bash
iverilog -Wall -o sim_hitbox src/hitbox.v tb/hitbox_tb.v
vvp sim_hitbox
```

Es combinacional, así que el testbench no necesita reloj. Para cada borde de cada paleta comprueba un píxel dentro y uno fuera (por ejemplo `ball_x` = 20 da golpe y 19 no; `ball_y` = 279 da golpe y 280 no con `p1_y` = 200), y repite el patrón con las dos paletas desplazadas por separado (`p1_y` = 300 con `p2_y` = 200 y al revés), porque si las dos valieran lo mismo no se podría detectar un módulo que lea la `y` de la otra paleta. Un testbench con solo casos que esperan golpe no detecta una zona un píxel más grande. La salida debe terminar en `EXITO: TODOS LOS TESTS PASARON (0 ERRORES)`.

### 7. Simular `score`

```bash
iverilog -g2012 -o sim_score src/score.v tb/score_tb.v
vvp sim_score
```

El testbench instancia dos veces el módulo: una con `MAX_SCORE` = 3 (para llegar rápido al límite) y otra con el valor por defecto (11). Prueba un punto por jugador, goles simultáneos en el mismo ciclo, un pulso de dos ciclos (cuenta 2: el contrato es un punto por ciclo), la saturación (un gol después de ganar no cambia el marcador, también con el gol del otro jugador), `reset` y `clear` con un gol al mismo tiempo (deben ganar), el empate en `MAX_SCORE` y que `win_pX` se active exactamente al llegar al máximo. Termina en `0 errores`.

### 8. Simular `calibration`

```bash
iverilog -g2012 -o sim_cal src/calibration.v tb/calibration_tb.v
vvp sim_cal
```

Instancia tres veces el módulo (`CALIB_FRAMES` = 0, 3 y 180) con los mismos estímulos. Comprueba la salida blanca/negra durante la calibración, que `rgb_juego` no se filtra, que sin `frame_tick` no avanza, el límite exacto (N-1 y N cuadros), que el contador se detiene, que con N = 0 nunca calibra y que un `reset` reinicia la calibración. Debe terminar en `TODAS LAS PRUEBAS PASARON`.

### 9. Simular el sistema completo (`top_pong`)

```bash
iverilog -g2012 -Wall -o sim_top src/vga_sync.v src/paddle_move.v src/pixel_gen.v src/ball_move.v src/hitbox.v src/score.v src/calibration.v src/ir_sync_detector.v src/ir_contador_tiempo.v src/ir_fsm.v src/ir_shift_register.v src/ir_decoder.v src/game_fsm.v src/top.v tb/top_tb.v
vvp sim_top
```

Hay que listar **todos** los archivos fuente: el top instancia a los demás módulos y, si falta alguno, Icarus responde `Unknown module type`. El testbench comprueba que al soltar el reset las dos paletas valen 200, que mantener `up_p1` mueve solo la paleta 1 cuatro píxeles por cuadro, que `down_p2` mueve solo la paleta 2, que la pelota arranca en (315, 235) y avanza (313, 233), (311, 231), (309, 229) cuadro a cuadro, que `rgb` vale `E73` en la esquina de la pelota (integración `ball_x`, `ball_y` con `pixel_gen`) y que `rgb` vale `000` siempre que `video_on = 0`. También prueba la integración de la colisión: asigna la pelota en `ball_x` = 31 hacia la izquierda con la paleta 1 en 200, espera que en el siguiente cuadro llegue a 29 y en el otro rebote a 30 con `dir_x` = 0 (si `hitbox` no estuviera conectado en el top, este caso fallaría). Esos chequeos de `rgb` no tienen carrera con el movimiento de la pelota porque esta solo cambia en el blanking, donde `video_on = 0`. Además prueba la integración de los goles: con la pelota en `ball_x` = 12 hacia la izquierda y la paleta 1 alejada, espera `goal_p2` en 1, la pelota en (315, 235) y el pulso apagado un ciclo después; lo mismo en la pared derecha con `goal_p1`. Comprueba además el marcador en el sistema: tras el gol de la pared izquierda el marcador pasa a 0-1 y tras el de la derecha a 1-1, con el color de la primera caja de cada jugador en pantalla. Instancia `top_pong #(.CALIB_FRAMES(0))`: con los 180 cuadros de calibración la simulación tardaría 3 s de tiempo simulado (unos 10 minutos reales, por los 30 s que ya toman los 118 ms) y los chequeos del juego fallarían porque la salida sería blanca. Simula unos 118 ms (siete cuadros) y tiene un temporizador de seguridad de 300 ms: cada cuadro agregado suma 16.8 ms, así que agregar más cuadros exige revisar ese límite (con 100 ms el temporizador saltaba antes de que terminara la simulación). Para fijar el estado de la prueba de colisión usa asignaciones jerárquicas normales (`dut.movimiento_pelota.ball_x = 31`), no `force`, porque `force` bloquea las asignaciones del propio módulo y la pelota no se movería. Las lecturas se hacen 1 ns después del flanco de reloj, porque `y` se actualiza con asignación no bloqueante en ese flanco.

Desde que el top incluye la FSM, la partida arranca congelada en REPOSO: el testbench envía una trama NEC con `CMD_START` (`8'h57`) y espera a `game_enable` con un límite de 50 ciclos (tarda 4). Después prueba el movimiento con botones, la hitbox, los goles, el marcador, el control IR de punta a punta (trama válida y trama corrupta), `START` ignorado en JUGANDO, la victoria de cada jugador (`score` = 10 y un gol, forzado por jerarquía), el congelamiento en GAME_OVER y el regreso a REPOSO con el marcador en 0-0, las paletas en 200 y la pelota en (315, 235) (se desplazan antes de volver a REPOSO para comprobar que `clear` las reinicia). En esos tres últimos casos `ir_start` se fuerza con `force`/`release` para ahorrar tiempo; el camino completo `ir_rx` → `ir_decoder` lo cubren la Prueba 1C del top y `tb_ir_decoder`, que comprueba la duración del pulso. La simulación avanza unos 706 ms (el temporizador de seguridad es de 1000 ms) y tarda unos 5 minutos reales.

### 10. Simular `ir_sync_detector`

```bash
iverilog -o sim_ir src/ir_sync_detector.v tb/tb_ir_sync_detector.v
vvp sim_ir
gtkwave ondas_detector.vcd
```

El testbench baja `ir_rx` (como si se pulsara un botón del control) y lo vuelve a subir. En las formas de onda se ve que `ir_sync` es `ir_rx` retrasada dos ciclos de reloj, y que `flanco_bajada` y `flanco_subida` son pulsos de un ciclo. Por ahora el testbench no comprueba nada automáticamente.

### 11. Simular `game_fsm`

```bash
iverilog -g2012 -Wall -o sim_fsm src/game_fsm.v tb/game_fsm_tb.v
vvp sim_fsm
```

El testbench tiene 9 pruebas: reset inicial en REPOSO; inmunidad a `win_p1`/`win_p2` en REPOSO; `ir_start` (un ciclo) lleva a JUGANDO; inmunidad a `ir_start` durante JUGANDO; victoria de P1 hacia GAME_OVER y regreso a REPOSO; nueva partida con victoria de P2 y retención en GAME_OVER; condiciones simultáneas en JUGANDO (7A: `ir_start` y `win_p1` en el mismo ciclo gana la victoria; 7B: `win_p1` y `win_p2` a la vez va a GAME_OVER); recuperación desde el estado inválido `2'b11`; y reset síncrono en mitad de la partida. Termina con `EXITO: TODOS LOS TESTS PASARON`.

### 12. Simular `ir_decoder`

```bash
iverilog -g2012 -Wall -o sim_dec src/ir_sync_detector.v src/ir_contador_tiempo.v src/ir_fsm.v src/ir_shift_register.v src/ir_decoder.v tb/tb_ir_decoder.v
vvp sim_dec
```

El testbench envía tramas NEC y tiene 12 casos: los casos 1 a 4 comprueban el mapeo de `P1_UP`, `P1_DOWN`, `P2_UP` y `P2_DOWN`; el 5 envía una trama corrupta (`cmd` y `~cmd` no coinciden) que debe rechazarse sin alterar las salidas; el 6 envía `CMD_START` y comprueba que `ir_start` produce un solo pulso; el 7, una trama START corrupta (0 pulsos); el 8, una trama seguida de repeticiones a 108 ms que sostienen la dirección más allá de 216 ms; el 9, una repetición tardía (fuera de los 120 ms) que se ignora; el 10, una repetición sin comando previo tras un reset; el 11, espacios demasiado corto (1.0 ms) y demasiado largo (10 ms); y el 12, START mantenido con repeticiones (un solo `ir_start`). `tb/tb_ir_fsm.v` comprueba, con `ir_fsm` solo, el ruido, una trama completa (1 pulso de `data_ready`), una repetición válida (1 pulso de `repeat_ready`), un espacio corto y el timeout. El rechazo de una trama corrupta también se prueba de punta a punta en `top_tb`.


### 13. Sintetizar y programar la Basys3

1. Crear un proyecto en Vivado para la parte `xc7a35tcpg236-1`.
2. Agregar todos los archivos de `src/` (incluidos `hitbox.v`, los módulos IR, `ir_decoder.v` y `game_fsm.v`) como fuentes y `constraints/Basys3.xdc` como restricciones.
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
| `ir_rx` | Pmod JA, pin JA1 (J1) | salida del receptor IR (activa en bajo); el `.xdc` le pide un pull-up interno (`PULLUP true`) |
| `comando_actual[7:0]` | LEDs LD0 a LD7 | último comando NEC válido, para identificar las teclas del control |

En el archivo de Digilent los pines VGA aparecen agrupados rojo, azul, verde, y el primero de cada grupo es el bit menos significativo de ese canal. Hay que respetar ese orden al asignar `rgb`, de lo contrario los colores salen alterados.

### Limitaciones conocidas

- Los botones entran directamente a los registros, sin sincronizar con el reloj ni filtrar rebotes. Para mantenerlos pulsados no afecta, pero queda pendiente agregar una cadena de dos registros (el mismo esquema de `ir_sync_detector` sirve). Lo mismo vale para la entrada `ir_rx`: pasa por `ir_sync_detector`, que sí la sincroniza.
- La pelota rebota contra las paletas y las paredes superior e inferior, y las paredes laterales son la línea de gol (reinicio al centro y pulso `goal_p1`/`goal_p2`). La partida la controla `game_fsm`: arranca congelada en REPOSO y comienza con la tecla de inicio del control IR (`CMD_START`); al llegar un jugador a `MAX_SCORE` pasa a GAME_OVER y otra pulsación de inicio vuelve a REPOSO y borra el marcador. **Aún no existe una forma de iniciar la partida con los botones de la placa**: solo el control IR genera `ir_start`. La velocidad debe ser como máximo `PADDLE_W` para que no atraviese las paletas.
- **Pendiente en pantalla:** `state`, `win_p1` y `win_p2` no llegan a `pixel_gen`, así que todavía no hay menú de REPOSO ni pantalla de GAME_OVER con el ganador; hoy la partida solo se ve congelada.
- **Tramas de repetición NEC:** implementadas y verificadas en simulación (`tb_ir_decoder`, casos 8 a 12, y `tb_ir_fsm`) y, según Luis, en la tarjeta. El margen entre el período de repetición (108 ms) y `hold_counter` (120 ms) es de solo 12 ms: con otro control podría entrecortarse.
- **Un solo comando a la vez:** con un único receptor IR no pueden moverse las dos paletas en el mismo instante por IR (sí con los botones). Mientras llega una trama no se interpreta otra.
- **Códigos del control:** los códigos de `ir_decoder` son los leídos de un control Hyundai D&PHYUN-30. Si se usa otro control, hay que volver a leerlos con los LEDs y actualizarlos en el decodificador y en los testbenches.
- **Testbenches de la base de Jose:** `tb_ir_sync_detector` y `tb_contador_tiempo` aún no comprueban resultados ni tienen casos límite, y `tb_ir_shift_register` comprueba una sola trama.
- **Verificación en hardware:** según Luis, todo lo implementado hasta ahora funciona en la tarjeta y se probó en el monitor (imagen, paletas, pelota, colisiones, línea de gol, marcador, calibración, la FSM, el control IR con repeticiones y el reinicio de paletas y pelota con `clear`). Aún no existen las pantallas de REPOSO y GAME_OVER.
- **Alcance del receptor:** el VS1838B suelto detecta bien solo dentro de un cono estrecho. Conviene montarlo con la cúpula de frente a los jugadores, con 100 nF (y 4.7 a 10 µF) entre VCC y GND pegados a las patas, y probar lejos de luz solar directa.
- La pantalla de calibración dura `CALIB_FRAMES` = 180 cuadros (unos 3 s) después de cada reset; mientras tanto el juego corre pero no se ve. Aún no se probó en el monitor que *Auto Adjust* la use bien; la alternativa sería activarla con un interruptor.
- Los testbenches de cada módulo usan los valores por defecto de los `parameter` (ver "Constantes y parámetros del diseño").
- Todo el diseño actual está probado en la tarjeta y en el monitor (según Luis): imagen, paletas, pelota, colisiones, línea de gol, marcador, calibración, la FSM y el control IR. Faltan por hacer las pantallas de REPOSO y GAME_OVER.

## Uso de IA

El uso de herramientas de IA está documentado en [AI_USAGE.md](AI_USAGE.md).
