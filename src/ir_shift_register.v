`timescale 1ns / 1ps

module ir_shift_register (
    input clk,                  // reloj 100MHz
    input reset,                // reset general
    input shift_en,             // habilitacion desde la FSM
    input shift_in,             // bit decodificado (0 o 1)
    output reg [31:0] trama_out // palabra completa de 32 bits
);

    always @(posedge clk) begin
        if (reset) begin
            trama_out <= 32'd0;
        end else if (shift_en) begin
            // desplazamiento a la derecha porque NEC envia LSB primero
            trama_out <= {shift_in, trama_out[31:1]};
        end
    end

endmodule