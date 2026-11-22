`timescale 1ns / 1ps

module tb_ir_shift_register;

    // Entradas
    reg clk;
    reg reset;
    reg shift_en;
    reg shift_in;

    // Salida
    wire [31:0] trama_out;

    // Trama NEC de prueba (~cmd=8'hA8, cmd=8'h57 [START], ~dir=8'hFF, dir=8'h00)
    localparam [31:0] TRAMA_NEC_TEST = 32'hA857FF00;

    integer error_count = 0;
    integer i;

    // Instancia del modulo a probar (DUT)
    ir_shift_register uut (
        .clk(clk),
        .reset(reset),
        .shift_en(shift_en),
        .shift_in(shift_in),
        .trama_out(trama_out)
    );

    // Reloj de 100 MHz (periodo = 10 ns)
    always #5 clk = ~clk;

    initial begin
        $display("=== Iniciando simulacion de ir_shift_register ===");

        clk      = 1'b0;
        reset    = 1'b1;
        shift_en = 1'b0;
        shift_in = 1'b0;

        // --- Caso 1: Reset sincrono inicial ---
        @(posedge clk);
        #1;
        if (trama_out === 32'h00000000) begin
            $display("[PASS] Caso 1 (Reset inicial): trama_out = %h", trama_out);
        end else begin
            $display("[FAIL] Caso 1 (Reset inicial): trama_out = %h (Esp: 00000000)", trama_out);
            error_count = error_count + 1;
        end

        reset = 1'b0;

        // --- Caso 2: Retencion en 0 cuando shift_en = 0 aunque shift_in = 1 ---
        shift_in = 1'b1;
        repeat (4) @(posedge clk);
        #1;
        if (trama_out === 32'h00000000) begin
            $display("[PASS] Caso 2 (Bloqueo shift_en=0): trama_out = %h", trama_out);
        end else begin
            $display("[FAIL] Caso 2 (Bloqueo shift_en=0): trama_out = %h (Esp: 00000000)", trama_out);
            error_count = error_count + 1;
        end

        // --- Caso 3: Desplazamiento a la derecha (primer bit entra por MSB trama_out[31]) ---
        shift_en = 1'b1;
        shift_in = 1'b1;
        @(posedge clk);
        #1;
        shift_en = 1'b0;

        if (trama_out === 32'h80000000) begin
            $display("[PASS] Caso 3 (Primer bit por MSB): trama_out = %h", trama_out);
        end else begin
            $display("[FAIL] Caso 3 (Primer bit por MSB): trama_out = %h (Esp: 80000000)", trama_out);
            error_count = error_count + 1;
        end

        // --- Caso 4: Reset sincrono a mitad de recepcion ---
        reset = 1'b1;
        @(posedge clk);
        #1;
        reset = 1'b0;

        if (trama_out === 32'h00000000) begin
            $display("[PASS] Caso 4 (Reset en operacion): trama_out = %h", trama_out);
        end else begin
            $display("[FAIL] Caso 4 (Reset en operacion): trama_out = %h (Esp: 00000000)", trama_out);
            error_count = error_count + 1;
        end

        // --- Caso 5: Recepcion completa de trama NEC de 32 bits (LSB primero) ---
        for (i = 0; i < 32; i = i + 1) begin
            shift_in = TRAMA_NEC_TEST[i];
            shift_en = 1'b1;
            @(posedge clk);
            #1;
        end
        shift_en = 1'b0;

        if (trama_out === TRAMA_NEC_TEST) begin
            $display("[PASS] Caso 5 (Trama NEC 32 bits): trama_out = %h", trama_out);
        end else begin
            $display("[FAIL] Caso 5 (Trama NEC 32 bits): trama_out = %h (Esp: %h)", trama_out, TRAMA_NEC_TEST);
            error_count = error_count + 1;
        end

        // --- Caso 6: Caso limite - Proteccion de trama reconstruida con shift_en = 0 ---
        shift_in = 1'b1;
        repeat (3) @(posedge clk);
        #1;
        shift_in = 1'b0;
        repeat (3) @(posedge clk);
        #1;

        if (trama_out === TRAMA_NEC_TEST) begin
            $display("[PASS] Caso 6 (Proteccion tras 32 bits): trama_out = %h", trama_out);
        end else begin
            $display("[FAIL] Caso 6 (Proteccion tras 32 bits): trama_out = %h (Esp: %h)", trama_out, TRAMA_NEC_TEST);
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