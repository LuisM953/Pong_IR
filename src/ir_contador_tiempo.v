`timescale 1ns / 1ps

module ir_contador_tiempo (
    input clk,            // reloj basys 3 (100MHz)
    input reset,          // boton de reset general
    input flanco_bajada,  // pulso que avisa inicio de senal IR
    input flanco_subida,  // pulso que avisa fin de senal IR
    output reg [19:0] cuenta_actual // cable grueso de 20 bits para la FSM
);

    // cable interno de la compuerta OR
    wire reset_interno;

    // logica combinacional: compuerta OR
    // se activa si oprimimos reset fisico O si el detector manda un flanco
    assign reset_interno = reset | flanco_bajada | flanco_subida;

    // logica secuencial: registro de 20 bits y multiplexor
    always @(posedge clk) begin
        if (reset_interno) begin
            // el MUX elige el carril del cero (se reinicia el cronometro)
            cuenta_actual <= 20'd0; 
        end else begin
            // el MUX elige el carril del sumador (sigue contando el tiempo)
            cuenta_actual <= cuenta_actual + 1'b1;
        end
    end

endmodule