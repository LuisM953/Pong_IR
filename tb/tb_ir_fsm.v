`timescale 1ns / 1ps

module tb_ir_fsm();

    reg clk;
    reg reset;
    reg flanco_bajada;
    reg flanco_subida;
    reg [19:0] cuenta_actual;

    wire shift_en;
    wire shift_in;
    wire data_ready;
    wire repeat_ready; // MODIFICADO: Nuevo puerto de trama de repeticion

    // MODIFICADO: Contadores de verificacion de pulsos y errores
    integer data_ready_count   = 0;
    integer repeat_ready_count = 0;
    integer error_count        = 0;

    // instanciamos la FSM
    ir_fsm uut (
        .clk(clk),
        .reset(reset),
        .flanco_bajada(flanco_bajada),
        .flanco_subida(flanco_subida),
        .cuenta_actual(cuenta_actual),
        .shift_en(shift_en),
        .shift_in(shift_in),
        .data_ready(data_ready),
        .repeat_ready(repeat_ready) // MODIFICADO: Conexion del puerto repeat_ready
    );

    // reloj 100MHz
    always #5 clk = ~clk;

    // tarea auxiliar para simular el envio de 1 bit NEC
    task enviar_bit_nec(input bit_val);
        begin
            // 1. termina el pulso bajo de 562.5us (56250 ciclos)
            #40;
            cuenta_actual = 20'd56_250;
            flanco_subida = 1;
            #10;
            flanco_subida = 0;

            // 2. termina el espacio en alto (56250 para '0', 168750 para '1')
            #40;
            if (bit_val == 1'b1)
                cuenta_actual = 20'd168_750;
            else
                cuenta_actual = 20'd56_250;
            
            flanco_bajada = 1;
            #10;
            flanco_bajada = 0;
        end
    endtask

    integer i;
    reg [31:0] trama_prueba = 32'h00FFA25D; // codigo de ejemplo de una tecla

    initial begin
        $dumpfile("ondas_fsm.vcd");
        $dumpvars(0, tb_ir_fsm);

        // inicializacion
        clk = 0;
        reset = 1;
        flanco_bajada = 0;
        flanco_subida = 0;
        cuenta_actual = 20'd0;

        #20 reset = 0;
        #30;

        // CASO 1: Prueba de ruido (pulso muy corto, debe volver a IDLE)
        $display("--- Prueba 1: Inyectando ruido ---");
        data_ready_count   = 0; // MODIFICADO
        repeat_ready_count = 0; // MODIFICADO
        flanco_bajada = 1; #10; flanco_bajada = 0;
        #30;
        cuenta_actual = 20'd15_000; // mucho menor a 800,000
        flanco_subida = 1; #10; flanco_subida = 0;
        #40;
        // MODIFICADO: Verificar que el ruido no activo data_ready ni repeat_ready
        if (data_ready_count !== 0 || repeat_ready_count !== 0) begin
            $display("[FAIL] Prueba 1 (Ruido): data_ready=%0d, repeat_ready=%0d", data_ready_count, repeat_ready_count);
            error_count = error_count + 1;
        end else begin
            $display("[PASS] Prueba 1 (Ruido): Pulso corto rechazado (0 disparos)");
        end

        // CASO 2: Trama NEC valida de 32 bits
        $display("--- Prueba 2: Enviando trama NEC completa ---");
        data_ready_count   = 0; // MODIFICADO
        repeat_ready_count = 0; // MODIFICADO
        // inicio de pulso bajo (9ms)
        flanco_bajada = 1; #10; flanco_bajada = 0;
        #40;
        // fin de 9ms (900,000 ciclos)
        cuenta_actual = 20'd900_000;
        flanco_subida = 1; #10; flanco_subida = 0;
        #40;
        // fin de pausa alta de 4.5ms (450,000 ciclos)
        cuenta_actual = 20'd450_000;
        flanco_bajada = 1; #10; flanco_bajada = 0;

        // enviamos los 32 bits uno por uno
        for (i = 0; i < 32; i = i + 1) begin
            enviar_bit_nec(trama_prueba[i]);
        end

        // pulso final de cierre (stop bit de 562.5us)
        #40;
        cuenta_actual = 20'd56_250;
        flanco_subida = 1; #10; flanco_subida = 0;

        #50;
        // MODIFICADO: Verificar exactamente 1 pulso de data_ready y 0 de repeat_ready
        if (data_ready_count !== 1 || repeat_ready_count !== 0 || data_ready !== 1'b0) begin
            $display("[FAIL] Prueba 2 (Trama completa): data_ready=%0d (Esp:1), repeat_ready=%0d (Esp:0)",
                     data_ready_count, repeat_ready_count);
            error_count = error_count + 1;
        end else begin
            $display("[PASS] Prueba 2 (Trama completa): data_ready genero exactamente 1 pulso y repeat_ready=0");
        end

        // MODIFICADO: CASO 3: Trama de repeticion NEC valida (9 ms bajo + 2.25 ms alto + stop bit 562.5 us)
        $display("--- Prueba 3: Enviando trama de repeticion NEC valida ---");
        data_ready_count   = 0;
        repeat_ready_count = 0;
        // inicio de pulso bajo (9 ms)
        flanco_bajada = 1; #10; flanco_bajada = 0;
        #40;
        // fin de 9 ms (900,000 ciclos) -> pasa a LEADER_HIGH
        cuenta_actual = 20'd900_000;
        flanco_subida = 1; #10; flanco_subida = 0;
        #40;
        // fin de pausa alta de 2.25 ms (225,000 ciclos, > 180,000 y <= 400,000) -> pasa a REPEAT_STOP
        cuenta_actual = 20'd225_000;
        flanco_bajada = 1; #10; flanco_bajada = 0;
        #40;
        // fin de rafaga final de 562.5 us (56,250 ciclos) -> emite repeat_ready = 1 y vuelve a IDLE
        cuenta_actual = 20'd56_250;
        flanco_subida = 1; #10; flanco_subida = 0;

        #50;
        if (repeat_ready_count !== 1 || data_ready_count !== 0 || repeat_ready !== 1'b0) begin
            $display("[FAIL] Prueba 3 (Repeticion): repeat_ready=%0d (Esp:1), data_ready=%0d (Esp:0), repeat_actual=%b",
                     repeat_ready_count, data_ready_count, repeat_ready);
            error_count = error_count + 1;
        end else begin
            $display("[PASS] Prueba 3 (Repeticion): repeat_ready genero exactamente 1 pulso de ciclo y data_ready=0");
        end

        // MODIFICADO: CASO 4: Espacio en LEADER_HIGH demasiado corto (100,000 ciclos <= 180,000)
        $display("--- Prueba 4: Espacio demasiado corto en LEADER_HIGH (debe volver a IDLE) ---");
        data_ready_count   = 0;
        repeat_ready_count = 0;
        flanco_bajada = 1; #10; flanco_bajada = 0;
        #40;
        cuenta_actual = 20'd900_000;
        flanco_subida = 1; #10; flanco_subida = 0;
        #40;
        cuenta_actual = 20'd100_000; // menor a 180,000
        flanco_bajada = 1; #10; flanco_bajada = 0;
        #40;
        cuenta_actual = 20'd56_250;
        flanco_subida = 1; #10; flanco_subida = 0;

        #50;
        if (repeat_ready_count !== 0 || data_ready_count !== 0) begin
            $display("[FAIL] Prueba 4 (Espacio corto): repeat_ready=%0d, data_ready=%0d", repeat_ready_count, data_ready_count);
            error_count = error_count + 1;
        end else begin
            $display("[PASS] Prueba 4 (Espacio corto): Rechazado sin activar repeat_ready ni data_ready");
        end

        // MODIFICADO: CASO 5: Espacio demasiado largo en LEADER_HIGH (> 950,000 -> timeout a IDLE)
        $display("--- Prueba 5: Espacio demasiado largo en LEADER_HIGH (timeout a IDLE) ---");
        data_ready_count   = 0;
        repeat_ready_count = 0;
        flanco_bajada = 1; #10; flanco_bajada = 0;
        #40;
        cuenta_actual = 20'd900_000;
        flanco_subida = 1; #10; flanco_subida = 0;
        #40;
        cuenta_actual = 20'd960_000; // supera 950,000 -> timeout
        #20;
        cuenta_actual = 20'd0;
        #30;
        if (repeat_ready_count !== 0 || data_ready_count !== 0 || uut.estado_actual !== 3'd0) begin
            $display("[FAIL] Prueba 5 (Timeout): estado=%0d (Esp:0), repeat_ready=%0d, data_ready=%0d",
                     uut.estado_actual, repeat_ready_count, data_ready_count);
            error_count = error_count + 1;
        end else begin
            $display("[PASS] Prueba 5 (Timeout): FSM regreso a IDLE sin disparar salidas");
        end

        $display("Simulacion de FSM terminada.");
        // MODIFICADO: Resumen final de verificacion
        if (error_count == 0) begin
            $display("EXITO: TODOS LOS TESTS DE FSM PASARON (0 ERRORES).");
        end else begin
            $display("ERROR: SE ENCONTRARON %0d FALLOS EN FSM.", error_count);
        end
        $finish;
    end

    // monitor en consola
    always @(posedge clk) begin
        if (!reset) begin
            if (data_ready) begin
                data_ready_count = data_ready_count + 1; // MODIFICADO
                $display("TIEMPO %0t: data_ready = 1! Trama de 32 bits recibida con exito.", $time);
            end
            if (repeat_ready) begin // MODIFICADO
                repeat_ready_count = repeat_ready_count + 1;
                $display("TIEMPO %0t: repeat_ready = 1! Trama de repeticion detectada con exito.", $time);
            end
        end
    end

endmodule