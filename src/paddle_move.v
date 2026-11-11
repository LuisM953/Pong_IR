module paddle_move (
    input  wire clk,
    input  wire reset,
    input  wire frame_tick,   // un pulso por cuadro (60 Hz)
    input  wire up,
    input  wire down,
    output reg  [9:0] y       // borde superior de la paleta
);

localparam  SCREEN_H = 480,
            PADDLE_H = 80,
            BORDER_W = 10,   
            SPEED    = 4,
            Y_MIN    = BORDER_W, 
            Y_MAX    = (SCREEN_H - BORDER_W - PADDLE_H),
            Y_INIT   = (SCREEN_H - PADDLE_H)/2;

always @(posedge clk) begin
    if (reset) begin
        y <= Y_INIT;
    end else if (frame_tick) begin
        if (up && !down) begin
            if (y <= Y_MIN + SPEED) begin
                y <= Y_MIN;
            end else begin
                y <= y - SPEED;
            end
        end else if (!up && down) begin
            if ((y + SPEED) >= Y_MAX) begin
                y <= Y_MAX;
            end else begin
                y <= y + SPEED;
            end    
        end   
    end 
end

endmodule