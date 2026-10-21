`timescale 1ns/1ps
module vga_sync_tb;
    reg clk; 
    reg reset;
    wire hsync, vsync, video_on, tick;
    wire [9:0] x, y;

    vga_sync dut (.clk(clk), .reset(reset), .hsync(hsync), .vsync(vsync),
                  .video_on(video_on), .x(x), .y(y), .tick(tick));

    always #5 clk = ~clk;          // periodo 10 ns = 100 MHz

    initial begin
        $dumpfile("vga_sync_tb.vcd");
        $dumpvars(0, vga_sync_tb); 
        clk = 0;
        reset = 1; 
        #100 reset = 0;
        #20000000;
        $finish;
    end
endmodule