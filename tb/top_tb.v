`timescale 1ns / 1ps

module top_pong_tb;

    reg clk;
    reg reset;
    reg up_p1;
    reg down_p1;
    reg up_p2;
    reg down_p2;

    wire hsync;
    wire vsync;
    wire [11:0] rgb;

    integer error_count = 0;

    top_pong dut (
        .clk(clk),
        .reset(reset),
        .up_p1(up_p1),
        .down_p1(down_p1),
        .up_p2(up_p2),
        .down_p2(down_p2),
        .hsync(hsync),
        .vsync(vsync),
        .rgb(rgb)
    );

    always #5 clk = ~clk;

    // 1. Temporizador de seguridad (100 ms)
    initial begin
        #100000000; // 100 ms en nanosegundos
        $display("[FAIL] TIMEOUT: La simulacion tardo mas de 100 ms. Revisa frame_tick.");
        $finish;
    end

    // Comprobacion continua de Salida de Video (Blanking)
    always @(posedge clk) begin
        // Durante el blanking (video_on = 0), el rgb debe ser 000 siempre.
        if (!reset && dut.video_on == 1'b0) begin
            if (rgb !== 12'h000) begin
                $display("[FAIL] Blanking: rgb = %h (Esperado: 000) en x:%0d, y:%0d", rgb, dut.x, dut.y);
                error_count = error_count + 1;
            end
        end
    end

    initial begin
        $display("=== Iniciando simulacion del TOP MODULE ===");
        
        clk = 0;
        up_p1 = 0; down_p1 = 0;
        up_p2 = 0; down_p2 = 0;
        
        // --- Prueba 1: Comprobacion del Reset ---
        reset = 1;
        #100;
        reset = 0;
        #10;
        
        // Comprobar que al soltar el reset ambas paletas valen 200.
        if (dut.p1_y === 10'd200 && dut.p2_y === 10'd200) begin
            $display("[PASS] Reset: p1_y = 200, p2_y = 200");
        end else begin
            $display("[FAIL] Reset: p1_y = %0d, p2_y = %0d (Esperado: 200, 200)", dut.p1_y, dut.p2_y);
            error_count = error_count + 1;
        end

        // --- Prueba 2: Movimiento con boton (Jugador 1) ---
        $display("--- Probando up_p1 (Jugador 1) durante varios cuadros ---");
        up_p1 = 1; 
        
        // Primer frame_tick
        @(posedge dut.frame_tick);
        @(posedge clk); 
        #1; // Esperar 1 ns despues del flanco para leer el registro ya actualizado
        
        if (dut.p1_y === 10'd196 && dut.p2_y === 10'd200) begin
            $display("[PASS] up_p1 (Frame 1): p1_y = 196, p2_y = 200");
        end else begin
            $display("[FAIL] up_p1 (Frame 1): p1_y = %0d, p2_y = %0d", dut.p1_y, dut.p2_y);
            error_count = error_count + 1;
        end
        
        // Segundo frame_tick
        @(posedge dut.frame_tick);
        @(posedge clk);
        #1; // Retardo para leer correctamente
        
        if (dut.p1_y === 10'd192 && dut.p2_y === 10'd200) begin
            $display("[PASS] up_p1 (Frame 2): p1_y = 192, p2_y = 200");
        end else begin
            $display("[FAIL] up_p1 (Frame 2): p1_y = %0d, p2_y = %0d", dut.p1_y, dut.p2_y);
            error_count = error_count + 1;
        end
        
        // Al apagar el boton aqui (1 ns despues del flanco), evitamos la carrera del caso 2.
        up_p1 = 0; 

        // --- Prueba 3: Los dos jugadores (Jugador 2) ---
        $display("--- Probando down_p2 (Jugador 2) ---");
        
        // Al encender el boton aqui, lo hacemos lejos del flanco anterior.
        down_p2 = 1; 
        
        // Tercer frame_tick
        @(posedge dut.frame_tick);
        @(posedge clk);
        #1; // Retardo para leer correctamente
        
        // Comprobar que p2_y baja en la pantalla (aumenta a 204) y p1_y se mantiene.
        if (dut.p1_y === 10'd192 && dut.p2_y === 10'd204) begin
            $display("[PASS] down_p2 (Frame 3): p1_y = 192, p2_y = 204");
        end else begin
            $display("[FAIL] down_p2 (Frame 3): p1_y = %0d, p2_y = %0d", dut.p1_y, dut.p2_y);
            error_count = error_count + 1;
        end
        
        down_p2 = 0; 

        $display("=== Simulacion Finalizada ===");
        if (error_count == 0) begin
            $display("EXITO: TODOS LOS TESTS PASARON (0 ERRORES).");
        end else begin
            $display("ERROR: SE ENCONTRARON %0d FALLOS", error_count);
        end
        
        $finish;
    end

endmodule