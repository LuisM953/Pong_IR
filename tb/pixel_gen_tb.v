`timescale 1ns / 1ps

module pixel_gen_tb;

    // Entradas
    reg [9:0] x;
    reg [9:0] y;
    reg video_on;
    reg [9:0] p1_y;
    reg [9:0] p2_y;
    reg [9:0] ball_x;
    reg [9:0] ball_y;

    // Salida
    wire [11:0] rgb;

    integer error_count = 0;

    // Instancia del modulo a probar (DUT)
    pixel_gen uut (
        .x(x),
        .y(y),
        .video_on(video_on),
        .p1_y(p1_y),
        .p2_y(p2_y),
        .ball_x(ball_x),
        .ball_y(ball_y),
        .rgb(rgb)
    );

    // Tarea para automatizar estimulos y verificacion de resultados
    task check_pixel;
        input [9:0] test_x;
        input [9:0] test_y;
        input test_video;
        input [11:0] expected_rgb;
        input [255:0] test_name;
        begin
            x = test_x;
            y = test_y;
            video_on = test_video;

            #10; // Espera para propagacion combinacional

            if (rgb === expected_rgb) begin
                $display("[PASS] %-60s | x:%3d, y:%3d, vid:%b | Salida: %h", test_name, test_x, test_y, test_video, rgb);
            end else begin
                $display("[FAIL] %-60s | x:%3d, y:%3d, vid:%b | Salida: %h (Esp: %h)", test_name, test_x, test_y, test_video, rgb, expected_rgb);
                error_count = error_count + 1;
            end
        end
    endtask

    initial begin
        $display("=== Iniciando simulacion ===");
        
        // Inicializar posiciones fijas para pruebas heredadas
        p1_y = 10'd200;
        p2_y = 10'd200;
        ball_x = 10'd315;
        ball_y = 10'd235;

        // --- 1. Video desactivado ---
        check_pixel(10'd20,  10'd200, 1'b0, 12'h000, "Video apagado en P1");
        check_pixel(10'd315, 10'd235, 1'b0, 12'h000, "Video apagado en Pelota");

        // --- 2. Fondo y Borde general ---
        check_pixel(10'd0,   10'd0,   1'b1, 12'h667, "Borde: Esquina Sup-Izq exterior");
        check_pixel(10'd10,  10'd10,  1'b1, 12'h102, "Fondo: Esquina Sup-Izq interior");
        check_pixel(10'd100, 10'd100, 1'b1, 12'h102, "Fondo: Zona libre");

        // --- 3. Paddle 1 (X: 20..29, Y: 200..279) ---
        check_pixel(10'd20,  10'd200, 1'b1, 12'hFF3, "P1: Esquina Sup-Izq");
        check_pixel(10'd29,  10'd279, 1'b1, 12'hFF3, "P1: Esquina Inf-Der");
        check_pixel(10'd19,  10'd240, 1'b1, 12'h102, "P1 Borde: 1px Izquierda (Fondo)");
        check_pixel(10'd30,  10'd240, 1'b1, 12'h102, "P1 Borde: 1px Derecha (Fondo)");
        check_pixel(10'd25,  10'd199, 1'b1, 12'h102, "P1 Borde: 1px Arriba (Fondo)");
        check_pixel(10'd25,  10'd280, 1'b1, 12'h102, "P1 Borde: 1px Abajo (Fondo)");

        // --- 4. Paddle 2 (X: 610..619, Y: 200..279) ---
        check_pixel(10'd610, 10'd200, 1'b1, 12'hF35, "P2: Esquina Sup-Izq");
        check_pixel(10'd619, 10'd279, 1'b1, 12'hF35, "P2: Esquina Inf-Der");
        check_pixel(10'd609, 10'd240, 1'b1, 12'h102, "P2 Borde: 1px Izquierda (Fondo)");
        check_pixel(10'd620, 10'd240, 1'b1, 12'h102, "P2 Borde: 1px Derecha (Fondo)");
        check_pixel(10'd615, 10'd199, 1'b1, 12'h102, "P2 Borde: 1px Arriba (Fondo)");
        check_pixel(10'd615, 10'd280, 1'b1, 12'h102, "P2 Borde: 1px Abajo (Fondo)");

        // --- 5. Pelota (Centro, posición por defecto) ---
        check_pixel(10'd315, 10'd235, 1'b1, 12'hE73, "Pelota (Centro): Esquina Sup-Izq");
        check_pixel(10'd324, 10'd244, 1'b1, 12'hE73, "Pelota (Centro): Esquina Inf-Der");
        check_pixel(10'd314, 10'd240, 1'b1, 12'h102, "Pelota (Centro) Borde: 1px Izq (Fondo)");
        check_pixel(10'd325, 10'd240, 1'b1, 12'h102, "Pelota (Centro) Borde: 1px Der (Fondo)");
        check_pixel(10'd317, 10'd234, 1'b1, 12'h102, "Pelota (Centro) Borde: 1px Arr (Fondo)");
        check_pixel(10'd317, 10'd245, 1'b1, 12'h102, "Pelota (Centro) Borde: 1px Aba (Fondo)");

        // --- 6. Linea Central (X: 319..320) ---
        check_pixel(10'd319, 10'd20,  1'b1, 12'h667, "Linea Central: Tramo ON superior");
        check_pixel(10'd319, 10'd24,  1'b1, 12'h102, "Linea Central: Tramo OFF superior");
        check_pixel(10'd319, 10'd459, 1'b1, 12'h667, "Linea Central: Espejo Inferior");
        check_pixel(10'd318, 10'd20,  1'b1, 12'h102, "Linea Borde: 1px Izq (Fondo)");
        check_pixel(10'd321, 10'd20,  1'b1, 12'h102, "Linea Borde: 1px Der (Fondo)");
        
        // --- 7. Casos limite con paleta desplazada (al tope Y_MIN = 10) ---
        p1_y = 10'd10;
        check_pixel(10'd20,  10'd10,  1'b1, 12'hFF3, "P1 Desplazado (Y=10): Esq Sup-Izq");
        check_pixel(10'd29,  10'd89,  1'b1, 12'hFF3, "P1 Desplazado (Y=10): Esq Inf-Der");
        check_pixel(10'd25,  10'd90,  1'b1, 12'h102, "P1 Desplazado Borde: 1px Abajo (Fondo)");
        check_pixel(10'd19,  10'd40,  1'b1, 12'h102, "P1 Desplazado Borde: 1px Izq (Fondo)");
        check_pixel(10'd30,  10'd40,  1'b1, 12'h102, "P1 Desplazado Borde: 1px Der (Fondo)");
        p1_y = 10'd200; // Limpieza

        p2_y = 10'd390;
        check_pixel(10'd610, 10'd390, 1'b1, 12'hF35, "P2 Desplazado (Y=390): Esq Sup-Izq");
        check_pixel(10'd619, 10'd469, 1'b1, 12'hF35, "P2 Desplazado (Y=390): Esq Inf-Der");
        check_pixel(10'd615, 10'd470, 1'b1, 12'h667, "P2 Desplazado Borde: 1px Abajo (Borde)"); // MODIFICADO: Espera 667 y texto (Borde)
        check_pixel(10'd615, 10'd389, 1'b1, 12'h102, "P2 Desplazado Borde: 1px Arriba (Fondo)");
        p2_y = 10'd200; // Limpieza

        // Pruebas de Prioridad (Colisiones de Dibujo)
        check_pixel(10'd319, 10'd236, 1'b1, 12'hE73, "Prioridad: Pelota tapa a Linea Central (319, 236)");

        ball_x = 10'd25;
        ball_y = 10'd205; 
        check_pixel(10'd25, 10'd205, 1'b1, 12'hFF3, "Prioridad: Paleta 1 tapa a Pelota (25, 205)");
        
        ball_x = 10'd315; // Limpieza
        ball_y = 10'd235;

        // --- 8. Casos limite con pelota desplazada a las cuatro esquinas (10x10) ---
        
        // Esquina Superior Izquierda (10, 10)
        ball_x = 10'd10;
        ball_y = 10'd10;
        check_pixel(10'd10, 10'd10, 1'b1, 12'hE73, "Pelota Desplazada (10,10): Esq Sup-Izq");
        check_pixel(10'd19, 10'd19, 1'b1, 12'hE73, "Pelota Desplazada (10,10): Esq Inf-Der");
        check_pixel(10'd9,  10'd10, 1'b1, 12'h667, "Pelota Desplazada (10,10) Borde: 1px Izq (Borde)");
        check_pixel(10'd10, 10'd9,  1'b1, 12'h667, "Pelota Desplazada (10,10) Borde: 1px Arr (Borde)");
        check_pixel(10'd20, 10'd20, 1'b1, 12'h102, "Pelota Desplazada (10,10) Borde: Fuera (Fondo)");

        // Esquina Superior Derecha (620, 10)
        ball_x = 10'd620;
        ball_y = 10'd10;
        check_pixel(10'd620, 10'd10, 1'b1, 12'hE73, "Pelota Desplazada (620,10): Esq Sup-Izq");
        check_pixel(10'd629, 10'd19, 1'b1, 12'hE73, "Pelota Desplazada (620,10): Esq Inf-Der");
        check_pixel(10'd630, 10'd10, 1'b1, 12'h667, "Pelota Desplazada (620,10) Borde: 1px Der (Borde)");
        check_pixel(10'd620, 10'd9,  1'b1, 12'h667, "Pelota Desplazada (620,10) Borde: 1px Arr (Borde)");
        check_pixel(10'd619, 10'd20, 1'b1, 12'h102, "Pelota Desplazada (620,10) Borde: Fuera (Fondo)");

        // Esquina Inferior Izquierda (10, 460)
        ball_x = 10'd10;
        ball_y = 10'd460;
        check_pixel(10'd10, 10'd460, 1'b1, 12'hE73, "Pelota Desplazada (10,460): Esq Sup-Izq");
        check_pixel(10'd19, 10'd469, 1'b1, 12'hE73, "Pelota Desplazada (10,460): Esq Inf-Der");
        check_pixel(10'd9,  10'd460, 1'b1, 12'h667, "Pelota Desplazada (10,460) Borde: 1px Izq (Borde)");
        check_pixel(10'd10, 10'd470, 1'b1, 12'h667, "Pelota Desplazada (10,460) Borde: 1px Aba (Borde)");
        check_pixel(10'd20, 10'd459, 1'b1, 12'h102, "Pelota Desplazada (10,460) Borde: Fuera (Fondo)");

        // Esquina Inferior Derecha (620, 460)
        ball_x = 10'd620;
        ball_y = 10'd460;
        check_pixel(10'd620, 10'd460, 1'b1, 12'hE73, "Pelota Desplazada (620,460): Esq Sup-Izq");
        check_pixel(10'd629, 10'd469, 1'b1, 12'hE73, "Pelota Desplazada (620,460): Esq Inf-Der");
        check_pixel(10'd630, 10'd460, 1'b1, 12'h667, "Pelota Desplazada (620,460) Borde: 1px Der (Borde)");
        check_pixel(10'd620, 10'd470, 1'b1, 12'h667, "Pelota Desplazada (620,460) Borde: 1px Aba (Borde)");
        check_pixel(10'd619, 10'd459, 1'b1, 12'h102, "Pelota Desplazada (620,460) Borde: Fuera (Fondo)");

        $display("=== Simulacion Finalizada ===");
        if (error_count == 0) begin
            $display("EXITO: TODOS LOS TESTS PASARON (0 ERRORES)");
        end else begin
            $display("ERROR: SE ENCONTRARON %0d FALLOS", error_count);
        end
        $finish;
    end

endmodule