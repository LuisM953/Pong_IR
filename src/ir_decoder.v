`timescale 1ns / 1ps

module ir_decoder (
    input clk,                    // reloj 100MHz basys 3
    input reset,                  // reset general
    input ir_rx,                  // pin fisico del sensor IR
    output [7:0] comando_actual,  // salida para ver el codigo en los LEDs
    output reg ir_p1_up,          // mover paleta 1 arriba
    output reg ir_p1_down,        // mover paleta 1 abajo
    output reg ir_p2_up,          // mover paleta 2 arriba
    output reg ir_p2_down,        // mover paleta 2 abajo
    output reg ir_start           // iniciar partida (pulso de 1 ciclo)
);

    // codigos NEC tipicos (ajustables segun tu control remoto)
    localparam CMD_P1_UP   = 8'h18, // ej. flecha arriba
               CMD_P1_DOWN = 8'h52, // ej. flecha abajo
               CMD_P2_UP   = 8'h0C, // ej. tecla 1
               CMD_P2_DOWN = 8'h42, // ej. tecla 7
               CMD_START   = 8'h1C; // Codigo temporal para Start/OK

    // cables de interconexion interna
    wire ir_sync;
    wire flanco_bajada;
    wire flanco_subida;
    wire [19:0] cuenta_actual;
    wire shift_en;
    wire shift_in;
    wire data_ready;
    wire [31:0] trama_32;

    // 1. Sincronizador y detector de flancos
    ir_sync_detector u_sync (
        .clk(clk),
        .reset(reset),
        .ir_rx(ir_rx),
        .ir_sync(ir_sync),
        .flanco_bajada(flanco_bajada),
        .flanco_subida(flanco_subida)
    );

    // 2. Contador de tiempo de 20 bits
    ir_contador_tiempo u_timer (
        .clk(clk),
        .reset(reset),
        .flanco_bajada(flanco_bajada),
        .flanco_subida(flanco_subida),
        .cuenta_actual(cuenta_actual)
    );

    // 3. Maquina de estados finitos
    ir_fsm u_fsm (
        .clk(clk),
        .reset(reset),
        .flanco_bajada(flanco_bajada),
        .flanco_subida(flanco_subida),
        .cuenta_actual(cuenta_actual),
        .shift_en(shift_en),
        .shift_in(shift_in),
        .data_ready(data_ready)
    );

    // 4. Registro de desplazamiento de 32 bits
    ir_shift_register u_shift (
        .clk(clk),
        .reset(reset),
        .shift_en(shift_en),
        .shift_in(shift_in),
        .trama_out(trama_32)
    );

    // extraccion y validacion de integridad (byte comando vs byte invertido)
    wire [7:0] cmd     = trama_32[23:16];
    wire [7:0] cmd_inv = trama_32[31:24];
    wire trama_valida  = (cmd == ~cmd_inv);

    reg [7:0] ultimo_comando;
    assign comando_actual = ultimo_comando;

    // temporizador de retencion de 120 ms (12,000,000 ciclos a 100MHz)
    reg [23:0] hold_counter;

    always @(posedge clk) begin
        if (reset) begin
            ultimo_comando <= 8'h00;
            hold_counter   <= 24'd0;
            ir_p1_up       <= 1'b0;
            ir_p1_down     <= 1'b0;
            ir_p2_up       <= 1'b0;
            ir_p2_down     <= 1'b0;
            ir_start       <= 1'b0;
        end else begin
            ir_start       <= 1'b0; // desactivamos la señal de inicio
            // cuando llega una trama completa y valida, actualizamos el comando
            if (data_ready && trama_valida) begin
                ultimo_comando <= cmd;
                hold_counter   <= 24'd12_000_000; // sostiene el movimiento 120 ms
                if (cmd == CMD_START) begin
                    ir_start   <= 1'b1; // activamos la señal de inicio
                end
            end else if (hold_counter > 24'd0) begin
                hold_counter   <= hold_counter - 1'b1;
            end

            // activamos las direcciones mientras el contador de retencion este activo
            if (hold_counter > 24'd0) begin
                ir_p1_up   <= (ultimo_comando == CMD_P1_UP);
                ir_p1_down <= (ultimo_comando == CMD_P1_DOWN);
                ir_p2_up   <= (ultimo_comando == CMD_P2_UP);
                ir_p2_down <= (ultimo_comando == CMD_P2_DOWN);
            end else begin
                ir_p1_up   <= 1'b0;
                ir_p1_down <= 1'b0;
                ir_p2_up   <= 1'b0;
                ir_p2_down <= 1'b0;
            end
        end
    end

endmodule