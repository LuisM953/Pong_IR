`timescale 1ns/1ps
module vga_sync_tb;
    reg clk; 
    reg reset;
    reg medido;
    reg medido_ft;
    
    time t_inicio, t_fin, ancho;
    time t_ft_prev, ft_ancho, ft_periodo;
    
    wire hsync, vsync, video_on, tick, frame_tick;
    wire [9:0] x, y;

    vga_sync dut (.clk(clk), .reset(reset), .hsync(hsync), .vsync(vsync),
                  .video_on(video_on), .x(x), .y(y), .tick(tick), 
                  .frame_tick(frame_tick));

    always #5 clk = ~clk;

    initial begin // Estimulo
        $dumpfile("vga_sync_tb.vcd");
        $dumpvars(0, vga_sync_tb); 
        clk = 0;
        medido = 0;
        medido_ft = 0;
        
        reset = 1; 
        #50; 
        
        // Corrección del reset
        if (frame_tick !== 1'b0) 
            $display("FAIL: frame_tick no es 0 durante el reset (valor detectado: %b)", frame_tick);
        else                     
            $display("PASS: frame_tick en 0 durante el reset");
        
        #50 reset = 0; 
        
        #35000000; 
        
        if (!medido) $display("FAIL: hsync nunca completo el pulso");
        if (!medido_ft) $display("FAIL: frame_tick nunca completo la medicion");
        $finish;
    end

    initial begin // Medicion hsync
        wait (reset == 0);          
        @(negedge hsync);           
        t_inicio = $time;        
        @(posedge hsync);         
        t_fin = $time;
        ancho = t_fin - t_inicio;            
        if (ancho !== 3840) $display("FAIL: ancho de hsync = %0d ns (esperado 3840)", ancho);
        else                $display("PASS: ancho de hsync = %0d ns", ancho);
        medido = 1; 
    end
    
    initial begin // Medicion frame_tick
        wait (reset == 0);
        
        @(posedge frame_tick);
        t_ft_prev = $time;
        
        // 2. Comprobación de posición espacial al instante de subir el pulso
        if (x !== 10'd799 || y !== 10'd524) begin
            $display("FAIL: frame_tick en posicion incorrecta x:%0d, y:%0d (esperado 799, 524)", x, y);
        end else begin
            $display("PASS: frame_tick en posicion correcta x:799, y:524");
        end
        
        @(negedge frame_tick);
        ft_ancho = $time - t_ft_prev;
        if (ft_ancho !== 10) $display("FAIL: ancho de frame_tick = %0d ns (esperado 10)", ft_ancho);
        else                 $display("PASS: ancho de frame_tick = %0d ns", ft_ancho);
        
        @(posedge frame_tick);
        ft_periodo = $time - t_ft_prev;
        if (ft_periodo !== 16800000) $display("FAIL: periodo de frame_tick = %0d ns (esperado 16800000)", ft_periodo);
        else                         $display("PASS: periodo de frame_tick = %0d ns", ft_periodo);
        
        medido_ft = 1;
    end
endmodule