module synap_con_tb;

parameter NUM_AXONS = 256;
parameter NUM_NEURONS = 256;

reg enable, clk, rst;
reg [$clog2(NUM_AXONS)-1:0] axon_number;
wire [$clog2(NUM_AXONS)-1:0] neuron_number;
wire valid;
wire done;

synapse_connection #(
    .NUM_AXONS(NUM_AXONS),
    .NUM_NEURONS(NUM_NEURONS)
) UUT (
	.clk(clk),
	.rst(rst),
	.axon_number(axon_number),
    .enable(enable),
	.synap_con_done(done),
	.neuron_number(neuron_number),
	.neuron_number_valid(valid) // if that neuron has a connection with the axon spike
);

defparam UUT.synap_matrix.genblk1[0].neuron_con_inst.LUT6_inst_0.INIT = 64'hba502b6aaaac7467,
         UUT.synap_matrix.genblk1[0].neuron_con_inst.LUT6_inst_1.INIT = 64'hda869ec794438a23,
         UUT.synap_matrix.genblk1[0].neuron_con_inst.LUT6_inst_2.INIT = 64'h34da925752a6d292,
         UUT.synap_matrix.genblk1[0].neuron_con_inst.LUT6_inst_3.INIT = 64'heaafeaaa292b002b;

initial begin
    clk = 0;
    forever #2.5 clk = ~clk;
end
initial begin
    rst = 1; repeat(2) @(negedge clk); rst = 0;
end
initial begin
    if (rst) enable = 0;
    else if (valid||done) enable = 0;
    else begin 
        repeat(3) @(negedge clk);
        enable = 1;
    end
end

reg next_axon;

always @(negedge clk) begin
    if  (rst) next_axon <= 0;
    else if (done) next_axon <= 1;
    else next_axon <= 0;
end

always @(negedge clk) begin
    if (rst) axon_number <= 1'b0;
    else if (next_axon) axon_number <= axon_number + 1'b1;

    //$monitor(“display time = %d; axon_number = %h ; connection = %b;”, $time,axon_number,connection);

    if (axon_number == 255) $finish;
end

endmodule;
