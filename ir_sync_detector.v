`timescale 1ns / 1ps

module ir_sync_detector (
    input clk,            // Reloj de 100 MHz de la Basys 3
    input reset,          // Botón de reinicio general
    input ir_rx,          // Señal asíncrona física del sensor IR
    output ir_sync,       // Señal limpia y síncrona (para el Contador)
    output flanco_bajada, // Pulso de 1 ciclo: Inicio del pulso IR
    output flanco_subida  // Pulso de 1 ciclo: Fin del pulso IR
);

    // =========================================================================
    // DECLARACIÓN DE CABLES INTERNOS (Salidas de los Flip-Flops)
    // =========================================================================
    reg ir_sync_mid;      // Salida del FF1
    reg ir_sync_reg;      // Salida del FF2 (El presente)
    reg ir_sync_prev;     // Salida del FF3 (El pasado)

    // Conectamos el registro interno a la salida del módulo
    assign ir_sync = ir_sync_reg;

    // =========================================================================
    // LÓGICA SECUENCIAL: LOS 3 FLIP-FLOPS (Dependen del Reloj)
    // =========================================================================
    // posedge clk: Flanco de subida del reloj (Toma la foto)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Estado de reposo del sensor IR es Alto (1)
            ir_sync_mid  <= 1'b1; 
            ir_sync_reg  <= 1'b1;
            ir_sync_prev <= 1'b1;
        end else begin
            // FF1 captura la señal física
            ir_sync_mid  <= ir_rx;       
            // FF2 captura lo del FF1 (Termina la sincronización)
            ir_sync_reg  <= ir_sync_mid; 
            // FF3 captura el presente para guardarlo como "pasado"
            ir_sync_prev <= ir_sync_reg; 
        end
    end

    // =========================================================================
    // LÓGICA COMBINACIONAL: COMPUERTAS AND Y NOT (Detector de flancos)
    // =========================================================================
    // Operadores: & (AND), ~ (NOT)
    
    // Flanco de bajada: Pasado es 1 (ir_sync_prev) Y Presente es 0 (~ir_sync_reg)
    assign flanco_bajada = ir_sync_prev & (~ir_sync_reg);
    
    // Flanco de subida: Pasado es 0 (~ir_sync_prev) Y Presente es 1 (ir_sync_reg)
    assign flanco_subida = (~ir_sync_prev) & ir_sync_reg;

endmodule
