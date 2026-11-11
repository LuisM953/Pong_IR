module hitbox (
    input  wire [9:0] p1_y,
    input  wire [9:0] p2_y,
    input  wire [9:0] ball_x,
    input  wire [9:0] ball_y,
    output wire hit_p1,
    output wire hit_p2
);

localparam  SCREEN_W      = 640,
            MARGIN        = 20,
            PADDLE_W      = 10,
            PADDLE_H      = 80,
            BALL_W        = 10,
            BALL_H        = 10,
            P1_X          = MARGIN,
            P2_X          = (SCREEN_W - MARGIN - PADDLE_W);

assign hit_p1 = (ball_x >= P1_X) && (ball_x <= P1_X + PADDLE_W - 1) && (ball_y < p1_y + PADDLE_H) && (ball_y + BALL_H > p1_y);
assign hit_p2 = (ball_x <= P2_X) && (ball_x >= P2_X - BALL_W   + 1) && (ball_y < p2_y + PADDLE_H) && (ball_y + BALL_H > p2_y);

endmodule
           