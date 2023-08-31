module neuron_con_tb;

parameter NUM_AXONS = 256;
// signals
reg clk, rst;
reg [$clog2(NUM_AXONS)-1:0] axon_number;
wire connection;

// defparam    UUT.LUT6_inst_0.INIT=64'hba502b6aaaac7467 ,
//             UUT.LUT6_inst_1.INIT=64'hda869ec794438a23 ,
//             UUT.LUT6_inst_2.INIT=64'h34da925752a6d292 ,
//             UUT.LUT6_inst_3.INIT=64'heaafeaaa292b002b ;
// defparam is not applied correctly
// defparam    UUT.LUT6_inst_0.INIT=64'h000000000000000f;

neuron_con #(
    .NUM_AXONS(NUM_AXONS)
)
UUT (
    .clk(clk),
    .rst(rst),
    .axon_number(axon_number),
    .connection(connection)
);

initial begin
    clk = 0;
    forever #2.5 clk = ~clk;
end
initial begin
    rst = 1; repeat(2) @(negedge clk); rst = 0;
end

always @(negedge clk) begin
    if (rst) axon_number <= 1'b0;
    else axon_number <= axon_number + 1'b1;

    //$monitor(“display time = %d; axon_number = %h ; connection = %b;”, $time,axon_number,connection);

    if (axon_number == 255) $finish;
end

endmodule;

