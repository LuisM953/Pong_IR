`timescale 1ns / 1ps

module ir_fsm (
    input clk,                   // reloj 100MHz basys 3
    input reset,                 // reset general
    input flanco_bajada,         // pulso del detector
    input flanco_subida,         // pulso del detector
    input [19:0] cuenta_actual,  // tiempo medido por el contador
    output reg shift_en,         // habilita guardar bit en el registro
    output reg shift_in,         // bit decodificado (0 o 1)
    output reg data_ready        // bandera de trama de 32 bits lista
);

    // codificacion de los 5 estados
    localparam IDLE        = 3'd0;
    localparam LEADER_LOW  = 3'd1;
    localparam LEADER_HIGH = 3'd2;
    localparam READ_DATA   = 3'd3;
    localparam STOP_BIT    = 3'd4;

    reg [2:0] estado_actual, estado_siguiente;
    reg [5:0] bits_leidos; // cuenta de 0 a 31

    // 1. registro de estado y contador de bits (secuencial)
    always @(posedge clk) begin
        if (reset) begin
            estado_actual <= IDLE;
            bits_leidos   <= 6'd0;
        end else begin
            estado_actual <= estado_siguiente;

            if (estado_actual == IDLE || estado_actual == LEADER_HIGH) begin
                bits_leidos <= 6'd0;
            end else if (shift_en) begin
                bits_leidos <= bits_leidos + 1'b1;
            end
        end
    end

    // 2. logica de transiciones y salidas (combinacional)
    always @(*) begin
        estado_siguiente = estado_actual;
        shift_en         = 1'b0;
        shift_in         = 1'b0;
        data_ready       = 1'b0;

        case (estado_actual)
            IDLE: begin
                if (flanco_bajada)
                    estado_siguiente = LEADER_LOW;
            end

            LEADER_LOW: begin
                if (flanco_subida) begin
                    if (cuenta_actual > 20'd800_000)
                        estado_siguiente = LEADER_HIGH; // inicio valido de 9ms
                    else
                        estado_siguiente = IDLE;        // pulso corto (ruido)
                end else if (cuenta_actual > 20'd950_000) begin
                    estado_siguiente = IDLE;            // timeout
                end
            end

            LEADER_HIGH: begin
                if (flanco_bajada) begin
                    if (cuenta_actual > 20'd400_000)
                        estado_siguiente = READ_DATA;   // pausa valida de 4.5ms
                    else
                        estado_siguiente = IDLE;        // error de protocolo
                end else if (cuenta_actual > 20'd950_000) begin
                    estado_siguiente = IDLE;            // timeout
                end
            end

            READ_DATA: begin
                // en flanco de bajada termina el espacio en alto y decidimos 0 o 1
                if (flanco_bajada) begin
                    shift_en = 1'b1;
                    if (cuenta_actual > 20'd100_000)
                        shift_in = 1'b1; // ~1.68ms -> 1 logico
                    else
                        shift_in = 1'b0; // ~562us  -> 0 logico

                    // si ya leimos el bit 31 (el 32avo bit), vamos al cierre
                    if (bits_leidos == 6'd31)
                        estado_siguiente = STOP_BIT;
                end else if (cuenta_actual > 20'd950_000) begin
                    estado_siguiente = IDLE; // timeout si se corta la senal
                end
            end

            STOP_BIT: begin
                // esperamos el flanco de subida final para cerrar la trama
                if (flanco_subida) begin
                    data_ready       = 1'b1;
                    estado_siguiente = IDLE;
                end else if (cuenta_actual > 20'd950_000) begin
                    estado_siguiente = IDLE;
                end
            end

            default: estado_siguiente = IDLE;
        endcase
    end

endmodule