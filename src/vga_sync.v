module vga_sync (
    input  wire clk,        // 100 MHz
    input  wire reset,
    output wire hsync,
    output wire vsync,
    output wire video_on,   // 1 solo en la zona visible
    output wire [9:0] x,    // columna actual
    output wire [9:0] y,     // fila actual
    output wire frame_tick,
    output wire tick
);

reg [1:0] contador; // Contador de 2 bits
reg [9:0] h_count, v_count;

// Combinacional
assign tick       = (contador == 2'd3);
assign frame_tick = (tick && h_count == 10'd799 && v_count == 10'd524);
assign hsync      = ~(h_count >= 10'd656 && h_count <= 10'd751);  // activo en 0
assign vsync      = ~(v_count >= 10'd490 && v_count <= 10'd491);
assign video_on   = (h_count < 10'd640)  && (v_count < 10'd480);
assign x          = h_count;
assign y          = v_count;
 
always @(posedge clk) begin
    if (reset) begin
        contador <= 2'd0;
        h_count  <= 10'd0;
        v_count  <= 10'd0;

    end else begin
        contador <= contador + 1'b1;   // de 3 vuelve a 0 solo, por ser de 2 bits
        if (tick) begin
            if (h_count == 10'd799) begin
                h_count <= 10'd0;
                if (v_count == 10'd524) begin
                    v_count <= 10'd0;
                end else begin
                    v_count <= v_count + 1'b1 ;
                end
            end else begin
                h_count <= h_count + 1'b1;
            end
        end
    end
end

endmodule
