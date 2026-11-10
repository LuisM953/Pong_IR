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

    wire [9:0] x, y, p1_y, p2_y, ball_x, ball_y;
    wire video_on, frame_tick, hit_p1, hit_p2;

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

    paddle_move paddle1 (
        .clk(clk),
        .reset(reset),
        .frame_tick(frame_tick),
        .up(up_p1),
        .down(down_p1),
        .y(p1_y)
    );

    paddle_move paddle2 (
        .clk(clk),
        .reset(reset),
        .frame_tick(frame_tick),
        .up(up_p2),
        .down(down_p2),
        .y(p2_y)
    );

    pixel_gen generador_imagen (
        .x(x),
        .y(y),
        .video_on(video_on),
        .p1_y(p1_y),
        .p2_y(p2_y),
        .ball_x(ball_x),
        .ball_y(ball_y),
        .rgb(rgb)
    );

    ball_move movimiento_pelota (
        .clk(clk),
        .reset(reset),
        .frame_tick(frame_tick),
        .hit_p1(hit_p1),
        .hit_p2(hit_p2),
        .ball_x(ball_x),
        .ball_y(ball_y)
    );

    hitbox detector_colisiones (
        .p1_y(p1_y),
        .p2_y(p2_y),
        .ball_x(ball_x),
        .ball_y(ball_y),
        .hit_p1(hit_p1),
        .hit_p2(hit_p2)
    );

endmodule