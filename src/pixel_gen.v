module pixel_gen #(
    parameter  SCREEN_W      = 640,
               SCREEN_H      = 480,
               PADDLE_W      = 10,
               PADDLE_H      = 80,
               BALL_W        = 10,
               BALL_H        = 10,    
               LINE_W        = 2,
               MARGIN        = 20,
               BORDER_W      = 10,
               MAX_SCORE     = 11,
               BOX_SIZE      = 6,
               BOX_MARGIN    = 2 // Restriccion -> BOX_SIZE + BOX_MARGIN (BOX_STEP) debe ser potencia de 2 (ej. 4, 8, 16)
)(
    input  wire [9:0] x,
    input  wire [9:0] y,
    input  wire [9:0] p1_y,
    input  wire [9:0] p2_y,
    input  wire [9:0] ball_x,
    input  wire [9:0] ball_y,
    input  wire [3:0] score_p1,
    input  wire [3:0] score_p2,
    input  wire video_on,
    output wire [11:0] rgb
);

localparam  LINE_INICIO   = (SCREEN_W/2  - LINE_W/2),
            P1_X_INICIO   =  MARGIN,
            P2_X_INICIO   = (SCREEN_W    - MARGIN     - PADDLE_W),
            BOX_STEP      = (BOX_SIZE    + BOX_MARGIN),
            SCORE_Y_MIN   = ((BORDER_W   - BOX_SIZE)/2),
            SCORE_Y_MAX   = (SCORE_Y_MIN + BOX_SIZE   - 1),
            SCORE_BOXES_W = (MAX_SCORE   * BOX_STEP   - BOX_MARGIN),
            P1_SC_X_MIN   = (SCREEN_W/2  - BORDER_W   - SCORE_BOXES_W),
            P1_SC_X_MAX   = (SCREEN_W/2  - BORDER_W   - 1),
            P2_SC_X_MIN   = (SCREEN_W/2  + BORDER_W),
            P2_SC_X_MAX   = (P2_SC_X_MIN + SCORE_BOXES_W - 1);

// Guardia en tiempo de elaboracion/simulacion para verificar que BOX_STEP sea potencia de 2
initial begin
    if ((BOX_STEP == 0) || ((BOX_STEP & (BOX_STEP - 1)) != 0)) begin
        $display("[ERROR] pixel_gen: BOX_STEP (%0d) = BOX_SIZE + BOX_MARGIN debe ser potencia de 2.", BOX_STEP);
        $finish;
    end
end

wire paddle1_on, paddle2_on, central_line, ball_on, border_line, scoreboard;
wire p1_box_area, p2_box_area, p1_box_on, p2_box_on;
wire [9:0] y_fold;

assign y_fold       = (y <  SCREEN_H/2) ?  y : (SCREEN_H - 1 - y);
assign paddle1_on   = (x >= P1_X_INICIO  &&  x <= P1_X_INICIO + PADDLE_W - 1)        && (y >= p1_y         &&  y <= p1_y          + PADDLE_H   - 1);
assign paddle2_on   = (x >= P2_X_INICIO  &&  x <= P2_X_INICIO + PADDLE_W - 1)        && (y >= p2_y         &&  y <= p2_y          + PADDLE_H   - 1);
assign ball_on      = (x >= ball_x       &&  x <= ball_x      + BALL_W   - 1)        && (y >= ball_y       &&  y <= ball_y        + BALL_H     - 1);
assign border_line  = (x <  BORDER_W)    || (x >= SCREEN_W    - BORDER_W)            || (y < BORDER_W)     || (y >= SCREEN_H      - BORDER_W);
assign scoreboard   = (y >= 1            &&  y <= BORDER_W - 2) && (x >= P1_SC_X_MIN -  BOX_MARGIN)        && (x <= P2_SC_X_MAX   + BOX_MARGIN);
assign p1_box_area  = (y >= SCORE_Y_MIN  &&  y <= SCORE_Y_MAX)  && (x >= P1_SC_X_MIN && x  <= P1_SC_X_MAX) && (((P1_SC_X_MAX - x) & (BOX_STEP - 1)) < BOX_SIZE);
assign p2_box_area  = (y >= SCORE_Y_MIN  &&  y <= SCORE_Y_MAX)  && (x >= P2_SC_X_MIN && x  <= P2_SC_X_MAX) && (((x - P2_SC_X_MIN) & (BOX_STEP - 1)) < BOX_SIZE);
assign p1_box_on    = p1_box_area        && ((P1_SC_X_MAX - x)  < score_p1 * BOX_STEP);
assign p2_box_on    = p2_box_area        && ((x - P2_SC_X_MIN)  < score_p2 * BOX_STEP);
assign central_line = (x >= LINE_INICIO  &&  x <= LINE_INICIO   + LINE_W   - 1)      && (y_fold[2]         == 1'b1); 
assign rgb          = !video_on                    ? 12'h000 : 
                      (paddle1_on)                 ? 12'hFF3 :
                      (paddle2_on)                 ? 12'hF35 :
                      (ball_on)                    ? 12'hE73 :
                      (p1_box_on)                  ? 12'hFF3 :
                      (p2_box_on)                  ? 12'hF35 : 
                      (p1_box_area || p2_box_area) ? 12'h213 : 
                      (scoreboard)                 ? 12'h334 :
                      (central_line)               ? 12'h667 :
                      (border_line)                ? 12'h667 :
                                                      12'h102;

endmodule