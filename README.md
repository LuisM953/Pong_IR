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
- [ ] Testbench por cada módulo, con casos límite.

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
Receptor IR -> Decodificador NEC -> Mapeo de teclas --+
                                                      +-> Lógica del Pong (FSM) -> Generador de píxeles -> vga_sync -> Monitor
Reloj 100 MHz -> clock enable (tick cada 4 ciclos) ---+
```

Todo el diseño trabaja con un solo reloj de 100 MHz. Para obtener la cadencia de píxel de ~25 MHz que necesita el VGA se usa un pulso de habilitación (`tick`) cada 4 ciclos, en vez de generar un reloj dividido.

### Módulos

| Módulo | Archivo | Estado |
|---|---|---|
| Sincronía VGA | `src/vga_sync.v` | Hecho, con testbench |
| Generador de píxeles (paletas, pelota, línea central) | por definir | Pendiente |
| Lógica del juego y FSM | por definir | Pendiente |
| Decodificador NEC | por definir | Pendiente |
| Mapeo de teclas | por definir | Pendiente |
| Módulo superior (top) | por definir | Pendiente |

### Parámetros de `vga_sync` (640x480 a 60 Hz)

| | Visible | Front porch | Sync | Back porch | Total |
|---|---|---|---|---|---|
| Horizontal (píxeles) | 640 | 16 | 96 | 48 | 800 |
| Vertical (líneas) | 480 | 10 | 2 | 33 | 525 |

Las dos sincronías tienen polaridad negativa. Valores esperados en simulación: `tick` cada 40 ns, línea de 32 µs, pulso de HSYNC de 3.84 µs, pulso de VSYNC de 64 µs y cuadro de 16.8 ms.

## Cómo reproducir

### 1. Clonar el repositorio

```bash
git clone https://github.com/<usuario>/Pong_IR.git
cd Pong_IR
```

### 2. Simular un módulo (ejemplo: `vga_sync`)

```bash
iverilog -o sim src/vga_sync.v tb/vga_sync_tb.v
vvp sim
gtkwave vga.vcd
```

En GTKWave, agregar las señales `clk`, `reset`, `tick`, `h_count`, `v_count`, `hsync`, `vsync` y `video_on`, y comprobar los tiempos de la tabla de arriba. Los archivos `.vvp` y `.vcd` se generan al simular y no se suben al repositorio.

### 3. Sintetizar y programar la Basys3

*(Por completar cuando exista el módulo superior.)*

1. Crear un proyecto en Vivado para la parte `xc7a35tcpg236-1`.
2. Agregar los archivos de `src/` y el archivo `.xdc` de `constraints/`.
3. Definir el módulo superior (top).
4. Ejecutar Generate Bitstream y programar la tarjeta desde Hardware Manager.
5. Conectar el monitor al puerto VGA y el receptor IR al Pmod indicado en el `.xdc`.

## Uso de IA

El uso de herramientas de IA está documentado en [AI_USAGE.md](AI_USAGE.md).
