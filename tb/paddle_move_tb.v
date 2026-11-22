`timescale 1ns / 1ps

module tb_paddle_move;

    // 1. Declaraciones
    reg clk;
    reg reset;
    reg frame_tick;
    reg game_enable; // Entrada de habilitacion del juego (FSM)
    reg up;
    reg down;
    reg clear;       // Entrada para resetear la paleta a la posicion inicial
    wire [9:0] y;

    integer error_count = 0;
    integer i;

    // 2. Instancia del modulo
    paddle_move uut (
        .clk(clk),
        .reset(reset),
        .frame_tick(frame_tick),
        .game_enable(game_enable),
        .up(up),
        .down(down),
        .clear(clear), // Conexion del puerto clear
        .y(y)
    );

    // 3. Reloj (se invierte cada 5 ns)
    always #5 clk = ~clk;

    // 4. Task de comprobacion secuencial
    task check_move;
        input test_up;
        input test_down;
        input test_tick;
        input [9:0] expected_y;
        input [255:0] test_name;
        begin
            // Asignar entradas
            up = test_up;
            down = test_down;
            frame_tick = test_tick;

            // Esperar el flanco de subida del reloj
            @(posedge clk);
            
            // Esperar un instante para leer la salida ya actualizada (delta-cycle delay)
            #1; 

            // Comparar utilizando !== para detectar posibles valores indefinidos (X)
            if (y !== expected_y) begin
                $display("[FAIL] %-35s | en:%b up:%b down:%b tick:%b | y: %0d (Esperado: %0d)", test_name, game_enable, up, down, frame_tick, y, expected_y);
                error_count = error_count + 1;
            end else begin
                $display("[PASS] %-35s | en:%b up:%b down:%b tick:%b | y: %0d", test_name, game_enable, up, down, frame_tick, y);
            end
        end
    endtask

    initial begin
        $display("=== Iniciando simulacion ===");
        
        // Inicializacion vital para que el always del reloj funcione
        clk = 0;

        // 5. Reset al inicio
        reset = 1;
        frame_tick = 0;
        game_enable = 0; // Inicia deshabilitado (estado REPOSO de la FSM)
        up = 0;
        down = 0;
        clear = 0;       // Inicializacion de clear
        
        #20; // Mantener el reset activo unos ciclos
        reset = 0;
        #10;
        
        // Comprobar estado despues del reset
        if (y !== 10'd200) begin
            $display("[FAIL] Reset inicial | y: %0d (Esperado: 200)", y);
            error_count = error_count + 1;
        end else begin
            $display("[PASS] Reset inicial | y: %0d", y);
        end

        // Comprobar bloqueo cuando game_enable = 0 (aunque haya frame_tick y botones)
        check_move(1'b1, 1'b0, 1'b1, 10'd200, "Up con tick pero game_enable=0");
        check_move(1'b0, 1'b1, 1'b1, 10'd200, "Down con tick pero game_enable=0");

        // Habilitar juego (estado JUGANDO) para el resto de pruebas
        game_enable = 1'b1;

        // 6. Casos de prueba (en el orden solicitado)
        
        // - up sin frame_tick: y sigue en 200
        check_move(1'b1, 1'b0, 1'b0, 10'd200, "Up sin frame_tick");

        // - un paso arriba (up con frame_tick): 196
        check_move(1'b1, 1'b0, 1'b1, 10'd196, "Un paso arriba");

        // - un paso abajo (down con frame_tick): de nuevo 200
        check_move(1'b0, 1'b1, 1'b1, 10'd200, "Un paso abajo");

        // - los dos botones a la vez: no se mueve
        check_move(1'b1, 1'b1, 1'b1, 10'd200, "Los dos botones");

        // - ninguno presionado: no se mueve
        check_move(1'b0, 1'b0, 1'b1, 10'd200, "Ningun boton");

        // - saturaciones: Bucle hacia arriba
        $display("--- Forzando saturacion hacia arriba ---");
        // De 200 a 10 a pasos de 4 toma 48 iteraciones. Usamos 60 para exceder el limite intencionalmente.
        for (i = 0; i < 60; i = i + 1) begin
            up = 1'b1; down = 1'b0; frame_tick = 1'b1;
            @(posedge clk);
        end
        check_move(1'b1, 1'b0, 1'b1, 10'd10, "Saturacion Arriba (Tope en 10)");

        // - saturaciones: Bucle hacia abajo
        $display("--- Forzando saturacion hacia abajo ---");
        // De 10 a 390 a pasos de 4 toma 95 iteraciones. Usamos 110.
        for (i = 0; i < 110; i = i + 1) begin
            up = 1'b0; down = 1'b1; frame_tick = 1'b1;
            @(posedge clk);
        end
        check_move(1'b0, 1'b1, 1'b1, 10'd390, "Saturacion Abajo (Tope en 390)");

        // Congelamiento en GAME_OVER (game_enable=0 en medio de la cancha) y prioridad de reset
        game_enable = 1'b0;
        check_move(1'b1, 1'b0, 1'b1, 10'd390, "Congelado en 390 al bajar game_enable");

        reset = 1'b1;
        @(posedge clk);
        #1;
        reset = 1'b0;
        if (y !== 10'd200) begin
            $display("[FAIL] Reset con game_enable=0 | y: %0d (Esperado: 200)", y);
            error_count = error_count + 1;
        end else begin
            $display("[PASS] Reset con game_enable=0 | y: %0d", y);
        end

        // --- 7. Pruebas de clear (independiente de tick/enable/botones y en pleno movimiento) ---
        $display("--- Probando clear en paddle_move ---");

        // Desplazar paleta fuera de 200 (200 -> 196 -> 192)
        game_enable = 1'b1;
        check_move(1'b1, 1'b0, 1'b1, 10'd196, "Preparacion clear: paso 1 (196)");
        check_move(1'b1, 1'b0, 1'b1, 10'd192, "Preparacion clear: paso 2 (192)");

        // Caso 7A: clear con game_enable=0, frame_tick=0 y up=1 -> vuelve a 200 sin importar tick/enable/up
        game_enable = 1'b0;
        clear = 1'b1;
        check_move(1'b1, 1'b0, 1'b0, 10'd200, "clear con en=0, tick=0, up=1 -> 200");
        clear = 1'b0;

        // Caso 7B: clear con game_enable=0, frame_tick=1 y down=1 desde y=350 -> vuelve a 200
        frame_tick = 1'b0;
        uut.y = 10'd350;
        #10;
        clear = 1'b1;
        check_move(1'b0, 1'b1, 1'b1, 10'd200, "clear con en=0, tick=1, down=1 -> 200");
        clear = 1'b0;

        // Caso 7C: clear en pleno movimiento (game_enable=1, frame_tick=1, down=1)
        game_enable = 1'b1;
        check_move(1'b0, 1'b1, 1'b1, 10'd204, "Movimiento activo paso 1 (204)");
        check_move(1'b0, 1'b1, 1'b1, 10'd208, "Movimiento activo paso 2 (208)");

        clear = 1'b1;
        check_move(1'b0, 1'b1, 1'b1, 10'd200, "clear en pleno movimiento -> 200");

        // Al soltar clear con el boton aun presionado, reanuda movimiento desde 200
        clear = 1'b0;
        check_move(1'b0, 1'b1, 1'b1, 10'd204, "Reanudacion tras soltar clear (204)");
        up = 1'b0; down = 1'b0; frame_tick = 1'b0;

        $display("=== Simulacion Finalizada ===");
        if (error_count == 0) begin
            $display("EXITO: TODOS LOS TESTS PASARON (0 ERRORES)");
        end else begin
            $display("ERROR: SE ENCONTRARON %0d FALLOS", error_count);
        end
        
        $finish;
    end

endmodule