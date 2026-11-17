module ball_move (
    input  wire clk,
    input  wire reset,
    input  wire frame_tick,
    input  wire hit_p1,
    input  wire hit_p2,
    output reg  goal_p1,       // 1 cuando la pelota llega a la pared derecha
    output reg  goal_p2,       // 1 cuando la pelota llega a la pared izquierda
    output reg  [9:0] ball_x,  // columna del borde izquierdo de la pelota
    output reg  [9:0] ball_y   // fila del borde superior de la pelota
);

localparam  SCREEN_W      = 640,
            SCREEN_H      = 480,
            BORDER_W      = 10,
            PADDLE_W      = 10,
            BALL_W        = 10,
            BALL_H        = 10,
            MARGIN        = 20,
            BALL_SPEED    = 2,
            X_MIN         = BORDER_W,
            Y_MIN         = BORDER_W,
            X_MAX         = SCREEN_W - BALL_W - BORDER_W,
            Y_MAX         = SCREEN_H - BALL_H - BORDER_W,
            P1_X          = MARGIN,
            P2_X          = (SCREEN_W - MARGIN - PADDLE_W),
            BALL_X_INICIO = (SCREEN_W/2 - BALL_W/2),
            BALL_Y_INICIO = (SCREEN_H/2 - BALL_H/2);
            
reg dir_x, dir_y; // 0 = derecha/abajo, 1 = izquierda/arriba 
wire gol_izq = (dir_x == 1 && !hit_p1 && ball_x <= X_MIN + BALL_SPEED); 
wire gol_der = (dir_x == 0 && !hit_p2 && ball_x >= X_MAX - BALL_SPEED);
wire gol     = gol_izq || gol_der;

always @(posedge clk) begin
    goal_p1 <= 0; // resetear goles cada ciclo
    goal_p2 <= 0; // resetear goles cada ciclo
    if (reset) begin
        ball_x <= BALL_X_INICIO;
        ball_y <= BALL_Y_INICIO;
        dir_x <= 1; // direccion inicial: izquierda
        dir_y <= 1; // direccion inicial: arriba
    end else if (frame_tick) begin
        if (dir_x == 1) begin //izquierda
            if (hit_p1) begin
                ball_x <= P1_X + PADDLE_W; // reposicionar pelota a la derecha de la paleta
                dir_x <= !dir_x; // cambiar direccion a derecha
            end else if (gol_izq) begin
                ball_x <= BALL_X_INICIO; // reposicionar pelota al centro
                ball_y <= BALL_Y_INICIO;
                goal_p2 <= 1; // marcar gol para jugador 2
                dir_x <= 1; // mantener direccion a izquierda
            end else begin
                ball_x <= ball_x - BALL_SPEED;
            end
        end else begin // derecha
            if (hit_p2) begin
                ball_x <= P2_X - BALL_W; // reposicionar pelota a la izquierda de la paleta
                dir_x <= !dir_x; // cambiar direccion a izquierda
            end else if (gol_der) begin
                ball_x <= BALL_X_INICIO; // reposicionar pelota al centro
                ball_y <= BALL_Y_INICIO;
                goal_p1 <= 1; // marcar gol para jugador 1
                dir_x <= 0; // mantener direccion a derecha
            end else begin
                ball_x <= ball_x + BALL_SPEED;
            end
        end

        if (!gol) begin
            if (dir_y == 1) begin // arriba
                if (ball_y <= Y_MIN + BALL_SPEED) begin
                    ball_y <= Y_MIN;
                    dir_y <= !dir_y; // cambiar direccion a abajo
                end else begin
                    ball_y <= ball_y - BALL_SPEED;
                end
            end else begin // abajo
                if (ball_y >= Y_MAX - BALL_SPEED) begin
                    ball_y <= Y_MAX;
                    dir_y <= !dir_y; // cambiar direccion a arriba
                end else begin
                    ball_y <= ball_y + BALL_SPEED;
                end    
            end   
        end
    end 
end

endmodule