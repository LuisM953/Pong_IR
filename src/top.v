module top_pong #(
    // Cuadros de la pantalla de calibracion (180 = ~3 s a ~60 Hz).
    // En simulacion: top_pong #(.CALIB_FRAMES(0)) para ir directo al juego.
    parameter CALIB_FRAMES = 180
)(
    input  wire clk,
    input  wire reset,
    input  wire up_p1,
    input  wire down_p1,
    input  wire up_p2,
    input  wire down_p2,
    input  wire ir_rx,
    output wire hsync,
    output wire vsync,
    output wire [7:0] comando_actual,
    output wire [11:0] rgb
);
    localparam  SCREEN_W      = 640,
                SCREEN_H      = 480,
                PADDLE_W      = 10,
                PADDLE_H      = 80,
                BALL_W        = 10,
                BALL_H        = 10,    
                LINE_W        = 2,
                MARGIN        = 20,
                BORDER_W      = 10,
                PADDLE_SPEED  = 4,
                BALL_SPEED    = 2,
                MAX_SCORE     = 11, //MAXIMO 15, por el ancho de 4 bits de los contadores de score
                BOX_SIZE      = 6,
                BOX_MARGIN    = 2;  // Restriccion -> BOX_SIZE + BOX_MARGIN (BOX_STEP) debe ser potencia de 2 (ej. 4, 8, 16)

    wire video_on, frame_tick, hit_p1, hit_p2, goal_p1, goal_p2, win_p1, win_p2;
    wire ir_p1_up, ir_p1_down, ir_p2_up, ir_p2_down, ir_start, game_enable, clear;
    wire [9:0] x, y, p1_y, p2_y, ball_x, ball_y;
    wire [3:0] score_p1, score_p2;

    vga_sync controlador_vga (
        .clk(clk),
        .reset(reset),
        .hsync(hsync),
        .vsync(vsync),
        .video_on(video_on),
        .x(x),
        .y(y),
        .frame_tick(frame_tick),
        .tick()
    );

    // pixel_gen entrega rgb_juego; calibracion decide que sale por rgb
    // (pantalla blanca de calibracion al inicio, luego el juego).
    wire [11:0] rgb_juego;

    calibration #(
        .CALIB_FRAMES(CALIB_FRAMES)
    ) calibracion (
        .clk(clk),
        .reset(reset),
        .frame_tick(frame_tick),
        .video_on(video_on),
        .rgb_juego(rgb_juego),
        .calibrando(),
        .rgb(rgb)
    );

    paddle_move #(
        .SCREEN_H(SCREEN_H),
        .PADDLE_H(PADDLE_H),
        .BORDER_W(BORDER_W),
        .SPEED(PADDLE_SPEED)
    ) paddle1 (
        .clk(clk),
        .reset(reset),
        .frame_tick(frame_tick),
        .game_enable(game_enable),
        .up(up_p1 | ir_p1_up),
        .down(down_p1 | ir_p1_down),
        .clear(clear),
        .y(p1_y)
    );

    paddle_move #(
        .SCREEN_H(SCREEN_H),
        .PADDLE_H(PADDLE_H),
        .BORDER_W(BORDER_W),
        .SPEED(PADDLE_SPEED)
    ) paddle2 (
        .clk(clk),
        .reset(reset),
        .frame_tick(frame_tick),
        .game_enable(game_enable),
        .up(up_p2 | ir_p2_up),
        .down(down_p2 | ir_p2_down),
        .clear(clear),
        .y(p2_y)
    );

    pixel_gen #(
        .SCREEN_W(SCREEN_W),
        .SCREEN_H(SCREEN_H),
        .PADDLE_W(PADDLE_W),
        .PADDLE_H(PADDLE_H),
        .BALL_W(BALL_W),
        .BALL_H(BALL_H),
        .LINE_W(LINE_W),
        .MARGIN(MARGIN),
        .BORDER_W(BORDER_W),
        .MAX_SCORE(MAX_SCORE),
        .BOX_SIZE(BOX_SIZE),
        .BOX_MARGIN(BOX_MARGIN)
    ) generador_imagen (
        .x(x),
        .y(y),
        .video_on(video_on),
        .p1_y(p1_y),
        .p2_y(p2_y),
        .ball_x(ball_x),
        .ball_y(ball_y),
        .score_p1(score_p1),
        .score_p2(score_p2),
        .rgb(rgb_juego)
    );

    ball_move #(
        .SCREEN_W(SCREEN_W),
        .SCREEN_H(SCREEN_H),
        .BORDER_W(BORDER_W),
        .PADDLE_W(PADDLE_W),
        .BALL_W(BALL_W),
        .BALL_H(BALL_H),
        .MARGIN(MARGIN),
        .BALL_SPEED(BALL_SPEED)
    ) movimiento_pelota (
        .clk(clk),
        .reset(reset),
        .frame_tick(frame_tick),
        .hit_p1(hit_p1),
        .hit_p2(hit_p2),
        .clear(clear),
        .game_enable(game_enable),
        .ball_x(ball_x),
        .ball_y(ball_y),
        .goal_p1(goal_p1),
        .goal_p2(goal_p2)
    );

    hitbox #(
        .SCREEN_W(SCREEN_W),
        .MARGIN(MARGIN),
        .PADDLE_W(PADDLE_W),
        .PADDLE_H(PADDLE_H),
        .BALL_W(BALL_W),
        .BALL_H(BALL_H)
    ) detector_colisiones (
        .p1_y(p1_y),
        .p2_y(p2_y),
        .ball_x(ball_x),
        .ball_y(ball_y),
        .hit_p1(hit_p1),
        .hit_p2(hit_p2)
    );

    score #(
        .MAX_SCORE(MAX_SCORE)
    ) marcador (
        .clk(clk),
        .reset(reset),
        .clear(clear),
        .goal_p1(goal_p1),
        .goal_p2(goal_p2),
        .win_p1(win_p1),
        .win_p2(win_p2),
        .score_p1(score_p1),
        .score_p2(score_p2)
    );

    ir_decoder decodificador_ir (
        .clk(clk),
        .reset(reset),
        .ir_rx(ir_rx),
        .comando_actual(comando_actual),
        .ir_p1_up(ir_p1_up),
        .ir_p1_down(ir_p1_down),
        .ir_p2_up(ir_p2_up),
        .ir_p2_down(ir_p2_down),
        .ir_start(ir_start)        // Pulso de 1 ciclo para iniciar partida
    );

    game_fsm maquina_juego (
        .clk(clk),
        .reset(reset),
        .win_p1(win_p1),
        .win_p2(win_p2),
        .ir_start(ir_start),       // Pulso de 1 ciclo desde ir_decoder
        .clear(clear),                  // Limpia el marcador al iniciar partida
        .game_enable(game_enable), // Habilita el movimiento de pelota/paletas
        .state()
    );

endmodule