`timescale 1ns / 1ps

module tb_ball_move;

    // 1. Declaraciones
    reg clk;
    reg reset;
    reg frame_tick;

    wire [9:0] ball_x;
    wire [9:0] ball_y;

    integer error_count = 0;
    integer i;

    // 2. Instancia del modulo a probar (DUT)
    ball_move uut (
        .clk(clk),
        .reset(reset),
        .frame_tick(frame_tick),
        .ball_x(ball_x),
        .ball_y(ball_y)
    );

    // 3. Reloj de 100 MHz (Periodo de 10 ns)
    always #5 clk = ~clk;

    // 4. Task de comprobacion secuencial
    task check_ball;
        input test_tick;
        input [9:0] expected_x;
        input [9:0] expected_y;
        input [255:0] test_name;
        begin
            frame_tick = test_tick;

            @(posedge clk);
            #1; // Lectura 1 ns despues del flanco para evitar condiciones de carrera

            if (ball_x !== expected_x || ball_y !== expected_y) begin
                $display("[FAIL] %-45s | tick:%b | (x,y): (%0d,%0d) - Esperado: (%0d,%0d)", 
                         test_name, frame_tick, ball_x, ball_y, expected_x, expected_y);
                error_count = error_count + 1;
            end else begin
                $display("[PASS] %-45s | tick:%b | (x,y): (%0d,%0d)", 
                         test_name, frame_tick, ball_x, ball_y);
            end
        end
    endtask

    initial begin
        $display("=== Iniciando simulacion de ball_move ===");

        clk = 0;
        frame_tick = 0;

        // -------------------------------------------------------------
        // 1. Reset
        // -------------------------------------------------------------
        reset = 1;
        #20;
        reset = 0;
        #10;

        if (ball_x !== 10'd315 || ball_y !== 10'd235 || uut.dir_x !== 1'b1 || uut.dir_y !== 1'b1) begin
            $display("[FAIL] Reset inicial | (x,y): (%0d,%0d), dir_x:%b, dir_y:%b (Esperado: 315,235, 1,1)",
                     ball_x, ball_y, uut.dir_x, uut.dir_y);
            error_count = error_count + 1;
        end else begin
            $display("[PASS] Reset inicial | (x,y): (315,235), dir_x:1, dir_y:1");
        end

        // -------------------------------------------------------------
        // 2. Sin frame_tick
        // -------------------------------------------------------------
        check_ball(1'b0, 10'd315, 10'd235, "Sin frame_tick (Ciclo 1)");
        check_ball(1'b0, 10'd315, 10'd235, "Sin frame_tick (Ciclo 2)");
        check_ball(1'b0, 10'd315, 10'd235, "Sin frame_tick (Ciclo 3)");

        // -------------------------------------------------------------
        // 3. Movimiento paso a paso (diagonal arriba-izquierda)
        // -------------------------------------------------------------
        check_ball(1'b1, 10'd313, 10'd233, "Paso 1 (Frame 1)");
        check_ball(1'b1, 10'd311, 10'd231, "Paso 2 (Frame 2)");
        check_ball(1'b1, 10'd309, 10'd229, "Paso 3 (Frame 3)"); // CORREGIDO: 1'b1

        // Desactivar frame_tick antes de forzar estados fuera del flanco
        frame_tick = 0;
        #10;

        // -------------------------------------------------------------
        // 4 y 5. Cuatro rebotes y ajuste exacto a limites (Overshoot)
        // -------------------------------------------------------------
        $display("--- Rebotes y Ajuste Exacto a Limites (Overshoot) ---");

        // --- Pared Izquierda (X_MIN = 10) ---
        uut.ball_x = 10'd11;
        uut.dir_x  = 1'b1;
        #10;
        check_ball(1'b1, 10'd10, 10'd227, "Rebote Izq: Ajuste exacto a X_MIN (10)");
        if (uut.dir_x !== 1'b0) begin
            $display("[FAIL] Rebote Izq: dir_x no cambio a 0 (derecha)");
            error_count = error_count + 1;
        end
        check_ball(1'b1, 10'd12, 10'd225, "Rebote Izq: Cuadro posterior (12)");

        frame_tick = 0; #10;

        // --- Pared Derecha (X_MAX = 620) ---
        uut.ball_x = 10'd619;
        uut.dir_x  = 1'b0;
        #10;
        check_ball(1'b1, 10'd620, 10'd223, "Rebote Der: Ajuste exacto a X_MAX (620)");
        if (uut.dir_x !== 1'b1) begin
            $display("[FAIL] Rebote Der: dir_x no cambio a 1 (izquierda)");
            error_count = error_count + 1;
        end
        check_ball(1'b1, 10'd618, 10'd221, "Rebote Der: Cuadro posterior (618)");

        frame_tick = 0; #10;

        // --- Pared Superior (Y_MIN = 10) ---
        uut.ball_y = 10'd11;
        uut.dir_y  = 1'b1;
        #10;
        check_ball(1'b1, 10'd616, 10'd10, "Rebote Sup: Ajuste exacto a Y_MIN (10)");
        if (uut.dir_y !== 1'b0) begin
            $display("[FAIL] Rebote Sup: dir_y no cambio a 0 (abajo)");
            error_count = error_count + 1;
        end
        check_ball(1'b1, 10'd614, 10'd12, "Rebote Sup: Cuadro posterior (12)");

        frame_tick = 0; #10;

        // --- Pared Inferior (Y_MAX = 460) ---
        uut.ball_y = 10'd459;
        uut.dir_y  = 1'b0;
        #10;
        check_ball(1'b1, 10'd612, 10'd460, "Rebote Inf: Ajuste exacto a Y_MAX (460)");
        if (uut.dir_y !== 1'b1) begin
            $display("[FAIL] Rebote Inf: dir_y no cambio a 1 (arriba)");
            error_count = error_count + 1;
        end
        check_ball(1'b1, 10'd610, 10'd458, "Rebote Inf: Cuadro posterior (458)");

        // -------------------------------------------------------------
        // 6. Bucle largo (Simulacion de 2000 cuadros)
        // -------------------------------------------------------------
        $display("--- Bucle Largo (2000 cuadros de simulacion) ---");
        for (i = 0; i < 2000; i = i + 1) begin
            frame_tick = 1;
            @(posedge clk);
            #1;
            if (ball_x < 10'd10 || ball_x > 10'd620 || ball_y < 10'd10 || ball_y > 10'd460) begin
                $display("[FAIL] Bucle largo | Violacion de limites en cuadro %0d: (x,y) = (%0d,%0d)", i, ball_x, ball_y);
                error_count = error_count + 1;
            end
            frame_tick = 0;
            @(posedge clk);
        end

        // -------------------------------------------------------------
        // Resumen Final
        // -------------------------------------------------------------
        $display("=== Simulacion Finalizada ===");
        if (error_count == 0) begin
            $display("EXITO: TODOS LOS TESTS PASARON (0 ERRORES)");
        end else begin
            $display("ERROR: SE ENCONTRARON %0d FALLOS", error_count);
        end

        $finish;
    end

endmodule