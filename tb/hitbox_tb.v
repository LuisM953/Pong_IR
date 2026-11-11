`timescale 1ns / 1ps

module hitbox_tb;

    reg [9:0] p1_y;
    reg [9:0] p2_y;
    reg [9:0] ball_x;
    reg [9:0] ball_y;

    wire hit_p1;
    wire hit_p2;

    integer error_count = 0;

    hitbox uut (
        .p1_y(p1_y),
        .p2_y(p2_y),
        .ball_x(ball_x),
        .ball_y(ball_y),
        .hit_p1(hit_p1),
        .hit_p2(hit_p2)
    );

    task check_hit;
        input [9:0] test_p1_y;
        input [9:0] test_p2_y;
        input [9:0] test_ball_x;
        input [9:0] test_ball_y;
        input expected_hit_p1;
        input expected_hit_p2;
        input [255:0] test_name;
        begin
            p1_y   = test_p1_y;
            p2_y   = test_p2_y;
            ball_x = test_ball_x;
            ball_y = test_ball_y;

            #10; // Retardo combinacional puro

            if (hit_p1 !== expected_hit_p1 || hit_p2 !== expected_hit_p2) begin
                $display("[FAIL] %-60s | ball:(%0d,%0d) | hit_p1:%b (Esp:%b) hit_p2:%b (Esp:%b)",
                         test_name, test_ball_x, test_ball_y, hit_p1, expected_hit_p1, hit_p2, expected_hit_p2);
                error_count = error_count + 1;
            end else begin
                $display("[PASS] %-60s | ball:(%0d,%0d) | hit_p1:%b hit_p2:%b",
                         test_name, test_ball_x, test_ball_y, hit_p1, hit_p2);
            end
        end
    endtask

    initial begin
        $display("=== Iniciando simulacion de hitbox ===");

        // --- 1. Estado sin colision general ---
        check_hit(10'd200, 10'd200, 10'd100, 10'd200, 1'b0, 1'b0, "Fuera de alcance general");

        // =========================================================================
        // 2. PALETA 1 (X: 20..29, Y: 200..279) - Pruebas de Límites (Dentro/Fuera)
        // =========================================================================
        
        // --- Eje X ---
        check_hit(10'd200, 10'd200, 10'd20,  10'd235, 1'b1, 1'b0, "P1: Borde izquierdo dentro (x=20)");
        check_hit(10'd200, 10'd200, 10'd19,  10'd235, 1'b0, 1'b0, "P1: Borde izquierdo fuera (x=19)");
        
        check_hit(10'd200, 10'd200, 10'd29,  10'd235, 1'b1, 1'b0, "P1: Borde derecho dentro (x=29)");
        check_hit(10'd200, 10'd200, 10'd30,  10'd235, 1'b0, 1'b0, "P1: Borde derecho fuera (x=30)");

        // --- Eje Y (con p1_y = 200, y_valida de la pelota: 191..279) ---
        check_hit(10'd200, 10'd200, 10'd20,  10'd191, 1'b1, 1'b0, "P1: Borde superior dentro (y=191)");
        check_hit(10'd200, 10'd200, 10'd20,  10'd190, 1'b0, 1'b0, "P1: Borde superior fuera (y=190)");

        check_hit(10'd200, 10'd200, 10'd20,  10'd279, 1'b1, 1'b0, "P1: Borde inferior dentro (y=279)");
        check_hit(10'd200, 10'd200, 10'd20,  10'd280, 1'b0, 1'b0, "P1: Borde inferior fuera (y=280)");


        // =========================================================================
        // 3. PALETA 2 (X: 601..610, Y: 200..279) - Pruebas de Límites (Dentro/Fuera)
        // =========================================================================

        // --- Eje X ---
        check_hit(10'd200, 10'd200, 10'd601, 10'd235, 1'b0, 1'b1, "P2: Borde izquierdo dentro (x=601)");
        check_hit(10'd200, 10'd200, 10'd600, 10'd235, 1'b0, 1'b0, "P2: Borde izquierdo fuera (x=600)");

        check_hit(10'd200, 10'd200, 10'd610, 10'd235, 1'b0, 1'b1, "P2: Borde derecho dentro (x=610)");
        check_hit(10'd200, 10'd200, 10'd611, 10'd235, 1'b0, 1'b0, "P2: Borde derecho fuera (x=611)");

        // --- Eje Y ---
        check_hit(10'd200, 10'd200, 10'd610, 10'd191, 1'b0, 1'b1, "P2: Borde superior dentro (y=191)");
        check_hit(10'd200, 10'd200, 10'd610, 10'd190, 1'b0, 1'b0, "P2: Borde superior fuera (y=190)");

        check_hit(10'd200, 10'd200, 10'd610, 10'd279, 1'b0, 1'b1, "P2: Borde inferior dentro (y=279)");
        check_hit(10'd200, 10'd200, 10'd610, 10'd280, 1'b0, 1'b0, "P2: Borde inferior fuera (y=280)");


        // =========================================================================
        // 4. PALETA 1 DESPLAZADA (P1_Y = 300, P2_Y = 200, y_valida: 291..379)
        // =========================================================================
        check_hit(10'd300, 10'd200, 10'd20,  10'd290, 1'b0, 1'b0, "P1 Desplazado (y=300): Fuera por arriba (y=290)");
        check_hit(10'd300, 10'd200, 10'd20,  10'd291, 1'b1, 1'b0, "P1 Desplazado (y=300): Borde superior dentro (y=291)");
        check_hit(10'd300, 10'd200, 10'd20,  10'd379, 1'b1, 1'b0, "P1 Desplazado (y=300): Borde inferior dentro (y=379)");
        check_hit(10'd300, 10'd200, 10'd20,  10'd380, 1'b0, 1'b0, "P1 Desplazado (y=300): Fuera por abajo (y=380)");


        // =========================================================================
        // 5. PALETA 2 DESPLAZADA (P1_Y = 200, P2_Y = 300, y_valida: 291..379)
        // =========================================================================
        check_hit(10'd200, 10'd300, 10'd610, 10'd290, 1'b0, 1'b0, "P2 Desplazado (y=300): Fuera por arriba (y=290)");
        check_hit(10'd200, 10'd300, 10'd610, 10'd291, 1'b0, 1'b1, "P2 Desplazado (y=300): Borde superior dentro (y=291)");
        check_hit(10'd200, 10'd300, 10'd610, 10'd379, 1'b0, 1'b1, "P2 Desplazado (y=300): Borde inferior dentro (y=379)");
        check_hit(10'd200, 10'd300, 10'd610, 10'd380, 1'b0, 1'b0, "P2 Desplazado (y=300): Fuera por abajo (y=380)");


        // --- Resumen Final ---
        $display("=== Simulacion Finalizada ===");
        if (error_count == 0) begin
            $display("EXITO: TODOS LOS TESTS PASARON (0 ERRORES)");
        end else begin
            $display("ERROR: SE ENCONTRARON %0d FALLOS", error_count);
        end

        $finish;
    end

endmodule