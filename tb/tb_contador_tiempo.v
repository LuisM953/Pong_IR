`timescale 1ns / 1ps

module tb_contador_tiempo();

    // señales de control para la simulacion
    reg clk;
    reg reset;
    reg flanco_bajada;
    reg flanco_subida;

    // cable para observar como va la cuenta
    wire [19:0] cuenta_actual;

    // instanciamos el modulo del contador
    contador_tiempo uut (
        .clk(clk),
        .reset(reset),
        .flanco_bajada(flanco_bajada),
        .flanco_subida(flanco_subida),
        .cuenta_actual(cuenta_actual)
    );

    // generamos el reloj de 100MHz
    always #5 clk = ~clk;

    initial begin
        // configuracion para exportar las ondas
        $dumpfile("ondas_contador.vcd"); 
        $dumpvars(0, tb_contador_tiempo);

        // estado inicial
        clk = 0;
        reset = 1;
        flanco_bajada = 0;
        flanco_subida = 0;
        
        #20 reset = 0; // soltamos el reset fisico
        
        // dejamos que el contador sume libremente por 50 ns (5 ciclos)
        #50; 
        
        // simulamos que el detector manda un flanco de bajada (1 ciclo de reloj)
        $display("Llega flanco de bajada: el contador deberia irse a 0");
        flanco_bajada = 1;
        #10; // dura solo 10ns
        flanco_bajada = 0;

        // dejamos que cuente el tiempo del pulso (ej. 100 ns)
        #100;
        
        // simulamos que el detector manda un flanco de subida
        $display("Llega flanco de subida: el contador deberia irse a 0 otra vez");
        flanco_subida = 1;
        #10; // dura solo 10ns
        flanco_subida = 0;

        // dejamos que cuente un poco mas para ver la grafica final
        #50;
        
        $display("Fin de la prueba del contador.");
        $finish;
    end

endmodule