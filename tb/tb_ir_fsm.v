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

    // instanciamos la FSM
    ir_fsm uut (
        .clk(clk),
        .reset(reset),
        .flanco_bajada(flanco_bajada),
        .flanco_subida(flanco_subida),
        .cuenta_actual(cuenta_actual),
        .shift_en(shift_en),
        .shift_in(shift_in),
        .data_ready(data_ready)
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
        flanco_bajada = 1; #10; flanco_bajada = 0;
        #30;
        cuenta_actual = 20'd15_000; // mucho menor a 800,000
        flanco_subida = 1; #10; flanco_subida = 0;
        #40;

        // CASO 2: Trama NEC valida de 32 bits
        $display("--- Prueba 2: Enviando trama NEC completa ---");
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
        $display("Simulacion de FSM terminada.");
        $finish;
    end

    // monitor en consola
    always @(posedge clk) begin
        if (data_ready)
            $display("TIEMPO %0t: data_ready = 1! Trama de 32 bits recibida con exito.", $time);
    end

endmodule