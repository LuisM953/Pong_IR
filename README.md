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
- [ ] Testbench por cada módulo, con casos límite (hecho para `vga_sync`, `pixel_gen` y `paddle_move`).

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
├── src/            # módulos Verilog
├── tb/             # testbenches
├── constraints/    # archivo .xdc de la Basys3
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

Todo el diseño trabaja con un solo reloj de 100 MHz. Para obtener la cadencia de píxel de ~25 MHz que necesita el VGA se usa un pulso de habilitación (`tick`) cada 4 ciclos, en vez de generar un reloj dividido. Así hay un único dominio de reloj y se evitan los problemas de temporización y de cruce entre relojes.

### Módulos y estado

| Módulo | Archivo | Estado |
|---|---|---|
| Sincronía VGA | `src/vga_sync.v` | Hecho, con testbench autoverificable de HSYNC. Pendiente: salida `frame_tick` |
| Generador de píxeles (paletas, pelota, línea central) | `src/pixel_gen.v` | Hecho, con testbench de bordes. Pendiente: posiciones como entradas |
| Movimiento de una paleta | `src/paddle_move.v` | Hecho, con testbench |
| Lógica del juego (pelota, colisiones, puntaje) y FSM | por definir | Pendiente |
| Decodificador NEC | por definir | Pendiente |
| Mapeo de teclas | por definir | Pendiente |
| Módulo superior (top) | por definir | Pendiente |

### Parámetros de `vga_sync` (640x480 a 60 Hz)

| | Visible | Front porch | Sync | Back porch | Total |
|---|---|---|---|---|---|
| Horizontal (píxeles) | 640 | 16 | 96 | 48 | 800 |
| Vertical (líneas) | 480 | 10 | 2 | 33 | 525 |

Las dos sincronías tienen polaridad negativa (valen 1 en reposo y 0 durante el pulso).

Valores esperados en simulación: `tick` cada 40 ns, línea de 32 µs, pulso de HSYNC de 3.84 µs, pulso de VSYNC de 64 µs y cuadro de 16.8 ms.

### Diseño de `pixel_gen`

El módulo recibe la posición del píxel (`x`, `y`) y `video_on` desde `vga_sync` y devuelve el color de 12 bits (4 por canal). Cada objeto es un rectángulo definido por comparaciones, y las medidas están en `localparam` para cambiarlas en un solo lugar.

| Objeto | Tamaño | Posición inicial | Color (`rgb`) |
|---|---|---|---|
| Paleta 1 | 10 x 80 | `x` 20 a 29, centrada en `y` (200 a 279) | `FF3` |
| Paleta 2 | 10 x 80 | `x` 610 a 619, centrada en `y` (200 a 279) | `F35` |
| Pelota | 10 x 10 | centrada en la pantalla (`x` 315 a 324, `y` 235 a 244) | `E73` |
| Línea central | 2 de ancho, discontinua | `x` 319 a 320 | `667` |
| Fondo (zona visible) | | | `102` |
| Fuera de la zona visible | | | `000` (siempre negro) |

Decisiones de diseño:

- **Prioridad de colores** (de mayor a menor): fuera de la zona visible, paletas, pelota, línea central, fondo. Así la pelota se ve por encima de la línea.
- **Negro en el blanking:** fuera de `video_on` la salida es siempre `000`, porque el monitor VGA calibra su nivel de negro en esas zonas.
- **Línea discontinua:** se obtiene con un bit de la coordenada `y` (tramos de 4 filas). Para que sea simétrica entre arriba y abajo se usa una coordenada "doblada" respecto al centro: `y_fold` vale `y` en la mitad superior y `479 - y` en la inferior.
- **Posiciones como parámetros:** las posiciones de las paletas y la pelota pasarán a ser entradas del módulo (las actualizará la lógica del juego), y los `localparam` actuales quedarán como valores iniciales.

### Diseño de `paddle_move`

Mueve el borde superior (`y`) de una paleta con las entradas `up` y `down`. Se instancia una vez por jugador.

| Parámetro | Valor | Significado |
|---|---|---|
| `SPEED` | 4 | píxeles por cuadro (240 píxeles por segundo a 60 Hz) |
| `Y_MIN` | 0 | límite de arriba |
| `Y_MAX` | 400 | límite de abajo (`SCREEN_H - PADDLE_H`) |
| `Y_INIT` | 200 | posición inicial (centrada) |

Decisiones de diseño:

- **Una actualización por cuadro:** `y` solo cambia cuando `frame_tick` vale 1. Si cambiara en cada ciclo de 100 MHz, la paleta se movería cientos de millones de píxeles por segundo. Actualizar al terminar la zona visible evita además que la imagen se corte a mitad de un cuadro.
- **Saturación:** la paleta se detiene en 0 y en 400. Al subir se compara `y <= SPEED` **antes** de restar, porque `y` no tiene signo y `2 - 4` daría 1022 (la paleta saltaría al fondo).
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

La salida de la terminal debe decir `PASS: ancho de hsync = 3840 ns`.

En GTKWave, agregar las señales `clk`, `reset`, `tick`, `h_count`, `v_count`, `hsync`, `vsync` y `video_on`, y comprobar los tiempos de la tabla de arriba. Los archivos `.vvp` y `.vcd` se generan al simular y no se suben al repositorio.

### 3. Simular `pixel_gen`

```bash
iverilog -o sim_pixel src/pixel_gen.v tb/pixel_gen_tb.v
vvp sim_pixel
```

El testbench comprueba el color de píxeles dentro y justo fuera de cada cara de las paletas, la pelota y la línea central, los tramos de la línea y que `video_on = 0` fuerza negro. La salida debe terminar en `EXITO: TODOS LOS TESTS PASARON (0 ERRORES)`.

### 4. Simular `paddle_move`

```bash
iverilog -o sim_paddle src/paddle_move.v tb/paddle_move_tb.v
vvp sim_paddle
```

El testbench comprueba el reset, que sin `frame_tick` no hay movimiento, un paso arriba y uno abajo, los dos botones a la vez, ningún botón y la saturación en 0 y en 400. La salida debe terminar en `EXITO: TODOS LOS TESTS PASARON (0 ERRORES)`.

### 5. Sintetizar y programar la Basys3

*(Por completar cuando exista el módulo superior.)*

1. Crear un proyecto en Vivado para la parte `xc7a35tcpg236-1`.
2. Agregar los archivos de `src/` y el archivo `.xdc` de `constraints/`.
3. Definir el módulo superior (top).
4. Ejecutar Generate Bitstream y programar la tarjeta desde Hardware Manager.
5. Conectar el monitor al puerto VGA y el receptor IR al Pmod indicado en el `.xdc`.

## Uso de IA

El uso de herramientas de IA está documentado en [AI_USAGE.md](AI_USAGE.md).
