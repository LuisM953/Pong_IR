`timescale 1ns / 1ps

module pixel_gen_tb;

    // Entradas
    reg [9:0] x;
    reg [9:0] y;
    reg video_on;

    // Salida
    wire [11:0] rgb;

    integer error_count = 0;

    // Instancia del modulo a probar (DUT)
    pixel_gen uut (
        .x(x),
        .y(y),
        .video_on(video_on),
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
                $display("[PASS] %-35s | x:%3d, y:%3d, vid:%b | Salida: %h", test_name, test_x, test_y, test_video, rgb);
            end else begin
                $display("[FAIL] %-35s | x:%3d, y:%3d, vid:%b | Salida: %h (Esp: %h)", test_name, test_x, test_y, test_video, rgb, expected_rgb);
                error_count = error_count + 1;
            end
        end
    endtask

    initial begin
        $display("=== Iniciando simulacion ===");

        // --- 1. Video desactivado ---
        check_pixel(10'd20,  10'd200, 1'b0, 12'h000, "Video apagado en P1");
        check_pixel(10'd315, 10'd235, 1'b0, 12'h000, "Video apagado en Pelota");

        // --- 2. Fondo ---
        check_pixel(10'd0,   10'd0,   1'b1, 12'h102, "Fondo: Esquina Sup-Izq");
        check_pixel(10'd100, 10'd100, 1'b1, 12'h102, "Fondo: Zona libre");

        // --- 3. Paddle 1 (X: 20..29, Y: 200..279) ---
        check_pixel(10'd20,  10'd200, 1'b1, 12'hFF3, "P1: Esquina Sup-Izq");
        check_pixel(10'd29,  10'd279, 1'b1, 12'hFF3, "P1: Esquina Inf-Der");
        // Casos de borde P1
        check_pixel(10'd19,  10'd240, 1'b1, 12'h102, "P1 Borde: 1px Izquierda (Fondo)");
        check_pixel(10'd30,  10'd240, 1'b1, 12'h102, "P1 Borde: 1px Derecha (Fondo)");
        check_pixel(10'd25,  10'd199, 1'b1, 12'h102, "P1 Borde: 1px Arriba (Fondo)");
        check_pixel(10'd25,  10'd280, 1'b1, 12'h102, "P1 Borde: 1px Abajo (Fondo)");

        // --- 4. Paddle 2 (X: 610..619, Y: 200..279) ---
        check_pixel(10'd610, 10'd200, 1'b1, 12'hF35, "P2: Esquina Sup-Izq");
        check_pixel(10'd619, 10'd279, 1'b1, 12'hF35, "P2: Esquina Inf-Der");
        // Casos de borde P2
        check_pixel(10'd609, 10'd240, 1'b1, 12'h102, "P2 Borde: 1px Izquierda (Fondo)");
        check_pixel(10'd620, 10'd240, 1'b1, 12'h102, "P2 Borde: 1px Derecha (Fondo)");
        check_pixel(10'd615, 10'd199, 1'b1, 12'h102, "P2 Borde: 1px Arriba (Fondo)");
        check_pixel(10'd615, 10'd280, 1'b1, 12'h102, "P2 Borde: 1px Abajo (Fondo)");

        // --- 5. Pelota (X: 315..324, Y: 235..244) ---
        check_pixel(10'd315, 10'd235, 1'b1, 12'hE73, "Pelota: Esquina Sup-Izq");
        check_pixel(10'd324, 10'd244, 1'b1, 12'hE73, "Pelota: Esquina Inf-Der");
        // Casos de borde Pelota (evitando X=319..320 para no cruzar con Línea Central)
        check_pixel(10'd314, 10'd240, 1'b1, 12'h102, "Pelota Borde: 1px Izq (Fondo)");
        check_pixel(10'd325, 10'd240, 1'b1, 12'h102, "Pelota Borde: 1px Der (Fondo)");
        check_pixel(10'd317, 10'd234, 1'b1, 12'h102, "Pelota Borde: 1px Arr (Fondo)");
        check_pixel(10'd317, 10'd245, 1'b1, 12'h102, "Pelota Borde: 1px Aba (Fondo)");

        // --- 6. Linea Central (X: 319..320) ---
        check_pixel(10'd319, 10'd4,   1'b1, 12'h667, "Linea Central: Tramo ON");
        check_pixel(10'd319, 10'd0,   1'b1, 12'h102, "Linea Central: Tramo OFF");
        check_pixel(10'd319, 10'd475, 1'b1, 12'h667, "Linea Central: Espejo Inferior");
        // Casos de borde Linea Central
        check_pixel(10'd318, 10'd4,   1'b1, 12'h102, "Linea Borde: 1px Izq (Fondo)");
        check_pixel(10'd321, 10'd4,   1'b1, 12'h102, "Linea Borde: 1px Der (Fondo)");

        $display("=== Simulacion Finalizada ===");
        if (error_count == 0) begin
            $display("EXITO: TODOS LOS TESTS PASARON (0 ERRORES)");
        end else begin
            $display("ERROR: SE ENCONTRARON %0d FALLOS", error_count);
        end
        $finish;
    end

endmodule