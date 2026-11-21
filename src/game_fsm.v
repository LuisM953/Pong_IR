module game_fsm #(
    parameter REPOSO    = 2'b00,
              JUGANDO   = 2'b01,
              GAME_OVER = 2'b10
              // 11: estado invalido, se recupera a REPOSO
)(
    input  wire clk,
    input  wire reset,
    input  wire win_p1,
    input  wire win_p2,
    input  wire ir_start,     // Pulso de 1 ciclo desde ir_decoder
    output wire clear,        // Limpia el marcador al iniciar partida
    output wire game_enable,  // Habilita el movimiento de pelota/paletas
    output reg  [1:0] state   // 00: REPOSO, 01: JUGANDO, 10: GAME_OVER
);

    reg [1:0] state_next;

    // 1. registro de estado (secuencial)
    always @(posedge clk) begin
        if (reset)
            state <= REPOSO;
        else
            state <= state_next;
    end

    // 2. logica de transiciones y salidas (combinacional)
    always @(*) begin
        state_next  = state;
        case (state)
            REPOSO: begin
                if (ir_start)
                    state_next = JUGANDO;
            end

            JUGANDO: begin
                if (win_p1 || win_p2)
                    state_next = GAME_OVER;
            end

            GAME_OVER: begin
                if (ir_start)
                    state_next = REPOSO; // Vuelve a REPOSO para limpiar el marcador y esperar otra partida
            end
            default: begin
                state_next = REPOSO; // Recuperacion segura desde estado invalido 2'b11
            end
        endcase
    end

    assign clear       = (state == REPOSO);
    assign game_enable = (state == JUGANDO);

endmodule