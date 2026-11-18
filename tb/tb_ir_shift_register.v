`timescale 1ns / 1ps

module tb_ir_shift_register();

    reg clk;
    reg reset;
    reg shift_en;
    reg shift_in;
    wire [31:0] trama_out;

    // instanciamos el registro de 32 bits
    ir_shift_register uut (
        .clk(clk),
        .reset(reset),
        .shift_en(shift_en),
        .shift_in(shift_in),
        .trama_out(trama_out)
    );

    // reloj 100MHz
    always #5 clk = ~clk;

    // trama NEC de ejemplo: ~cmd=8'hE7, cmd=8'h18 (P1_UP), ~dir=8'hFF, dir=8'h00
    reg [31:0] dato_esperado = 32'hE718FF00;
    integer i;

    initial begin
        $dumpfile("ondas_shift.vcd");
        $dumpvars(0, tb_ir_shift_register);

        clk = 0;
        reset = 1;
        shift_en = 0;
        shift_in = 0;

        #20 reset = 0;
        #20;

        // inyectamos los 32 bits uno por uno empezando por el bit 0 (LSB)
        for (i = 0; i < 32; i = i + 1) begin
            @(negedge clk);
            shift_in = dato_esperado[i];
            shift_en = 1'b1;
            @(posedge clk);
            #1;
        end

        // caso borde: apagamos shift_en y cambiamos shift_in para ver si se protege el dato
        @(negedge clk);
        shift_en = 1'b0;
        shift_in = 1'b1;
        #40;

        if (trama_out == dato_esperado)
            $display("EXITO: Trama reconstruida correctamente = %h", trama_out);
        else
            $display("ERROR: Se esperaba %h pero se obtuvo %h", dato_esperado, trama_out);

        $finish;
    end

endmodule