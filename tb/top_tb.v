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

    top_pong #(
        .CALIB_FRAMES(0) // MODIFICADO: Omitir calibracion inicial para simular el juego directamente
    ) dut (
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

    // 1. Temporizador de seguridad ampliado a 300 ms para dar margen amplio a los 7 cuadros completos
    initial begin
        #300000000; // 300 ms en nanosegundos
        $display("[FAIL] TIMEOUT: La simulacion tardo mas de 300 ms. Revisa frame_tick.");
        $finish;
    end

    // Comprobacion continua de Salida de Video (Blanking)
    always @(posedge clk) begin
        if (!reset) begin
            // Durante el blanking (video_on = 0), el rgb debe ser 000 siempre.
            if (dut.video_on == 1'b0) begin
                if (rgb !== 12'h000) begin
                    $display("[FAIL] Blanking: rgb = %h (Esperado: 000) en x:%0d, y:%0d", rgb, dut.x, dut.y);
                    error_count = error_count + 1;
                end
            end 
            // Integracion RGB Pelota (esquina superior izq)
            else if (dut.x == dut.ball_x && dut.y == dut.ball_y) begin 
                if (rgb !== 12'hE73) begin
                    $display("[FAIL] Integracion Pelota: rgb = %h (Esperado: E73) en x:%0d, y:%0d", rgb, dut.x, dut.y);
                    error_count = error_count + 1;
                end
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
        
        // Comprobar que al soltar el reset las paletas valen 200 y la pelota esta en el centro (315, 235)
        // Verificar tambien marcador inicial 0-0 y banderas de victoria en 0
        if (dut.p1_y === 10'd200 && dut.p2_y === 10'd200 && dut.ball_x === 10'd315 && dut.ball_y === 10'd235 &&
            dut.goal_p1 === 1'b0 && dut.goal_p2 === 1'b0 &&
            dut.score_p1 === 4'd0 && dut.score_p2 === 4'd0 && dut.win_p1 === 1'b0 && dut.win_p2 === 1'b0) begin
            $display("[PASS] Reset: p1_y = 200, p2_y = 200, pelota = (315, 235), score = 0-0, win = 0");
        end else begin
            $display("[FAIL] Reset: p1_y = %0d, p2_y = %0d, pelota = (%0d, %0d), score = %0d-%0d, win = %b-%b", 
                     dut.p1_y, dut.p2_y, dut.ball_x, dut.ball_y, dut.score_p1, dut.score_p2, dut.win_p1, dut.win_p2);
            error_count = error_count + 1;
        end

        // --- Prueba 2: Movimiento con boton (Jugador 1) ---
        $display("--- Probando up_p1 (Jugador 1) durante varios cuadros ---");
        up_p1 = 1; 
        
        // Primer frame_tick
        @(posedge dut.frame_tick);
        @(posedge clk); 
        #1; // Esperar 1 ns despues del flanco para leer el registro ya actualizado
        
        if (dut.p1_y === 10'd196 && dut.p2_y === 10'd200 && dut.ball_x === 10'd313 && dut.ball_y === 10'd233) begin
            $display("[PASS] up_p1 (Frame 1): p1_y = 196, p2_y = 200, pelota = (313, 233)");
        end else begin
            $display("[FAIL] up_p1 (Frame 1): p1_y = %0d, p2_y = %0d, pelota = (%0d, %0d)", 
                     dut.p1_y, dut.p2_y, dut.ball_x, dut.ball_y);
            error_count = error_count + 1;
        end
        
        // Segundo frame_tick
        @(posedge dut.frame_tick);
        @(posedge clk);
        #1; // Retardo para leer correctamente
        
        if (dut.p1_y === 10'd192 && dut.p2_y === 10'd200 && dut.ball_x === 10'd311 && dut.ball_y === 10'd231) begin
            $display("[PASS] up_p1 (Frame 2): p1_y = 192, p2_y = 200, pelota = (311, 231)");
        end else begin
            $display("[FAIL] up_p1 (Frame 2): p1_y = %0d, p2_y = %0d, pelota = (%0d, %0d)", 
                     dut.p1_y, dut.p2_y, dut.ball_x, dut.ball_y);
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
        
        if (dut.p1_y === 10'd192 && dut.p2_y === 10'd204 && dut.ball_x === 10'd309 && dut.ball_y === 10'd229) begin
            $display("[PASS] down_p2 (Frame 3): p1_y = 192, p2_y = 204, pelota = (309, 229)");
        end else begin
            $display("[FAIL] down_p2 (Frame 3): p1_y = %0d, p2_y = %0d, pelota = (%0d, %0d)", 
                     dut.p1_y, dut.p2_y, dut.ball_x, dut.ball_y);
            error_count = error_count + 1;
        end
        
        down_p2 = 0; 

        // Prueba 4: Integración Hitbox en Top (Rebote cruzando la paleta 1 en 2 pasos) ---
        $display("--- Probando integracion de Hitbox en Top ---");
        
        // Posición previa al flanco en x = 31
        dut.movimiento_pelota.ball_x = 10'd31;
        dut.movimiento_pelota.ball_y = 10'd200;
        dut.movimiento_pelota.dir_x  = 1'b1;
        dut.paddle1.y                = 10'd200;

        // Primer frame_tick: la pelota avanza de 31 a 29 (entrando a la hitbox)
        @(posedge dut.frame_tick);
        @(posedge clk);
        #1;

        if (dut.movimiento_pelota.ball_x === 10'd29 && dut.movimiento_pelota.dir_x === 1'b1) begin
            $display("[PASS] Integracion Hitbox (Paso 1): ball_x = 29, dir_x = 1");
        end else begin
            $display("[FAIL] Integracion Hitbox (Paso 1): ball_x = %0d, dir_x = %b (Esperado: 29, 1)", dut.movimiento_pelota.ball_x, dut.movimiento_pelota.dir_x);
            error_count = error_count + 1;
        end

        // Segundo frame_tick: la pelota detecta hit_p1, rebota y se posiciona en 30 con dir_x = 0
        @(posedge dut.frame_tick);
        @(posedge clk);
        #1;

        if (dut.movimiento_pelota.ball_x === 10'd30 && dut.movimiento_pelota.dir_x === 1'b0) begin
            $display("[PASS] Integracion Hitbox (Paso 2): Rebote exitoso, ball_x = 30, dir_x = 0");
        end else begin
            $display("[FAIL] Integracion Hitbox (Paso 2): ball_x = %0d, dir_x = %b (Esperado: 30, 0)", dut.movimiento_pelota.ball_x, dut.movimiento_pelota.dir_x);
            error_count = error_count + 1;
        end

        // --- Prueba 5: Integracion de Goles, Reinicio y Marcador (Score) en Top ---
        $display("--- Probando integracion de Goles, Reinicio y Score en Top ---");

        // Caso 5A: Gol en pared izquierda (esquivando paleta 1, ball_x = 12, dir_x = 1 -> goal_p2 = 1 y centro)
        dut.movimiento_pelota.ball_x = 10'd12;
        dut.movimiento_pelota.ball_y = 10'd100;
        dut.movimiento_pelota.dir_x  = 1'b1;
        dut.movimiento_pelota.dir_y  = 1'b0;
        dut.paddle1.y                = 10'd300; // Paleta 1 lejos para asegurar que no haya rebote

        @(posedge dut.frame_tick);
        @(posedge clk);
        #1;

        if (dut.ball_x === 10'd315 && dut.ball_y === 10'd235 && dut.goal_p2 === 1'b1 && dut.goal_p1 === 1'b0 && dut.movimiento_pelota.dir_x === 1'b1) begin
            $display("[PASS] Integracion Gol P2: Pelota reiniciada a (315, 235), goal_p2 = 1, dir_x = 1");
        end else begin
            $display("[FAIL] Integracion Gol P2: pelota = (%0d, %0d), goal_p2 = %b, goal_p1 = %b, dir_x = %b",
                     dut.ball_x, dut.ball_y, dut.goal_p2, dut.goal_p1, dut.movimiento_pelota.dir_x);
            error_count = error_count + 1;
        end

        // Comprobar limpieza del pulso goal_p2 e incremento de score_p2 a 1 (marcador 0-1)
        @(posedge clk);
        #1;
        if (dut.goal_p2 !== 1'b0 || dut.score_p1 !== 4'd0 || dut.score_p2 !== 4'd1) begin
            $display("[FAIL] Integracion Score P2: goal_p2 = %b (Esp:0), score = %0d-%0d (Esp: 0-1)",
                     dut.goal_p2, dut.score_p1, dut.score_p2);
            error_count = error_count + 1;
        end else begin
            $display("[PASS] Integracion Score P2: Pulso limpio y marcador actualizado a 0-1");
        end

        // MODIFICADO: Verificar integracion RGB del marcador en pantalla (0-1 -> P1 caja 0 apagada, P2 caja 0 encendida)
        wait (dut.x == 10'd309 && dut.y == 10'd4);
        #1;
        if (rgb !== 12'h213) begin
            $display("[FAIL] Integracion RGB Score P1 (0-1): rgb = %h (Esp: 213) en (309, 4)", rgb);
            error_count = error_count + 1;
        end else begin
            $display("[PASS] Integracion RGB Score P1 (0-1): Caja 0 apagada (213)");
        end

        wait (dut.x == 10'd330 && dut.y == 10'd4);
        #1;
        if (rgb !== 12'hF35) begin
            $display("[FAIL] Integracion RGB Score P2 (0-1): rgb = %h (Esp: F35) en (330, 4)", rgb);
            error_count = error_count + 1;
        end else begin
            $display("[PASS] Integracion RGB Score P2 (0-1): Caja 0 encendida (F35)");
        end

        // Caso 5B: Gol en pared derecha (esquivando paleta 2, ball_x = 618, dir_x = 0 -> goal_p1 = 1 y centro)
        dut.movimiento_pelota.ball_x = 10'd618;
        dut.movimiento_pelota.ball_y = 10'd100;
        dut.movimiento_pelota.dir_x  = 1'b0;
        dut.movimiento_pelota.dir_y  = 1'b0;
        dut.paddle2.y                = 10'd300; // Paleta 2 lejos para asegurar que no haya rebote

        @(posedge dut.frame_tick);
        @(posedge clk);
        #1;

        if (dut.ball_x === 10'd315 && dut.ball_y === 10'd235 && dut.goal_p1 === 1'b1 && dut.goal_p2 === 1'b0 && dut.movimiento_pelota.dir_x === 1'b0) begin
            $display("[PASS] Integracion Gol P1: Pelota reiniciada a (315, 235), goal_p1 = 1, dir_x = 0");
        end else begin
            $display("[FAIL] Integracion Gol P1: pelota = (%0d, %0d), goal_p1 = %b, goal_p2 = %b, dir_x = %b",
                     dut.ball_x, dut.ball_y, dut.goal_p1, dut.goal_p2, dut.movimiento_pelota.dir_x);
            error_count = error_count + 1;
        end

        // Comprobar limpieza del pulso goal_p1 e incremento de score_p1 a 1 (marcador 1-1)
        @(posedge clk);
        #1;
        if (dut.goal_p1 !== 1'b0 || dut.score_p1 !== 4'd1 || dut.score_p2 !== 4'd1) begin
            $display("[FAIL] Integracion Score P1: goal_p1 = %b (Esp:0), score = %0d-%0d (Esp: 1-1)",
                     dut.goal_p1, dut.score_p1, dut.score_p2);
            error_count = error_count + 1;
        end else begin
            $display("[PASS] Integracion Score P1: Pulso limpio y marcador actualizado a 1-1");
        end

        // MODIFICADO: Verificar integracion RGB del marcador en pantalla (1-1 -> P1 caja 0 encendida en amarillo)
        wait (dut.x == 10'd309 && dut.y == 10'd4);
        #1;
        if (rgb !== 12'hFF3) begin
            $display("[FAIL] Integracion RGB Score P1 (1-1): rgb = %h (Esp: FF3) en (309, 4)", rgb);
            error_count = error_count + 1;
        end else begin
            $display("[PASS] Integracion RGB Score P1 (1-1): Caja 0 encendida (FF3)");
        end

        $display("=== Simulacion Finalizada ===");
        if (error_count == 0) begin
            $display("EXITO: TODOS LOS TESTS PASARON (0 ERRORES).");
        end else begin
            $display("ERROR: SE ENCONTRARON %0d FALLOS", error_count);
        end
        
        $finish;
    end

endmodule