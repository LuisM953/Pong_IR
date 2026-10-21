`timescale 1ns/1ps
module vga_sync_tb;
    reg clk; 
    reg reset;
    reg medido;
    time t_inicio, t_fin, ancho;
    wire hsync, vsync, video_on, tick;
    wire [9:0] x, y;

    vga_sync dut (.clk(clk), .reset(reset), .hsync(hsync), .vsync(vsync),
                  .video_on(video_on), .x(x), .y(y), .tick(tick));

    always #5 clk = ~clk;          // periodo 10 ns = 100 MHz

    initial begin //Estimulo
        $dumpfile("vga_sync_tb.vcd");
        $dumpvars(0, vga_sync_tb); 
        clk = 0;
        medido = 0;
        reset = 1; 
        #100 reset = 0;
        #20000000;
        if (!medido) $display("FAIL: hsync nunca completo el pulso");
        $finish;
    end

    initial begin //Medicion hsync
        wait (reset == 0);          // espera a que termine el reset
        @(negedge hsync);           // espera la bajada de hsync
        t_inicio = $time;        
        @(posedge hsync);         
        t_fin = $time;
        ancho = t_fin - t_inicio;           
        if (ancho !== 3840) $display("FAIL: ancho de hsync = %0d ns (esperado 3840)", ancho);
        else                $display("PASS: ancho de hsync = %0d ns", ancho);
        medido = 1; 
    end
endmodule