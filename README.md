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
- [ ] Testbench por cada módulo, con casos límite (hecho para `vga_sync`, `pixel_gen`, `paddle_move` y el módulo superior `top_pong`).

## Hardware

- Digilent Basys3 y cable micro-USB.
- Monitor con entrada VGA y cable VGA.
- Receptor IR de 38 kHz (VS1838B) conectado a un puerto Pmod: VCC a 3.3 V, GND a GND y OUT a un pin de datos.
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
│   └── top.v           # módulo superior (top_pong)
├── tb/
│   ├── vga_sync_tb.v
│   ├── pixel_gen_tb.v
│   ├── paddle_move_tb.v
│   └── top_tb.v
├── constraints/
│   └── Basys3.xdc      # asignación de pines de la Basys3
├── docs/           # informe, diagramas y capturas de simulación
├── README.md
└── AI_USAGE.md     # registro del uso de herramientas de IA
```

## Arquitectura

```
Receptor IR -> Decodificador NEC -> Mapeo de teclas -> up/down de cada jugador
                                                              |
                                                              v
                                          paddle_move (x2) -> posición y de cada paleta
                                                              |
                                                              v
Reloj 100 MHz -> vga_sync -> x, y, video_on, frame_tick ---> pixel_gen -> rgb -> Monitor
```

Por ahora los controles son los botones de la Basys3 (ver tabla de pines). El receptor IR, el decodificador NEC y el mapeo de teclas reemplazarán esas entradas `up`/`down` sin cambiar el resto del diseño. El módulo `top_pong` (`src/top.v`) solo conecta los módulos entre sí y con los pines de la tarjeta.

Todo el diseño trabaja con un solo reloj de 100 MHz. Para obtener la cadencia de píxel de ~25 MHz que necesita el VGA se usa un pulso de habilitación (`tick`) cada 4 ciclos, en vez de generar un reloj dividido. Así hay un único dominio de reloj y se evitan los problemas de temporización y de cruce entre relojes.

### Módulos y estado

| Módulo | Archivo | Estado |
|---|---|---|
| Sincronía VGA | `src/vga_sync.v` | Hecho, con testbench autoverificable (HSYNC y `frame_tick`) |
| Generador de píxeles (paletas, pelota, línea central, borde) | `src/pixel_gen.v` | Hecho, con testbench de bordes. Recibe `p1_y` y `p2_y` como entradas. Pendiente: posición de la pelota como entrada |
| Movimiento de una paleta | `src/paddle_move.v` | Hecho, con testbench (límites ajustados al borde) |
| Lógica del juego (pelota, colisiones, puntaje) y FSM | por definir | Pendiente |
| Decodificador NEC | por definir | Pendiente |
| Mapeo de teclas | por definir | Pendiente |
| Módulo superior (top) | `src/top.v` (módulo `top_pong`) | Hecho, con testbench (`tb/top_tb.v`). Probado en la Basys3 con un monitor VGA: las paletas se mueven con los botones |

### Parámetros de `vga_sync` (640x480 a 60 Hz)

| | Visible | Front porch | Sync | Back porch | Total |
|---|---|---|---|---|---|
| Horizontal (píxeles) | 640 | 16 | 96 | 48 | 800 |
| Vertical (líneas) | 480 | 10 | 2 | 33 | 525 |

Las dos sincronías tienen polaridad negativa (valen 1 en reposo y 0 durante el pulso).

Valores esperados en simulación: `tick` cada 40 ns, línea de 32 µs, pulso de HSYNC de 3.84 µs, pulso de VSYNC de 64 µs y cuadro de 16.8 ms.

**Salida `frame_tick`:** pulso de un ciclo de reloj (10 ns) una vez por cuadro, cuando `tick = 1`, `h_count = 799` y `v_count = 524` (último píxel del cuadro, dentro del blanking vertical). Es el que habilita el movimiento en `paddle_move`. Si no se incluyera `tick` en la condición, el pulso duraría 4 ciclos y la paleta se movería 4 veces por cuadro.

### Diseño de `pixel_gen`

El módulo recibe la posición del píxel (`x`, `y`) y `video_on` desde `vga_sync`, y la posición vertical de cada paleta (`p1_y`, `p2_y`, 10 bits) desde `paddle_move`, y devuelve el color de 12 bits (4 por canal, en el orden rojo, verde, azul). Cada objeto es un rectángulo definido por comparaciones, y las medidas están en `localparam` para cambiarlas en un solo lugar.

| Objeto | Tamaño | Posición inicial | Color (`rgb`) |
|---|---|---|---|
| Paleta 1 | 10 x 80 | `x` 20 a 29, centrada en `y` (200 a 279) | `FF3` |
| Paleta 2 | 10 x 80 | `x` 610 a 619, centrada en `y` (200 a 279) | `F35` |
| Pelota | 10 x 10 | centrada en la pantalla (`x` 315 a 324, `y` 235 a 244) | `E73` |
| Línea central | 2 de ancho, discontinua | `x` 319 a 320 | `667` |
| Borde | 10 de grosor (`BORDER_W`) en los cuatro lados | `x` < 10, `x` >= 630, `y` < 10, `y` >= 470 | `667` |
| Fondo (zona visible) | | | `102` |
| Fuera de la zona visible | | | `000` (siempre negro) |

Decisiones de diseño:

- **Prioridad de colores** (de mayor a menor): fuera de la zona visible, paletas, pelota, línea central, borde, fondo. Así la pelota se ve por encima de la línea y las paletas por encima del borde.
- **Negro en el blanking:** fuera de `video_on` la salida es siempre `000`, porque el monitor VGA calibra su nivel de negro en esas zonas.
- **Línea discontinua:** se obtiene con un bit de la coordenada `y` (tramos de 4 filas). Para que sea simétrica entre arriba y abajo se usa una coordenada "doblada" respecto al centro: `y_fold` vale `y` en la mitad superior y `479 - y` en la inferior.
- **Posición vertical de las paletas como entrada:** `pixel_gen` es puramente combinacional (no guarda nada ni tiene reset); solo lee `p1_y` y `p2_y`, que llegan de `paddle_move`. La posición `x` de cada paleta sigue siendo constante. La pelota seguirá fija hasta que exista su módulo de movimiento.
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

El testbench comprueba el color de píxeles dentro y justo fuera de cada cara de las paletas, la pelota, la línea central (tramos encendido y apagado, arriba y en el espejo inferior) y el borde (esquina exterior y píxel interior), una paleta desplazada al tope superior (`p1_y` = 10) y que `video_on = 0` fuerza negro. La salida debe terminar en `EXITO: TODOS LOS TESTS PASARON (0 ERRORES)`.

### 4. Simular `paddle_move`

```bash
iverilog -o sim_paddle src/paddle_move.v tb/paddle_move_tb.v
vvp sim_paddle
```

El testbench comprueba el reset, que sin `frame_tick` no hay movimiento, un paso arriba y uno abajo, los dos botones a la vez, ningún botón y la saturación en 10 y en 390. La salida debe terminar en `EXITO: TODOS LOS TESTS PASARON (0 ERRORES)`.

### 5. Simular el sistema completo (`top_pong`)

```bash
iverilog -o sim_top src/vga_sync.v src/paddle_move.v src/pixel_gen.v src/top.v tb/top_tb.v
vvp sim_top
```

Hay que listar **todos** los archivos fuente: el top instancia a los demás módulos y, si falta alguno, Icarus responde `Unknown module type`. El testbench comprueba que al soltar el reset las dos paletas valen 200, que mantener `up_p1` mueve solo la paleta 1 cuatro píxeles por cuadro, que `down_p2` mueve solo la paleta 2, y que `rgb` vale `000` siempre que `video_on = 0`. Simula unos 50 ms (tres cuadros) y tiene un temporizador de seguridad de 100 ms. Las lecturas se hacen 1 ns después del flanco de reloj, porque `y` se actualiza con asignación no bloqueante en ese flanco.

### 6. Sintetizar y programar la Basys3

1. Crear un proyecto en Vivado para la parte `xc7a35tcpg236-1`.
2. Agregar los cuatro archivos de `src/` como fuentes y `constraints/Basys3.xdc` como restricciones.
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

- Los botones entran directamente a los registros, sin sincronizar con el reloj ni filtrar rebotes. Para mantenerlos pulsados no afecta, pero queda pendiente agregar una cadena de dos registros.
- Todavía no hay pelota en movimiento, marcador ni máquina de estados, y el control por IR no está integrado.

## Uso de IA

El uso de herramientas de IA está documentado en [AI_USAGE.md](AI_USAGE.md).
