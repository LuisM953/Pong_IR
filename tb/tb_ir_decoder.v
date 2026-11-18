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
    wire ir_start; // MODIFICADO: Nueva salida de inicio de partida (pulso de 1 ciclo)

    // MODIFICADO: Bus agrupado para verificar exclusividad (one-hot) de las 4 direcciones
    wire [3:0] dirs = {ir_p1_up, ir_p1_down, ir_p2_up, ir_p2_down};

    // MODIFICADO: Contadores para verificar el pulso de 1 ciclo de ir_start y errores
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
        .ir_start(ir_start) // MODIFICADO: Conexion de ir_start
    );

    // reloj 100MHz
    always #5 clk = ~clk;

    // MODIFICADO: Monitor sincrono para capturar el pulso de 10 ns de ir_start
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

    // MODIFICADO: Tarea para probar cada tecla de paleta y exigir exclusividad en dirs
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
        // MODIFICADO: Verificar estado inicial tras reset incluyendo ir_start y dirs
        if (ir_start !== 1'b0 || dirs !== 4'b0000 || comando_actual !== 8'h00) begin
            $display("[FAIL] Reset: comando=%h, dirs=%b, ir_start=%b", comando_actual, dirs, ir_start);
            error_count = error_count + 1;
        end
        #1_000_000; // esperamos 1 ms en reposo

        // CASO 1: Trama valida para subir paleta 1 (cmd = 8'h18, ~cmd = 8'hE7)
        $display("--- Caso 1: Enviando trama NEC valida (P1_UP = 8'h18) ---");
        probar_tecla_paleta(32'hE718FF00, 8'h18, 4'b1000, "Caso 1 (P1_UP)"); // MODIFICADO

        #2_000_000; // pausa entre teclas

        // MODIFICADO: CASO 2: Trama valida para bajar paleta 1 (cmd = 8'h52, ~cmd = 8'hAD)
        $display("--- Caso 2: Enviando trama NEC valida (P1_DOWN = 8'h52) ---");
        probar_tecla_paleta(32'hAD52FF00, 8'h52, 4'b0100, "Caso 2 (P1_DOWN)");

        #2_000_000; // pausa entre teclas

        // MODIFICADO: CASO 3: Trama valida para subir paleta 2 (cmd = 8'h0C, ~cmd = 8'hF3)
        $display("--- Caso 3: Enviando trama NEC valida (P2_UP = 8'h0C) ---");
        probar_tecla_paleta(32'hF30CFF00, 8'h0C, 4'b0010, "Caso 3 (P2_UP)");

        #2_000_000; // pausa entre teclas

        // MODIFICADO: CASO 4: Trama valida para bajar paleta 2 (cmd = 8'h42, ~cmd = 8'hBD)
        $display("--- Caso 4: Enviando trama NEC valida (P2_DOWN = 8'h42) ---");
        probar_tecla_paleta(32'hBD42FF00, 8'h42, 4'b0001, "Caso 4 (P2_DOWN)");

        #2_000_000; // pausa entre teclas

        // CASO 5: Trama corrupta (cmd = 8'h52 pero ~cmd = 8'h00, error de transmision)
        $display("--- Caso 5: Enviando trama corrupta (debe ser rechazada) ---");
        start_pulse_count = 0; // MODIFICADO
        enviar_trama_nec(32'h0052FF00);
        #100_000;
        $display("Resultado Caso 5 -> comando=%h | ir_p1_down=%b (esperado: 0) | ir_start=%b", comando_actual, ir_p1_down, ir_start);
        // MODIFICADO: Verificar que no sobreescribio el ultimo comando valido (8'h42) ni activo ir_p1_down
        if (comando_actual !== 8'h42 || dirs !== 4'b0001 || start_pulse_count !== 0) begin
            $display("[FAIL] Caso 5: Trama corrupta altero salidas (cmd=%h, dirs=%b, pulsos_start=%0d)",
                     comando_actual, dirs, start_pulse_count);
            error_count = error_count + 1;
        end else begin
            $display("[PASS] Caso 5: Trama corrupta rechazada sin alterar el estado previo");
        end

        #2_000_000; // pausa entre teclas

        // MODIFICADO: CASO 6: Trama valida para Start/OK (cmd = 8'h1C, ~cmd = 8'hE3)
        $display("--- Caso 6: Enviando trama NEC valida (START = 8'h1C) ---");
        start_pulse_count = 0;
        enviar_trama_nec(32'hE31CFF00);
        #100_000;
        $display("Resultado Caso 6 -> comando=%h | ir_start_actual=%b | pulsos_start=%0d (esperado: 1)",
                 comando_actual, ir_start, start_pulse_count);
        if (comando_actual !== 8'h1C || start_pulse_count !== 1 || ir_start !== 1'b0 || dirs !== 4'b0000) begin
            $display("[FAIL] Caso 6: comando=%h (Esp:1C), pulsos_start=%0d (Esp:1), ir_start=%b (Esp:0), dirs=%b",
                     comando_actual, start_pulse_count, ir_start, dirs);
            error_count = error_count + 1;
        end else begin
            $display("[PASS] Caso 6: ir_start genero exactamente 1 pulso de ciclo y limpio direcciones");
        end

        #2_000_000; // pausa entre teclas

        // MODIFICADO: CASO 7: Trama corrupta con codigo START (cmd = 8'h1C, ~cmd = 8'h00)
        $display("--- Caso 7: Enviando trama START corrupta (debe ser rechazada) ---");
        start_pulse_count = 0;
        enviar_trama_nec(32'h001CFF00);
        #100_000;
        if (start_pulse_count !== 0 || ir_start !== 1'b0 || dirs !== 4'b0000) begin
            $display("[FAIL] Caso 7: Trama START corrupta disparo ir_start (pulsos=%0d)", start_pulse_count);
            error_count = error_count + 1;
        end else begin
            $display("[PASS] Caso 7: Trama START corrupta rechazada (0 pulsos)");
        end

        $display("Simulacion completa finalizada.");
        // MODIFICADO: Resumen global de verificacion
        if (error_count == 0) begin
            $display("EXITO: TODOS LOS TESTS PASARON (0 ERRORES).");
        end else begin
            $display("ERROR: SE ENCONTRARON %0d FALLOS.", error_count);
        end
        $finish;
    end

endmodule