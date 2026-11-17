`timescale 1ns / 1ps

module tb_ball_move;

    // 1. Declaraciones
    reg clk;
    reg reset;
    reg frame_tick;
    
    // Estímulos independientes para aislar ball_move
    reg hit_p1_reg;
    reg hit_p2_reg;

    // MODIFICADO: Cables de salida para monitorear los goles
    wire goal_p1;
    wire goal_p2;

    wire [9:0] ball_x;
    wire [9:0] ball_y;

    integer error_count = 0;
    integer i;

    // MODIFICADO: Variables para contar goles y detectar pulsos consecutivos en el bucle largo
    integer count_goal_p1 = 0;
    integer count_goal_p2 = 0;
    reg prev_goal_p1 = 0;
    reg prev_goal_p2 = 0;

    // 2. Instancia del modulo a probar (DUT) conectada a los registros de control
    ball_move uut (
        .clk(clk),
        .reset(reset),
        .frame_tick(frame_tick),
        .hit_p1(hit_p1_reg),
        .hit_p2(hit_p2_reg),
        .goal_p1(goal_p1), // MODIFICADO: Conexion de salida gol jugador 1
        .goal_p2(goal_p2), // MODIFICADO: Conexion de salida gol jugador 2
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
        hit_p1_reg = 0;
        hit_p2_reg = 0;

        // -------------------------------------------------------------
        // 1. Reset
        // -------------------------------------------------------------
        reset = 1;
        #20;
        reset = 0;
        #10;

        // MODIFICADO: Verificar tambien que las señales de gol inicien en 0
        if (ball_x !== 10'd315 || ball_y !== 10'd235 || uut.dir_x !== 1'b1 || uut.dir_y !== 1'b1 || goal_p1 !== 1'b0 || goal_p2 !== 1'b0) begin
            $display("[FAIL] Reset inicial | (x,y): (%0d,%0d), dir_x:%b, dir_y:%b, g1:%b, g2:%b",
                     ball_x, ball_y, uut.dir_x, uut.dir_y, goal_p1, goal_p2);
            error_count = error_count + 1;
        end else begin
            $display("[PASS] Reset inicial | (x,y): (315,235), dir_x:1, dir_y:1, goles:0");
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
        check_ball(1'b1, 10'd309, 10'd229, "Paso 3 (Frame 3)");

        // Desactivar frame_tick antes de forzar estados fuera del flanco
        frame_tick = 0;
        #10;

        // -------------------------------------------------------------
        // 4 y 5. Pruebas de Rebote (Hitbox aislada) y Ajustes exactos
        // -------------------------------------------------------------
        $display("--- Pruebas de Colision y Rebote con Paletas ---");

        // --- Caso A: Golpe en Paleta 1 (ball_x en zona de golpe = 29, y esperada = 202 por dir_y = abajo) ---
        uut.ball_x = 10'd29; uut.ball_y = 10'd200; uut.dir_x = 1'b1; uut.dir_y = 1'b0;
        hit_p1_reg = 1'b1; // Activar golpe P1
        #10;
        check_ball(1'b1, 10'd30, 10'd202, "Golpe P1: ball_x=29 -> ajusta a 30");
        if (uut.dir_x !== 1'b0) begin
            $display("[FAIL] Golpe P1: dir_x no invirtio a 0");
            error_count = error_count + 1;
        end
        hit_p1_reg = 0; // Limpiar estímulo
        frame_tick = 0; #10;

        // --- Caso B: Golpe en Paleta 2 (ball_x en zona de golpe = 601, y esperada = 202) ---
        uut.ball_x = 10'd601; uut.ball_y = 10'd200; uut.dir_x = 1'b0; uut.dir_y = 1'b0;
        hit_p2_reg = 1'b1; // Activar golpe P2
        #10;
        check_ball(1'b1, 10'd600, 10'd202, "Golpe P2: ball_x=601 -> ajusta a 600");
        if (uut.dir_x !== 1'b1) begin
            $display("[FAIL] Golpe P2: dir_x no invirtio a 1");
            error_count = error_count + 1;
        end
        hit_p2_reg = 0; // Limpiar estímulo
        frame_tick = 0; #10;

        // --- Caso C: Pelota alejándose de P1 (hit_p1_reg activo pero dir_x = 0, no debe rebotar) ---
        uut.ball_x = 10'd25; uut.ball_y = 10'd200; uut.dir_x = 1'b0; uut.dir_y = 1'b0;
        hit_p1_reg = 1'b1; // hit activo por posición, pero se aleja
        #10;
        check_ball(1'b1, 10'd27, 10'd202, "Sin rebote P1: Pelota alejandose");
        if (uut.dir_x !== 1'b0) begin
            $display("[FAIL] Sin rebote P1: dir_x cambio indebidamente");
            error_count = error_count + 1;
        end
        hit_p1_reg = 0;
        frame_tick = 0; #10;

        // --- Caso D: Pelota alejándose de P2 (hit_p2_reg activo pero dir_x = 1, no debe rebotar) ---
        uut.ball_x = 10'd605; uut.ball_y = 10'd200; uut.dir_x = 1'b1; uut.dir_y = 1'b0;
        hit_p2_reg = 1'b1; // hit activo por posición, pero se aleja
        #10;
        check_ball(1'b1, 10'd603, 10'd202, "Sin rebote P2: Pelota alejandose");
        if (uut.dir_x !== 1'b1) begin
            $display("[FAIL] Sin rebote P2: dir_x cambio indebidamente");
            error_count = error_count + 1;
        end
        hit_p2_reg = 0;
        frame_tick = 0; #10;

        // MODIFICADO: Pruebas de Goles y Reinicio al Centro (reemplazan el antiguo rebote lateral)
        $display("--- Pruebas de Goles en Paredes Laterales y Reinicio ---");

        // --- MODIFICADO: 1. Casi gol izquierdo (ball_x = 14, dir_x = 1 -> va a x = 12 sin pulso ni reinicio) ---
        uut.ball_x = 10'd14; uut.ball_y = 10'd200; uut.dir_x = 1'b1; uut.dir_y = 1'b0;
        #10;
        check_ball(1'b1, 10'd12, 10'd202, "Casi gol Izq (14->12): Sin pulso ni reinicio");
        if (goal_p1 !== 1'b0 || goal_p2 !== 1'b0 || uut.dir_x !== 1'b1) begin
            $display("[FAIL] Casi gol Izq: goal_p1=%b, goal_p2=%b, dir_x=%b (Esperado: 0, 0, 1)", goal_p1, goal_p2, uut.dir_x);
            error_count = error_count + 1;
        end
        frame_tick = 0; #10;

        // --- Pared Izquierda (X_MIN = 10) -> Gol para P2, reinicio a (315, 235), mantiene dir_x = 1 ---
        uut.ball_x = 10'd12; uut.ball_y = 10'd200; uut.dir_x = 1'b1; uut.dir_y = 1'b0;
        #10;
        check_ball(1'b1, 10'd315, 10'd235, "Gol P2 (Exacto 12): Centro (315,235)");
        if (goal_p2 !== 1'b1 || goal_p1 !== 1'b0 || uut.dir_x !== 1'b1) begin
            $display("[FAIL] Gol P2 Exacto: goal_p2=%b (Esp:1), goal_p1=%b (Esp:0), dir_x=%b (Esp:1)", goal_p2, goal_p1, uut.dir_x);
            error_count = error_count + 1;
        end
        // MODIFICADO: Verificar que el pulso goal_p2 dura un solo ciclo de reloj
        frame_tick = 0;
        @(posedge clk); #1;
        if (goal_p2 !== 1'b0) begin
            $display("[FAIL] Gol P2: Pulso goal_p2 no se limpio en el siguiente ciclo");
            error_count = error_count + 1;
        end

        // --- Pared Izquierda Overshoot (ball_x = 11) ---
        uut.ball_x = 10'd11; uut.ball_y = 10'd200; uut.dir_x = 1'b1; uut.dir_y = 1'b0;
        #10;
        check_ball(1'b1, 10'd315, 10'd235, "Gol P2 (Overshoot 11): Centro (315,235)");
        if (goal_p2 !== 1'b1) begin
            $display("[FAIL] Gol P2 Overshoot: goal_p2 no se activo");
            error_count = error_count + 1;
        end
        check_ball(1'b1, 10'd313, 10'd237, "Gol P2: Saque cuadro posterior (313,237)");
        frame_tick = 0; #10;

        // --- MODIFICADO: 2. Casi gol derecho (ball_x = 616, dir_x = 0 -> va a x = 618 sin pulso ni reinicio) ---
        uut.ball_x = 10'd616; uut.ball_y = 10'd200; uut.dir_x = 1'b0; uut.dir_y = 1'b0;
        #10;
        check_ball(1'b1, 10'd618, 10'd202, "Casi gol Der (616->618): Sin pulso ni reinicio");
        if (goal_p1 !== 1'b0 || goal_p2 !== 1'b0 || uut.dir_x !== 1'b0) begin
            $display("[FAIL] Casi gol Der: goal_p1=%b, goal_p2=%b, dir_x=%b (Esperado: 0, 0, 0)", goal_p1, goal_p2, uut.dir_x);
            error_count = error_count + 1;
        end
        frame_tick = 0; #10;

        // --- Pared Derecha (X_MAX = 620) -> Gol para P1, reinicio a (315, 235), mantiene dir_x = 0 ---
        uut.ball_x = 10'd618; uut.ball_y = 10'd200; uut.dir_x = 1'b0; uut.dir_y = 1'b0;
        #10;
        check_ball(1'b1, 10'd315, 10'd235, "Gol P1 (Exacto 618): Centro (315,235)");
        if (goal_p1 !== 1'b1 || goal_p2 !== 1'b0 || uut.dir_x !== 1'b0) begin
            $display("[FAIL] Gol P1 Exacto: goal_p1=%b (Esp:1), goal_p2=%b (Esp:0), dir_x=%b (Esp:0)", goal_p1, goal_p2, uut.dir_x);
            error_count = error_count + 1;
        end
        // MODIFICADO: Verificar que el pulso goal_p1 dura un solo ciclo de reloj
        frame_tick = 0;
        @(posedge clk); #1;
        if (goal_p1 !== 1'b0) begin
            $display("[FAIL] Gol P1: Pulso goal_p1 no se limpio en el siguiente ciclo");
            error_count = error_count + 1;
        end

        // --- Pared Derecha Overshoot (ball_x = 619) ---
        uut.ball_x = 10'd619; uut.ball_y = 10'd200; uut.dir_x = 1'b0; uut.dir_y = 1'b0;
        #10;
        check_ball(1'b1, 10'd315, 10'd235, "Gol P1 (Overshoot 619): Centro (315,235)");
        if (goal_p1 !== 1'b1) begin
            $display("[FAIL] Gol P1 Overshoot: goal_p1 no se activo");
            error_count = error_count + 1;
        end
        check_ball(1'b1, 10'd317, 10'd237, "Gol P1: Saque cuadro posterior (317,237)");
        frame_tick = 0; #10;

        // --- Pared Superior (Y_MIN = 10) ---
        uut.ball_x = 10'd300; uut.ball_y = 10'd12; uut.dir_x = 1'b0; uut.dir_y = 1'b1;
        #10;
        check_ball(1'b1, 10'd302, 10'd10, "Rebote Sup: Aterrizaje exacto (12->10)");
        if (uut.dir_y !== 1'b0) begin
            $display("[FAIL] Rebote Sup Exacto: dir_y no cambio a 0");
            error_count = error_count + 1;
        end
        frame_tick = 0; #10;

        uut.ball_x = 10'd300; uut.ball_y = 10'd11; uut.dir_x = 1'b0; uut.dir_y = 1'b1;
        #10;
        check_ball(1'b1, 10'd302, 10'd10, "Rebote Sup: Overshoot (11->10)");
        check_ball(1'b1, 10'd304, 10'd12, "Rebote Sup: Cuadro posterior (12)");
        frame_tick = 0; #10;

        // --- Pared Inferior (Y_MAX = 460) ---
        uut.ball_x = 10'd300; uut.ball_y = 10'd458; uut.dir_x = 1'b0; uut.dir_y = 1'b0;
        #10;
        check_ball(1'b1, 10'd302, 10'd460, "Rebote Inf: Aterrizaje exacto (458->460)");
        if (uut.dir_y !== 1'b1) begin
            $display("[FAIL] Rebote Inf Exacto: dir_y no cambio a 1");
            error_count = error_count + 1;
        end
        frame_tick = 0; #10;

        uut.ball_x = 10'd300; uut.ball_y = 10'd459; uut.dir_x = 1'b0; uut.dir_y = 1'b0;
        #10;
        check_ball(1'b1, 10'd302, 10'd460, "Rebote Inf: Overshoot (459->460)");
        check_ball(1'b1, 10'd304, 10'd458, "Rebote Inf: Cuadro posterior (458)");

        // -------------------------------------------------------------
        // 6. Bucle largo (Simulacion de 2000 cuadros)
        // -------------------------------------------------------------
        $display("--- Bucle Largo (2000 cuadros de simulacion) ---");
        prev_goal_p1 = 0;
        prev_goal_p2 = 0;
        for (i = 0; i < 2000; i = i + 1) begin
            frame_tick = 1;
            @(posedge clk);
            #1;
            
            // Verificar límites espaciales
            if (ball_x < 10'd10 || ball_x > 10'd620 || ball_y < 10'd10 || ball_y > 10'd460) begin
                $display("[FAIL] Bucle largo | Violacion de limites en cuadro %0d: (x,y) = (%0d,%0d)", i, ball_x, ball_y);
                error_count = error_count + 1;
            end

            // MODIFICADO: 3. Contar pulsos de gol y verificar que no haya dos consecutivos
            if (goal_p1) begin
                count_goal_p1 = count_goal_p1 + 1;
                if (prev_goal_p1) begin
                    $display("[FAIL] Bucle largo | Dos pulsos seguidos de goal_p1 en cuadro %0d", i);
                    error_count = error_count + 1;
                end
            end
            if (goal_p2) begin
                count_goal_p2 = count_goal_p2 + 1;
                if (prev_goal_p2) begin
                    $display("[FAIL] Bucle largo | Dos pulsos seguidos de goal_p2 en cuadro %0d", i);
                    error_count = error_count + 1;
                end
            end

            prev_goal_p1 = goal_p1;
            prev_goal_p2 = goal_p2;

            frame_tick = 0;
            @(posedge clk);
        end
        $display("[INFO] Bucle largo finalizado | Goles P1: %0d | Goles P2: %0d", count_goal_p1, count_goal_p2);

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