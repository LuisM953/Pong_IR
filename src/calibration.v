`timescale 1ns/1ps
// calibracion.v
// Pantalla de calibracion para el auto-ajuste del monitor VGA.
//
// Durante los primeros CALIB_FRAMES cuadros despues del reset, la zona visible
// (video_on = 1) se envia completamente blanca y el blanking en negro. Asi el
// monitor detecta los bordes reales de la imagen (640x480). Al terminar, la
// salida pasa a mostrar la imagen del juego (rgb_juego).
//
// CALIB_FRAMES = 180 son ~3 s a ~60 Hz. Con CALIB_FRAMES = 0 no hay calibracion
// (util en simulacion para probar el juego sin esperar).
module calibration #(
    parameter CALIB_FRAMES = 180
) (
    input  wire        clk,
    input  wire        reset,
    input  wire        frame_tick,   // un pulso por cuadro (de vga_sync)
    input  wire        video_on,     // 1 = zona visible
    input  wire [11:0] rgb_juego,    // imagen del juego (de pixel_gen)
    output wire        calibrando,   // 1 mientras dura la calibracion
    output wire [11:0] rgb           // salida final hacia el conector VGA
);
    // Ancho del contador: suficiente para contar hasta CALIB_FRAMES.
    // El +2 evita un ancho de 0 bits cuando CALIB_FRAMES = 0.
    localparam W = $clog2(CALIB_FRAMES + 2);

    reg [W-1:0] frames;

    // Cuenta cuadros y se detiene al llegar a CALIB_FRAMES.
    always @(posedge clk) begin
        if (reset)
            frames <= 0;
        else if (frame_tick && calibrando)
            frames <= frames + 1'b1;
    end

    assign calibrando = (frames < CALIB_FRAMES);

    // Multiplexor de salida: blanco/negro durante la calibracion, juego despues.
    assign rgb = calibrando ? (video_on ? 12'hFFF : 12'h000) : rgb_juego;

endmodule
