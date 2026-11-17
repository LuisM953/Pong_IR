module score #(
    parameter MAX_SCORE = 11 //MAXIMO 15, por el ancho de 4 bits de los contadores de score
)(
    input  wire clk,
    input  wire reset,
    input  wire clear,
    input  wire goal_p1,
    input  wire goal_p2,
    output wire win_p1,
    output wire win_p2,
    output reg  [3:0] score_p1,
    output reg  [3:0] score_p2
    
);
assign win_p1 = (score_p1 >= MAX_SCORE);
assign win_p2 = (score_p2 >= MAX_SCORE);

always @(posedge clk) begin
    if (reset || clear) begin
        score_p1 <= 0;
        score_p2 <= 0;
    end else begin 
        // 1. Cada ciclo de clk con goal_pX en alto suma 1 punto (ball_move entrega pulsos de 1 ciclo).
        // 2. Bloques 'if' independientes evitan perdida de puntos si llegaran dos goles en el mismo ciclo;
        //    si ambos alcanzan MAX_SCORE simultaneamente, se permite empate (win_p1=1 y win_p2=1).
        if (goal_p1 && !win_p1 && !win_p2) begin
            score_p1 <= score_p1 + 1;
        end 
        if (goal_p2 && !win_p1 && !win_p2) begin
            score_p2 <= score_p2 + 1;
        end 
    end       
end

endmodule