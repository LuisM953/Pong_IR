module pixel_gen (
    input  wire [9:0] x,
    input  wire [9:0] y,
    input  wire [9:0] p1_y,
    input  wire [9:0] p2_y,
    input  wire video_on,
    output wire [11:0] rgb
);

localparam  SCREEN_W      = 640,
            SCREEN_H      = 480,
            PADDLE_W      = 10,
            PADDLE_H      = 80,
            BALL_W        = 10,
            BALL_H        = 10,    
            LINE_W        = 2,
            MARGIN        = 20,
            BORDER_W      = 10,
            LINE_INICIO   = (SCREEN_W/2 - LINE_W/2),
            P1_X_INICIO   = MARGIN,
            P2_X_INICIO   = (SCREEN_W-MARGIN-PADDLE_W),
            BALL_X_INICIO = (SCREEN_W/2 - BALL_W/2),
            BALL_Y_INICIO = (SCREEN_H/2 - BALL_H/2);

wire paddle1_on, paddle2_on, central_line, ball_on, border_line;
wire [9:0] y_fold;

assign y_fold       = (y < SCREEN_H/2) ? y : (SCREEN_H - 1 - y);
assign paddle1_on   = (x >= P1_X_INICIO && x <= P1_X_INICIO + PADDLE_W - 1)   && (y >= p1_y && y <= p1_y + PADDLE_H - 1);
assign paddle2_on   = (x >= P2_X_INICIO && x <= P2_X_INICIO + PADDLE_W - 1)   && (y >= p2_y && y <= p2_y + PADDLE_H - 1);
assign ball_on      = (x >= BALL_X_INICIO && x <= BALL_X_INICIO + BALL_W - 1) && (y >= BALL_Y_INICIO && y <= BALL_Y_INICIO + BALL_H - 1);
assign central_line = (x >= LINE_INICIO && x <= LINE_INICIO + LINE_W - 1)     && (y_fold[2] == 1'b1); 
assign border_line  = (x < BORDER_W) || (x >= SCREEN_W - BORDER_W) || (y < BORDER_W) || (y >= SCREEN_H - BORDER_W);
assign rgb          = !video_on                  ? 12'h000 : 
                      (paddle1_on)               ? 12'hFF3 :
                      (paddle2_on)               ? 12'hF35 :
                      (ball_on)                  ? 12'hE73 :
                      (central_line)             ? 12'h667 :
                      (border_line)              ? 12'h667 :
                                                   12'h102;

endmodule