`timescale 1ns / 1ps

module tb_paddle_move;

    // 1. Declaraciones
    reg clk;
    reg reset;
    reg frame_tick;
    reg up;
    reg down;
    wire [9:0] y;

    integer error_count = 0;
    integer i;

    // 2. Instancia del modulo
    paddle_move uut (
        .clk(clk),
        .reset(reset),
        .frame_tick(frame_tick),
        .up(up),
        .down(down),
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
                $display("[FAIL] %-30s | up:%b down:%b tick:%b | y: %0d (Esperado: %0d)", test_name, up, down, frame_tick, y, expected_y);
                error_count = error_count + 1;
            end else begin
                $display("[PASS] %-30s | up:%b down:%b tick:%b | y: %0d", test_name, up, down, frame_tick, y);
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
        up = 0;
        down = 0;
        
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
        // De 200 a 0 a pasos de 4 toma 50 iteraciones. Usamos 60 para exceder el limite intencionalmente.
        for (i = 0; i < 60; i = i + 1) begin
            up = 1'b1; down = 1'b0; frame_tick = 1'b1;
            @(posedge clk);
        end
        // Al terminar el bucle, al aplicar la task se da "un paso mas" y se verifica que no pase de 0
        check_move(1'b1, 1'b0, 1'b1, 10'd0, "Saturacion Arriba (Tope en 0)");

        // - saturaciones: Bucle hacia abajo
        $display("--- Forzando saturacion hacia abajo ---");
        // De 0 a 400 a pasos de 4 toma 100 iteraciones. Usamos 110.
        for (i = 0; i < 110; i = i + 1) begin
            up = 1'b0; down = 1'b1; frame_tick = 1'b1;
            @(posedge clk);
        end
        // Comprobar el limite de bajada (pantalla - paleta = 480 - 80 = 400)
        check_move(1'b0, 1'b1, 1'b1, 10'd400, "Saturacion Abajo (Tope en 400)");

        $display("=== Simulacion Finalizada ===");
        if (error_count == 0) begin
            $display("EXITO: TODOS LOS TESTS PASARON (0 ERRORES)");
        end else begin
            $display("ERROR: SE ENCONTRARON %0d FALLOS", error_count);
        end
        
        $finish;
    end

endmodule