`timescale 1ns/1ps
// calibration_tb.v
// Prueba el modulo calibracion con tres valores de CALIB_FRAMES:
//   - 0   : sin calibracion, la salida es siempre la imagen del juego
//   - 3   : valor pequeno para ver la transicion completa
//   - 180 : valor por defecto (el de la tarjeta)
// Los tres reciben los mismos estimulos.
module calibration_tb;

    reg         clk = 0;
    reg         reset = 1;
    reg         frame_tick = 0;
    reg         video_on = 0;
    reg  [11:0] rgb_juego = 12'h0F0;

    wire        cal_0,  cal_3,  cal_180;
    wire [11:0] rgb_0,  rgb_3,  rgb_180;

    integer errores = 0;

    always #5 clk = ~clk;   // 100 MHz

    calibration #(.CALIB_FRAMES(0))   dut0   (.clk(clk), .reset(reset), .frame_tick(frame_tick),
        .video_on(video_on), .rgb_juego(rgb_juego), .calibrando(cal_0),   .rgb(rgb_0));
    calibration #(.CALIB_FRAMES(3))   dut3   (.clk(clk), .reset(reset), .frame_tick(frame_tick),
        .video_on(video_on), .rgb_juego(rgb_juego), .calibrando(cal_3),   .rgb(rgb_3));
    calibration                       dut180 (.clk(clk), .reset(reset), .frame_tick(frame_tick),
        .video_on(video_on), .rgb_juego(rgb_juego), .calibrando(cal_180), .rgb(rgb_180));

    // ---------- utilidades ----------
    task revisar(input [8*48-1:0] caso, input [11:0] obtenido, input [11:0] esperado);
        if (obtenido !== esperado) begin
            $display("ERROR  %0s: rgb = %h, esperado %h", caso, obtenido, esperado);
            errores = errores + 1;
        end
    endtask

    task revisar_bit(input [8*48-1:0] caso, input obtenido, input esperado);
        if (obtenido !== esperado) begin
            $display("ERROR  %0s: = %b, esperado %b", caso, obtenido, esperado);
            errores = errores + 1;
        end
    endtask

    // Un pulso de frame_tick de un ciclo de reloj.
    task un_cuadro;
        begin
            @(negedge clk) frame_tick = 1;
            @(negedge clk) frame_tick = 0;
        end
    endtask

    // Revisa la salida de un DUT con video_on = 1 y = 0.
    // Si calibra: blanco / negro. Si no: rgb_juego en ambos casos.
    task revisar_salida(input [8*48-1:0] caso, input calibra, input integer cual);
        reg [11:0] r;
        begin
            video_on = 1; #1;
            r = (cual == 0) ? rgb_0 : (cual == 3) ? rgb_3 : rgb_180;
            revisar(caso, r, calibra ? 12'hFFF : rgb_juego);
            video_on = 0; #1;
            r = (cual == 0) ? rgb_0 : (cual == 3) ? rgb_3 : rgb_180;
            revisar(caso, r, calibra ? 12'h000 : rgb_juego);
        end
    endtask

    integer i;

    initial begin
        $dumpfile("calibration_tb.vcd");
        $dumpvars(0, calibration_tb);

        // ---------- Caso 1: durante el reset ----------
        repeat (2) @(negedge clk);
        revisar_bit("reset: calibrando (N=0)",   cal_0,   1'b0);
        revisar_bit("reset: calibrando (N=3)",   cal_3,   1'b1);
        revisar_bit("reset: calibrando (N=180)", cal_180, 1'b1);
        revisar_salida("reset (N=3)",   1, 3);
        revisar_salida("reset (N=180)", 1, 180);
        revisar_salida("reset (N=0)",   0, 0);

        // Reset tiene prioridad sobre frame_tick.
        un_cuadro;
        revisar_bit("reset+tick: no cuenta (N=3)", dut3.frames == 0, 1'b1);
        @(negedge clk) reset = 0;

        // ---------- Caso 2: rgb_juego no se filtra durante la calibracion ----------
        rgb_juego = 12'hABC; revisar_salida("calib ignora rgb_juego (N=3)", 1, 3);
        rgb_juego = 12'h000; revisar_salida("calib ignora rgb_juego=0 (N=3)", 1, 3);
        rgb_juego = 12'h0F0;

        // ---------- Caso 3: sin frame_tick no avanza ----------
        repeat (20) @(negedge clk);
        revisar_bit("sin tick: frames=0 (N=3)", dut3.frames == 0, 1'b1);

        // ---------- Caso 4: limite N-1 -> N (N=3) ----------
        un_cuadro; un_cuadro;                       // 2 cuadros = N-1
        revisar_bit("N-1 cuadros: calibrando (N=3)", cal_3, 1'b1);
        revisar_salida("N-1 cuadros (N=3)", 1, 3);
        un_cuadro;                                  // 3 cuadros = N
        revisar_bit("N cuadros: termina (N=3)", cal_3, 1'b0);
        revisar_salida("N cuadros (N=3)", 0, 3);

        // ---------- Caso 5: el contador se detiene ----------
        for (i = 0; i < 10; i = i + 1) un_cuadro;
        revisar_bit("contador detenido en 3", dut3.frames == 3, 1'b1);
        revisar_bit("sigue sin calibrar (N=3)", cal_3, 1'b0);

        // ---------- Caso 6: N=0 nunca calibra ----------
        revisar_bit("N=0 nunca calibra", cal_0, 1'b0);
        revisar_bit("N=0 contador en 0", dut0.frames == 0, 1'b1);
        revisar_salida("N=0 muestra juego", 0, 0);

        // ---------- Caso 7: N=180 (valor por defecto) ----------
        // Ya van 13 cuadros; completar hasta 179 y luego 180.
        for (i = 13; i < 179; i = i + 1) un_cuadro;
        revisar_bit("179 cuadros: calibrando (N=180)", cal_180, 1'b1);
        un_cuadro;
        revisar_bit("180 cuadros: termina (N=180)", cal_180, 1'b0);
        revisar_salida("180 cuadros (N=180)", 0, 180);
        for (i = 0; i < 100; i = i + 1) un_cuadro;  // pasaria de 255 si no se detuviera
        revisar_bit("contador detenido en 180", dut180.frames == 180, 1'b1);
        revisar_bit("sigue sin calibrar (N=180)", cal_180, 1'b0);

        // ---------- Caso 8: un reset reinicia la calibracion ----------
        @(negedge clk) reset = 1;
        @(negedge clk) reset = 0;
        revisar_bit("tras reset: calibra de nuevo (N=3)",   cal_3,   1'b1);
        revisar_bit("tras reset: calibra de nuevo (N=180)", cal_180, 1'b1);
        revisar_salida("tras reset (N=3)", 1, 3);
        un_cuadro; un_cuadro; un_cuadro;
        revisar_bit("tras reset + 3 cuadros (N=3)", cal_3, 1'b0);

        if (errores == 0) $display("calibration_tb: TODAS LAS PRUEBAS PASARON");
        else              $display("calibration_tb: %0d ERRORES", errores);
        $finish;
    end

endmodule
