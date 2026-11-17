`timescale 1ns / 1ps

module score_tb;

    // 1. Declaraciones
    reg clk;
    reg reset;
    reg clear;
    reg goal_p1;
    reg goal_p2;

    wire win_p1;
    wire win_p2;
    wire [3:0] score_p1;
    wire [3:0] score_p2;

    // MODIFICADO: Cables de salida para la segunda instancia con MAX_SCORE por defecto (11)
    wire def_win_p1;
    wire def_win_p2;
    wire [3:0] def_score_p1;
    wire [3:0] def_score_p2;

    integer error_count = 0;
    integer k; // MODIFICADO: Iterador para probar la instancia por defecto hasta 11

    // 2. Instancia principal del modulo bajo prueba (DUT) con MAX_SCORE = 3 para pruebas rapidas
    score #(
        .MAX_SCORE(3)
    ) uut (
        .clk(clk),
        .reset(reset),
        .clear(clear),
        .goal_p1(goal_p1),
        .goal_p2(goal_p2),
        .win_p1(win_p1),
        .win_p2(win_p2),
        .score_p1(score_p1),
        .score_p2(score_p2)
    );

    // MODIFICADO: Segunda instancia sin sobrescribir parametros (usa MAX_SCORE = 11 por defecto)
    score uut_default (
        .clk(clk),
        .reset(reset),
        .clear(clear),
        .goal_p1(goal_p1),
        .goal_p2(goal_p2),
        .win_p1(def_win_p1),
        .win_p2(def_win_p2),
        .score_p1(def_score_p1),
        .score_p2(def_score_p2)
    );

    // 3. Reloj de 100 MHz (Periodo de 10 ns)
    always #5 clk = ~clk;

    // 4. Task de aplicacion de estimulos y verificacion secuencial
    task step_and_check;
        input        t_reset;
        input        t_clear;
        input        t_g1;
        input        t_g2;
        input [3:0]  exp_s1;
        input [3:0]  exp_s2;
        input        exp_w1;
        input        exp_w2;
        input [511:0] test_name; // MODIFICADO: Ampliado a 512 bits (64 caracteres) para evitar recortes
        begin
            reset   = t_reset;
            clear   = t_clear;
            goal_p1 = t_g1;
            goal_p2 = t_g2;

            @(posedge clk);
            #1; // Lectura 1 ns despues del flanco para evitar condiciones de carrera

            if (score_p1 !== exp_s1 || score_p2 !== exp_s2 || win_p1 !== exp_w1 || win_p2 !== exp_w2) begin
                $display("[FAIL] %-58s | P1:%0d (Esp:%0d) P2:%0d (Esp:%0d) | W1:%b (Esp:%b) W2:%b (Esp:%b)",
                         test_name, score_p1, exp_s1, score_p2, exp_s2, win_p1, exp_w1, win_p2, exp_w2);
                error_count = error_count + 1;
            end else begin
                $display("[PASS] %-58s | P1:%0d P2:%0d | W1:%b W2:%b",
                         test_name, score_p1, score_p2, win_p1, win_p2);
            end
        end
    endtask

    initial begin
        $display("=== Iniciando simulacion de score (MAX_SCORE = 3 y Default = 11) ===");

        clk     = 0;
        reset   = 0;
        clear   = 0;
        goal_p1 = 0;
        goal_p2 = 0;

        // -------------------------------------------------------------
        // Caso 1: Reset inicial (marcador 0-0 y win_p1, win_p2 en 0)
        // -------------------------------------------------------------
        step_and_check(1'b1, 1'b0, 1'b0, 1'b0, 4'd0, 4'd0, 1'b0, 1'b0, "1. Reset inicial (0-0)");
        step_and_check(1'b0, 1'b0, 1'b0, 1'b0, 4'd0, 4'd0, 1'b0, 1'b0, "1b. Soltar reset (mantiene 0-0)");

        // -------------------------------------------------------------
        // Caso 2: Primer gol de cada jugador (puntajes asimetricos)
        // -------------------------------------------------------------
        step_and_check(1'b0, 1'b0, 1'b1, 1'b0, 4'd1, 4'd0, 1'b0, 1'b0, "2a. Primer gol P1 (1-0)");
        step_and_check(1'b0, 1'b0, 1'b0, 1'b0, 4'd1, 4'd0, 1'b0, 1'b0, "2b. Ciclo reposo sin goles (1-0)");
        step_and_check(1'b0, 1'b0, 1'b0, 1'b1, 4'd1, 4'd1, 1'b0, 1'b0, "2c. Primer gol P2 (1-1)");

        // -------------------------------------------------------------
        // Caso 3: Llegar a MAX_SCORE - 1 (2-1 -> win sigue en 0)
        // -------------------------------------------------------------
        step_and_check(1'b0, 1'b0, 1'b1, 1'b0, 4'd2, 4'd1, 1'b0, 1'b0, "3. P1 llega a MAX_SCORE-1 (2-1, win=0)");

        // -------------------------------------------------------------
        // Caso 4: Llegar exactamente a MAX_SCORE (3-1 -> win_p1 sube en el mismo flanco)
        // -------------------------------------------------------------
        step_and_check(1'b0, 1'b0, 1'b1, 1'b0, 4'd3, 4'd1, 1'b1, 1'b0, "4. P1 llega a MAX_SCORE (3-1, win_p1=1)");

        // -------------------------------------------------------------
        // Caso 5: Un gol mas despues del maximo (el marcador no pasa de 3)
        // -------------------------------------------------------------
        step_and_check(1'b0, 1'b0, 1'b1, 1'b0, 4'd3, 4'd1, 1'b1, 1'b0, "5. Gol extra a P1 tras ganar (congelado 3-1)");

        // -------------------------------------------------------------
        // Caso 6: Gol del otro jugador despues de que alguien gano (ambos sentidos)
        // -------------------------------------------------------------
        step_and_check(1'b0, 1'b0, 1'b0, 1'b1, 4'd3, 4'd1, 1'b1, 1'b0, "6a. Gol P2 tras victoria de P1 (ignorado 3-1)");

        // MODIFICADO: Caso 6b (Simetrico) -> P2 gana (0-3) y luego llega goal_p1 (debe quedar congelado en 0-3)
        step_and_check(1'b1, 1'b0, 1'b0, 1'b0, 4'd0, 4'd0, 1'b0, 1'b0, "6b_reset. Reset antes de victoria P2 (0-0)");
        step_and_check(1'b0, 1'b0, 1'b0, 1'b1, 4'd0, 4'd1, 1'b0, 1'b0, "6b_step1. Gol 1 de P2 (0-1)");
        step_and_check(1'b0, 1'b0, 1'b0, 1'b1, 4'd0, 4'd2, 1'b0, 1'b0, "6b_step2. Gol 2 de P2 (0-2)");
        step_and_check(1'b0, 1'b0, 1'b0, 1'b1, 4'd0, 4'd3, 1'b0, 1'b1, "6b_step3. P2 gana en 0-3 (win_p2=1)");
        step_and_check(1'b0, 1'b0, 1'b1, 1'b0, 4'd0, 4'd3, 1'b0, 1'b1, "6b. Gol P1 tras victoria de P2 (ignorado 0-3)");

        // -------------------------------------------------------------
        // Caso 9: Reset a mitad de partida (vuelve a 0-0 y banderas bajan)
        // -------------------------------------------------------------
        step_and_check(1'b1, 1'b0, 1'b0, 1'b0, 4'd0, 4'd0, 1'b0, 1'b0, "9. Reset a mitad de partida (0-0, win=0)");

        // -------------------------------------------------------------
        // Caso 7: Los dos goles en el mismo ciclo (ambos suman -> 1-1)
        // -------------------------------------------------------------
        step_and_check(1'b0, 1'b0, 1'b1, 1'b1, 4'd1, 4'd1, 1'b0, 1'b0, "7. Goles simultaneos P1 y P2 (1-1)");

        // -------------------------------------------------------------
        // Caso 8: Pulso de dos ciclos de goal_p2 (cuenta 2 puntos: contrato 1 punto/ciclo)
        // Contrato: score evalua por nivel en cada posedge clk; 2 ciclos en alto = +2 puntos.
        // -------------------------------------------------------------
        step_and_check(1'b0, 1'b0, 1'b0, 1'b1, 4'd1, 4'd2, 1'b0, 1'b0, "8a. Pulso 2 ciclos goal_p2 - Ciclo 1 (1-2)");
        step_and_check(1'b0, 1'b0, 1'b0, 1'b1, 4'd1, 4'd3, 1'b0, 1'b1, "8b. Pulso 2 ciclos goal_p2 - Ciclo 2 (1-3, W2=1)");

        // -------------------------------------------------------------
        // Caso 12: clear desde un estado de victoria (1-3, W2=1 -> 0-0, W2=0)
        // -------------------------------------------------------------
        step_and_check(1'b0, 1'b1, 1'b0, 1'b0, 4'd0, 4'd0, 1'b0, 1'b0, "12. Clear desde victoria P2 (0-0, win=0)");

        // -------------------------------------------------------------
        // Caso 10: reset coincidiendo con goal_p1 y luego con goal_p2 (previo 2-1)
        // -------------------------------------------------------------
        step_and_check(1'b0, 1'b0, 1'b1, 1'b0, 4'd1, 4'd0, 1'b0, 1'b0, "10_prep1. Subir a 1-0");
        step_and_check(1'b0, 1'b0, 1'b1, 1'b1, 4'd2, 4'd1, 1'b0, 1'b0, "10_prep2. Subir a 2-1");
        step_and_check(1'b1, 1'b0, 1'b1, 1'b0, 4'd0, 4'd0, 1'b0, 1'b0, "10a. Reset coincidiendo con goal_p1 (0-0)");

        step_and_check(1'b0, 1'b0, 1'b1, 1'b0, 4'd1, 4'd0, 1'b0, 1'b0, "10_prep3. Subir a 1-0");
        step_and_check(1'b0, 1'b0, 1'b1, 1'b1, 4'd2, 4'd1, 1'b0, 1'b0, "10_prep4. Subir a 2-1");
        step_and_check(1'b1, 1'b0, 1'b0, 1'b1, 4'd0, 4'd0, 1'b0, 1'b0, "10b. Reset coincidiendo con goal_p2 (0-0)");

        // -------------------------------------------------------------
        // Caso 11: clear coincidiendo con goal_p1 y luego con goal_p2 (previo 2-1)
        // -------------------------------------------------------------
        step_and_check(1'b0, 1'b0, 1'b1, 1'b0, 4'd1, 4'd0, 1'b0, 1'b0, "11_prep1. Subir a 1-0");
        step_and_check(1'b0, 1'b0, 1'b1, 1'b1, 4'd2, 4'd1, 1'b0, 1'b0, "11_prep2. Subir a 2-1");
        step_and_check(1'b0, 1'b1, 1'b1, 1'b0, 4'd0, 4'd0, 1'b0, 1'b0, "11a. Clear coincidiendo con goal_p1 (0-0)");

        step_and_check(1'b0, 1'b0, 1'b1, 1'b0, 4'd1, 4'd0, 1'b0, 1'b0, "11_prep3. Subir a 1-0");
        step_and_check(1'b0, 1'b0, 1'b1, 1'b1, 4'd2, 4'd1, 1'b0, 1'b0, "11_prep4. Subir a 2-1");
        step_and_check(1'b0, 1'b1, 1'b0, 1'b1, 4'd0, 4'd0, 1'b0, 1'b0, "11b. Clear coincidiendo con goal_p2 (0-0)");

        // -------------------------------------------------------------
        // Caso 13: Empate en el maximo (ambos llegan a MAX_SCORE=3 en el mismo ciclo)
        // -------------------------------------------------------------
        step_and_check(1'b0, 1'b0, 1'b1, 1'b0, 4'd1, 4'd0, 1'b0, 1'b0, "13_prep1. Subir a 1-0");
        step_and_check(1'b0, 1'b0, 1'b1, 1'b1, 4'd2, 4'd1, 1'b0, 1'b0, "13_prep2. Subir a 2-1");
        step_and_check(1'b0, 1'b0, 1'b0, 1'b1, 4'd2, 4'd2, 1'b0, 1'b0, "13_prep3. Igualar a 2-2");
        step_and_check(1'b0, 1'b0, 1'b1, 1'b1, 4'd3, 4'd3, 1'b1, 1'b1, "13. Empate en MAX_SCORE (3-3, W1=1, W2=1)");

        // -------------------------------------------------------------
        // MODIFICADO: Caso 14: Instancia con MAX_SCORE por defecto (11 / 4'b1011)
        // -------------------------------------------------------------
        $display("--- Probando instancia con MAX_SCORE por defecto (11) ---");
        
        // Reset inicial en ambos modulos
        reset = 1'b1; clear = 1'b0; goal_p1 = 1'b0; goal_p2 = 1'b0;
        @(posedge clk); #1;
        reset = 1'b0;

        // Llevar P1 a 10 puntos y P2 a 4 puntos (puntajes asimetricos)
        for (k = 0; k < 10; k = k + 1) begin
            goal_p1 = 1'b1;
            goal_p2 = (k < 4) ? 1'b1 : 1'b0;
            @(posedge clk); #1;
        end
        goal_p1 = 1'b0; goal_p2 = 1'b0;

        // Verificar umbral previo (10-4 -> def_win_p1 debe seguir en 0)
        if (def_score_p1 !== 4'd10 || def_score_p2 !== 4'd4 || def_win_p1 !== 1'b0 || def_win_p2 !== 1'b0) begin
            $display("[FAIL] 14a. Default MAX_SCORE=11 umbral previo (10-4) | P1:%0d P2:%0d W1:%b W2:%b",
                     def_score_p1, def_score_p2, def_win_p1, def_win_p2);
            error_count = error_count + 1;
        end else begin
            $display("[PASS] 14a. Default MAX_SCORE=11 umbral previo (10-4, W1=0)  | P1:10 P2:4 | W1:0 W2:0");
        end

        // Gol 11 de P1 -> debe subir def_win_p1 a 1 en 11-4
        goal_p1 = 1'b1;
        @(posedge clk); #1;
        goal_p1 = 1'b0;

        if (def_score_p1 !== 4'd11 || def_score_p2 !== 4'd4 || def_win_p1 !== 1'b1 || def_win_p2 !== 1'b0) begin
            $display("[FAIL] 14b. Default MAX_SCORE=11 victoria P1 (11-4)     | P1:%0d P2:%0d W1:%b W2:%b",
                     def_score_p1, def_score_p2, def_win_p1, def_win_p2);
            error_count = error_count + 1;
        end else begin
            $display("[PASS] 14b. Default MAX_SCORE=11 victoria P1 (11-4, W1=1)  | P1:11 P2:4 | W1:1 W2:0");
        end

        // Gol 12 extra de P1 y gol de P2 -> debe saturar y quedar congelado en 11-4
        goal_p1 = 1'b1; goal_p2 = 1'b1;
        @(posedge clk); #1;
        goal_p1 = 1'b0; goal_p2 = 1'b0;

        if (def_score_p1 !== 4'd11 || def_score_p2 !== 4'd4 || def_win_p1 !== 1'b1 || def_win_p2 !== 1'b0) begin
            $display("[FAIL] 14c. Default MAX_SCORE=11 saturacion (11-4)      | P1:%0d P2:%0d W1:%b W2:%b",
                     def_score_p1, def_score_p2, def_win_p1, def_win_p2);
            error_count = error_count + 1;
        end else begin
            $display("[PASS] 14c. Default MAX_SCORE=11 saturacion (congelado 11-4) | P1:11 P2:4 | W1:1 W2:0");
        end

        // -------------------------------------------------------------
        // Resumen Final
        // -------------------------------------------------------------
        $display("=== Simulacion de score Finalizada ===");
        if (error_count == 0) begin
            $display("EXITO: TODOS LOS TESTS PASARON (0 ERRORES).");
        end else begin
            $display("ERROR: SE ENCONTRARON %0d FALLOS", error_count);
        end

        $finish;
    end

endmodule