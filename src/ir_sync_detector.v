`timescale 1ns / 1ps

module ir_sync_detector (
    input clk,            // reloj basys 3 (100MHz)
    input reset,          // boton de reset general
    input ir_rx,          // pin de entrada del sensor IR
    output ir_sync,       // senal ya limpia y sincronizada
    output flanco_bajada, // pulso 1 ciclo: cuando empieza la senal
    output flanco_subida  // pulso 1 ciclo: cuando termina la senal
);

    // cables internos para guardar los estados
    reg ir_sync_mid;      
    reg ir_sync_reg;      
    reg ir_sync_prev;     

    // la salida sincronizada viene del segundo FF
    assign ir_sync = ir_sync_reg;

    // logica de flip flops (secuencial)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // el sensor IR en reposo siempre manda 1, inicializamos en 1
            ir_sync_mid  <= 1'b1; 
            ir_sync_reg  <= 1'b1;
            ir_sync_prev <= 1'b1;
        end else begin
            ir_sync_mid  <= ir_rx;       // FF1 lee lo que llega del sensor
            ir_sync_reg  <= ir_sync_mid; // FF2 termina de estabilizar (anti-metastabilidad)
            ir_sync_prev <= ir_sync_reg; // FF3 guarda el estado anterior para comparar
        end
    end

    // logica combinacional para detectar los cambios
    // flanco de bajada: antes era 1 y ahora es 0
    assign flanco_bajada = ir_sync_prev & (~ir_sync_reg);
    
    // flanco de subida: antes era 0 y ahora es 1
    assign flanco_subida = (~ir_sync_prev) & ir_sync_reg;

endmodule