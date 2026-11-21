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
               BOX_MARGIN    = 2, // Restriccion -> BOX_SIZE + BOX_MARGIN (BOX_STEP) debe ser potencia de 2 (ej. 4, 8, 16)
               PANEL_BORDER  = 5,
               JUGANDO       = 2'b01,
               GAME_OVER     = 2'b10
)(
    input  wire [9:0] x,
    input  wire [9:0] y,
    input  wire [9:0] p1_y,
    input  wire [9:0] p2_y,
    input  wire [9:0] ball_x,
    input  wire [9:0] ball_y,
    input  wire [3:0] score_p1,
    input  wire [3:0] score_p2,
    input  wire [1:0] state,
    input  wire win_p1,
    input  wire win_p2,
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
            P2_SC_X_MAX   = (P2_SC_X_MIN + SCORE_BOXES_W - 1),
            PANEL_W       = (SCREEN_W    / 4),
            PANEL_H       = (SCREEN_H    / 4),
            PANEL_X_MIN   = ((SCREEN_W   - PANEL_W)   / 2),
            PANEL_X_MAX   = (PANEL_X_MIN + PANEL_W    - 1),
            PANEL_Y_MIN   = ((SCREEN_H   - PANEL_H)   / 2),
            PANEL_Y_MAX   = (PANEL_Y_MIN + PANEL_H    - 1),
            PANEL_CX      = (PANEL_X_MIN + PANEL_W    / 2),
            PANEL_CY      = (PANEL_Y_MIN + PANEL_H    / 2),
            ICON_W        = (PANEL_W     / 2),
            ICON_H        = (PANEL_H     / 2),
            HALF_B        = (PANEL_H     / 16); // Medio bloque (bloque completo = 2*HALF_B, siempre par)   

// Guardia en tiempo de elaboracion/simulacion para verificar que BOX_STEP sea potencia de 2
initial begin
    if ((BOX_STEP == 0) || ((BOX_STEP & (BOX_STEP - 1)) != 0)) begin
        $display("[ERROR] pixel_gen: BOX_STEP (%0d) = BOX_SIZE + BOX_MARGIN debe ser potencia de 2.", BOX_STEP);
        $finish;
    end
end

wire paddle1_on, paddle2_on, central_line, ball_on, border_line, scoreboard;
wire p1_box_area, p2_box_area, p1_box_on, p2_box_on;
wire panel_area, panel_border, start_icon, digit_1, digit_2;
wire [9:0] y_fold;
reg [11:0] overlay_rgb;
reg overlay_on;

always @(*) begin
    overlay_on  = 1'b0;
    overlay_rgb = 12'h000;

    case (state)
        JUGANDO: begin
            overlay_on = 1'b0;
        end

        GAME_OVER: begin
            if (panel_area) begin
                overlay_on = 1'b1;
                if (panel_border)
                    overlay_rgb = 12'hFFF;
                else if (win_p1)
                    overlay_rgb = digit_1 ? 12'h102 : 12'hFF3;
                else if (win_p2)
                    overlay_rgb = digit_2 ? 12'h102 : 12'hF35;
                else
                    overlay_rgb = 12'h667;
            end
        end

        default: begin // REPOSO (2'b00) y 2'b11
            if (panel_area) begin
                overlay_on  = 1'b1;
                overlay_rgb = (panel_border || start_icon) ? 12'hFFF : 12'h28C;
            end
        end
    endcase
end

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
assign panel_area   = (x >= PANEL_X_MIN  && x <= PANEL_X_MAX)   && (y >= PANEL_Y_MIN && y  <= PANEL_Y_MAX);
assign panel_border = panel_area         &&(x < PANEL_X_MIN     + PANEL_BORDER       || x  > PANEL_X_MAX - PANEL_BORDER || y < PANEL_Y_MIN + PANEL_BORDER || y > PANEL_Y_MAX - PANEL_BORDER);
assign start_icon   =  (x >= PANEL_CX - ICON_W/2 && x <= PANEL_CX + ICON_W/2 - 1) && (y >= PANEL_CY - ICON_H/2 && y <= PANEL_CY + ICON_H/2 - 1);
assign digit_1      = ((x >= PANEL_CX - HALF_B   && x <= PANEL_CX + HALF_B   - 1) && (y >= PANEL_CY - 5*HALF_B && y <= PANEL_CY + 5*HALF_B - 1)) || // Tronco central
                      ((x >= PANEL_CX - 3*HALF_B && x <= PANEL_CX - HALF_B   - 1) && (y >= PANEL_CY - 3*HALF_B && y <= PANEL_CY - HALF_B   - 1)) || // Visera sup-izq
                      ((x >= PANEL_CX - 3*HALF_B && x <= PANEL_CX + 3*HALF_B - 1) && (y >= PANEL_CY + 3*HALF_B && y <= PANEL_CY + 5*HALF_B - 1));   // Base inferior
assign digit_2      = ((x >= PANEL_CX - 3*HALF_B && x <= PANEL_CX + 3*HALF_B - 1) && (y >= PANEL_CY - 5*HALF_B && y <= PANEL_CY - 3*HALF_B - 1)) || // Barra superior
                      ((x >= PANEL_CX + HALF_B   && x <= PANEL_CX + 3*HALF_B - 1) && (y >= PANEL_CY - 5*HALF_B && y <= PANEL_CY + HALF_B   - 1)) || // Bajada derecha
                      ((x >= PANEL_CX - 3*HALF_B && x <= PANEL_CX + 3*HALF_B - 1) && (y >= PANEL_CY - HALF_B   && y <= PANEL_CY + HALF_B   - 1)) || // Barra central
                      ((x >= PANEL_CX - 3*HALF_B && x <= PANEL_CX - HALF_B   - 1) && (y >= PANEL_CY - HALF_B   && y <= PANEL_CY + 5*HALF_B - 1)) || // Bajada izquierda
                      ((x >= PANEL_CX - 3*HALF_B && x <= PANEL_CX + 3*HALF_B - 1) && (y >= PANEL_CY + 3*HALF_B && y <= PANEL_CY + 5*HALF_B - 1));   // Barra inferior
assign rgb          = !video_on                    ? 12'h000     :
                      (overlay_on)                 ? overlay_rgb :
                      (paddle1_on)                 ? 12'hFF3     :
                      (paddle2_on)                 ? 12'hF35     :
                      (ball_on)                    ? 12'hE73     :
                      (p1_box_on)                  ? 12'hFF3     :
                      (p2_box_on)                  ? 12'hF35     : 
                      (p1_box_area || p2_box_area) ? 12'h213     : 
                      (scoreboard)                 ? 12'h334     :
                      (central_line)               ? 12'h667     :
                      (border_line)                ? 12'h667     :
                                                     12'h102     ;

endmodule