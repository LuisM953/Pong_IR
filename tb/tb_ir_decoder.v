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

    // instanciamos el decodificador IR completo
    ir_decoder uut (
        .clk(clk),
        .reset(reset),
        .ir_rx(ir_rx),
        .comando_actual(comando_actual),
        .ir_p1_up(ir_p1_up),
        .ir_p1_down(ir_p1_down),
        .ir_p2_up(ir_p2_up),
        .ir_p2_down(ir_p2_down)
    );

    // reloj 100MHz
    always #5 clk = ~clk;

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

    initial begin
        // grabamos solo las senales principales para mantener ligero el archivo .vcd
        $dumpfile("ondas_decoder.vcd");
        $dumpvars(1, tb_ir_decoder);

        clk = 0;
        reset = 1;
        ir_rx = 1; // sensor en reposo

        #100 reset = 0;
        #1_000_000; // esperamos 1 ms en reposo

        // CASO 1: Trama valida para subir paleta 1 (cmd = 8'h18, ~cmd = 8'hE7)
        $display("--- Caso 1: Enviando trama NEC valida (P1_UP = 8'h18) ---");
        enviar_trama_nec(32'hE718FF00);
        #100_000; // esperamos 100 us para verificar las salidas
        $display("Resultado Caso 1 -> comando=%h | ir_p1_up=%b (esperado: 1)", comando_actual, ir_p1_up);

        #2_000_000; // pausa entre teclas

        // CASO 2: Trama corrupta (cmd = 8'h52 pero ~cmd = 8'h00, error de transmision)
        $display("--- Caso 2: Enviando trama corrupta (debe ser rechazada) ---");
        enviar_trama_nec(32'h0052FF00);
        #100_000;
        $display("Resultado Caso 2 -> comando=%h | ir_p1_down=%b (esperado: 0)", comando_actual, ir_p1_down);

        $display("Simulacion completa finalizada.");
        $finish;
    end

endmodule