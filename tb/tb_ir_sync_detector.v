`timescale 1ns / 1ps

module tb_ir_sync_detector;

    // Entradas
    reg clk;
    reg reset;
    reg ir_rx;

    // Salidas
    wire ir_sync;
    wire flanco_bajada;
    wire flanco_subida;

    integer error_count = 0;

    // Instancia del modulo a probar (DUT)
    ir_sync_detector uut (
        .clk(clk),
        .reset(reset),
        .ir_rx(ir_rx),
        .ir_sync(ir_sync),
        .flanco_bajada(flanco_bajada),
        .flanco_subida(flanco_subida)
    );

    // Reloj de 100 MHz (periodo = 10 ns)
    always #5 clk = ~clk;

    initial begin
        $display("=== Iniciando simulacion de ir_sync_detector ===");

        clk   = 1'b0;
        reset = 1'b1;
        ir_rx = 1'b1; // Sensor IR en reposo (activo en bajo)

        // --- Caso 1: Reset asincrono y reposo sin falsos flancos ---
        #12;
        reset = 1'b0;
        #1;

        if (ir_sync === 1'b1 && flanco_bajada === 1'b0 && flanco_subida === 1'b0) begin
            $display("[PASS] Caso 1 (Reset y reposo): ir_sync=1, bajada=0, subida=0");
        end else begin
            $display("[FAIL] Caso 1 (Reset y reposo): ir_sync=%b, bajada=%b, subida=%b", ir_sync, flanco_bajada, flanco_subida);
            error_count = error_count + 1;
        end

        // --- Caso 2: Flanco de bajada (latencia de 2 FF y pulso exacto de 1 ciclo) ---
        @(posedge clk);
        #1;
        ir_rx = 1'b0;

        // Ciclo 1 tras cambio: FF1 captura 0, FF2 aun mantiene 1
        @(posedge clk);
        #1;
        if (ir_sync === 1'b1 && flanco_bajada === 1'b0 && flanco_subida === 1'b0) begin
            $display("[PASS] Caso 2A (Bajada ciclo 1 - sync FF1): ir_sync=1, bajada=0");
        end else begin
            $display("[FAIL] Caso 2A (Bajada ciclo 1 - sync FF1): ir_sync=%b, bajada=%b, subida=%b", ir_sync, flanco_bajada, flanco_subida);
            error_count = error_count + 1;
        end

        // Ciclo 2 tras cambio: FF2 pasa a 0 y se activa flanco_bajada por 1 ciclo
        @(posedge clk);
        #1;
        if (ir_sync === 1'b0 && flanco_bajada === 1'b1 && flanco_subida === 1'b0) begin
            $display("[PASS] Caso 2B (Bajada ciclo 2 - pulso ON): ir_sync=0, bajada=1");
        end else begin
            $display("[FAIL] Caso 2B (Bajada ciclo 2 - pulso ON): ir_sync=%b, bajada=%b, subida=%b", ir_sync, flanco_bajada, flanco_subida);
            error_count = error_count + 1;
        end

        // Ciclo 3 tras cambio: flanco_bajada regresa a 0 aunque ir_rx siga en 0
        @(posedge clk);
        #1;
        if (ir_sync === 1'b0 && flanco_bajada === 1'b0 && flanco_subida === 1'b0) begin
            $display("[PASS] Caso 2C (Bajada ciclo 3 - pulso OFF): ir_sync=0, bajada=0");
        end else begin
            $display("[FAIL] Caso 2C (Bajada ciclo 3 - pulso OFF): ir_sync=%b, bajada=%b, subida=%b", ir_sync, flanco_bajada, flanco_subida);
            error_count = error_count + 1;
        end

        // --- Caso 3: Flanco de subida (latencia de 2 FF y pulso exacto de 1 ciclo) ---
        ir_rx = 1'b1;

        // Ciclo 1 tras subida: FF1 captura 1, FF2 aun mantiene 0
        @(posedge clk);
        #1;
        if (ir_sync === 1'b0 && flanco_subida === 1'b0 && flanco_bajada === 1'b0) begin
            $display("[PASS] Caso 3A (Subida ciclo 1 - sync FF1): ir_sync=0, subida=0");
        end else begin
            $display("[FAIL] Caso 3A (Subida ciclo 1 - sync FF1): ir_sync=%b, subida=%b, bajada=%b", ir_sync, flanco_subida, flanco_bajada);
            error_count = error_count + 1;
        end

        // Ciclo 2 tras subida: FF2 pasa a 1 y se activa flanco_subida por 1 ciclo
        @(posedge clk);
        #1;
        if (ir_sync === 1'b1 && flanco_subida === 1'b1 && flanco_bajada === 1'b0) begin
            $display("[PASS] Caso 3B (Subida ciclo 2 - pulso ON): ir_sync=1, subida=1");
        end else begin
            $display("[FAIL] Caso 3B (Subida ciclo 2 - pulso ON): ir_sync=%b, subida=%b, bajada=%b", ir_sync, flanco_subida, flanco_bajada);
            error_count = error_count + 1;
        end

        // Ciclo 3 tras subida: flanco_subida regresa a 0
        @(posedge clk);
        #1;
        if (ir_sync === 1'b1 && flanco_subida === 1'b0 && flanco_bajada === 1'b0) begin
            $display("[PASS] Caso 3C (Subida ciclo 3 - pulso OFF): ir_sync=1, subida=0");
        end else begin
            $display("[FAIL] Caso 3C (Subida ciclo 3 - pulso OFF): ir_sync=%b, subida=%b, bajada=%b", ir_sync, flanco_subida, flanco_bajada);
            error_count = error_count + 1;
        end

        // --- Caso 4: Caso limite - Glitch sub-ciclo entre flancos de reloj (filtrado) ---
        ir_rx = 1'b0;
        #3;
        ir_rx = 1'b1;

        repeat (3) @(posedge clk);
        #1;
        if (ir_sync === 1'b1 && flanco_bajada === 1'b0 && flanco_subida === 1'b0) begin
            $display("[PASS] Caso 4 (Glitch sub-ciclo filtrado): ir_sync=1, bajada=0, subida=0");
        end else begin
            $display("[FAIL] Caso 4 (Glitch sub-ciclo filtrado): ir_sync=%b, bajada=%b, subida=%b", ir_sync, flanco_bajada, flanco_subida);
            error_count = error_count + 1;
        end

        // --- Caso 5: Caso limite - Reset asincrono con linea en bajo (sin falso flanco_subida) ---
        ir_rx = 1'b0;
        repeat (2) @(posedge clk);
        #1;

        reset = 1'b1;
        #2;
        if (ir_sync === 1'b1 && flanco_subida === 1'b0 && flanco_bajada === 1'b0) begin
            $display("[PASS] Caso 5 (Reset asincrono en nivel bajo): ir_sync=1, subida=0, bajada=0");
        end else begin
            $display("[FAIL] Caso 5 (Reset asincrono en nivel bajo): ir_sync=%b, subida=%b, bajada=%b", ir_sync, flanco_subida, flanco_bajada);
            error_count = error_count + 1;
        end

        reset = 1'b0;
        ir_rx = 1'b1;

        $display("=== Simulacion Finalizada ===");
        if (error_count == 0) begin
            $display("EXITO: TODOS LOS TESTS PASARON (0 ERRORES)");
        end else begin
            $display("ERROR: SE ENCONTRARON %0d FALLOS", error_count);
        end
        $finish;
    end

endmodule