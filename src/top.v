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

    wire [9:0] x, y;
    wire video_on;
    wire frame_tick;
    wire [9:0] p1_y;
    wire [9:0] p2_y;

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
        .rgb(rgb)
    );

endmodule