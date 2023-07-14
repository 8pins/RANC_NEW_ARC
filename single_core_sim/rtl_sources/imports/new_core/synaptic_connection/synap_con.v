module synapse_connection 
#(
	NUM_AXONS = 256,
	NUM_NEURONS = 256
)
(
	input clk,
	input rst,
	input [$clog2(NUM_AXONS)-1:0] axon_number,
	
	output reg synap_con_done,
	output reg [$clog2(NUM_NEURONS)-1:0] neuron_number,
	output reg neuron_number_valid // if that neuron has a connection with the axon spike

);
    wire matrix_connection;
    reg [$clog2(NUM_NEURONS)-1:0] counter;
    
    synap_matrix 
	#(
		.NUM_AXONS(NUM_AXONS),
		.NUM_NEURONS(NUM_AXONS)
	) synap_matrix 
    (
        .clk(clk),
        .rst(rst),
        .axon_number(axon_number),
        .neuron_number(neuron_number),

        .matrix_connection(matrix_connection)
    );

    // output logic
    always @(posedge clk) begin
        if (rst) begin
            neuron_number <= 1'b0;
            neuron_number_valid <= 1'b0;
        end
        else if (matrix_connection) begin
            neuron_number <= counter;
            neuron_number_valid <= 1'b1;
        end
        else begin 
            neuron_number <= 1'b0;
            neuron_number_valid <= 1'b0;
        end
            
    end

    // neuron number counter
    always @(posedge clk) begin
        if (rst) begin
            counter <= 'b0;
			synap_con_done <= 1'b0;
        end
        else if (counter == 255) begin
			counter <= 1'b0;
			synap_con_done <= 1'b1;
		end
		else begin
            counter <= counter + 1'b1;
			synap_con_done <= 1'b0;
        end
    end
    
endmodule

module synap_matrix
#(
	NUM_AXONS = 256,
	NUM_NEURONS = 256
)
(
    input clk,
    input rst,
    input [$clog2(NUM_AXONS)-1:0] axon_number,
    input [$clog2(NUM_NEURONS)-1:0] neuron_number,

    output reg matrix_connection
);

    wire output_matrix_connection;
    wire [NUM_NEURONS-1:0] neuron_con_outs;

    // instance of 256 neuron connection
	genvar curr_neuron_num;
	
	for (curr_neuron_num = 0; curr_neuron_num < NUM_NEURONS; curr_neuron_num = curr_neuron_num + 1) begin 
		neuron_con #(.NUM_AXONS(NUM_AXONS)) neuron_con_inst (.clk(clk),.rst(rst),.axon_number(axon_number), .connection(neuron_con_outs[curr_neuron_num]));
	end


    // mux logic
    always @(posedge clk) begin
        if (rst)
            matrix_connection <= 1'b0;
        else begin
            matrix_connection = neuron_con_outs[neuron_number];
        end
    end
endmodule