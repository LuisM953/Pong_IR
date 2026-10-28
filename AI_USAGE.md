# Uso de IA en el proyecto

Este archivo documenta cómo se usó la IA en el proyecto, como exige el profesor: qué herramienta, con qué propósito y qué código se generó.

**Herramienta usada hasta ahora:** Claude (Anthropic), como apoyo de estudio y revisión.

## Reglas que seguimos

1. La IA explica los conceptos antes de escribir cualquier código.
2. El primer intento de cada módulo lo escribimos nosotros.
3. Todo código que venga de la IA se marca como tal en esta tabla y con un comentario en el archivo fuente.
4. Antes de integrar un módulo, cada integrante debe poder explicarlo con sus propias palabras.

## Registro

| Fecha | Propósito | Qué aportó la IA | Qué hicimos nosotros | Archivos afectados |
|---|---|---|---|---|
| 2026-10-14 al 16 | Planificación | Propuesta de arquitectura por bloques, cronograma, lista de materiales y comparación de receptores IR | Elegimos la tarjeta (Basys3), ajustamos el cronograma a nuestras fechas | Ninguno |
| 2026-10-21 | Aprender el timing VGA 640x480 | Explicación del principio del VGA, tabla de porches y sincronía, y la idea de usar un `tick` (clock enable) en vez de un reloj dividido | Estudiar la explicación | Ninguno |
| 2026-10-21 | Escribir `vga_sync.v` | Declaración de puertos del módulo (interfaz), pistas para cada parte y revisión de errores. Código sugerido por la IA: las asignaciones combinacionales de `tick`, `hsync`, `video_on`, `x` e `y`, y el bloque secuencial `always` corregido de los contadores | Primer intento completo del módulo; cálculo del rango de `vsync` (490 a 491); integración de las correcciones | `src/vga_sync.v` |
| 2026-10-21 | Testbench de `vga_sync` | Esqueleto del testbench (`$dumpfile`, `$dumpvars`, generación de reloj) y los valores esperados de tiempos | Completar el testbench, simular en GTKWave y medir los tiempos con cursores | `tb/vga_sync_tb.v` |
| 2026-10-21 | Control de versiones | Estructura de carpetas, `.gitignore`, comandos de git y borradores de `README.md` y `AI_USAGE.md` | Crear el repositorio y organizar los archivos | `README.md`, `AI_USAGE.md`, `.gitignore` |
| 2026-10-21 | Testbench autoverificable de HSYNC | Esqueleto con tres huecos y las construcciones `$time`, `@(negedge)`, `wait` y `!==`; explicación de la separación en bloques `initial` (estímulo, medición); **código escrito por la IA a petición nuestra:** la bandera `medido` y su comprobación al final del estímulo (3 líneas) | Completar los huecos, separar el estímulo de la medición, corregir los errores de sintaxis, simular y comprobar `PASS: ancho de hsync = 3840 ns` | `tb/vga_sync_tb.v` |
| 2026-10-21 | Uso de GTKWave | Explicación de señales, formato decimal, marcadores, archivos `.gtkw` y cómo ubicar un instante a partir del valor de `h_count` | Simular, abrir las formas de onda y medir los flancos de `hsync` | Ninguno |
| 2026-10-21 | Preguntas de sustentación sobre `vga_sync` | Preguntas (tick frente a reloj dividido, rango de `hsync`, `h_count` frente a `x`, combinacional frente a secuencial, polaridad negativa) y correcciones de nuestras respuestas | Responder con nuestras palabras y corregir los errores de comprensión | Ninguno |
| 2026-10-28 | Diseño de `pixel_gen.v` | Concepto (cada objeto es un rectángulo definido por comparaciones, selección de color por prioridad, `video_on` fuerza negro), tabla de puntos de prueba en los bordes, y revisión de errores: `=` por `==`, coma faltante en el `localparam`, `PADDLE_W` por `PADDLE_H`, nombre `ball` por `ball_on`, `y_fold` mal calculado y el color de fondo en la zona no visible (debe ser negro). Sugerencia de usar un bit de `y` para la línea discontinua y de doblar la coordenada `y` para que sea simétrica | Escribir todo el módulo: `localparam` de medidas y posiciones, las señales de cada objeto, la cadena de `rgb`, la paleta de colores, la línea discontinua con `y[2]`, el doblez `y_fold`, las paletas centradas y la pelota de 10x10 | `src/pixel_gen.v` |
| 2026-10-28 | Visualización del cuadro | La IA instaló Icarus Verilog en su propio entorno, simuló `pixel_gen.v` sobre los 640x480 píxeles con un testbench que ella escribió (no incluido en el repositorio) y generó una imagen PNG para ver el resultado; comprobó por simulación los bordes de cada objeto y la simetría | Revisar la imagen y decidir mantener los tamaños | Ninguno (imagen solo para revisión) |
| 2026-10-28 | Documentación | Borradores actualizados de `README.md` y `AI_USAGE.md` | Revisar y confirmar que reflejan lo que hicimos | `README.md`, `AI_USAGE.md` |

## Plantilla para nuevas entradas

```
| AAAA-MM-DD | Propósito | Qué aportó la IA | Qué hicimos nosotros | Archivos |
```

> Este registro debe ser fiel a lo que realmente pasó: si algo de lo que aparece en la columna "Qué aportó la IA" lo escribimos nosotros, o viceversa, hay que corregirlo.
