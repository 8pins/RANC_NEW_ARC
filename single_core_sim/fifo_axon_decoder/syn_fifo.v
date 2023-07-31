module synchronous_fifo #(
  parameter DEPTH = 8, 
  parameter DATA_WIDTH = 8,
  parameter FILENAME = "fifo_init.mem"
) 
(
  input clk, rst,
  input w_en, r_en,
  input [DATA_WIDTH-1:0] data_in,
  output reg [DATA_WIDTH-1:0] data_out,
  output full, empty,
  output reg valid
);
  
  localparam PTR_WIDTH = $clog2(DEPTH);
  reg [PTR_WIDTH:0] w_ptr, r_ptr; // addition bit to detect full/empty condition
  (* ram_style = "block" *) reg [DATA_WIDTH-1:0] fifo [0:DEPTH-1];
  wire wrap_around; // test with wire instead of reg

  initial begin
      $readmemh(FILENAME, fifo); // change this from readmemb to readmemh since input data format changed
      data_out <= 0;
  end
  
  // Set Default values on reset.
  always@(posedge clk) begin
    if(rst) begin
      w_ptr <= 0; r_ptr <= 0;
      data_out <= 0;
      valid <= 0;
    end
  end
  
  // To write data to FIFO
  always@(posedge clk) begin
    if(w_en & !full)begin
      fifo[w_ptr[PTR_WIDTH-1:0]] <= data_in;
      w_ptr <= w_ptr + 1;
    end
  end
  
  // To read data from FIFO
  always@(posedge clk) begin
    if(r_en & !empty) begin
      data_out <= fifo[r_ptr[PTR_WIDTH-1:0]];
      r_ptr <= r_ptr + 1;
      valid <= 1;
    end
    else valid <= 0;
  end
  
  assign wrap_around = w_ptr[PTR_WIDTH] ^ r_ptr[PTR_WIDTH]; // To check MSB of write and read pointers are different
  
  //Full condition: MSB of write and read pointers are different and remainimg bits are same.
  assign full = wrap_around & (w_ptr[PTR_WIDTH-1:0] == r_ptr[PTR_WIDTH-1:0]);
  
  //Empty condition: All bits of write and read pointers are same.
  //assign empty = !wrap_around & (w_ptr[PTR_WIDTH-1:0] == r_ptr[PTR_WIDTH-1:0]);
  //or
  assign empty = (w_ptr == r_ptr);
endmodule