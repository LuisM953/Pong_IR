`timescale 1ns / 1ps

module tb_ir_contador_tiempo;

    // Entradas
    reg clk;
    reg reset;
    reg flanco_bajada;
    reg flanco_subida;

    // Salida
    wire [19:0] cuenta_actual;

    integer error_count = 0;

    // Instancia del modulo a probar (DUT)
    ir_contador_tiempo uut (
        .clk(clk),
        .reset(reset),
        .flanco_bajada(flanco_bajada),
        .flanco_subida(flanco_subida),
        .cuenta_actual(cuenta_actual)
    );

    // Reloj de 100 MHz (periodo = 10 ns)
    always #5 clk = ~clk;

    initial begin
        $display("=== Iniciando simulacion de ir_contador_tiempo ===");

        clk           = 1'b0;
        reset         = 1'b1;
        flanco_bajada = 1'b0;
        flanco_subida = 1'b0;

        // --- Caso 1: Reset sincrono inicial ---
        @(posedge clk);
        #1;
        if (cuenta_actual === 20'd0) begin
            $display("[PASS] Caso 1 (Reset inicial): cuenta_actual = %0d", cuenta_actual);
        end else begin
            $display("[FAIL] Caso 1 (Reset inicial): cuenta_actual = %0d (Esp: 0)", cuenta_actual);
            error_count = error_count + 1;
        end

        reset = 1'b0;

        // --- Caso 2: Conteo libre durante 5 ciclos ---
        repeat (5) @(posedge clk);
        #1;
        if (cuenta_actual === 20'd5) begin
            $display("[PASS] Caso 2 (Conteo libre 5 ciclos): cuenta_actual = %0d", cuenta_actual);
        end else begin
            $display("[FAIL] Caso 2 (Conteo libre 5 ciclos): cuenta_actual = %0d (Esp: 5)", cuenta_actual);
            error_count = error_count + 1;
        end

        // --- Caso 3: Reinicio a 0 por flanco_bajada (pulso de 1 ciclo) y reanudacion ---
        flanco_bajada = 1'b1;
        @(posedge clk);
        #1;
        flanco_bajada = 1'b0;

        if (cuenta_actual === 20'd0) begin
            $display("[PASS] Caso 3A (Flanco bajada -> 0): cuenta_actual = %0d", cuenta_actual);
        end else begin
            $display("[FAIL] Caso 3A (Flanco bajada -> 0): cuenta_actual = %0d (Esp: 0)", cuenta_actual);
            error_count = error_count + 1;
        end

        @(posedge clk);
        #1;
        if (cuenta_actual === 20'd1) begin
            $display("[PASS] Caso 3B (Reanudacion tras bajada): cuenta_actual = %0d", cuenta_actual);
        end else begin
            $display("[FAIL] Caso 3B (Reanudacion tras bajada): cuenta_actual = %0d (Esp: 1)", cuenta_actual);
            error_count = error_count + 1;
        end

        // --- Caso 4: Reinicio a 0 por flanco_subida (pulso de 1 ciclo) ---
        repeat (9) @(posedge clk);
        #1;

        flanco_subida = 1'b1;
        @(posedge clk);
        #1;
        flanco_subida = 1'b0;

        if (cuenta_actual === 20'd0) begin
            $display("[PASS] Caso 4 (Flanco subida -> 0): cuenta_actual = %0d", cuenta_actual);
        end else begin
            $display("[FAIL] Caso 4 (Flanco subida -> 0): cuenta_actual = %0d (Esp: 0)", cuenta_actual);
            error_count = error_count + 1;
        end

        // --- Caso 5: Caso limite - flanco_bajada y flanco_subida simultaneos ---
        repeat (3) @(posedge clk);
        #1;

        flanco_bajada = 1'b1;
        flanco_subida = 1'b1;
        @(posedge clk);
        #1;
        flanco_bajada = 1'b0;
        flanco_subida = 1'b0;

        if (cuenta_actual === 20'd0) begin
            $display("[PASS] Caso 5 (Flancos simultaneos): cuenta_actual = %0d", cuenta_actual);
        end else begin
            $display("[FAIL] Caso 5 (Flancos simultaneos): cuenta_actual = %0d (Esp: 0)", cuenta_actual);
            error_count = error_count + 1;
        end

        // --- Caso 6: Caso limite - Desbordamiento de 20 bits (20'hFFFFF -> 0) ---
        uut.cuenta_actual = 20'hFFFFF;
        #1;
        @(posedge clk);
        #1;

        if (cuenta_actual === 20'd0) begin
            $display("[PASS] Caso 6 (Desbordamiento 20 bits): cuenta_actual = %0d", cuenta_actual);
        end else begin
            $display("[FAIL] Caso 6 (Desbordamiento 20 bits): cuenta_actual = %0d (Esp: 0)", cuenta_actual);
            error_count = error_count + 1;
        end

        $display("=== Simulacion Finalizada ===");
        if (error_count == 0) begin
            $display("EXITO: TODOS LOS TESTS PASARON (0 ERRORES)");
        end else begin
            $display("ERROR: SE ENCONTRARON %0d FALLOS", error_count);
        end
        $finish;
    end

endmodule