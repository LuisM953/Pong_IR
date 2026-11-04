`timescale 1ns / 1ps

module tb_ir_sync_detector();

    // entradas para inyectar a la simulacion
    reg clk;
    reg reset;
    reg ir_rx;

    // cables para ver las salidas
    wire ir_sync;
    wire flanco_bajada;
    wire flanco_subida;

    // instanciamos el modulo de hardware
    ir_sync_detector uut (
        .clk(clk),
        .reset(reset),
        .ir_rx(ir_rx),
        .ir_sync(ir_sync),
        .flanco_bajada(flanco_bajada),
        .flanco_subida(flanco_subida)
    );

    // creamos el reloj de 100MHz (invierte cada 5ns)
    always #5 clk = ~clk;

    initial begin
        // configuracion para exportar las ondas a gtkwave o eda playground
        $dumpfile("ondas_detector.vcd"); 
        $dumpvars(0, tb_ir_sync_detector);

        // estado inicial del sistema
        clk = 0;
        reset = 1;
        ir_rx = 1; // sensor inactivo
        
        #20 reset = 0; // soltamos el reset
        #30; 

        // simulamos que oprimimos un boton del control
        $display("Probando flanco de bajada...");
        ir_rx = 0; 
        
        // mantenemos el boton oprimido un rato
        #100;
        
        // soltamos el boton
        $display("Probando flanco de subida...");
        ir_rx = 1; 

        #50;
        $display("Fin de la prueba.");
        $finish;
    end

endmodule
