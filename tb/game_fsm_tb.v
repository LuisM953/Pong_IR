`timescale 1ns / 1ps

module game_fsm_tb;

    // Entradas
    reg clk;
    reg reset;
    reg win_p1;
    reg win_p2;
    reg ir_start;

    // Salidas
    wire clear;
    wire game_enable;
    wire [1:0] state;

    localparam [1:0] REPOSO    = 2'b00,
                     JUGANDO   = 2'b01,
                     GAME_OVER = 2'b10,
                     INVALIDO  = 2'b11;

    integer error_count = 0;

    // Instancia del modulo bajo prueba (DUT)
    // Limite conocido: al volver de GAME_OVER a REPOSO, clear=1 baja win_p1/win_p2 en 1 ciclo de clk;
    // dado que una trama NEC tarda ~67.5 ms, ir_start no puede coincidir con win residual en hardware.
    game_fsm dut (
        .clk(clk),
        .reset(reset),
        .win_p1(win_p1),
        .win_p2(win_p2),
        .ir_start(ir_start),
        .clear(clear),
        .game_enable(game_enable),
        .state(state)
    );

    // Reloj de 100 MHz (periodo = 10 ns)
    always #5 clk = ~clk;

    // Tarea de verificacion de estado y salidas Moore
    task check_fsm;
        input [1:0] exp_state;
        input       exp_clear;
        input       exp_enable;
        input [511:0] test_name;
        begin
            if (state === exp_state && clear === exp_clear && game_enable === exp_enable) begin
                $display("[PASS] %-54s | state=%b, clear=%b, game_enable=%b",
                         test_name, state, clear, game_enable);
            end else begin
                $display("[FAIL] %-54s | state=%b (Esp:%b), clear=%b (Esp:%b), game_enable=%b (Esp:%b)",
                         test_name, state, exp_state, clear, exp_clear, game_enable, exp_enable);
                error_count = error_count + 1;
            end
        end
    endtask

    initial begin
        $display("=== Iniciando simulacion de GAME_FSM ===");

        clk      = 1'b0;
        reset    = 1'b1;
        win_p1   = 1'b0;
        win_p2   = 1'b0;
        ir_start = 1'b0;

        // --- Prueba 1: Reset inicial -> REPOSO ---
        @(posedge clk);
        #1;
        reset = 1'b0;
        #1;
        check_fsm(REPOSO, 1'b1, 1'b0, "1. Reset -> estado REPOSO (clear activo)");

        // --- Prueba 2: Inmunidad a win_p1 / win_p2 en REPOSO ---
        win_p1 = 1'b1;
        @(posedge clk);
        #1;
        win_p1 = 1'b0;
        win_p2 = 1'b1;
        @(posedge clk);
        #1;
        win_p2 = 1'b0;
        check_fsm(REPOSO, 1'b1, 1'b0, "2. Ignora win_p1/win_p2 estando en REPOSO");

        // --- Prueba 3: Pulso ir_start (1 ciclo) -> REPOSO a JUGANDO ---
        ir_start = 1'b1;
        @(posedge clk);
        #1;
        ir_start = 1'b0; // Fin del pulso de 1 ciclo
        check_fsm(JUGANDO, 1'b0, 1'b1, "3A. ir_start (1 ciclo) -> JUGANDO (game_enable=1)");

        @(posedge clk);
        #1;
        check_fsm(JUGANDO, 1'b0, 1'b1, "3B. Mantiene JUGANDO tras bajar ir_start");

        // --- Prueba 4: Inmunidad a ir_start durante JUGANDO ---
        ir_start = 1'b1;
        @(posedge clk);
        #1;
        ir_start = 1'b0;
        check_fsm(JUGANDO, 1'b0, 1'b1, "4. Ignora ir_start adicional estando en JUGANDO");

        // --- Prueba 5: Victoria P1 -> GAME_OVER y retorno a REPOSO ---
        win_p1 = 1'b1;
        @(posedge clk);
        #1;
        check_fsm(GAME_OVER, 1'b0, 1'b0, "5A. win_p1 -> GAME_OVER (juego congelado)");

        // Mantener win_p1 en 1 varios ciclos para verificar que GAME_OVER no sale por si solo
        repeat (3) @(posedge clk);
        #1;
        check_fsm(GAME_OVER, 1'b0, 1'b0, "5B. Mantiene GAME_OVER con win_p1=1 sostenido");

        // Pulso ir_start en GAME_OVER con win_p1 aun en 1 -> vuelve a REPOSO para limpiar marcador
        ir_start = 1'b1;
        @(posedge clk);
        #1;
        ir_start = 1'b0;
        check_fsm(REPOSO, 1'b1, 1'b0, "5C. ir_start con win_p1=1 -> REPOSO (clear=1)");
        win_p1 = 1'b0; // Simula que score baja win_p1 tras recibir clear=1

        // --- Prueba 6: Nueva partida, victoria P2 y retencion en GAME_OVER con win=0 ---
        ir_start = 1'b1;
        @(posedge clk);
        #1;
        ir_start = 1'b0;
        check_fsm(JUGANDO, 1'b0, 1'b1, "6A. Segundo ir_start -> inicia nueva partida");

        win_p2 = 1'b1;
        @(posedge clk);
        #1;
        win_p2 = 1'b0;
        check_fsm(GAME_OVER, 1'b0, 1'b0, "6B. win_p2 -> GAME_OVER");

        // Permanecer varios ciclos en GAME_OVER con win=0 y sin ir_start (salida exclusiva por ir_start)
        repeat (3) @(posedge clk);
        #1;
        check_fsm(GAME_OVER, 1'b0, 1'b0, "6C. Mantiene GAME_OVER con win=0 y sin ir_start");

        // --- Prueba 7: Condiciones simultaneas en JUGANDO (prioridad de victoria y empate) ---
        // Volver a JUGANDO (GAME_OVER -> REPOSO -> JUGANDO)
        ir_start = 1'b1;
        @(posedge clk);
        #1;
        ir_start = 1'b0;

        ir_start = 1'b1;
        @(posedge clk);
        #1;
        ir_start = 1'b0;

        // Caso 7A: ir_start y win_p1 en el mismo ciclo -> gana win_p1 (pasa a GAME_OVER)
        ir_start = 1'b1;
        win_p1   = 1'b1;
        @(posedge clk);
        #1;
        ir_start = 1'b0;
        win_p1   = 1'b0;
        check_fsm(GAME_OVER, 1'b0, 1'b0, "7A. ir_start + win_p1 simultaneos -> GAME_OVER");

        // Volver a JUGANDO para probar victoria simultanea
        ir_start = 1'b1;
        @(posedge clk);
        #1;
        ir_start = 1'b0;

        ir_start = 1'b1;
        @(posedge clk);
        #1;
        ir_start = 1'b0;

        // Caso 7B: win_p1 y win_p2 simultaneos en JUGANDO -> GAME_OVER
        win_p1 = 1'b1;
        win_p2 = 1'b1;
        @(posedge clk);
        #1;
        win_p1 = 1'b0;
        win_p2 = 1'b0;
        check_fsm(GAME_OVER, 1'b0, 1'b0, "7B. win_p1 + win_p2 simultaneos -> GAME_OVER");

        // --- Prueba 8: Recuperacion segura desde estado invalido 2'b11 ---
        force dut.state = INVALIDO;
        #1;
        release dut.state; // Queda retenido en 2'b11 hasta el siguiente flanco de reloj
        check_fsm(INVALIDO, 1'b0, 1'b0, "8A. Inyeccion de estado invalido 2'b11");

        @(posedge clk);
        #1;
        check_fsm(REPOSO, 1'b1, 1'b0, "8B. Recuperacion automatica 2'b11 -> REPOSO");

        // --- Prueba 9: Reset sincrono en mitad de partida ---
        ir_start = 1'b1;
        @(posedge clk);
        #1;
        ir_start = 1'b0;

        reset = 1'b1;
        @(posedge clk);
        #1;
        reset = 1'b0;
        check_fsm(REPOSO, 1'b1, 1'b0, "9. Reset en JUGANDO -> retorno inmediato a REPOSO");

        $display("=== Simulacion Finalizada ===");
        if (error_count == 0) begin
            $display("EXITO: TODOS LOS TESTS PASARON (0 ERRORES).");
        end else begin
            $display("ERROR: SE ENCONTRARON %0d FALLOS.", error_count);
        end

        $finish;
    end

endmodule