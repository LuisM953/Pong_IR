`timescale 1ns / 1ps

module pixel_gen_tb;

    localparam [1:0] JUGANDO   = 2'b01,
                     GAME_OVER = 2'b10;

    // Entradas
    reg [9:0] x;
    reg [9:0] y;
    reg video_on;
    reg [9:0] p1_y;
    reg [9:0] p2_y;
    reg [9:0] ball_x;
    reg [9:0] ball_y;
    reg [3:0] score_p1;
    reg [3:0] score_p2;
    reg [1:0] state;
    reg win_p1;
    reg win_p2;

    // Salida
    wire [11:0] rgb;

    integer error_count = 0;

    // Instancia del modulo a probar (DUT)
    pixel_gen uut (
        .x(x),
        .y(y),
        .p1_y(p1_y),
        .p2_y(p2_y),
        .ball_x(ball_x),
        .ball_y(ball_y),
        .score_p1(score_p1),
        .score_p2(score_p2),
        .state(state),
        .win_p1(win_p1),
        .win_p2(win_p2),
        .video_on(video_on),
        .rgb(rgb)
    );

    // Tarea para automatizar estimulos y verificacion de resultados
    task check_pixel;
        input [9:0] test_x;
        input [9:0] test_y;
        input test_video;
        input [11:0] expected_rgb;
        input [511:0] test_name;
        begin
            x = test_x;
            y = test_y;
            video_on = test_video;

            #10; // Espera para propagacion combinacional

            if (rgb === expected_rgb) begin
                $display("[PASS] %-40s | x:%3d, y:%3d, st:%b | Salida: %h", test_name, test_x, test_y, state, rgb);
            end else begin
                $display("[FAIL] %-40s | x:%3d, y:%3d, st:%b | Salida: %h (Esp: %h)", test_name, test_x, test_y, state, rgb, expected_rgb);
                error_count = error_count + 1;
            end
        end
    endtask

    initial begin
        $display("=== Iniciando simulacion ===");
        
        // Inicializar estado de juego activo y posiciones por defecto
        p1_y     = 10'd200;
        p2_y     = 10'd200;
        ball_x   = 10'd315;
        ball_y   = 10'd235;
        score_p1 = 4'd0;
        score_p2 = 4'd0;
        state    = JUGANDO;
        win_p1   = 1'b0;
        win_p2   = 1'b0;

        // --- 1. Video desactivado ---
        check_pixel(10'd20,  10'd200, 1'b0, 12'h000, "Video apagado en P1");
        check_pixel(10'd315, 10'd235, 1'b0, 12'h000, "Video apagado en Pelota");

        // --- 2. Fondo y Borde general ---
        check_pixel(10'd0,   10'd0,   1'b1, 12'h667, "Borde: Esq Sup-Izq exterior");
        check_pixel(10'd10,  10'd10,  1'b1, 12'h102, "Fondo: Esq Sup-Izq interior");
        check_pixel(10'd100, 10'd100, 1'b1, 12'h102, "Fondo: Zona libre");

        // --- 3. Paddle 1 (X: 20..29, Y: 200..279) ---
        check_pixel(10'd20,  10'd200, 1'b1, 12'hFF3, "P1: Esquina Sup-Izq");
        check_pixel(10'd29,  10'd279, 1'b1, 12'hFF3, "P1: Esquina Inf-Der");
        check_pixel(10'd19,  10'd240, 1'b1, 12'h102, "P1 Borde: 1px Izquierda");
        check_pixel(10'd30,  10'd240, 1'b1, 12'h102, "P1 Borde: 1px Derecha");
        check_pixel(10'd25,  10'd199, 1'b1, 12'h102, "P1 Borde: 1px Arriba");
        check_pixel(10'd25,  10'd280, 1'b1, 12'h102, "P1 Borde: 1px Abajo");

        // --- 4. Paddle 2 (X: 610..619, Y: 200..279) ---
        check_pixel(10'd610, 10'd200, 1'b1, 12'hF35, "P2: Esquina Sup-Izq");
        check_pixel(10'd619, 10'd279, 1'b1, 12'hF35, "P2: Esquina Inf-Der");
        check_pixel(10'd609, 10'd240, 1'b1, 12'h102, "P2 Borde: 1px Izquierda");
        check_pixel(10'd620, 10'd240, 1'b1, 12'h102, "P2 Borde: 1px Derecha");
        check_pixel(10'd615, 10'd199, 1'b1, 12'h102, "P2 Borde: 1px Arriba");
        check_pixel(10'd615, 10'd280, 1'b1, 12'h102, "P2 Borde: 1px Abajo");

        // --- 5. Pelota (Centro, posicion por defecto) ---
        check_pixel(10'd315, 10'd235, 1'b1, 12'hE73, "Pelota (Centro): Esq Sup-Izq");
        check_pixel(10'd324, 10'd244, 1'b1, 12'hE73, "Pelota (Centro): Esq Inf-Der");
        check_pixel(10'd314, 10'd240, 1'b1, 12'h102, "Pelota Borde: 1px Izquierda");
        check_pixel(10'd325, 10'd240, 1'b1, 12'h102, "Pelota Borde: 1px Derecha");
        check_pixel(10'd317, 10'd234, 1'b1, 12'h102, "Pelota Borde: 1px Arriba");
        check_pixel(10'd317, 10'd245, 1'b1, 12'h102, "Pelota Borde: 1px Abajo");

        // --- 6. Linea Central (X: 319..320) ---
        check_pixel(10'd319, 10'd20,  1'b1, 12'h667, "Linea Central: Tramo ON sup");
        check_pixel(10'd319, 10'd24,  1'b1, 12'h102, "Linea Central: Tramo OFF sup");
        check_pixel(10'd319, 10'd459, 1'b1, 12'h667, "Linea Central: Espejo Inf");
        check_pixel(10'd318, 10'd20,  1'b1, 12'h102, "Linea Borde: 1px Izquierda");
        check_pixel(10'd321, 10'd20,  1'b1, 12'h102, "Linea Borde: 1px Derecha");
        
        // --- 7. Casos limite con paleta desplazada ---
        p1_y = 10'd10;
        check_pixel(10'd20,  10'd10,  1'b1, 12'hFF3, "P1 Desplazado (Y=10): Sup-Izq");
        check_pixel(10'd29,  10'd89,  1'b1, 12'hFF3, "P1 Desplazado (Y=10): Inf-Der");
        check_pixel(10'd25,  10'd90,  1'b1, 12'h102, "P1 Desplazado: 1px Abajo");
        check_pixel(10'd19,  10'd40,  1'b1, 12'h102, "P1 Desplazado: 1px Izquierda");
        check_pixel(10'd30,  10'd40,  1'b1, 12'h102, "P1 Desplazado: 1px Derecha");
        p1_y = 10'd200;

        p2_y = 10'd390;
        check_pixel(10'd610, 10'd390, 1'b1, 12'hF35, "P2 Desplazado (Y=390): Sup-Izq");
        check_pixel(10'd619, 10'd469, 1'b1, 12'hF35, "P2 Desplazado (Y=390): Inf-Der");
        check_pixel(10'd615, 10'd470, 1'b1, 12'h667, "P2 Desplazado: 1px Aba (Borde)");
        check_pixel(10'd615, 10'd389, 1'b1, 12'h102, "P2 Desplazado: 1px Arr (Fondo)");
        p2_y = 10'd200;

        // Pruebas de Prioridad (Colisiones de Dibujo en JUGANDO)
        check_pixel(10'd319, 10'd236, 1'b1, 12'hE73, "Prioridad: Pelota tapa linea");

        ball_x = 10'd25;
        ball_y = 10'd205; 
        check_pixel(10'd25, 10'd205, 1'b1, 12'hFF3, "Prioridad: P1 tapa pelota");
        
        ball_x = 10'd315;
        ball_y = 10'd235;

        // --- 8. Casos limite con pelota desplazada a las cuatro esquinas ---
        ball_x = 10'd10;
        ball_y = 10'd10;
        check_pixel(10'd10, 10'd10, 1'b1, 12'hE73, "Pelota (10,10): Esq Sup-Izq");
        check_pixel(10'd19, 10'd19, 1'b1, 12'hE73, "Pelota (10,10): Esq Inf-Der");
        check_pixel(10'd9,  10'd10, 1'b1, 12'h667, "Pelota (10,10): 1px Izq (Borde)");
        check_pixel(10'd10, 10'd9,  1'b1, 12'h667, "Pelota (10,10): 1px Arr (Borde)");
        check_pixel(10'd20, 10'd20, 1'b1, 12'h102, "Pelota (10,10): Fuera (Fondo)");

        ball_x = 10'd620;
        ball_y = 10'd10;
        check_pixel(10'd620, 10'd10, 1'b1, 12'hE73, "Pelota (620,10): Esq Sup-Izq");
        check_pixel(10'd629, 10'd19, 1'b1, 12'hE73, "Pelota (620,10): Esq Inf-Der");
        check_pixel(10'd630, 10'd10, 1'b1, 12'h667, "Pelota (620,10): 1px Der (Borde)");
        check_pixel(10'd620, 10'd9,  1'b1, 12'h667, "Pelota (620,10): 1px Arr (Borde)");
        check_pixel(10'd619, 10'd20, 1'b1, 12'h102, "Pelota (620,10): Fuera (Fondo)");

        ball_x = 10'd10;
        ball_y = 10'd460;
        check_pixel(10'd10, 10'd460, 1'b1, 12'hE73, "Pelota (10,460): Esq Sup-Izq");
        check_pixel(10'd19, 10'd469, 1'b1, 12'hE73, "Pelota (10,460): Esq Inf-Der");
        check_pixel(10'd9,  10'd460, 1'b1, 12'h667, "Pelota (10,460): 1px Izq (Borde)");
        check_pixel(10'd10, 10'd470, 1'b1, 12'h667, "Pelota (10,460): 1px Aba (Borde)");
        check_pixel(10'd20, 10'd459, 1'b1, 12'h102, "Pelota (10,460): Fuera (Fondo)");

        ball_x = 10'd620;
        ball_y = 10'd460;
        check_pixel(10'd620, 10'd460, 1'b1, 12'hE73, "Pelota (620,460): Esq Sup-Izq");
        check_pixel(10'd629, 10'd469, 1'b1, 12'hE73, "Pelota (620,460): Esq Inf-Der");
        check_pixel(10'd630, 10'd460, 1'b1, 12'h667, "Pelota (620,460): 1px Der (Borde)");
        check_pixel(10'd620, 10'd470, 1'b1, 12'h667, "Pelota (620,460): 1px Aba (Borde)");
        check_pixel(10'd619, 10'd459, 1'b1, 12'h102, "Pelota (620,460): Fuera (Fondo)");

        ball_x = 10'd315;
        ball_y = 10'd235;

        // --- 9. Marcador (Scoreboard empotrado en BORDER_W: Y=1..8, Cajas: Y=2..7) ---
        check_pixel(10'd300, 10'd0,   1'b1, 12'h667, "Scoreboard: Fila y=0 borde");
        check_pixel(10'd300, 10'd9,   1'b1, 12'h667, "Scoreboard: Fila y=9 borde");
        check_pixel(10'd222, 10'd1,   1'b1, 12'h334, "Scoreboard: Esq Sup-Izq placa");
        check_pixel(10'd417, 10'd8,   1'b1, 12'h334, "Scoreboard: Esq Inf-Der placa");
        check_pixel(10'd221, 10'd4,   1'b1, 12'h667, "Scoreboard: 1px Izq (Borde)");
        check_pixel(10'd418, 10'd4,   1'b1, 12'h667, "Scoreboard: 1px Der (Borde)");
        check_pixel(10'd319, 10'd4,   1'b1, 12'h334, "Scoreboard: Tapa linea central");

        // Ranuras vacias (0-0) y separaciones entre cajas
        check_pixel(10'd309, 10'd2,   1'b1, 12'h213, "Score 0-0: P1 Caja 0 apagada");
        check_pixel(10'd304, 10'd7,   1'b1, 12'h213, "Score 0-0: P1 Caja 0 Inf-Izq");
        check_pixel(10'd303, 10'd4,   1'b1, 12'h334, "Score 0-0: P1 hueco entre cajas");
        check_pixel(10'd224, 10'd4,   1'b1, 12'h213, "Score 0-0: P1 Caja 10 apagada");
        check_pixel(10'd330, 10'd2,   1'b1, 12'h213, "Score 0-0: P2 Caja 0 apagada");
        check_pixel(10'd335, 10'd7,   1'b1, 12'h213, "Score 0-0: P2 Caja 0 Inf-Der");
        check_pixel(10'd336, 10'd4,   1'b1, 12'h334, "Score 0-0: P2 hueco entre cajas");
        check_pixel(10'd415, 10'd4,   1'b1, 12'h213, "Score 0-0: P2 Caja 10 apagada");

        // Marcador asimetrico 3-7
        score_p1 = 4'd3;
        score_p2 = 4'd7;
        check_pixel(10'd309, 10'd4,   1'b1, 12'hFF3, "Score 3-7: P1 Caja 0 encendida");
        check_pixel(10'd293, 10'd4,   1'b1, 12'hFF3, "Score 3-7: P1 Caja 2 encendida");
        check_pixel(10'd285, 10'd4,   1'b1, 12'h213, "Score 3-7: P1 Caja 3 apagada");
        check_pixel(10'd330, 10'd4,   1'b1, 12'hF35, "Score 3-7: P2 Caja 0 encendida");
        check_pixel(10'd378, 10'd4,   1'b1, 12'hF35, "Score 3-7: P2 Caja 6 encendida");
        check_pixel(10'd386, 10'd4,   1'b1, 12'h213, "Score 3-7: P2 Caja 7 apagada");

        // Marcador lleno 11-11
        score_p1 = 4'd11;
        score_p2 = 4'd11;
        check_pixel(10'd224, 10'd4,   1'b1, 12'hFF3, "Score 11-11: P1 Caja 10 encendida");
        check_pixel(10'd415, 10'd4,   1'b1, 12'hF35, "Score 11-11: P2 Caja 10 encendida");
        check_pixel(10'd309, 10'd4,   1'b0, 12'h000, "Video apagado sobre marcador");

        score_p1 = 4'd0;
        score_p2 = 4'd0;

        // --- 10. Estado REPOSO / default 2'b00 ---
        // Panel: X=240..399, Y=180..299 | Marco 5px: Izq 240..244, Der 395..399, Sup 180..184, Inf 295..299
        // Icono: X=280..359, Y=210..269
        state = 2'b00;

        // Fronteras exteriores e interiores de los 4 bordes del marco
        check_pixel(10'd239, 10'd240, 1'b1, 12'h102, "REPOSO: 1px Izq fuera panel");
        check_pixel(10'd240, 10'd180, 1'b1, 12'hFFF, "REPOSO: Marco Esq Sup-Izq");
        check_pixel(10'd244, 10'd240, 1'b1, 12'hFFF, "REPOSO: Marco Izq ultimo px (244)");
        check_pixel(10'd245, 10'd240, 1'b1, 12'h28C, "REPOSO: 1px dentro marco Izq (245)");

        check_pixel(10'd400, 10'd240, 1'b1, 12'h102, "REPOSO: 1px Der fuera panel");
        check_pixel(10'd399, 10'd299, 1'b1, 12'hFFF, "REPOSO: Marco Esq Inf-Der");
        check_pixel(10'd395, 10'd240, 1'b1, 12'hFFF, "REPOSO: Marco Der primer px (395)");
        check_pixel(10'd394, 10'd240, 1'b1, 12'h28C, "REPOSO: 1px dentro marco Der (394)");

        check_pixel(10'd300, 10'd179, 1'b1, 12'h102, "REPOSO: 1px Arr fuera panel");
        check_pixel(10'd300, 10'd184, 1'b1, 12'hFFF, "REPOSO: Marco Sup ultimo px (184)");
        check_pixel(10'd300, 10'd185, 1'b1, 12'h28C, "REPOSO: 1px dentro marco Sup (185)");

        check_pixel(10'd300, 10'd300, 1'b1, 12'h102, "REPOSO: 1px Aba fuera panel");
        check_pixel(10'd300, 10'd295, 1'b1, 12'hFFF, "REPOSO: Marco Inf primer px (295)");
        check_pixel(10'd300, 10'd294, 1'b1, 12'h28C, "REPOSO: 1px dentro marco Inf (294)");

        // Fronteras exactas de los 4 lados del icono blanco (280..359, 210..269)
        check_pixel(10'd280, 10'd210, 1'b1, 12'hFFF, "REPOSO: Icono Esq Sup-Izq");
        check_pixel(10'd359, 10'd269, 1'b1, 12'hFFF, "REPOSO: Icono Esq Inf-Der");
        check_pixel(10'd279, 10'd240, 1'b1, 12'h28C, "REPOSO: Icono 1px Izq (279)");
        check_pixel(10'd360, 10'd240, 1'b1, 12'h28C, "REPOSO: Icono 1px Der (360)");
        check_pixel(10'd320, 10'd209, 1'b1, 12'h28C, "REPOSO: Icono 1px Arr (209)");
        check_pixel(10'd320, 10'd270, 1'b1, 12'h28C, "REPOSO: Icono 1px Aba (270)");

        // Prioridad sobre pelota y visibilidad del resto de cancha
        check_pixel(10'd315, 10'd235, 1'b1, 12'hFFF, "REPOSO: Panel tapa pelota centro");
        check_pixel(10'd319, 10'd175, 1'b1, 12'h667, "REPOSO: Linea central visible");
        check_pixel(10'd20,  10'd200, 1'b1, 12'hFF3, "REPOSO: Paleta P1 visible");
        check_pixel(10'd610, 10'd200, 1'b1, 12'hF35, "REPOSO: Paleta P2 visible");
        check_pixel(10'd309, 10'd4,   1'b1, 12'h213, "REPOSO: Marcador en 0 visible");

        // --- 11. Estado GAME_OVER (HALF_B = 7, caja glifos X: 299..340, Y: 205..274) ---
        state  = GAME_OVER;
        win_p1 = 1'b1;
        win_p2 = 1'b0;

        // Fronteras del digito "1": Tronco (313..326, 205..274), Visera (299..312, 219..232), Base (299..340, 261..274)
        check_pixel(10'd240, 10'd180, 1'b1, 12'hFFF, "GAME_OVER P1: Marco blanco");
        check_pixel(10'd250, 10'd200, 1'b1, 12'hFF3, "GAME_OVER P1: Fondo amarillo P1");
        check_pixel(10'd313, 10'd205, 1'b1, 12'h102, "GAME_OVER P1: 1 Tronco Sup-Izq");
        check_pixel(10'd326, 10'd205, 1'b1, 12'h102, "GAME_OVER P1: 1 Tronco Sup-Der");
        check_pixel(10'd320, 10'd204, 1'b1, 12'hFF3, "GAME_OVER P1: 1px Arr tronco");
        check_pixel(10'd312, 10'd240, 1'b1, 12'hFF3, "GAME_OVER P1: 1px Izq tronco");
        check_pixel(10'd327, 10'd240, 1'b1, 12'hFF3, "GAME_OVER P1: 1px Der tronco");
        check_pixel(10'd299, 10'd219, 1'b1, 12'h102, "GAME_OVER P1: 1 Visera Sup-Izq");
        check_pixel(10'd312, 10'd232, 1'b1, 12'h102, "GAME_OVER P1: 1 Visera Inf-Der");
        check_pixel(10'd298, 10'd225, 1'b1, 12'hFF3, "GAME_OVER P1: 1px Izq visera");
        check_pixel(10'd305, 10'd218, 1'b1, 12'hFF3, "GAME_OVER P1: 1px Arr visera");
        check_pixel(10'd305, 10'd233, 1'b1, 12'hFF3, "GAME_OVER P1: 1px Aba visera");
        check_pixel(10'd299, 10'd261, 1'b1, 12'h102, "GAME_OVER P1: 1 Base Sup-Izq");
        check_pixel(10'd340, 10'd274, 1'b1, 12'h102, "GAME_OVER P1: 1 Base Inf-Der");
        check_pixel(10'd298, 10'd268, 1'b1, 12'hFF3, "GAME_OVER P1: 1px Izq base");
        check_pixel(10'd341, 10'd268, 1'b1, 12'hFF3, "GAME_OVER P1: 1px Der base");
        check_pixel(10'd305, 10'd260, 1'b1, 12'hFF3, "GAME_OVER P1: 1px Arr base");
        check_pixel(10'd320, 10'd275, 1'b1, 12'hFF3, "GAME_OVER P1: 1px Aba base");

        win_p1 = 1'b0;
        win_p2 = 1'b1;

        // Fronteras exteriores del digito "2" (299..340, 205..274) y sus 5 barras
        check_pixel(10'd250, 10'd200, 1'b1, 12'hF35, "GAME_OVER P2: Fondo rojo P2");
        check_pixel(10'd299, 10'd205, 1'b1, 12'h102, "GAME_OVER P2: 2 Esq Sup-Izq");
        check_pixel(10'd340, 10'd274, 1'b1, 12'h102, "GAME_OVER P2: 2 Esq Inf-Der");
        check_pixel(10'd320, 10'd204, 1'b1, 12'hF35, "GAME_OVER P2: 1px Arr barra sup");
        check_pixel(10'd320, 10'd275, 1'b1, 12'hF35, "GAME_OVER P2: 1px Aba barra inf");
        check_pixel(10'd298, 10'd255, 1'b1, 12'hF35, "GAME_OVER P2: 1px Izq bajada");
        check_pixel(10'd341, 10'd225, 1'b1, 12'hF35, "GAME_OVER P2: 1px Der bajada");

        // Fronteras interiores (huecos) del digito "2" para detectar barras con filas/cols de mas
        // Hueco sup-izq: X=299..326, Y=219..232 | Barra central: Y=233..246 | Hueco inf-der: X=313..340, Y=247..260
        check_pixel(10'd305, 10'd218, 1'b1, 12'h102, "GAME_OVER P2: 2 Barra sup (218)");
        check_pixel(10'd305, 10'd219, 1'b1, 12'hF35, "GAME_OVER P2: Hueco sup-izq (219)");
        check_pixel(10'd305, 10'd232, 1'b1, 12'hF35, "GAME_OVER P2: 1px Arr barra med");
        check_pixel(10'd305, 10'd233, 1'b1, 12'h102, "GAME_OVER P2: 2 Barra med (233)");
        check_pixel(10'd326, 10'd225, 1'b1, 12'hF35, "GAME_OVER P2: 1px Izq bajada der");
        check_pixel(10'd327, 10'd225, 1'b1, 12'h102, "GAME_OVER P2: 2 Bajada der (327)");

        check_pixel(10'd330, 10'd246, 1'b1, 12'h102, "GAME_OVER P2: 2 Barra med (246)");
        check_pixel(10'd330, 10'd247, 1'b1, 12'hF35, "GAME_OVER P2: 1px Aba barra med");
        check_pixel(10'd330, 10'd260, 1'b1, 12'hF35, "GAME_OVER P2: Hueco inf-der (260)");
        check_pixel(10'd330, 10'd261, 1'b1, 12'h102, "GAME_OVER P2: 2 Barra inf (261)");
        check_pixel(10'd312, 10'd255, 1'b1, 12'h102, "GAME_OVER P2: 2 Bajada izq (312)");
        check_pixel(10'd313, 10'd255, 1'b1, 12'hF35, "GAME_OVER P2: 1px Der bajada izq");

        win_p1 = 1'b0;
        win_p2 = 1'b0;
        check_pixel(10'd320, 10'd240, 1'b1, 12'h667, "GAME_OVER: Respaldo sin ganador");

        // --- 12. Estado invalido (2'b11) y prioridad de video_on ---
        state  = 2'b11;
        win_p1 = 1'b1;
        check_pixel(10'd250, 10'd200, 1'b1, 12'h28C, "Estado 2'b11: Fondo REPOSO");
        check_pixel(10'd320, 10'd240, 1'b1, 12'hFFF, "Estado 2'b11: Icono REPOSO");
        check_pixel(10'd320, 10'd240, 1'b0, 12'h000, "Video apagado sobre panel");

        $display("=== Simulacion Finalizada ===");
        if (error_count == 0) begin
            $display("EXITO: TODOS LOS TESTS PASARON (0 ERRORES)");
        end else begin
            $display("ERROR: SE ENCONTRARON %0d FALLOS", error_count);
        end
        $finish;
    end

endmodule