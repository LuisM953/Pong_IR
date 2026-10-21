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
| 2026-10-21 | Bandera `medido` en el testbench | Escribí las 3 líneas (por ahorrar tiempo) | Revisión y prueba con diseño roto | tb/vga_sync_tb.v |
