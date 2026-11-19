`timescale 1ns / 1ps

module tb_ir_decoder();

    reg clk;
    reg reset;
    reg ir_rx;

    wire [7:0] comando_actual;
    wire ir_p1_up;
    wire ir_p1_down;
    wire ir_p2_up;
    wire ir_p2_down;
    wire ir_start; // Nueva salida de inicio de partida (pulso de 1 ciclo)

    // Bus agrupado para verificar exclusividad (one-hot) de las 4 direcciones
    wire [3:0] dirs = {ir_p1_up, ir_p1_down, ir_p2_up, ir_p2_down};

    // Contadores para verificar el pulso de 1 ciclo de ir_start y errores
    integer start_pulse_count = 0;
    integer error_count = 0;

    // instanciamos el decodificador IR completo
    ir_decoder uut (
        .clk(clk),
        .reset(reset),
        .ir_rx(ir_rx),
        .comando_actual(comando_actual),
        .ir_p1_up(ir_p1_up),
        .ir_p1_down(ir_p1_down),
        .ir_p2_up(ir_p2_up),
        .ir_p2_down(ir_p2_down),
        .ir_start(ir_start) // Conexion de ir_start
    );

    // reloj 100MHz
    always #5 clk = ~clk;

    // Monitor sincrono para capturar el pulso de 10 ns de ir_start
    always @(posedge clk) begin
        if (!reset && ir_start) begin
            start_pulse_count = start_pulse_count + 1;
        end
    end

    // tarea que genera los pulsos fisicos NEC en tiempo real sobre el pin ir_rx
    task enviar_trama_nec(input [31:0] trama);
        integer i;
        begin
            // 1. pulso de inicio (9 ms en bajo + 4.5 ms en alto)
            ir_rx = 0;
            #9_000_000;
            ir_rx = 1;
            #4_500_000;

            // 2. envio de los 32 bits (LSB primero)
            for (i = 0; i < 32; i = i + 1) begin
                // pausamos la grabacion VCD en los bits intermedios para no saturar EPWave
                if (i == 3)  $dumpoff;
                if (i == 29) $dumpon;

                ir_rx = 0;
                #562_500; // pulso bajo fijo de 562.5 us
                ir_rx = 1;
                if (trama[i] == 1'b1)
                    #1_687_500; // '1' logico: 1.6875 ms en alto
                else
                    #562_500;   // '0' logico: 562.5 us en alto
            end

            // 3. pulso final de cierre (stop bit de 562.5 us)
            ir_rx = 0;
            #562_500;
            ir_rx = 1;
        end
    endtask

    // Tarea para probar cada tecla de paleta y exigir exclusividad en dirs
    task probar_tecla_paleta;
        input [31:0]  trama;
        input [7:0]   exp_cmd;
        input [3:0]   exp_dirs; // {p1_up, p1_down, p2_up, p2_down}
        input [255:0] nombre;
        begin
            start_pulse_count = 0;
            enviar_trama_nec(trama);
            #100_000; // esperamos 100 us para verificar las salidas
            if (comando_actual !== exp_cmd || dirs !== exp_dirs || start_pulse_count !== 0 || ir_start !== 1'b0) begin
                $display("[FAIL] %s -> cmd=%h (Esp:%h) | dirs=%b (Esp:%b) | pulsos_start=%0d (Esp:0)",
                         nombre, comando_actual, exp_cmd, dirs, exp_dirs, start_pulse_count);
                error_count = error_count + 1;
            end else begin
                $display("[PASS] %s -> cmd=%h | dirs=%b | ir_start=0",
                         nombre, comando_actual, dirs);
            end
        end
    endtask

    initial begin
        // grabamos solo las senales principales para mantener ligero el archivo .vcd
        $dumpfile("ondas_decoder.vcd");
        $dumpvars(1, tb_ir_decoder);

        clk = 0;
        reset = 1;
        ir_rx = 1; // sensor en reposo

        #100 reset = 0;
        // Verificar estado inicial tras reset incluyendo ir_start y dirs
        if (ir_start !== 1'b0 || dirs !== 4'b0000 || comando_actual !== 8'h00) begin
            $display("[FAIL] Reset: comando=%h, dirs=%b, ir_start=%b", comando_actual, dirs, ir_start);
            error_count = error_count + 1;
        end
        #1_000_000; // esperamos 1 ms en reposo

        // MODIFICADO: CASO 1: Trama valida para subir paleta 1 (cmd = 8'h02, ~cmd = 8'hFD)
        $display("--- Caso 1: Enviando trama NEC valida (P1_UP = 8'h02) ---"); // MODIFICADO
        probar_tecla_paleta(32'hFD02FF00, 8'h02, 4'b1000, "Caso 1 (P1_UP)"); // MODIFICADO

        #2_000_000; // pausa entre teclas

        // MODIFICADO: CASO 2: Trama valida para bajar paleta 1 (cmd = 8'h08, ~cmd = 8'hF7)
        $display("--- Caso 2: Enviando trama NEC valida (P1_DOWN = 8'h08) ---"); // MODIFICADO
        probar_tecla_paleta(32'hF708FF00, 8'h08, 4'b0100, "Caso 2 (P1_DOWN)"); // MODIFICADO

        #2_000_000; // pausa entre teclas

        // MODIFICADO: CASO 3: Trama valida para subir paleta 2 (cmd = 8'h19, ~cmd = 8'hE6)
        $display("--- Caso 3: Enviando trama NEC valida (P2_UP = 8'h19) ---"); // MODIFICADO
        probar_tecla_paleta(32'hE619FF00, 8'h19, 4'b0010, "Caso 3 (P2_UP)"); // MODIFICADO

        #2_000_000; // pausa entre teclas

        // MODIFICADO: CASO 4: Trama valida para bajar paleta 2 (cmd = 8'h1D, ~cmd = 8'hE2)
        $display("--- Caso 4: Enviando trama NEC valida (P2_DOWN = 8'h1D) ---"); // MODIFICADO
        probar_tecla_paleta(32'hE21DFF00, 8'h1D, 4'b0001, "Caso 4 (P2_DOWN)"); // MODIFICADO

        #2_000_000; // pausa entre teclas

        // MODIFICADO: CASO 5: Trama corrupta (cmd = 8'h08 pero ~cmd = 8'h00, error de transmision)
        $display("--- Caso 5: Enviando trama corrupta (debe ser rechazada) ---");
        start_pulse_count = 0;
        enviar_trama_nec(32'h0008FF00); // MODIFICADO
        #100_000;
        $display("Resultado Caso 5 -> comando=%h | ir_p1_down=%b (esperado: 0) | ir_start=%b", comando_actual, ir_p1_down, ir_start);
        // MODIFICADO: Verificar que no sobreescribio el ultimo comando valido (8'h1D) ni activo ir_p1_down
        if (comando_actual !== 8'h1D || dirs !== 4'b0001 || start_pulse_count !== 0) begin // MODIFICADO
            $display("[FAIL] Caso 5: Trama corrupta altero salidas (cmd=%h, dirs=%b, pulsos_start=%0d)",
                     comando_actual, dirs, start_pulse_count);
            error_count = error_count + 1;
        end else begin
            $display("[PASS] Caso 5: Trama corrupta rechazada sin alterar el estado previo");
        end

        #2_000_000; // pausa entre teclas

        // MODIFICADO: CASO 6: Trama valida para Start/OK (cmd = 8'h57, ~cmd = 8'hA8)
        $display("--- Caso 6: Enviando trama NEC valida (START = 8'h57) ---"); // MODIFICADO
        start_pulse_count = 0;
        enviar_trama_nec(32'hA857FF00); // MODIFICADO
        #100_000;
        $display("Resultado Caso 6 -> comando=%h | ir_start_actual=%b | pulsos_start=%0d (esperado: 1)",
                 comando_actual, ir_start, start_pulse_count);
        if (comando_actual !== 8'h57 || start_pulse_count !== 1 || ir_start !== 1'b0 || dirs !== 4'b0000) begin // MODIFICADO
            $display("[FAIL] Caso 6: comando=%h (Esp:57), pulsos_start=%0d (Esp:1), ir_start=%b (Esp:0), dirs=%b", // MODIFICADO
                     comando_actual, start_pulse_count, ir_start, dirs);
            error_count = error_count + 1;
        end else begin
            $display("[PASS] Caso 6: ir_start genero exactamente 1 pulso de ciclo y limpio direcciones");
        end

        #2_000_000; // pausa entre teclas

        // MODIFICADO: CASO 7: Trama corrupta con codigo START (cmd = 8'h57, ~cmd = 8'h00)
        $display("--- Caso 7: Enviando trama START corrupta (debe ser rechazada) ---");
        start_pulse_count = 0;
        enviar_trama_nec(32'h0057FF00); // MODIFICADO
        #100_000;
        if (start_pulse_count !== 0 || ir_start !== 1'b0 || dirs !== 4'b0000) begin
            $display("[FAIL] Caso 7: Trama START corrupta disparo ir_start (pulsos=%0d)", start_pulse_count);
            error_count = error_count + 1;
        end else begin
            $display("[PASS] Caso 7: Trama START corrupta rechazada (0 pulsos)");
        end

        $display("Simulacion completa finalizada.");
        // Resumen global de verificacion
        if (error_count == 0) begin
            $display("EXITO: TODOS LOS TESTS PASARON (0 ERRORES).");
        end else begin
            $display("ERROR: SE ENCONTRARON %0d FALLOS.", error_count);
        end
        $finish;
    end

endmodule