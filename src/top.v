module top_pong (
    input  wire clk,
    input  wire reset,
    input  wire up_p1,
    input  wire down_p1,
    input  wire up_p2,
    input  wire down_p2,
    output wire hsync,
    output wire vsync,
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
                PADDLE_SPEED  = 4,
                BALL_SPEED    = 2;

    wire video_on, frame_tick, hit_p1, hit_p2, goal_p1, goal_p2;
    wire [9:0] x, y, p1_y, p2_y, ball_x, ball_y;

    vga_sync controlador_vga (
        .clk(clk),
        .reset(reset),
        .hsync(hsync),
        .vsync(vsync),
        .video_on(video_on),
        .x(x),
        .y(y),
        .frame_tick(frame_tick),
        .tick()
    );

    paddle_move #(
        .SCREEN_H(SCREEN_H),
        .PADDLE_H(PADDLE_H),
        .BORDER_W(BORDER_W),
        .SPEED(PADDLE_SPEED)
    ) paddle1 (
        .clk(clk),
        .reset(reset),
        .frame_tick(frame_tick),
        .up(up_p1),
        .down(down_p1),
        .y(p1_y)
    );

    paddle_move #(
        .SCREEN_H(SCREEN_H),
        .PADDLE_H(PADDLE_H),
        .BORDER_W(BORDER_W),
        .SPEED(PADDLE_SPEED)
    ) paddle2 (
        .clk(clk),
        .reset(reset),
        .frame_tick(frame_tick),
        .up(up_p2),
        .down(down_p2),
        .y(p2_y)
    );

    pixel_gen #(
        .SCREEN_W(SCREEN_W),
        .SCREEN_H(SCREEN_H),
        .PADDLE_W(PADDLE_W),
        .PADDLE_H(PADDLE_H),
        .BALL_W(BALL_W),
        .BALL_H(BALL_H),
        .LINE_W(LINE_W),
        .MARGIN(MARGIN),
        .BORDER_W(BORDER_W)
    ) generador_imagen (
        .x(x),
        .y(y),
        .video_on(video_on),
        .p1_y(p1_y),
        .p2_y(p2_y),
        .ball_x(ball_x),
        .ball_y(ball_y),
        .rgb(rgb)
    );

    ball_move #(
        .SCREEN_W(SCREEN_W),
        .SCREEN_H(SCREEN_H),
        .BORDER_W(BORDER_W),
        .PADDLE_W(PADDLE_W),
        .BALL_W(BALL_W),
        .BALL_H(BALL_H),
        .MARGIN(MARGIN),
        .BALL_SPEED(BALL_SPEED)
    ) movimiento_pelota (
        .clk(clk),
        .reset(reset),
        .frame_tick(frame_tick),
        .hit_p1(hit_p1),
        .hit_p2(hit_p2),
        .ball_x(ball_x),
        .ball_y(ball_y),
        .goal_p1(goal_p1),
        .goal_p2(goal_p2)
    );

    hitbox #(
        .SCREEN_W(SCREEN_W),
        .MARGIN(MARGIN),
        .PADDLE_W(PADDLE_W),
        .PADDLE_H(PADDLE_H),
        .BALL_W(BALL_W),
        .BALL_H(BALL_H)
    ) detector_colisiones (
        .p1_y(p1_y),
        .p2_y(p2_y),
        .ball_x(ball_x),
        .ball_y(ball_y),
        .hit_p1(hit_p1),
        .hit_p2(hit_p2)
    );

endmodule