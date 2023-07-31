// module core(
// 	input packet,
// 	output packet,
// 	input clk, rst_n);

// 	module pack_decode(
// 		input packet,
// 		output axon_nr,
// 		output spike_en)
// 	//act like a syn fifo 

// 	endmodule
	
	
		
// 	module NB như cũ (
// 		input axon_nr,
// 		input spike_en,
// 		output axon_nr
// 		output spike_en,
// 		output finish);

// 	module fsm_controler(
// 		input spike_en,
// 		output neuron_en
// 		output neuron_nr);
	
// 	module synapse connection(
// 		input axon number
// 		output neuron number
// 		) 
			
	
	
// 	module new_CSRAM 
	
// 	//module Scheduler
	
// 	module ROuter
	
// endmodule
// 	//module neuron(
// 		input axon_nr,
// 		input neuron_en,
// 		output csram_read,
// 		output axon_nr,
// 		output dx,
// 		output dy,
// 		input parameter);
		
// 		module pack_encode(
// 		input axon_nr,
// 		input spike_en,
// 		output pack)

		

// 	endmodule

// 	module synapse_connection0(
// 			input axon_nr
// 			output connected);

`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Core.v
//
// Created for Dr. Akoglu's Reconfigurable Computing Lab
//  at the University of Arizona
// 
// Contains all the modules for a single RANC core.
//////////////////////////////////////////////////////////////////////////////////

module Core #(
    parameter CORE_NUMB = 0,
    parameter PACKET_WIDTH = 30,
    parameter NUM_NEURONS = 256,
    parameter NUM_AXONS = 256,
    parameter NUM_TICKS = 16,
    parameter NUM_WEIGHTS = 4,
    parameter NUM_RESET_MODES = 2,
    parameter POTENTIAL_WIDTH = 9,
    parameter WEIGHT_WIDTH = 9,
    parameter LEAK_WIDTH = 9,
    parameter THRESHOLD_WIDTH = 9,
    parameter DX_MSB = 29,
    parameter DX_LSB = 21,
    parameter DY_MSB = 20,
    parameter DY_LSB = 12,
    parameter ROUTER_BUFFER_DEPTH = 4,
    parameter CSRAM_FILE = "",
    parameter TC_FILE = "",
    parameter FIFO_FILE = ""
)(
    input clk,
    // input tick, 
    input rst,
    input ren_in_west,
    input ren_in_east,
    input ren_in_north,
    input ren_in_south,
    input empty_in_west,
    input empty_in_east,
    input empty_in_north,
    input empty_in_south,
    input [PACKET_WIDTH-1:0] east_in,
    input [PACKET_WIDTH-1:0] west_in,
    input [PACKET_WIDTH-(DX_MSB-DX_LSB+1)-1:0] north_in,
    input [PACKET_WIDTH-(DX_MSB-DX_LSB+1)-1:0] south_in,
    output ren_out_west,
    output ren_out_east,
    output ren_out_north,
    output ren_out_south,
    output empty_out_west,
    output empty_out_east,
    output empty_out_north,
    output empty_out_south,
    output [PACKET_WIDTH-1:0] east_out,
    output [PACKET_WIDTH-1:0] west_out,
    output [PACKET_WIDTH-(DX_MSB-DX_LSB+1)-1:0] north_out,
    output [PACKET_WIDTH-(DX_MSB-DX_LSB+1)-1:0] south_out,
    output core_done,
    output token_controller_error,
    output scheduler_error                  
);
    
    localparam DX_WIDTH = (DX_MSB-DX_LSB+1);
    localparam DY_WIDTH = (DY_MSB-DY_LSB+1);
    localparam CSRAM_WIDTH = POTENTIAL_WIDTH + POTENTIAL_WIDTH + WEIGHT_WIDTH*NUM_WEIGHTS + LEAK_WIDTH + THRESHOLD_WIDTH + THRESHOLD_WIDTH + $clog2(NUM_RESET_MODES) + DX_WIDTH + DY_WIDTH + $clog2(NUM_AXONS) + $clog2(NUM_TICKS);
    localparam CSRAM_SYNAPTIC_CONNECTIONS_BOTTOM_INDEX = CSRAM_WIDTH;
    localparam CSRAM_CURRENT_POTENTIAL_BOTTOM_INDEX = CSRAM_SYNAPTIC_CONNECTIONS_BOTTOM_INDEX - POTENTIAL_WIDTH;
    localparam CSRAM_RESET_POTENTIAL_BOTTOM_INDEX = CSRAM_CURRENT_POTENTIAL_BOTTOM_INDEX - POTENTIAL_WIDTH;
    localparam CSRAM_WEIGHTS_BOTTOM_INDEX = CSRAM_RESET_POTENTIAL_BOTTOM_INDEX - WEIGHT_WIDTH*NUM_WEIGHTS;
    localparam CSRAM_LEAK_BOTTOM_INDEX = CSRAM_WEIGHTS_BOTTOM_INDEX - LEAK_WIDTH;
    localparam CSRAM_THRESHOLD_BOTTOM_INDEX = CSRAM_LEAK_BOTTOM_INDEX - THRESHOLD_WIDTH;
    localparam CSRAM_FLOOR_BOTTOM_INDEX = CSRAM_THRESHOLD_BOTTOM_INDEX - THRESHOLD_WIDTH;
    localparam CSRAM_RESET_MODE_BOTTOM_INDEX = CSRAM_FLOOR_BOTTOM_INDEX - $clog2(NUM_RESET_MODES);
    localparam CSRAM_DX_BOTTOM_INDEX = CSRAM_RESET_MODE_BOTTOM_INDEX - DX_WIDTH;
    localparam CSRAM_DY_BOTTOM_INDEX = CSRAM_DX_BOTTOM_INDEX - DY_WIDTH;
    localparam CSRAM_AXON_DESTINATION_BOTTOM_INDEX = CSRAM_DY_BOTTOM_INDEX - $clog2(NUM_AXONS);
    localparam CSRAM_SPIKE_DELIVERY_TICK_BOTTOM_INDEX = CSRAM_AXON_DESTINATION_BOTTOM_INDEX - $clog2(NUM_AXONS);
    
    // Scheduler // AxonDecoder
    wire [$clog2(NUM_AXONS) - 1:0] axon_spikes;
    wire [$clog2(NUM_AXONS) + $clog2(NUM_TICKS) - 1:0] fifo_out_axon_spikes;
    wire axon_spikes_valid;
    wire core_full;
    
    // CSRAM
    wire [CSRAM_WIDTH-1:0] CSRAM_data;
    wire CSRAM_complete; // dont need
    wire [$clog2(NUM_NEURONS)-1:0] CSRAM_addr;
    
    // Token Controller
    wire CSRAM_write, CSRAM_set, CSRAM_init; // only need CSRAM_write
    wire router_spike;
    wire neuron_block_en, neuron_block_next_neuron;
    wire neuron_block_write_current_potential;
    wire [$clog2(NUM_WEIGHTS)-1:0] neuron_instruction;

    wire [$clog2(NUM_NEURONS)-1:0] neuron_number_data;
    wire neuron_number_data_valid;

    wire [$clog2(NUM_AXONS)-1:0] axon_number_data;
    wire decoder_empty;
    wire read_spike;
    wire synap_con_done;
    wire synap_enable;
    
    // Nueron Block
    wire [POTENTIAL_WIDTH-1:0] neuron_potential;
    wire neuron_block_spike;

    // Router -> Scheduler // now is AxonDecoder
    wire [$clog2(NUM_AXONS) + $clog2(NUM_TICKS) - 1:0] axon_decoder_in;     // scheduler_packet 
    wire axon_decoder_wr_en;                                                     // scheduler_wen
    
    // Router -> Token Controller
    wire local_buffers_full;
    
    assign scheduler_error = core_full;
// Scheduler #(
//     .NUM_AXONS(NUM_AXONS),
//     .NUM_TICKS(NUM_TICKS)
// ) Scheduler (
//     .clk(clk),
//     .rst(rst),
//     .wen(scheduler_wen),
//     .set(scheduler_set),
//     .clr(scheduler_clr),
//     .packet(scheduler_packet),
//     .axon_spikes(axon_spikes),
//     .error(scheduler_error)
// );

// Change Scheduler to a synchronous FIFO to store input axon spikes 
// Need to check vivado syn FIFO IP
// FIFO has a valid signal when reading data

// fifo_generator_0 AxonDecoder (
//     .clk(clk),        // input wire clk
//     .srst(rst),      // input wire srst
//     .din(axon_decoder_in),        // input wire [11 : 0] din
//     .wr_en(axon_decoder_wr_en),    // input wire wr_en
//     .rd_en(read_spike),    // input wire rd_en
//     .dout(fifo_out_axon_spikes),      // output wire [11 : 0] dout
//     .full(core_full),      // output wire full
//     .wr_ack(),  // output wire wr_ack
//     .empty(decoder_empty),    // output wire empty
//     .valid(axon_spikes_valid)    // output wire valid //
// );

synchronous_fifo #(
    .DEPTH(128),
    .DATA_WIDTH(12),
    .FILENAME(FIFO_FILE)
) AxonDecoder (
    .clk(clk),        // input wire clk
    .rst(rst),      // input wire srst
    .data_in(axon_decoder_in),        // input wire [11 : 0] din
    .w_en(axon_decoder_wr_en),    // input wire wr_en
    .r_en(read_spike),    // input wire rd_en
    .data_out(fifo_out_axon_spikes),      // output wire [11 : 0] dout
    .full(core_full),      // output wire full
    //.wr_ack(),  // output wire wr_ack
    .empty(decoder_empty),    // output wire empty
    .valid(axon_spikes_valid) 
);

assign axon_spikes = fifo_out_axon_spikes[$clog2(NUM_AXONS) + $clog2(NUM_TICKS) - 1 -:$clog2(NUM_AXONS)];
/* Addressing:
    ~ NUM_AXONS - Synaptic Connections
    ~ POTENTIAL_WIDTH - Current Potential
    ~ POTENTIAL_WIDTH - Reset Potential
    ~ WEIGHT_WIDTH*NUM_WEIGHTS - Weights
    ~ LEAK_WIDTH - Leak
    ~ THRESHOLD_WIDTH - Positive Threshold
    ~ THRESHOLD_WIDTH - Negative Threshold
    ~ $clog2(NUM_RESET_MODES) - Reset Mode
    ~ DX_WIDTH - Destination X
    ~ DY_WIDTH - Destination Y
    ~ $clog2(NUM_AXONS) - Axon Destination
    ~ $clog2(NUM_TICKS) - Spike Delivery Tick */


synapse_connection #(
    .NUM_AXONS(NUM_AXONS),
    .NUM_NEURONS(NUM_NEURONS)
) synapse_connection (
	.clk(clk),
	.rst(rst),
	.axon_number(axon_number_data),
    .enable(synap_enable),
	.synap_con_done(synap_con_done),
	.neuron_number(neuron_number_data),
	.neuron_number_valid(neuron_number_data_valid) // if that neuron has a connection with the axon spike
);

	
CSRAM #(
	// TBD: decrease core SRAM width, remain structure

    .FILENAME(CSRAM_FILE),
    .NUM_NEURONS(NUM_NEURONS),
    .WIDTH(CSRAM_WIDTH),
    .WRITE_INDEX(CSRAM_CURRENT_POTENTIAL_BOTTOM_INDEX),
    .WRITE_WIDTH(POTENTIAL_WIDTH)
) CSRAM (
    .clk(clk),
    .wen(CSRAM_write),  
    .address(CSRAM_addr),
    .data_in({neuron_potential, CSRAM_data[CSRAM_CURRENT_POTENTIAL_BOTTOM_INDEX-1:0]}),
    .data_out(CSRAM_data)
);

Controller #(
    .NUM_AXONS(NUM_AXONS),
    .NUM_NEURONS(NUM_NEURONS),
    .NUM_WEIGHTS(NUM_WEIGHTS),
    .FILENAME(TC_FILE)
) Controller (
    .clk(clk), 
    .rst(rst),
    // .tick(tick),
    .spike_in(neuron_block_spike), 				// spike calculated by NB
    .local_buffers_full(local_buffers_full),	// from router

    .axon_number_in(axon_spikes), 					// axon_spikes is the axon number that has spike
	.axon_number_valid(axon_spikes_valid), 						// verify axon_spikes signal
	
    .synap_enable(synap_enable),
    .axon_number_out(axon_number_data),
    .synap_done(synap_con_done),
    //  synapses connection is now a module that output the neuron number if that neuron has connection with the axon spikes
    // .synapses(CSRAM_data[CSRAM_SYNAPTIC_CONNECTIONS_BOTTOM_INDEX +: NUM_AXONS]), 

    .decoder_empty(decoder_empty),              // check if axon_decoder has data
    .read_spike(read_spike),                    // request data from axon_decoder

    .neuron_number_in(neuron_number_data),
    .neuron_number_valid(neuron_number_data_valid),
    
    // .error(token_controller_error),				
    // .scheduler_set(scheduler_set), 
    // .scheduler_clr(scheduler_clr),
    .CSRAM_write(CSRAM_write),					// write en to CSRAM
    .CSRAM_addr(CSRAM_addr),					// write address to CSRAM
    .neuron_instruction(neuron_instruction), 	// where?
    .spike_out(router_spike),					// write en to Router
    .neuron_reg_en(neuron_block_en), 			// NB cal en
    .next_neuron(neuron_block_next_neuron),
    .write_current_potential(neuron_block_write_current_potential)
);

NeuronBlock #(
    .LEAK_WIDTH(LEAK_WIDTH),
    .WEIGHT_WIDTH(WEIGHT_WIDTH),
    .THRESHOLD_WIDTH(THRESHOLD_WIDTH),
    .POTENTIAL_WIDTH(POTENTIAL_WIDTH),
    .NUM_WEIGHTS(NUM_WEIGHTS),
    .NUM_RESET_MODES(NUM_RESET_MODES)
) NeuronBlock (
    .leak(CSRAM_data[CSRAM_LEAK_BOTTOM_INDEX +: LEAK_WIDTH]),
    .weights(CSRAM_data[CSRAM_WEIGHTS_BOTTOM_INDEX +: WEIGHT_WIDTH*NUM_WEIGHTS]),
    .positive_threshold(CSRAM_data[CSRAM_THRESHOLD_BOTTOM_INDEX +: THRESHOLD_WIDTH]),
    .negative_threshold(CSRAM_data[CSRAM_FLOOR_BOTTOM_INDEX +: THRESHOLD_WIDTH]),
    .reset_potential(CSRAM_data[CSRAM_RESET_POTENTIAL_BOTTOM_INDEX +: POTENTIAL_WIDTH]),
    .current_potential(CSRAM_data[CSRAM_CURRENT_POTENTIAL_BOTTOM_INDEX +: POTENTIAL_WIDTH]),
    .neuron_instruction(neuron_instruction),
    .reset_mode(CSRAM_data[CSRAM_RESET_MODE_BOTTOM_INDEX +: $clog2(NUM_RESET_MODES)]),
    .clk(clk),
    .next_neuron(neuron_block_next_neuron),
    .integrator_reg_en(neuron_block_en),
    .write_current_potential(neuron_block_write_current_potential),
    .write_potential(neuron_potential),
    .spike_out(neuron_block_spike)
);

Router #(
    .PACKET_WIDTH(PACKET_WIDTH),
    .DX_MSB(DX_MSB), 
    .DX_LSB(DX_LSB),
    .DY_MSB(DY_MSB),
    .DY_LSB(DY_LSB),
    .BUFFER_DEPTH(ROUTER_BUFFER_DEPTH)
) Router (
    .clk(clk),
    .rst(rst),
    .din_local(CSRAM_data[PACKET_WIDTH-1:0]),
    .din_local_wen(router_spike),
    .din_west(west_in),
    .din_east(east_in),
    .din_north(north_in),
    .din_south(south_in),
    .ren_in_west(ren_in_west),
    .ren_in_east(ren_in_east),
    .ren_in_north(ren_in_north),
    .ren_in_south(ren_in_south),
    .empty_in_west(empty_in_west),
    .empty_in_east(empty_in_east),
    .empty_in_north(empty_in_north),
    .empty_in_south(empty_in_south),
    .dout_west(west_out),
    .dout_east(east_out),
    .dout_north(north_out),
    .dout_south(south_out),
    .dout_local(axon_decoder_in),           // scheduler_packet
    .dout_wen_local(axon_decoder_wr_en),    // scheduler_wen
    .ren_out_west(ren_out_west),
    .ren_out_east(ren_out_east),
    .ren_out_north(ren_out_north),
    .ren_out_south(ren_out_south),
    .empty_out_west(empty_out_west),
    .empty_out_east(empty_out_east),
    .empty_out_north(empty_out_north),
    .empty_out_south(empty_out_south),
    .local_buffers_full(local_buffers_full)
);

reg [$clog2(NUM_AXONS)-3:0] count_num_packets;
reg [$clog2(NUM_AXONS)-3:0] count_done_packets;


always @(posedge clk) begin
    if (rst) count_num_packets <= 0;
    else begin
        if (axon_decoder_wr_en) count_num_packets <= count_num_packets + 1;
        else count_num_packets <= count_num_packets;
    end
end

always @(posedge clk) begin
    if (rst) count_done_packets <= 0;
    else begin
        if (synap_con_done) count_done_packets <= count_done_packets + 1;
        else count_done_packets <= count_done_packets;
    end
end

assign core_done = (count_done_packets && count_num_packets && (count_done_packets == count_num_packets)) ? 1'b1 : 1'b0; 


case (CORE_NUMB) 
    0: begin
        // defparam
        defparam synapse_connection.synap_matrix.genblk1[0].neuron_con_inst.LUT6_inst_0.INIT = 64'hba502b6aaaac7467;
        defparam synapse_connection.synap_matrix.genblk1[0].neuron_con_inst.LUT6_inst_1.INIT = 64'hda869ec794438a23;
        defparam synapse_connection.synap_matrix.genblk1[0].neuron_con_inst.LUT6_inst_2.INIT = 64'h34da925752a6d292;
        defparam synapse_connection.synap_matrix.genblk1[0].neuron_con_inst.LUT6_inst_3.INIT = 64'heaafeaaa292b002b;
        defparam synapse_connection.synap_matrix.genblk1[1].neuron_con_inst.LUT6_inst_0.INIT = 64'h8aab130a2029a5b7;
        defparam synapse_connection.synap_matrix.genblk1[1].neuron_con_inst.LUT6_inst_1.INIT = 64'h990ea12ea9afaaae;
        defparam synapse_connection.synap_matrix.genblk1[1].neuron_con_inst.LUT6_inst_2.INIT = 64'hd05bd14ba94b890a;
        defparam synapse_connection.synap_matrix.genblk1[1].neuron_con_inst.LUT6_inst_3.INIT = 64'h9aba2aa960a3aaaa;
        defparam synapse_connection.synap_matrix.genblk1[2].neuron_con_inst.LUT6_inst_0.INIT = 64'ha9542152e952658b;
        defparam synapse_connection.synap_matrix.genblk1[2].neuron_con_inst.LUT6_inst_1.INIT = 64'h5893da96bad7a356;
        defparam synapse_connection.synap_matrix.genblk1[2].neuron_con_inst.LUT6_inst_2.INIT = 64'hd65d52585056d032;
        defparam synapse_connection.synap_matrix.genblk1[2].neuron_con_inst.LUT6_inst_3.INIT = 64'heaac24a955a7540c;
        defparam synapse_connection.synap_matrix.genblk1[3].neuron_con_inst.LUT6_inst_0.INIT = 64'ha952bd53a8ee4e99;
        defparam synapse_connection.synap_matrix.genblk1[3].neuron_con_inst.LUT6_inst_1.INIT = 64'ha5aa2de8aadbaad6;
        defparam synapse_connection.synap_matrix.genblk1[3].neuron_con_inst.LUT6_inst_2.INIT = 64'h116ca42d86ada32f;
        defparam synapse_connection.synap_matrix.genblk1[3].neuron_con_inst.LUT6_inst_3.INIT = 64'h0aae6ed23df59d62;
        defparam synapse_connection.synap_matrix.genblk1[4].neuron_con_inst.LUT6_inst_0.INIT = 64'h928653092aa86695;
        defparam synapse_connection.synap_matrix.genblk1[4].neuron_con_inst.LUT6_inst_1.INIT = 64'h8683a6a2b687b6b3;
        defparam synapse_connection.synap_matrix.genblk1[4].neuron_con_inst.LUT6_inst_2.INIT = 64'h34908497a0cba6c7;
        defparam synapse_connection.synap_matrix.genblk1[4].neuron_con_inst.LUT6_inst_3.INIT = 64'h2aa2e8a840aa50a2;
        defparam synapse_connection.synap_matrix.genblk1[5].neuron_con_inst.LUT6_inst_0.INIT = 64'h551bd529b0afbfee;
        defparam synapse_connection.synap_matrix.genblk1[5].neuron_con_inst.LUT6_inst_1.INIT = 64'ha2772ade6ac3e84a;
        defparam synapse_connection.synap_matrix.genblk1[5].neuron_con_inst.LUT6_inst_2.INIT = 64'h50acc2aa82ab10aa;
        defparam synapse_connection.synap_matrix.genblk1[5].neuron_con_inst.LUT6_inst_3.INIT = 64'h6aa91245d4035203;
        defparam synapse_connection.synap_matrix.genblk1[6].neuron_con_inst.LUT6_inst_0.INIT = 64'h82a810a1d7773a6c;
        defparam synapse_connection.synap_matrix.genblk1[6].neuron_con_inst.LUT6_inst_1.INIT = 64'hbe4baa6baa2b60aa;
        defparam synapse_connection.synap_matrix.genblk1[6].neuron_con_inst.LUT6_inst_2.INIT = 64'h904ac04af65b325b;
        defparam synapse_connection.synap_matrix.genblk1[6].neuron_con_inst.LUT6_inst_3.INIT = 64'haa8d2aa9a4a9904a;
        defparam synapse_connection.synap_matrix.genblk1[7].neuron_con_inst.LUT6_inst_0.INIT = 64'hac502aa96aaa720b;
        defparam synapse_connection.synap_matrix.genblk1[7].neuron_con_inst.LUT6_inst_1.INIT = 64'ha8a828a926983451;
        defparam synapse_connection.synap_matrix.genblk1[7].neuron_con_inst.LUT6_inst_2.INIT = 64'h2a0baa4b2143712b;
        defparam synapse_connection.synap_matrix.genblk1[7].neuron_con_inst.LUT6_inst_3.INIT = 64'h5c462b24aa76ea63;
        defparam synapse_connection.synap_matrix.genblk1[8].neuron_con_inst.LUT6_inst_0.INIT = 64'hca1b682b2eaff1c2;
        defparam synapse_connection.synap_matrix.genblk1[8].neuron_con_inst.LUT6_inst_1.INIT = 64'ha90e2446a6db2683;
        defparam synapse_connection.synap_matrix.genblk1[8].neuron_con_inst.LUT6_inst_2.INIT = 64'h206ba46ba82bab2b;
        defparam synapse_connection.synap_matrix.genblk1[8].neuron_con_inst.LUT6_inst_3.INIT = 64'h4aace22aa92f28ee;
        defparam synapse_connection.synap_matrix.genblk1[9].neuron_con_inst.LUT6_inst_0.INIT = 64'ha0a82aab2aa926fa;
        defparam synapse_connection.synap_matrix.genblk1[9].neuron_con_inst.LUT6_inst_1.INIT = 64'h95a7b4aea883a54a;
        defparam synapse_connection.synap_matrix.genblk1[9].neuron_con_inst.LUT6_inst_2.INIT = 64'h4aa2ab4ab74ab56f;
        defparam synapse_connection.synap_matrix.genblk1[9].neuron_con_inst.LUT6_inst_3.INIT = 64'h055d91549a538bba;
        defparam synapse_connection.synap_matrix.genblk1[10].neuron_con_inst.LUT6_inst_0.INIT = 64'ha128ac2aaaae945e;
        defparam synapse_connection.synap_matrix.genblk1[10].neuron_con_inst.LUT6_inst_1.INIT = 64'hc292828a9232048a;
        defparam synapse_connection.synap_matrix.genblk1[10].neuron_con_inst.LUT6_inst_2.INIT = 64'ha8cb869292839a82;
        defparam synapse_connection.synap_matrix.genblk1[10].neuron_con_inst.LUT6_inst_3.INIT = 64'hcaa32aaa2b4ba14a;
        defparam synapse_connection.synap_matrix.genblk1[11].neuron_con_inst.LUT6_inst_0.INIT = 64'ha953215aaa2344ea;
        defparam synapse_connection.synap_matrix.genblk1[11].neuron_con_inst.LUT6_inst_1.INIT = 64'h2db7a5aba8afa27e;
        defparam synapse_connection.synap_matrix.genblk1[11].neuron_con_inst.LUT6_inst_2.INIT = 64'h546bd24baa0b092b;
        defparam synapse_connection.synap_matrix.genblk1[11].neuron_con_inst.LUT6_inst_3.INIT = 64'haaab6aab7502f517;
        defparam synapse_connection.synap_matrix.genblk1[12].neuron_con_inst.LUT6_inst_0.INIT = 64'ha952ab50a94257ba;
        defparam synapse_connection.synap_matrix.genblk1[12].neuron_con_inst.LUT6_inst_1.INIT = 64'h5ebab296b696bb52;
        defparam synapse_connection.synap_matrix.genblk1[12].neuron_con_inst.LUT6_inst_2.INIT = 64'h568a504b5157d89f;
        defparam synapse_connection.synap_matrix.genblk1[12].neuron_con_inst.LUT6_inst_3.INIT = 64'heaafa5abd4b6d4be;
        defparam synapse_connection.synap_matrix.genblk1[13].neuron_con_inst.LUT6_inst_0.INIT = 64'h20572ab7aaaa5665;
        defparam synapse_connection.synap_matrix.genblk1[13].neuron_con_inst.LUT6_inst_1.INIT = 64'h2aaaa2acb4142156;
        defparam synapse_connection.synap_matrix.genblk1[13].neuron_con_inst.LUT6_inst_2.INIT = 64'h24adb0adba48a94b;
        defparam synapse_connection.synap_matrix.genblk1[13].neuron_con_inst.LUT6_inst_3.INIT = 64'heaab6a5629d422a4;
        defparam synapse_connection.synap_matrix.genblk1[14].neuron_con_inst.LUT6_inst_0.INIT = 64'h9483d28b2aa8dae8;
        defparam synapse_connection.synap_matrix.genblk1[14].neuron_con_inst.LUT6_inst_1.INIT = 64'ha00bb04a942394a2;
        defparam synapse_connection.synap_matrix.genblk1[14].neuron_con_inst.LUT6_inst_2.INIT = 64'h28afa957a9172917;
        defparam synapse_connection.synap_matrix.genblk1[14].neuron_con_inst.LUT6_inst_3.INIT = 64'h8aaa824a304b80ab;
        defparam synapse_connection.synap_matrix.genblk1[15].neuron_con_inst.LUT6_inst_0.INIT = 64'h122b5e69aea98e5f;
        defparam synapse_connection.synap_matrix.genblk1[15].neuron_con_inst.LUT6_inst_1.INIT = 64'haa4bcb4adb0bc3ab;
        defparam synapse_connection.synap_matrix.genblk1[15].neuron_con_inst.LUT6_inst_2.INIT = 64'h2c11a4aeb8ababae;
        defparam synapse_connection.synap_matrix.genblk1[15].neuron_con_inst.LUT6_inst_3.INIT = 64'heaaaeac8a9cead47;
        defparam synapse_connection.synap_matrix.genblk1[16].neuron_con_inst.LUT6_inst_0.INIT = 64'hb4ba968a17d02a3f;
        defparam synapse_connection.synap_matrix.genblk1[16].neuron_con_inst.LUT6_inst_1.INIT = 64'h9a7baa3aa9ba28ba;
        defparam synapse_connection.synap_matrix.genblk1[16].neuron_con_inst.LUT6_inst_2.INIT = 64'ha78aa47bb07b3cfb;
        defparam synapse_connection.synap_matrix.genblk1[16].neuron_con_inst.LUT6_inst_3.INIT = 64'haaa26aaba829a84a;
        defparam synapse_connection.synap_matrix.genblk1[17].neuron_con_inst.LUT6_inst_0.INIT = 64'ha851aaa8aaabff90;
        defparam synapse_connection.synap_matrix.genblk1[17].neuron_con_inst.LUT6_inst_1.INIT = 64'ha1a8a56d29d5b151;
        defparam synapse_connection.synap_matrix.genblk1[17].neuron_con_inst.LUT6_inst_2.INIT = 64'h282b8cab86afa4a9;
        defparam synapse_connection.synap_matrix.genblk1[17].neuron_con_inst.LUT6_inst_3.INIT = 64'h90006e17a956aa57;
        defparam synapse_connection.synap_matrix.genblk1[18].neuron_con_inst.LUT6_inst_0.INIT = 64'h855a69da2aa802ee;
        defparam synapse_connection.synap_matrix.genblk1[18].neuron_con_inst.LUT6_inst_1.INIT = 64'h9b465246db035142;
        defparam synapse_connection.synap_matrix.genblk1[18].neuron_con_inst.LUT6_inst_2.INIT = 64'h1082a0aba22b3b4b;
        defparam synapse_connection.synap_matrix.genblk1[18].neuron_con_inst.LUT6_inst_3.INIT = 64'h2aacebab3d423553;
        defparam synapse_connection.synap_matrix.genblk1[19].neuron_con_inst.LUT6_inst_0.INIT = 64'haa4baa2baaa9a0d5;
        defparam synapse_connection.synap_matrix.genblk1[19].neuron_con_inst.LUT6_inst_1.INIT = 64'h92b390b2a5922a42;
        defparam synapse_connection.synap_matrix.genblk1[19].neuron_con_inst.LUT6_inst_2.INIT = 64'h84968602a61712b7;
        defparam synapse_connection.synap_matrix.genblk1[19].neuron_con_inst.LUT6_inst_3.INIT = 64'h12bd76ab802b84db;
        defparam synapse_connection.synap_matrix.genblk1[20].neuron_con_inst.LUT6_inst_0.INIT = 64'ha9412a682aac0cf5;
        defparam synapse_connection.synap_matrix.genblk1[20].neuron_con_inst.LUT6_inst_1.INIT = 64'h925295528512d392;
        defparam synapse_connection.synap_matrix.genblk1[20].neuron_con_inst.LUT6_inst_2.INIT = 64'h0b0f88aa828a92c3;
        defparam synapse_connection.synap_matrix.genblk1[20].neuron_con_inst.LUT6_inst_3.INIT = 64'h2aacaaa8ab522953;
        defparam synapse_connection.synap_matrix.genblk1[21].neuron_con_inst.LUT6_inst_0.INIT = 64'ha82b2c28a1288373;
        defparam synapse_connection.synap_matrix.genblk1[21].neuron_con_inst.LUT6_inst_1.INIT = 64'h1a2f092aa923292e;
        defparam synapse_connection.synap_matrix.genblk1[21].neuron_con_inst.LUT6_inst_2.INIT = 64'h602bf32ba9aaaa8a;
        defparam synapse_connection.synap_matrix.genblk1[21].neuron_con_inst.LUT6_inst_3.INIT = 64'h7aa12aa86cabe42b;
        defparam synapse_connection.synap_matrix.genblk1[22].neuron_con_inst.LUT6_inst_0.INIT = 64'h2d5535516d4017cd;
        defparam synapse_connection.synap_matrix.genblk1[22].neuron_con_inst.LUT6_inst_1.INIT = 64'h54b6a8928b57a315;
        defparam synapse_connection.synap_matrix.genblk1[22].neuron_con_inst.LUT6_inst_2.INIT = 64'h56d75654569656b7;
        defparam synapse_connection.synap_matrix.genblk1[22].neuron_con_inst.LUT6_inst_3.INIT = 64'hcaad6daa95ae548c;
        defparam synapse_connection.synap_matrix.genblk1[23].neuron_con_inst.LUT6_inst_0.INIT = 64'hab46aad3aaab22ef;
        defparam synapse_connection.synap_matrix.genblk1[23].neuron_con_inst.LUT6_inst_1.INIT = 64'haf22a4aea10fa562;
        defparam synapse_connection.synap_matrix.genblk1[23].neuron_con_inst.LUT6_inst_2.INIT = 64'h34a5b4ac92a80b4a;
        defparam synapse_connection.synap_matrix.genblk1[23].neuron_con_inst.LUT6_inst_3.INIT = 64'h8aa924122d45a4b5;
        defparam synapse_connection.synap_matrix.genblk1[24].neuron_con_inst.LUT6_inst_0.INIT = 64'h8a8a8aa922aa7c8c;
        defparam synapse_connection.synap_matrix.genblk1[24].neuron_con_inst.LUT6_inst_1.INIT = 64'h95c2b0ca828cd28b;
        defparam synapse_connection.synap_matrix.genblk1[24].neuron_con_inst.LUT6_inst_2.INIT = 64'h08aaa8aba82ab55a;
        defparam synapse_connection.synap_matrix.genblk1[24].neuron_con_inst.LUT6_inst_3.INIT = 64'heaaf6a8305a30a9a;
        defparam synapse_connection.synap_matrix.genblk1[25].neuron_con_inst.LUT6_inst_0.INIT = 64'h4aab8aa92aa4ea83;
        defparam synapse_connection.synap_matrix.genblk1[25].neuron_con_inst.LUT6_inst_1.INIT = 64'haa8ac102d52bd2ab;
        defparam synapse_connection.synap_matrix.genblk1[25].neuron_con_inst.LUT6_inst_2.INIT = 64'ha953a853a803aa93;
        defparam synapse_connection.synap_matrix.genblk1[25].neuron_con_inst.LUT6_inst_3.INIT = 64'h8aa8a8a92aabac8a;
        defparam synapse_connection.synap_matrix.genblk1[26].neuron_con_inst.LUT6_inst_0.INIT = 64'h8aad9a8d56962c66;
        defparam synapse_connection.synap_matrix.genblk1[26].neuron_con_inst.LUT6_inst_1.INIT = 64'h5257c9d699569b42;
        defparam synapse_connection.synap_matrix.genblk1[26].neuron_con_inst.LUT6_inst_2.INIT = 64'h282b900ad1520352;
        defparam synapse_connection.synap_matrix.genblk1[26].neuron_con_inst.LUT6_inst_3.INIT = 64'h6aa06aab2f2b0b2a;
        defparam synapse_connection.synap_matrix.genblk1[27].neuron_con_inst.LUT6_inst_0.INIT = 64'ha8952aab6aae3e74;
        defparam synapse_connection.synap_matrix.genblk1[27].neuron_con_inst.LUT6_inst_1.INIT = 64'hacaca9e52db5b195;
        defparam synapse_connection.synap_matrix.genblk1[27].neuron_con_inst.LUT6_inst_2.INIT = 64'h2b4ba92b810a2ca8;
        defparam synapse_connection.synap_matrix.genblk1[27].neuron_con_inst.LUT6_inst_3.INIT = 64'h7414ac04aab62a4a;
        defparam synapse_connection.synap_matrix.genblk1[28].neuron_con_inst.LUT6_inst_0.INIT = 64'hfc6a6a69aaae1696;
        defparam synapse_connection.synap_matrix.genblk1[28].neuron_con_inst.LUT6_inst_1.INIT = 64'hd05652569ad275de;
        defparam synapse_connection.synap_matrix.genblk1[28].neuron_con_inst.LUT6_inst_2.INIT = 64'h161b920bba4bb243;
        defparam synapse_connection.synap_matrix.genblk1[28].neuron_con_inst.LUT6_inst_3.INIT = 64'haaafe82a952a262a;
        defparam synapse_connection.synap_matrix.genblk1[29].neuron_con_inst.LUT6_inst_0.INIT = 64'ha54a2aabaaae009f;
        defparam synapse_connection.synap_matrix.genblk1[29].neuron_con_inst.LUT6_inst_1.INIT = 64'h892ba1a2a9aba572;
        defparam synapse_connection.synap_matrix.genblk1[29].neuron_con_inst.LUT6_inst_2.INIT = 64'hc09b83d3a5523147;
        defparam synapse_connection.synap_matrix.genblk1[29].neuron_con_inst.LUT6_inst_3.INIT = 64'he15f105382d70893;
        defparam synapse_connection.synap_matrix.genblk1[30].neuron_con_inst.LUT6_inst_0.INIT = 64'hb82bb7a92a270cab;
        defparam synapse_connection.synap_matrix.genblk1[30].neuron_con_inst.LUT6_inst_1.INIT = 64'hb66abe6aadaa20aa;
        defparam synapse_connection.synap_matrix.genblk1[30].neuron_con_inst.LUT6_inst_2.INIT = 64'h280fa8cea4cbb643;
        defparam synapse_connection.synap_matrix.genblk1[30].neuron_con_inst.LUT6_inst_3.INIT = 64'h82a82aaa8a53a822;
        defparam synapse_connection.synap_matrix.genblk1[31].neuron_con_inst.LUT6_inst_0.INIT = 64'hb253b14ba3289be3;
        defparam synapse_connection.synap_matrix.genblk1[31].neuron_con_inst.LUT6_inst_1.INIT = 64'h390ee9aea91f2097;
        defparam synapse_connection.synap_matrix.genblk1[31].neuron_con_inst.LUT6_inst_2.INIT = 64'h546bd26b2a6ba909;
        defparam synapse_connection.synap_matrix.genblk1[31].neuron_con_inst.LUT6_inst_3.INIT = 64'h2aa12babf12395ae;
        defparam synapse_connection.synap_matrix.genblk1[32].neuron_con_inst.LUT6_inst_0.INIT = 64'ha1aaa02be8a513a3;
        defparam synapse_connection.synap_matrix.genblk1[32].neuron_con_inst.LUT6_inst_1.INIT = 64'h206ba12a812b2126;
        defparam synapse_connection.synap_matrix.genblk1[32].neuron_con_inst.LUT6_inst_2.INIT = 64'he91549456d6a696a;
        defparam synapse_connection.synap_matrix.genblk1[32].neuron_con_inst.LUT6_inst_3.INIT = 64'haaa56aa28b568b57;
        defparam synapse_connection.synap_matrix.genblk1[33].neuron_con_inst.LUT6_inst_0.INIT = 64'habd22d532d6f46fb;
        defparam synapse_connection.synap_matrix.genblk1[33].neuron_con_inst.LUT6_inst_1.INIT = 64'hadcaa502a597a196;
        defparam synapse_connection.synap_matrix.genblk1[33].neuron_con_inst.LUT6_inst_2.INIT = 64'h932c83ac81ac392a;
        defparam synapse_connection.synap_matrix.genblk1[33].neuron_con_inst.LUT6_inst_3.INIT = 64'hcaaa6356b724b568;
        defparam synapse_connection.synap_matrix.genblk1[34].neuron_con_inst.LUT6_inst_0.INIT = 64'hca5b4229ebafecf0;
        defparam synapse_connection.synap_matrix.genblk1[34].neuron_con_inst.LUT6_inst_1.INIT = 64'hd557ac07aa12aa93;
        defparam synapse_connection.synap_matrix.genblk1[34].neuron_con_inst.LUT6_inst_2.INIT = 64'h3960b56b951b1419;
        defparam synapse_connection.synap_matrix.genblk1[34].neuron_con_inst.LUT6_inst_3.INIT = 64'hcaad4aa9b2aab2ab;
        defparam synapse_connection.synap_matrix.genblk1[35].neuron_con_inst.LUT6_inst_0.INIT = 64'h49da49282ead9cdd;
        defparam synapse_connection.synap_matrix.genblk1[35].neuron_con_inst.LUT6_inst_1.INIT = 64'hab5ae9626d26cd92;
        defparam synapse_connection.synap_matrix.genblk1[35].neuron_con_inst.LUT6_inst_2.INIT = 64'hd4e3d4ba968aaa4e;
        defparam synapse_connection.synap_matrix.genblk1[35].neuron_con_inst.LUT6_inst_3.INIT = 64'h0aab0faec76f744a;
        defparam synapse_connection.synap_matrix.genblk1[36].neuron_con_inst.LUT6_inst_0.INIT = 64'hc555955755562e7c;
        defparam synapse_connection.synap_matrix.genblk1[36].neuron_con_inst.LUT6_inst_1.INIT = 64'h892388abaaabaaab;
        defparam synapse_connection.synap_matrix.genblk1[36].neuron_con_inst.LUT6_inst_2.INIT = 64'h3153d552c0828803;
        defparam synapse_connection.synap_matrix.genblk1[36].neuron_con_inst.LUT6_inst_3.INIT = 64'h2aa1eaaaaaaabd4b;
        defparam synapse_connection.synap_matrix.genblk1[37].neuron_con_inst.LUT6_inst_0.INIT = 64'haa55baab2aab84e4;
        defparam synapse_connection.synap_matrix.genblk1[37].neuron_con_inst.LUT6_inst_1.INIT = 64'haaa928a92d552950;
        defparam synapse_connection.synap_matrix.genblk1[37].neuron_con_inst.LUT6_inst_2.INIT = 64'h282aa92a88938888;
        defparam synapse_connection.synap_matrix.genblk1[37].neuron_con_inst.LUT6_inst_3.INIT = 64'hf450bd4a2a0ae86a;
        defparam synapse_connection.synap_matrix.genblk1[38].neuron_con_inst.LUT6_inst_0.INIT = 64'he92b29aaaaa9d89e;
        defparam synapse_connection.synap_matrix.genblk1[38].neuron_con_inst.LUT6_inst_1.INIT = 64'hd52a436a826b666a;
        defparam synapse_connection.synap_matrix.genblk1[38].neuron_con_inst.LUT6_inst_2.INIT = 64'h229a98d3e2d3b92a;
        defparam synapse_connection.synap_matrix.genblk1[38].neuron_con_inst.LUT6_inst_3.INIT = 64'h8aadaaabab7a22db;
        defparam synapse_connection.synap_matrix.genblk1[39].neuron_con_inst.LUT6_inst_0.INIT = 64'ha5a82aab2aaabc9b;
        defparam synapse_connection.synap_matrix.genblk1[39].neuron_con_inst.LUT6_inst_1.INIT = 64'hb1578906a8a3a5a2;
        defparam synapse_connection.synap_matrix.genblk1[39].neuron_con_inst.LUT6_inst_2.INIT = 64'h14abaa93a8d73556;
        defparam synapse_connection.synap_matrix.genblk1[39].neuron_con_inst.LUT6_inst_3.INIT = 64'h564bd45ad69750b7;
        defparam synapse_connection.synap_matrix.genblk1[40].neuron_con_inst.LUT6_inst_0.INIT = 64'ha929b42baaaca8f0;
        defparam synapse_connection.synap_matrix.genblk1[40].neuron_con_inst.LUT6_inst_1.INIT = 64'hb28b32cab60ba46a;
        defparam synapse_connection.synap_matrix.genblk1[40].neuron_con_inst.LUT6_inst_2.INIT = 64'h288aa28a26cbb28a;
        defparam synapse_connection.synap_matrix.genblk1[40].neuron_con_inst.LUT6_inst_3.INIT = 64'haaacaaaaa84ba84a;
        defparam synapse_connection.synap_matrix.genblk1[41].neuron_con_inst.LUT6_inst_0.INIT = 64'hb2a895aaa1aac80e;
        defparam synapse_connection.synap_matrix.genblk1[41].neuron_con_inst.LUT6_inst_1.INIT = 64'h9bafa9aeadaea3af;
        defparam synapse_connection.synap_matrix.genblk1[41].neuron_con_inst.LUT6_inst_2.INIT = 64'hc24bf26bba7a8bb9;
        defparam synapse_connection.synap_matrix.genblk1[41].neuron_con_inst.LUT6_inst_3.INIT = 64'hdaa22aa96a632a0a;
        defparam synapse_connection.synap_matrix.genblk1[42].neuron_con_inst.LUT6_inst_0.INIT = 64'hb253aa512942cf8b;
        defparam synapse_connection.synap_matrix.genblk1[42].neuron_con_inst.LUT6_inst_1.INIT = 64'h5abbd4b69497b495;
        defparam synapse_connection.synap_matrix.genblk1[42].neuron_con_inst.LUT6_inst_2.INIT = 64'hd24a5b5b5b52cb16;
        defparam synapse_connection.synap_matrix.genblk1[42].neuron_con_inst.LUT6_inst_3.INIT = 64'h4aafaea0549752e4;
        defparam synapse_connection.synap_matrix.genblk1[43].neuron_con_inst.LUT6_inst_0.INIT = 64'h94aaaa8da96ff8f3;
        defparam synapse_connection.synap_matrix.genblk1[43].neuron_con_inst.LUT6_inst_1.INIT = 64'ha92a892c8d2f95b4;
        defparam synapse_connection.synap_matrix.genblk1[43].neuron_con_inst.LUT6_inst_2.INIT = 64'hb697a0b4932ca12a;
        defparam synapse_connection.synap_matrix.genblk1[43].neuron_con_inst.LUT6_inst_3.INIT = 64'h4aaee1592a45b055;
        defparam synapse_connection.synap_matrix.genblk1[44].neuron_con_inst.LUT6_inst_0.INIT = 64'h9a6e52a8aaacb0b8;
        defparam synapse_connection.synap_matrix.genblk1[44].neuron_con_inst.LUT6_inst_1.INIT = 64'h99dabeea9e6bd26b;
        defparam synapse_connection.synap_matrix.genblk1[44].neuron_con_inst.LUT6_inst_2.INIT = 64'h2b2ab303bb6a9b9b;
        defparam synapse_connection.synap_matrix.genblk1[44].neuron_con_inst.LUT6_inst_3.INIT = 64'h2aaecaabeb4a8a4a;
        defparam synapse_connection.synap_matrix.genblk1[45].neuron_con_inst.LUT6_inst_0.INIT = 64'h50eaeee922ab8cb1;
        defparam synapse_connection.synap_matrix.genblk1[45].neuron_con_inst.LUT6_inst_1.INIT = 64'haa5eea564acad54b;
        defparam synapse_connection.synap_matrix.genblk1[45].neuron_con_inst.LUT6_inst_2.INIT = 64'h20a6b2afbaab224b;
        defparam synapse_connection.synap_matrix.genblk1[45].neuron_con_inst.LUT6_inst_3.INIT = 64'heaa895cc145a1853;
        defparam synapse_connection.synap_matrix.genblk1[46].neuron_con_inst.LUT6_inst_0.INIT = 64'hea96155755542430;
        defparam synapse_connection.synap_matrix.genblk1[46].neuron_con_inst.LUT6_inst_1.INIT = 64'hc90a892aaa2a2aab;
        defparam synapse_connection.synap_matrix.genblk1[46].neuron_con_inst.LUT6_inst_2.INIT = 64'h2b4bc552d153c882;
        defparam synapse_connection.synap_matrix.genblk1[46].neuron_con_inst.LUT6_inst_3.INIT = 64'h2aab2aaa24aa354a;
        defparam synapse_connection.synap_matrix.genblk1[47].neuron_con_inst.LUT6_inst_0.INIT = 64'haab12aa96aaf10e3;
        defparam synapse_connection.synap_matrix.genblk1[47].neuron_con_inst.LUT6_inst_1.INIT = 64'h9084a04131509a91;
        defparam synapse_connection.synap_matrix.genblk1[47].neuron_con_inst.LUT6_inst_2.INIT = 64'ha9aaa1aab4b3928d;
        defparam synapse_connection.synap_matrix.genblk1[47].neuron_con_inst.LUT6_inst_3.INIT = 64'h9d15b9ec29a629aa;
        defparam synapse_connection.synap_matrix.genblk1[48].neuron_con_inst.LUT6_inst_0.INIT = 64'hac72817aaaa83fba;
        defparam synapse_connection.synap_matrix.genblk1[48].neuron_con_inst.LUT6_inst_1.INIT = 64'hb953514e94aa54ab;
        defparam synapse_connection.synap_matrix.genblk1[48].neuron_con_inst.LUT6_inst_2.INIT = 64'h0a4b8b4b895b496a;
        defparam synapse_connection.synap_matrix.genblk1[48].neuron_con_inst.LUT6_inst_3.INIT = 64'h4aaaab999c1b1242;
        defparam synapse_connection.synap_matrix.genblk1[49].neuron_con_inst.LUT6_inst_0.INIT = 64'hab4a2b2a6aa1bbea;
        defparam synapse_connection.synap_matrix.genblk1[49].neuron_con_inst.LUT6_inst_1.INIT = 64'h9546950a9aab8a6a;
        defparam synapse_connection.synap_matrix.genblk1[49].neuron_con_inst.LUT6_inst_2.INIT = 64'ha173a157a5571542;
        defparam synapse_connection.synap_matrix.genblk1[49].neuron_con_inst.LUT6_inst_3.INIT = 64'h46aa30ab8aaa8a0b;
        defparam synapse_connection.synap_matrix.genblk1[50].neuron_con_inst.LUT6_inst_0.INIT = 64'ha9aa27a82a2a62bf;
        defparam synapse_connection.synap_matrix.genblk1[50].neuron_con_inst.LUT6_inst_1.INIT = 64'hb67a3e6abc2b30ab;
        defparam synapse_connection.synap_matrix.genblk1[50].neuron_con_inst.LUT6_inst_2.INIT = 64'h2a5aa8be34fbb6da;
        defparam synapse_connection.synap_matrix.genblk1[50].neuron_con_inst.LUT6_inst_3.INIT = 64'h0aae2aaa2a3b2ab3;
        defparam synapse_connection.synap_matrix.genblk1[51].neuron_con_inst.LUT6_inst_0.INIT = 64'hadab2ca8212e2493;
        defparam synapse_connection.synap_matrix.genblk1[51].neuron_con_inst.LUT6_inst_1.INIT = 64'h9bae89aaa98228aa;
        defparam synapse_connection.synap_matrix.genblk1[51].neuron_con_inst.LUT6_inst_2.INIT = 64'h564ad22abaab8ba8;
        defparam synapse_connection.synap_matrix.genblk1[51].neuron_con_inst.LUT6_inst_3.INIT = 64'haa9eeaa8ee4baa0a;
        defparam synapse_connection.synap_matrix.genblk1[52].neuron_con_inst.LUT6_inst_0.INIT = 64'ha428b14868cbdfb2;
        defparam synapse_connection.synap_matrix.genblk1[52].neuron_con_inst.LUT6_inst_1.INIT = 64'h424ab2aa92aaf0ab;
        defparam synapse_connection.synap_matrix.genblk1[52].neuron_con_inst.LUT6_inst_2.INIT = 64'haaa440b55517d556;
        defparam synapse_connection.synap_matrix.genblk1[52].neuron_con_inst.LUT6_inst_3.INIT = 64'h8aa9aaab3aaaf2ac;
        defparam synapse_connection.synap_matrix.genblk1[53].neuron_con_inst.LUT6_inst_0.INIT = 64'h245baac72aaff45d;
        defparam synapse_connection.synap_matrix.genblk1[53].neuron_con_inst.LUT6_inst_1.INIT = 64'ha82eb4a4a485200b;
        defparam synapse_connection.synap_matrix.genblk1[53].neuron_con_inst.LUT6_inst_2.INIT = 64'h24a4a4a8a8292a4b;
        defparam synapse_connection.synap_matrix.genblk1[53].neuron_con_inst.LUT6_inst_3.INIT = 64'h6aadaa5728542815;
        defparam synapse_connection.synap_matrix.genblk1[54].neuron_con_inst.LUT6_inst_0.INIT = 64'h90974aaa2aa952c4;
        defparam synapse_connection.synap_matrix.genblk1[54].neuron_con_inst.LUT6_inst_1.INIT = 64'hfcd2a8c8a821d286;
        defparam synapse_connection.synap_matrix.genblk1[54].neuron_con_inst.LUT6_inst_2.INIT = 64'ha8a8a8ab815a1946;
        defparam synapse_connection.synap_matrix.genblk1[54].neuron_con_inst.LUT6_inst_3.INIT = 64'h6aacca80114a10ea;
        defparam synapse_connection.synap_matrix.genblk1[55].neuron_con_inst.LUT6_inst_0.INIT = 64'h158b95ab3eae738a;
        defparam synapse_connection.synap_matrix.genblk1[55].neuron_con_inst.LUT6_inst_1.INIT = 64'hda56da4a522ad602;
        defparam synapse_connection.synap_matrix.genblk1[55].neuron_con_inst.LUT6_inst_2.INIT = 64'h92d2929782969057;
        defparam synapse_connection.synap_matrix.genblk1[55].neuron_con_inst.LUT6_inst_3.INIT = 64'h2aa818cca8d63053;
        defparam synapse_connection.synap_matrix.genblk1[56].neuron_con_inst.LUT6_inst_0.INIT = 64'ha92929674d52dc42;
        defparam synapse_connection.synap_matrix.genblk1[56].neuron_con_inst.LUT6_inst_1.INIT = 64'h90da90dbaa6baa4a;
        defparam synapse_connection.synap_matrix.genblk1[56].neuron_con_inst.LUT6_inst_2.INIT = 64'h4242c3dbc6029183;
        defparam synapse_connection.synap_matrix.genblk1[56].neuron_con_inst.LUT6_inst_3.INIT = 64'h8aa52aabaaaa242b;
        defparam synapse_connection.synap_matrix.genblk1[57].neuron_con_inst.LUT6_inst_0.INIT = 64'habd9aaa82aa8cdbf;
        defparam synapse_connection.synap_matrix.genblk1[57].neuron_con_inst.LUT6_inst_1.INIT = 64'h94b4a9953595ac55;
        defparam synapse_connection.synap_matrix.genblk1[57].neuron_con_inst.LUT6_inst_2.INIT = 64'h2a5b9d6f9496d6b4;
        defparam synapse_connection.synap_matrix.genblk1[57].neuron_con_inst.LUT6_inst_3.INIT = 64'hb036a5a528aaba56;
        defparam synapse_connection.synap_matrix.genblk1[58].neuron_con_inst.LUT6_inst_0.INIT = 64'h906e962aaeaa3a9c;
        defparam synapse_connection.synap_matrix.genblk1[58].neuron_con_inst.LUT6_inst_1.INIT = 64'hd00b465a921e43f7;
        defparam synapse_connection.synap_matrix.genblk1[58].neuron_con_inst.LUT6_inst_2.INIT = 64'h9ad38adb8a43e92b;
        defparam synapse_connection.synap_matrix.genblk1[58].neuron_con_inst.LUT6_inst_3.INIT = 64'h0aac686b29470a93;
        defparam synapse_connection.synap_matrix.genblk1[59].neuron_con_inst.LUT6_inst_0.INIT = 64'ha26b2aa8aaa9fee9;
        defparam synapse_connection.synap_matrix.genblk1[59].neuron_con_inst.LUT6_inst_1.INIT = 64'hb457b4d6accba4ea;
        defparam synapse_connection.synap_matrix.genblk1[59].neuron_con_inst.LUT6_inst_2.INIT = 64'h68aba89aa84ea416;
        defparam synapse_connection.synap_matrix.genblk1[59].neuron_con_inst.LUT6_inst_3.INIT = 64'hc7da34b790aa3aae;
        defparam synapse_connection.synap_matrix.genblk1[60].neuron_con_inst.LUT6_inst_0.INIT = 64'h8249822aeaab0caf;
        defparam synapse_connection.synap_matrix.genblk1[60].neuron_con_inst.LUT6_inst_1.INIT = 64'hda828aea92279c02;
        defparam synapse_connection.synap_matrix.genblk1[60].neuron_con_inst.LUT6_inst_2.INIT = 64'h8a5792b612b78ab6;
        defparam synapse_connection.synap_matrix.genblk1[60].neuron_con_inst.LUT6_inst_3.INIT = 64'h4aa9eaa9211aa812;
        defparam synapse_connection.synap_matrix.genblk1[61].neuron_con_inst.LUT6_inst_0.INIT = 64'h124a9b1a212c40fc;
        defparam synapse_connection.synap_matrix.genblk1[61].neuron_con_inst.LUT6_inst_1.INIT = 64'haab6aa9ea64bb24e;
        defparam synapse_connection.synap_matrix.genblk1[61].neuron_con_inst.LUT6_inst_2.INIT = 64'h859ba18baaaaabab;
        defparam synapse_connection.synap_matrix.genblk1[61].neuron_con_inst.LUT6_inst_3.INIT = 64'h7abeeaa120b36496;
        defparam synapse_connection.synap_matrix.genblk1[62].neuron_con_inst.LUT6_inst_0.INIT = 64'haaa36ad0a94671ae;
        defparam synapse_connection.synap_matrix.genblk1[62].neuron_con_inst.LUT6_inst_1.INIT = 64'h4d2aa982ab036aa8;
        defparam synapse_connection.synap_matrix.genblk1[62].neuron_con_inst.LUT6_inst_2.INIT = 64'hd0ec55945105d943;
        defparam synapse_connection.synap_matrix.genblk1[62].neuron_con_inst.LUT6_inst_3.INIT = 64'h8aa56aa82aa9caae;
        defparam synapse_connection.synap_matrix.genblk1[63].neuron_con_inst.LUT6_inst_0.INIT = 64'ha1d72e13a928c0b2;
        defparam synapse_connection.synap_matrix.genblk1[63].neuron_con_inst.LUT6_inst_1.INIT = 64'h292bab2295219530;
        defparam synapse_connection.synap_matrix.genblk1[63].neuron_con_inst.LUT6_inst_2.INIT = 64'h1142886d812d092f;
        defparam synapse_connection.synap_matrix.genblk1[63].neuron_con_inst.LUT6_inst_3.INIT = 64'h0aad6b52a045214c;
        defparam synapse_connection.synap_matrix.genblk1[64].neuron_con_inst.LUT6_inst_0.INIT = 64'h88115b08aaaf2091;
        defparam synapse_connection.synap_matrix.genblk1[64].neuron_con_inst.LUT6_inst_1.INIT = 64'hac57a852aa538a53;
        defparam synapse_connection.synap_matrix.genblk1[64].neuron_con_inst.LUT6_inst_2.INIT = 64'hb429966ad53bf54b;
        defparam synapse_connection.synap_matrix.genblk1[64].neuron_con_inst.LUT6_inst_3.INIT = 64'heaa90caab5abb4ab;
        defparam synapse_connection.synap_matrix.genblk1[65].neuron_con_inst.LUT6_inst_0.INIT = 64'h148a94ba3ea89484;
        defparam synapse_connection.synap_matrix.genblk1[65].neuron_con_inst.LUT6_inst_1.INIT = 64'hd2d6d29252d3564a;
        defparam synapse_connection.synap_matrix.genblk1[65].neuron_con_inst.LUT6_inst_2.INIT = 64'h20d5a577803714d3;
        defparam synapse_connection.synap_matrix.genblk1[65].neuron_con_inst.LUT6_inst_3.INIT = 64'h6aa0d65acad70257;
        defparam synapse_connection.synap_matrix.genblk1[66].neuron_con_inst.LUT6_inst_0.INIT = 64'hc6ab96a99752c032;
        defparam synapse_connection.synap_matrix.genblk1[66].neuron_con_inst.LUT6_inst_1.INIT = 64'haa6bab2aa8aa90ba;
        defparam synapse_connection.synap_matrix.genblk1[66].neuron_con_inst.LUT6_inst_2.INIT = 64'h280aaccaaa4a2a4a;
        defparam synapse_connection.synap_matrix.genblk1[66].neuron_con_inst.LUT6_inst_3.INIT = 64'he29d6aa9a808a8ca;
        defparam synapse_connection.synap_matrix.genblk1[67].neuron_con_inst.LUT6_inst_0.INIT = 64'h2ad5aaaa2aaded85;
        defparam synapse_connection.synap_matrix.genblk1[67].neuron_con_inst.LUT6_inst_1.INIT = 64'h8494949113cd3745;
        defparam synapse_connection.synap_matrix.genblk1[67].neuron_con_inst.LUT6_inst_2.INIT = 64'h2aaaa86ab95e1894;
        defparam synapse_connection.synap_matrix.genblk1[67].neuron_con_inst.LUT6_inst_3.INIT = 64'hd1527541212b3aab;
        defparam synapse_connection.synap_matrix.genblk1[68].neuron_con_inst.LUT6_inst_0.INIT = 64'hb542e5192eab4d84;
        defparam synapse_connection.synap_matrix.genblk1[68].neuron_con_inst.LUT6_inst_1.INIT = 64'h90a760828053155a;
        defparam synapse_connection.synap_matrix.genblk1[68].neuron_con_inst.LUT6_inst_2.INIT = 64'h14538252aa2bbbab;
        defparam synapse_connection.synap_matrix.genblk1[68].neuron_con_inst.LUT6_inst_3.INIT = 64'hcaa9aaa9254b9552;
        defparam synapse_connection.synap_matrix.genblk1[69].neuron_con_inst.LUT6_inst_0.INIT = 64'h294a2a2a6aaf50da;
        defparam synapse_connection.synap_matrix.genblk1[69].neuron_con_inst.LUT6_inst_1.INIT = 64'h91769536acd2ab4a;
        defparam synapse_connection.synap_matrix.genblk1[69].neuron_con_inst.LUT6_inst_2.INIT = 64'h42aec2aab2aeb2a7;
        defparam synapse_connection.synap_matrix.genblk1[69].neuron_con_inst.LUT6_inst_3.INIT = 64'h44bad791166f88af;
        defparam synapse_connection.synap_matrix.genblk1[70].neuron_con_inst.LUT6_inst_0.INIT = 64'h8541094baaad81c2;
        defparam synapse_connection.synap_matrix.genblk1[70].neuron_con_inst.LUT6_inst_1.INIT = 64'hc222852a812badc3;
        defparam synapse_connection.synap_matrix.genblk1[70].neuron_con_inst.LUT6_inst_2.INIT = 64'h015684578297d2ab;
        defparam synapse_connection.synap_matrix.genblk1[70].neuron_con_inst.LUT6_inst_3.INIT = 64'hcaa9aaaa3b2228d3;
        defparam synapse_connection.synap_matrix.genblk1[71].neuron_con_inst.LUT6_inst_0.INIT = 64'h296b2b4aa92c4f35;
        defparam synapse_connection.synap_matrix.genblk1[71].neuron_con_inst.LUT6_inst_1.INIT = 64'h321b9a7aab63ab2b;
        defparam synapse_connection.synap_matrix.genblk1[71].neuron_con_inst.LUT6_inst_2.INIT = 64'h152bb12baaaaaa8b;
        defparam synapse_connection.synap_matrix.genblk1[71].neuron_con_inst.LUT6_inst_3.INIT = 64'h8ab7ea28bdab702a;
        defparam synapse_connection.synap_matrix.genblk1[72].neuron_con_inst.LUT6_inst_0.INIT = 64'hac2d6852e8cea1f2;
        defparam synapse_connection.synap_matrix.genblk1[72].neuron_con_inst.LUT6_inst_1.INIT = 64'h420ba2aaa2aae228;
        defparam synapse_connection.synap_matrix.genblk1[72].neuron_con_inst.LUT6_inst_2.INIT = 64'h98b254965557c046;
        defparam synapse_connection.synap_matrix.genblk1[72].neuron_con_inst.LUT6_inst_3.INIT = 64'haaa5aaa9aaab4ab2;
        defparam synapse_connection.synap_matrix.genblk1[73].neuron_con_inst.LUT6_inst_0.INIT = 64'haa55a554a8ec04b7;
        defparam synapse_connection.synap_matrix.genblk1[73].neuron_con_inst.LUT6_inst_1.INIT = 64'hb6533495b49724d4;
        defparam synapse_connection.synap_matrix.genblk1[73].neuron_con_inst.LUT6_inst_2.INIT = 64'h093aacaf94a41497;
        defparam synapse_connection.synap_matrix.genblk1[73].neuron_con_inst.LUT6_inst_3.INIT = 64'h4aaab546b561bc68;
        defparam synapse_connection.synap_matrix.genblk1[74].neuron_con_inst.LUT6_inst_0.INIT = 64'h82e7d29aaaade4b2;
        defparam synapse_connection.synap_matrix.genblk1[74].neuron_con_inst.LUT6_inst_1.INIT = 64'ha7d7aed7a2808a83;
        defparam synapse_connection.synap_matrix.genblk1[74].neuron_con_inst.LUT6_inst_2.INIT = 64'haa2aaa2ba9521512;
        defparam synapse_connection.synap_matrix.genblk1[74].neuron_con_inst.LUT6_inst_3.INIT = 64'h8aad62a0961a0e2a;
        defparam synapse_connection.synap_matrix.genblk1[75].neuron_con_inst.LUT6_inst_0.INIT = 64'h53fabaa82eafedd5;
        defparam synapse_connection.synap_matrix.genblk1[75].neuron_con_inst.LUT6_inst_1.INIT = 64'ha946eb525a52d34a;
        defparam synapse_connection.synap_matrix.genblk1[75].neuron_con_inst.LUT6_inst_2.INIT = 64'h832b8b23892bab42;
        defparam synapse_connection.synap_matrix.genblk1[75].neuron_con_inst.LUT6_inst_3.INIT = 64'h0aaec769cd0b9323;
        defparam synapse_connection.synap_matrix.genblk1[76].neuron_con_inst.LUT6_inst_0.INIT = 64'hc2a9d2a15613d202;
        defparam synapse_connection.synap_matrix.genblk1[76].neuron_con_inst.LUT6_inst_1.INIT = 64'h531bfa5aab4b9a2a;
        defparam synapse_connection.synap_matrix.genblk1[76].neuron_con_inst.LUT6_inst_2.INIT = 64'h09aba94bd15a535a;
        defparam synapse_connection.synap_matrix.genblk1[76].neuron_con_inst.LUT6_inst_3.INIT = 64'haaa3aaa9afaab92b;
        defparam synapse_connection.synap_matrix.genblk1[77].neuron_con_inst.LUT6_inst_0.INIT = 64'h8aa92aa8eaa074fe;
        defparam synapse_connection.synap_matrix.genblk1[77].neuron_con_inst.LUT6_inst_1.INIT = 64'ha6d1964514210aad;
        defparam synapse_connection.synap_matrix.genblk1[77].neuron_con_inst.LUT6_inst_2.INIT = 64'ha02aa0ae32b7e280;
        defparam synapse_connection.synap_matrix.genblk1[77].neuron_con_inst.LUT6_inst_3.INIT = 64'hf211b05d2837e402;
        defparam synapse_connection.synap_matrix.genblk1[78].neuron_con_inst.LUT6_inst_0.INIT = 64'hc4a86ea9aea6840c;
        defparam synapse_connection.synap_matrix.genblk1[78].neuron_con_inst.LUT6_inst_1.INIT = 64'h92825edaca2a51aa;
        defparam synapse_connection.synap_matrix.genblk1[78].neuron_con_inst.LUT6_inst_2.INIT = 64'h399aabcbaa62802b;
        defparam synapse_connection.synap_matrix.genblk1[78].neuron_con_inst.LUT6_inst_3.INIT = 64'h42af68482a4a3a1a;
        defparam synapse_connection.synap_matrix.genblk1[79].neuron_con_inst.LUT6_inst_0.INIT = 64'hb6ea2aa92aabb2be;
        defparam synapse_connection.synap_matrix.genblk1[79].neuron_con_inst.LUT6_inst_1.INIT = 64'ha087a492a552b54b;
        defparam synapse_connection.synap_matrix.genblk1[79].neuron_con_inst.LUT6_inst_2.INIT = 64'h2063a06aaa2ba8ae;
        defparam synapse_connection.synap_matrix.genblk1[79].neuron_con_inst.LUT6_inst_3.INIT = 64'h2d5bf5569053b06a;
        defparam synapse_connection.synap_matrix.genblk1[80].neuron_con_inst.LUT6_inst_0.INIT = 64'had6b3d282aa5ee8f;
        defparam synapse_connection.synap_matrix.genblk1[80].neuron_con_inst.LUT6_inst_1.INIT = 64'ha68bb68aa48b24eb;
        defparam synapse_connection.synap_matrix.genblk1[80].neuron_con_inst.LUT6_inst_2.INIT = 64'ha2cab09b268ab28e;
        defparam synapse_connection.synap_matrix.genblk1[80].neuron_con_inst.LUT6_inst_3.INIT = 64'h4aa9eaaaab4b284a;
        defparam synapse_connection.synap_matrix.genblk1[81].neuron_con_inst.LUT6_inst_0.INIT = 64'h82ba924aa02d92b1;
        defparam synapse_connection.synap_matrix.genblk1[81].neuron_con_inst.LUT6_inst_1.INIT = 64'ha977992ea93e93b7;
        defparam synapse_connection.synap_matrix.genblk1[81].neuron_con_inst.LUT6_inst_2.INIT = 64'h5052830aabab09a8;
        defparam synapse_connection.synap_matrix.genblk1[81].neuron_con_inst.LUT6_inst_3.INIT = 64'hbaa9aaa860a2f4d7;
        defparam synapse_connection.synap_matrix.genblk1[82].neuron_con_inst.LUT6_inst_0.INIT = 64'hb80a2a0129ad73e4;
        defparam synapse_connection.synap_matrix.genblk1[82].neuron_con_inst.LUT6_inst_1.INIT = 64'h73aaf4a2b5aab3e1;
        defparam synapse_connection.synap_matrix.genblk1[82].neuron_con_inst.LUT6_inst_2.INIT = 64'h9b5349456b66a12b;
        defparam synapse_connection.synap_matrix.genblk1[82].neuron_con_inst.LUT6_inst_3.INIT = 64'h6aaf6ea272d7ca52;
        defparam synapse_connection.synap_matrix.genblk1[83].neuron_con_inst.LUT6_inst_0.INIT = 64'ha412a154a8285e1c;
        defparam synapse_connection.synap_matrix.genblk1[83].neuron_con_inst.LUT6_inst_1.INIT = 64'ha8422d2aa4aca4ae;
        defparam synapse_connection.synap_matrix.genblk1[83].neuron_con_inst.LUT6_inst_2.INIT = 64'h895524b4b2a51283;
        defparam synapse_connection.synap_matrix.genblk1[83].neuron_con_inst.LUT6_inst_3.INIT = 64'h4aaaaa95a0c1aa45;
        defparam synapse_connection.synap_matrix.genblk1[84].neuron_con_inst.LUT6_inst_0.INIT = 64'h9abe0aa9a2ae66aa;
        defparam synapse_connection.synap_matrix.genblk1[84].neuron_con_inst.LUT6_inst_1.INIT = 64'h855bb40a8a3882ab;
        defparam synapse_connection.synap_matrix.genblk1[84].neuron_con_inst.LUT6_inst_2.INIT = 64'h28aaaa2aa92a254f;
        defparam synapse_connection.synap_matrix.genblk1[84].neuron_con_inst.LUT6_inst_3.INIT = 64'h4aafca818d0a8a0a;
        defparam synapse_connection.synap_matrix.genblk1[85].neuron_con_inst.LUT6_inst_0.INIT = 64'h0a10caa028ac6ce3;
        defparam synapse_connection.synap_matrix.genblk1[85].neuron_con_inst.LUT6_inst_1.INIT = 64'ha56649526b43c926;
        defparam synapse_connection.synap_matrix.genblk1[85].neuron_con_inst.LUT6_inst_2.INIT = 64'h8168eb6b812a0d2b;
        defparam synapse_connection.synap_matrix.genblk1[85].neuron_con_inst.LUT6_inst_3.INIT = 64'h2aa5d579552b4162;
        defparam synapse_connection.synap_matrix.genblk1[86].neuron_con_inst.LUT6_inst_0.INIT = 64'hd4a5950295523a04;
        defparam synapse_connection.synap_matrix.genblk1[86].neuron_con_inst.LUT6_inst_1.INIT = 64'h905792c7b2a3b2aa;
        defparam synapse_connection.synap_matrix.genblk1[86].neuron_con_inst.LUT6_inst_2.INIT = 64'h1d4ad00282029143;
        defparam synapse_connection.synap_matrix.genblk1[86].neuron_con_inst.LUT6_inst_3.INIT = 64'h0aac2aabaaabb15b;
        defparam synapse_connection.synap_matrix.genblk1[87].neuron_con_inst.LUT6_inst_0.INIT = 64'hbaadaaa92aa81277;
        defparam synapse_connection.synap_matrix.genblk1[87].neuron_con_inst.LUT6_inst_1.INIT = 64'ha280004119550811;
        defparam synapse_connection.synap_matrix.genblk1[87].neuron_con_inst.LUT6_inst_2.INIT = 64'ha9aba0ae00ab9281;
        defparam synapse_connection.synap_matrix.genblk1[87].neuron_con_inst.LUT6_inst_3.INIT = 64'h5552359fa9a2e9aa;
        defparam synapse_connection.synap_matrix.genblk1[88].neuron_con_inst.LUT6_inst_0.INIT = 64'he4ab60a8aead9e98;
        defparam synapse_connection.synap_matrix.genblk1[88].neuron_con_inst.LUT6_inst_1.INIT = 64'ha65a36cae0ca2223;
        defparam synapse_connection.synap_matrix.genblk1[88].neuron_con_inst.LUT6_inst_2.INIT = 64'h2ccaa96aa92b0b2b;
        defparam synapse_connection.synap_matrix.genblk1[88].neuron_con_inst.LUT6_inst_3.INIT = 64'h0aae612b296aee8a;
        defparam synapse_connection.synap_matrix.genblk1[89].neuron_con_inst.LUT6_inst_0.INIT = 64'h20a9aaa82aafbcf6;
        defparam synapse_connection.synap_matrix.genblk1[89].neuron_con_inst.LUT6_inst_1.INIT = 64'hb68fb2caa02aa5ab;
        defparam synapse_connection.synap_matrix.genblk1[89].neuron_con_inst.LUT6_inst_2.INIT = 64'h592be88b2846a52c;
        defparam synapse_connection.synap_matrix.genblk1[89].neuron_con_inst.LUT6_inst_3.INIT = 64'h83d81f4a1a6b3a2b;
        defparam synapse_connection.synap_matrix.genblk1[90].neuron_con_inst.LUT6_inst_0.INIT = 64'hb5420da82aaf5ea1;
        defparam synapse_connection.synap_matrix.genblk1[90].neuron_con_inst.LUT6_inst_1.INIT = 64'h9253a54aa1b2aa83;
        defparam synapse_connection.synap_matrix.genblk1[90].neuron_con_inst.LUT6_inst_2.INIT = 64'h12439283c28292c2;
        defparam synapse_connection.synap_matrix.genblk1[90].neuron_con_inst.LUT6_inst_3.INIT = 64'heaaa2aab294ba952;
        defparam synapse_connection.synap_matrix.genblk1[91].neuron_con_inst.LUT6_inst_0.INIT = 64'h9aabb78969a8a000;
        defparam synapse_connection.synap_matrix.genblk1[91].neuron_con_inst.LUT6_inst_1.INIT = 64'h1b2fadafb8afa6ae;
        defparam synapse_connection.synap_matrix.genblk1[91].neuron_con_inst.LUT6_inst_2.INIT = 64'hcad2ea0aab0a2b2b;
        defparam synapse_connection.synap_matrix.genblk1[91].neuron_con_inst.LUT6_inst_3.INIT = 64'heab62a29ec9128a2;
        defparam synapse_connection.synap_matrix.genblk1[92].neuron_con_inst.LUT6_inst_0.INIT = 64'h2a426ad14a8b3bdc;
        defparam synapse_connection.synap_matrix.genblk1[92].neuron_con_inst.LUT6_inst_1.INIT = 64'hccaae886a953aa54;
        defparam synapse_connection.synap_matrix.genblk1[92].neuron_con_inst.LUT6_inst_2.INIT = 64'h584b404b5a2b28ab;
        defparam synapse_connection.synap_matrix.genblk1[92].neuron_con_inst.LUT6_inst_3.INIT = 64'haaa8a5a8c003d242;
        defparam synapse_connection.synap_matrix.genblk1[93].neuron_con_inst.LUT6_inst_0.INIT = 64'hb14e2d2028a86af8;
        defparam synapse_connection.synap_matrix.genblk1[93].neuron_con_inst.LUT6_inst_1.INIT = 64'ha92ba16e916fb262;
        defparam synapse_connection.synap_matrix.genblk1[93].neuron_con_inst.LUT6_inst_2.INIT = 64'h049590b682ecab26;
        defparam synapse_connection.synap_matrix.genblk1[93].neuron_con_inst.LUT6_inst_3.INIT = 64'haaa8ea32b4d49594;
        defparam synapse_connection.synap_matrix.genblk1[94].neuron_con_inst.LUT6_inst_0.INIT = 64'hd27f52e82aacf295;
        defparam synapse_connection.synap_matrix.genblk1[94].neuron_con_inst.LUT6_inst_1.INIT = 64'h86eba66ab66bd26f;
        defparam synapse_connection.synap_matrix.genblk1[94].neuron_con_inst.LUT6_inst_2.INIT = 64'h32aaa02aa3e3a606;
        defparam synapse_connection.synap_matrix.genblk1[94].neuron_con_inst.LUT6_inst_3.INIT = 64'haaacaaabe3ca922a;
        defparam synapse_connection.synap_matrix.genblk1[95].neuron_con_inst.LUT6_inst_0.INIT = 64'h51525261a4ab8086;
        defparam synapse_connection.synap_matrix.genblk1[95].neuron_con_inst.LUT6_inst_1.INIT = 64'haa96ea525b4bd32b;
        defparam synapse_connection.synap_matrix.genblk1[95].neuron_con_inst.LUT6_inst_2.INIT = 64'h112294a682aa4297;
        defparam synapse_connection.synap_matrix.genblk1[95].neuron_con_inst.LUT6_inst_3.INIT = 64'hcaaf9d5ed507555b;
        defparam synapse_connection.synap_matrix.genblk1[96].neuron_con_inst.LUT6_inst_0.INIT = 64'hd0a694869557741e;
        defparam synapse_connection.synap_matrix.genblk1[96].neuron_con_inst.LUT6_inst_1.INIT = 64'hd9daa28eaa8abaae;
        defparam synapse_connection.synap_matrix.genblk1[96].neuron_con_inst.LUT6_inst_2.INIT = 64'hb142c24b855b1113;
        defparam synapse_connection.synap_matrix.genblk1[96].neuron_con_inst.LUT6_inst_3.INIT = 64'h2aaaeaaba2aab11a;
        defparam synapse_connection.synap_matrix.genblk1[97].neuron_con_inst.LUT6_inst_0.INIT = 64'h82adaaa82aa9b6d6;
        defparam synapse_connection.synap_matrix.genblk1[97].neuron_con_inst.LUT6_inst_1.INIT = 64'ha095364504550ab1;
        defparam synapse_connection.synap_matrix.genblk1[97].neuron_con_inst.LUT6_inst_2.INIT = 64'h282ba0af10af4281;
        defparam synapse_connection.synap_matrix.genblk1[97].neuron_con_inst.LUT6_inst_3.INIT = 64'h7011705fa02be02b;
        defparam synapse_connection.synap_matrix.genblk1[98].neuron_con_inst.LUT6_inst_0.INIT = 64'haaaba028aaac54e6;
        defparam synapse_connection.synap_matrix.genblk1[98].neuron_con_inst.LUT6_inst_1.INIT = 64'hd55b5553d44602af;
        defparam synapse_connection.synap_matrix.genblk1[98].neuron_con_inst.LUT6_inst_2.INIT = 64'h00468153d1526553;
        defparam synapse_connection.synap_matrix.genblk1[98].neuron_con_inst.LUT6_inst_3.INIT = 64'h6aa3659ab88b3aab;
        defparam synapse_connection.synap_matrix.genblk1[99].neuron_con_inst.LUT6_inst_0.INIT = 64'h20a82aaa2aa590c0;
        defparam synapse_connection.synap_matrix.genblk1[99].neuron_con_inst.LUT6_inst_1.INIT = 64'had1ba2daa36aa12b;
        defparam synapse_connection.synap_matrix.genblk1[99].neuron_con_inst.LUT6_inst_2.INIT = 64'h0a2ba8aa284b294b;
        defparam synapse_connection.synap_matrix.genblk1[99].neuron_con_inst.LUT6_inst_3.INIT = 64'h455b954b2a8a0aaa;
        defparam synapse_connection.synap_matrix.genblk1[100].neuron_con_inst.LUT6_inst_0.INIT = 64'ha8a9a0a82aad4aa6;
        defparam synapse_connection.synap_matrix.genblk1[100].neuron_con_inst.LUT6_inst_1.INIT = 64'hd25b866aa12a002b;
        defparam synapse_connection.synap_matrix.genblk1[100].neuron_con_inst.LUT6_inst_2.INIT = 64'haa4facdbb6dbd65a;
        defparam synapse_connection.synap_matrix.genblk1[100].neuron_con_inst.LUT6_inst_3.INIT = 64'h4aaeeaaa2adbaa92;
        defparam synapse_connection.synap_matrix.genblk1[101].neuron_con_inst.LUT6_inst_0.INIT = 64'h90a31539a0283e93;
        defparam synapse_connection.synap_matrix.genblk1[101].neuron_con_inst.LUT6_inst_1.INIT = 64'ha9279b2aa92b14a7;
        defparam synapse_connection.synap_matrix.genblk1[101].neuron_con_inst.LUT6_inst_2.INIT = 64'h9952a18aa8aaa80a;
        defparam synapse_connection.synap_matrix.genblk1[101].neuron_con_inst.LUT6_inst_3.INIT = 64'h2aa7eab936924452;
        defparam synapse_connection.synap_matrix.genblk1[102].neuron_con_inst.LUT6_inst_0.INIT = 64'hb41a7448cd516dc6;
        defparam synapse_connection.synap_matrix.genblk1[102].neuron_con_inst.LUT6_inst_1.INIT = 64'ha2ab92a2960f943e;
        defparam synapse_connection.synap_matrix.genblk1[102].neuron_con_inst.LUT6_inst_2.INIT = 64'hd446680f2a0baaaa;
        defparam synapse_connection.synap_matrix.genblk1[102].neuron_con_inst.LUT6_inst_3.INIT = 64'h0aae21295543d435;
        defparam synapse_connection.synap_matrix.genblk1[103].neuron_con_inst.LUT6_inst_0.INIT = 64'haf17257728a9d2e3;
        defparam synapse_connection.synap_matrix.genblk1[103].neuron_con_inst.LUT6_inst_1.INIT = 64'hafab25aeb594a356;
        defparam synapse_connection.synap_matrix.genblk1[103].neuron_con_inst.LUT6_inst_2.INIT = 64'h2d0535a5a2ada72b;
        defparam synapse_connection.synap_matrix.genblk1[103].neuron_con_inst.LUT6_inst_3.INIT = 64'h8aa9a756ad95aab4;
        defparam synapse_connection.synap_matrix.genblk1[104].neuron_con_inst.LUT6_inst_0.INIT = 64'haaa2c000aaadeeba;
        defparam synapse_connection.synap_matrix.genblk1[104].neuron_con_inst.LUT6_inst_1.INIT = 64'hd0569156808382ab;
        defparam synapse_connection.synap_matrix.genblk1[104].neuron_con_inst.LUT6_inst_2.INIT = 64'h280a8553c1931456;
        defparam synapse_connection.synap_matrix.genblk1[104].neuron_con_inst.LUT6_inst_3.INIT = 64'hcaa9caa3aaaa2aaa;
        defparam synapse_connection.synap_matrix.genblk1[105].neuron_con_inst.LUT6_inst_0.INIT = 64'h00cad86222abd8ff;
        defparam synapse_connection.synap_matrix.genblk1[105].neuron_con_inst.LUT6_inst_1.INIT = 64'hea57ead252c3d4d3;
        defparam synapse_connection.synap_matrix.genblk1[105].neuron_con_inst.LUT6_inst_2.INIT = 64'h54ab9aab8a4b0a53;
        defparam synapse_connection.synap_matrix.genblk1[105].neuron_con_inst.LUT6_inst_3.INIT = 64'hcaab411dc85a54a2;
        defparam synapse_connection.synap_matrix.genblk1[106].neuron_con_inst.LUT6_inst_0.INIT = 64'ha820242a55752e30;
        defparam synapse_connection.synap_matrix.genblk1[106].neuron_con_inst.LUT6_inst_1.INIT = 64'hb46aa26baa2aab2a;
        defparam synapse_connection.synap_matrix.genblk1[106].neuron_con_inst.LUT6_inst_2.INIT = 64'h286ba46ab0cab4cb;
        defparam synapse_connection.synap_matrix.genblk1[106].neuron_con_inst.LUT6_inst_3.INIT = 64'h2aadeaaaaaaaaa2b;
        defparam synapse_connection.synap_matrix.genblk1[107].neuron_con_inst.LUT6_inst_0.INIT = 64'ha981aaa9aaa9389a;
        defparam synapse_connection.synap_matrix.genblk1[107].neuron_con_inst.LUT6_inst_1.INIT = 64'h9dedb54931402d09;
        defparam synapse_connection.synap_matrix.genblk1[107].neuron_con_inst.LUT6_inst_2.INIT = 64'h28aaa2afb5a381ed;
        defparam synapse_connection.synap_matrix.genblk1[107].neuron_con_inst.LUT6_inst_3.INIT = 64'hd5746155a857a8aa;
        defparam synapse_connection.synap_matrix.genblk1[108].neuron_con_inst.LUT6_inst_0.INIT = 64'h855b65c92aa84888;
        defparam synapse_connection.synap_matrix.genblk1[108].neuron_con_inst.LUT6_inst_1.INIT = 64'h92961253d242554a;
        defparam synapse_connection.synap_matrix.genblk1[108].neuron_con_inst.LUT6_inst_2.INIT = 64'h9497a493a2a32a23;
        defparam synapse_connection.synap_matrix.genblk1[108].neuron_con_inst.LUT6_inst_3.INIT = 64'h0aa96aaab54a3556;
        defparam synapse_connection.synap_matrix.genblk1[109].neuron_con_inst.LUT6_inst_0.INIT = 64'h28aaaaa82aa5ccde;
        defparam synapse_connection.synap_matrix.genblk1[109].neuron_con_inst.LUT6_inst_1.INIT = 64'had5bed9aaecba92a;
        defparam synapse_connection.synap_matrix.genblk1[109].neuron_con_inst.LUT6_inst_2.INIT = 64'h0a2be8aaa8ea294b;
        defparam synapse_connection.synap_matrix.genblk1[109].neuron_con_inst.LUT6_inst_3.INIT = 64'he52dedd86c8b8a2b;
        defparam synapse_connection.synap_matrix.genblk1[110].neuron_con_inst.LUT6_inst_0.INIT = 64'h95520d0aaaa9bc9a;
        defparam synapse_connection.synap_matrix.genblk1[110].neuron_con_inst.LUT6_inst_1.INIT = 64'h82a2a54aa5238503;
        defparam synapse_connection.synap_matrix.genblk1[110].neuron_con_inst.LUT6_inst_2.INIT = 64'h83578002c283a2aa;
        defparam synapse_connection.synap_matrix.genblk1[110].neuron_con_inst.LUT6_inst_3.INIT = 64'haaaeaaaaad162956;
        defparam synapse_connection.synap_matrix.genblk1[111].neuron_con_inst.LUT6_inst_0.INIT = 64'h92a9a7a929ab3a01;
        defparam synapse_connection.synap_matrix.genblk1[111].neuron_con_inst.LUT6_inst_1.INIT = 64'h9baea5aea8aea6ae;
        defparam synapse_connection.synap_matrix.genblk1[111].neuron_con_inst.LUT6_inst_2.INIT = 64'hcad3e24baa4a8b28;
        defparam synapse_connection.synap_matrix.genblk1[111].neuron_con_inst.LUT6_inst_3.INIT = 64'h6a85aa2ae8c12aa2;
        defparam synapse_connection.synap_matrix.genblk1[112].neuron_con_inst.LUT6_inst_0.INIT = 64'ha5562551e90befc0;
        defparam synapse_connection.synap_matrix.genblk1[112].neuron_con_inst.LUT6_inst_1.INIT = 64'ha0aba2ae80a29102;
        defparam synapse_connection.synap_matrix.genblk1[112].neuron_con_inst.LUT6_inst_2.INIT = 64'h555751962aa622ae;
        defparam synapse_connection.synap_matrix.genblk1[112].neuron_con_inst.LUT6_inst_3.INIT = 64'h0aa1a8a8b02a5456;
        defparam synapse_connection.synap_matrix.genblk1[113].neuron_con_inst.LUT6_inst_0.INIT = 64'haa96aabd2aee9ffb;
        defparam synapse_connection.synap_matrix.genblk1[113].neuron_con_inst.LUT6_inst_1.INIT = 64'h282aa222a807ab62;
        defparam synapse_connection.synap_matrix.genblk1[113].neuron_con_inst.LUT6_inst_2.INIT = 64'h168792ac9208300b;
        defparam synapse_connection.synap_matrix.genblk1[113].neuron_con_inst.LUT6_inst_3.INIT = 64'h4aaba1542418b6b4;
        defparam synapse_connection.synap_matrix.genblk1[114].neuron_con_inst.LUT6_inst_0.INIT = 64'h92df8aa1a2a9f6e5;
        defparam synapse_connection.synap_matrix.genblk1[114].neuron_con_inst.LUT6_inst_1.INIT = 64'h957ba6caa6cdd6ca;
        defparam synapse_connection.synap_matrix.genblk1[114].neuron_con_inst.LUT6_inst_2.INIT = 64'h2aaaaaaaaa2b254e;
        defparam synapse_connection.synap_matrix.genblk1[114].neuron_con_inst.LUT6_inst_3.INIT = 64'haaaa082a08bbc28b;
        defparam synapse_connection.synap_matrix.genblk1[115].neuron_con_inst.LUT6_inst_0.INIT = 64'h5468d6aa24a4f4b0;
        defparam synapse_connection.synap_matrix.genblk1[115].neuron_con_inst.LUT6_inst_1.INIT = 64'ha90eaaba2a2bd56a;
        defparam synapse_connection.synap_matrix.genblk1[115].neuron_con_inst.LUT6_inst_2.INIT = 64'h700f90a7a0aa212e;
        defparam synapse_connection.synap_matrix.genblk1[115].neuron_con_inst.LUT6_inst_3.INIT = 64'hcaa8d01954065056;
        defparam synapse_connection.synap_matrix.genblk1[116].neuron_con_inst.LUT6_inst_0.INIT = 64'hcaae028f551df62a;
        defparam synapse_connection.synap_matrix.genblk1[116].neuron_con_inst.LUT6_inst_1.INIT = 64'h9346935699629baa;
        defparam synapse_connection.synap_matrix.genblk1[116].neuron_con_inst.LUT6_inst_2.INIT = 64'h180a955294538252;
        defparam synapse_connection.synap_matrix.genblk1[116].neuron_con_inst.LUT6_inst_3.INIT = 64'hcaaf6aab2fa998ab;
        defparam synapse_connection.synap_matrix.genblk1[117].neuron_con_inst.LUT6_inst_0.INIT = 64'hbaac2aa9caaa31a9;
        defparam synapse_connection.synap_matrix.genblk1[117].neuron_con_inst.LUT6_inst_1.INIT = 64'h84d0944510441825;
        defparam synapse_connection.synap_matrix.genblk1[117].neuron_con_inst.LUT6_inst_2.INIT = 64'he8aba0aa88a39281;
        defparam synapse_connection.synap_matrix.genblk1[117].neuron_con_inst.LUT6_inst_3.INIT = 64'h9813241d20a7e0a3;
        defparam synapse_connection.synap_matrix.genblk1[118].neuron_con_inst.LUT6_inst_0.INIT = 64'hfc6828292aa27c98;
        defparam synapse_connection.synap_matrix.genblk1[118].neuron_con_inst.LUT6_inst_1.INIT = 64'h940a5aaa9b2b41ab;
        defparam synapse_connection.synap_matrix.genblk1[118].neuron_con_inst.LUT6_inst_2.INIT = 64'h1ab38a934a53c869;
        defparam synapse_connection.synap_matrix.genblk1[118].neuron_con_inst.LUT6_inst_3.INIT = 64'haaac2a3b2a5a7273;
        defparam synapse_connection.synap_matrix.genblk1[119].neuron_con_inst.LUT6_inst_0.INIT = 64'h292baaa82aacae9d;
        defparam synapse_connection.synap_matrix.genblk1[119].neuron_con_inst.LUT6_inst_1.INIT = 64'had1ba4caaccaa96b;
        defparam synapse_connection.synap_matrix.genblk1[119].neuron_con_inst.LUT6_inst_2.INIT = 64'h88abe8cb28cba8ab;
        defparam synapse_connection.synap_matrix.genblk1[119].neuron_con_inst.LUT6_inst_3.INIT = 64'hc13b4d6868ab68aa;
        defparam synapse_connection.synap_matrix.genblk1[120].neuron_con_inst.LUT6_inst_0.INIT = 64'h942aba4aaaaa6db0;
        defparam synapse_connection.synap_matrix.genblk1[120].neuron_con_inst.LUT6_inst_1.INIT = 64'h8e8282a6945b956a;
        defparam synapse_connection.synap_matrix.genblk1[120].neuron_con_inst.LUT6_inst_2.INIT = 64'ha48394d684d68653;
        defparam synapse_connection.synap_matrix.genblk1[120].neuron_con_inst.LUT6_inst_3.INIT = 64'haaaf2aaba4aa14a2;
        defparam synapse_connection.synap_matrix.genblk1[121].neuron_con_inst.LUT6_inst_0.INIT = 64'h9520a4a9202ca4fc;
        defparam synapse_connection.synap_matrix.genblk1[121].neuron_con_inst.LUT6_inst_1.INIT = 64'h092e9c6aba2b352a;
        defparam synapse_connection.synap_matrix.genblk1[121].neuron_con_inst.LUT6_inst_2.INIT = 64'h0193e8aba92b292a;
        defparam synapse_connection.synap_matrix.genblk1[121].neuron_con_inst.LUT6_inst_3.INIT = 64'h6aabea9a22534317;
        defparam synapse_connection.synap_matrix.genblk1[122].neuron_con_inst.LUT6_inst_0.INIT = 64'hb0466a004a917dc1;
        defparam synapse_connection.synap_matrix.genblk1[122].neuron_con_inst.LUT6_inst_1.INIT = 64'haaab88869106917c;
        defparam synapse_connection.synap_matrix.genblk1[122].neuron_con_inst.LUT6_inst_2.INIT = 64'h51624a4b2a2baaaa;
        defparam synapse_connection.synap_matrix.genblk1[122].neuron_con_inst.LUT6_inst_3.INIT = 64'h6aa9a5a85412d554;
        defparam synapse_connection.synap_matrix.genblk1[123].neuron_con_inst.LUT6_inst_0.INIT = 64'ha947ab45aae9bfbf;
        defparam synapse_connection.synap_matrix.genblk1[123].neuron_con_inst.LUT6_inst_1.INIT = 64'hab42292eadada895;
        defparam synapse_connection.synap_matrix.genblk1[123].neuron_con_inst.LUT6_inst_2.INIT = 64'h141290a996a8909a;
        defparam synapse_connection.synap_matrix.genblk1[123].neuron_con_inst.LUT6_inst_3.INIT = 64'h4aade2d02a40a30c;
        defparam synapse_connection.synap_matrix.genblk1[124].neuron_con_inst.LUT6_inst_0.INIT = 64'h2487b4a8aaa89ab2;
        defparam synapse_connection.synap_matrix.genblk1[124].neuron_con_inst.LUT6_inst_1.INIT = 64'ha8d2a808ac802487;
        defparam synapse_connection.synap_matrix.genblk1[124].neuron_con_inst.LUT6_inst_2.INIT = 64'ha0a8a98aa01bb0c7;
        defparam synapse_connection.synap_matrix.genblk1[124].neuron_con_inst.LUT6_inst_3.INIT = 64'haaa2aaab06aa64aa;
        defparam synapse_connection.synap_matrix.genblk1[125].neuron_con_inst.LUT6_inst_0.INIT = 64'h55aa54ab2eae01cc;
        defparam synapse_connection.synap_matrix.genblk1[125].neuron_con_inst.LUT6_inst_1.INIT = 64'hfa47db22d693d60a;
        defparam synapse_connection.synap_matrix.genblk1[125].neuron_con_inst.LUT6_inst_2.INIT = 64'h9090949786f73a57;
        defparam synapse_connection.synap_matrix.genblk1[125].neuron_con_inst.LUT6_inst_3.INIT = 64'heaa8b82920971797;
        defparam synapse_connection.synap_matrix.genblk1[126].neuron_con_inst.LUT6_inst_0.INIT = 64'hd557155455561213;
        defparam synapse_connection.synap_matrix.genblk1[126].neuron_con_inst.LUT6_inst_1.INIT = 64'h8403a62ba2a6b782;
        defparam synapse_connection.synap_matrix.genblk1[126].neuron_con_inst.LUT6_inst_2.INIT = 64'h3552e50b8083c863;
        defparam synapse_connection.synap_matrix.genblk1[126].neuron_con_inst.LUT6_inst_3.INIT = 64'h8aaaeaa928aba55a;
        defparam synapse_connection.synap_matrix.genblk1[127].neuron_con_inst.LUT6_inst_0.INIT = 64'hbaadaaa86aaa7412;
        defparam synapse_connection.synap_matrix.genblk1[127].neuron_con_inst.LUT6_inst_1.INIT = 64'h8a95874115002295;
        defparam synapse_connection.synap_matrix.genblk1[127].neuron_con_inst.LUT6_inst_2.INIT = 64'haa2aa3aaaaae1284;
        defparam synapse_connection.synap_matrix.genblk1[127].neuron_con_inst.LUT6_inst_3.INIT = 64'hb227f1fc2982632b;
        defparam synapse_connection.synap_matrix.genblk1[128].neuron_con_inst.LUT6_inst_0.INIT = 64'hb14b5228aaabdae0;
        defparam synapse_connection.synap_matrix.genblk1[128].neuron_con_inst.LUT6_inst_1.INIT = 64'hc52344129683360a;
        defparam synapse_connection.synap_matrix.genblk1[128].neuron_con_inst.LUT6_inst_2.INIT = 64'h02d3aa53aa4aa92a;
        defparam synapse_connection.synap_matrix.genblk1[128].neuron_con_inst.LUT6_inst_3.INIT = 64'h6aafacab9403b083;
        defparam synapse_connection.synap_matrix.genblk1[129].neuron_con_inst.LUT6_inst_0.INIT = 64'ha48a2aa92aaafacd;
        defparam synapse_connection.synap_matrix.genblk1[129].neuron_con_inst.LUT6_inst_1.INIT = 64'hb6b7b6b2a726a482;
        defparam synapse_connection.synap_matrix.genblk1[129].neuron_con_inst.LUT6_inst_2.INIT = 64'h802ba24ba2132756;
        defparam synapse_connection.synap_matrix.genblk1[129].neuron_con_inst.LUT6_inst_3.INIT = 64'ha7f89794929a0a2b;
        defparam synapse_connection.synap_matrix.genblk1[130].neuron_con_inst.LUT6_inst_0.INIT = 64'ha6aa88e92aaf76c3;
        defparam synapse_connection.synap_matrix.genblk1[130].neuron_con_inst.LUT6_inst_1.INIT = 64'h92d792178553952a;
        defparam synapse_connection.synap_matrix.genblk1[130].neuron_con_inst.LUT6_inst_2.INIT = 64'h2a4a8a4a8aca92d2;
        defparam synapse_connection.synap_matrix.genblk1[130].neuron_con_inst.LUT6_inst_3.INIT = 64'h2aa02aaaad5b9b4b;
        defparam synapse_connection.synap_matrix.genblk1[131].neuron_con_inst.LUT6_inst_0.INIT = 64'hab6b2b0b292fd5ba;
        defparam synapse_connection.synap_matrix.genblk1[131].neuron_con_inst.LUT6_inst_1.INIT = 64'hba4fba7eab6f2b2e;
        defparam synapse_connection.synap_matrix.genblk1[131].neuron_con_inst.LUT6_inst_2.INIT = 64'h053ab9aaa9ab2a8b;
        defparam synapse_connection.synap_matrix.genblk1[131].neuron_con_inst.LUT6_inst_3.INIT = 64'hdaa54a2925a8e02a;
        defparam synapse_connection.synap_matrix.genblk1[132].neuron_con_inst.LUT6_inst_0.INIT = 64'h8c8fa201aba199b2;
        defparam synapse_connection.synap_matrix.genblk1[132].neuron_con_inst.LUT6_inst_1.INIT = 64'h692aa1a285ae9dac;
        defparam synapse_connection.synap_matrix.genblk1[132].neuron_con_inst.LUT6_inst_2.INIT = 64'hcb4049554527eb2a;
        defparam synapse_connection.synap_matrix.genblk1[132].neuron_con_inst.LUT6_inst_3.INIT = 64'h0aae6aa33ad28a50;
        defparam synapse_connection.synap_matrix.genblk1[133].neuron_con_inst.LUT6_inst_0.INIT = 64'h942eb22368ae92b3;
        defparam synapse_connection.synap_matrix.genblk1[133].neuron_con_inst.LUT6_inst_1.INIT = 64'ha16b256ea96a052a;
        defparam synapse_connection.synap_matrix.genblk1[133].neuron_con_inst.LUT6_inst_2.INIT = 64'h80d682d28a7c292f;
        defparam synapse_connection.synap_matrix.genblk1[133].neuron_con_inst.LUT6_inst_3.INIT = 64'heaad6319214500d6;
        defparam synapse_connection.synap_matrix.genblk1[134].neuron_con_inst.LUT6_inst_0.INIT = 64'hb6979689a2ad2481;
        defparam synapse_connection.synap_matrix.genblk1[134].neuron_con_inst.LUT6_inst_1.INIT = 64'hb012ac98a4932696;
        defparam synapse_connection.synap_matrix.genblk1[134].neuron_con_inst.LUT6_inst_2.INIT = 64'h80aa28aaa8233526;
        defparam synapse_connection.synap_matrix.genblk1[134].neuron_con_inst.LUT6_inst_3.INIT = 64'heaada2a900aad0aa;
        defparam synapse_connection.synap_matrix.genblk1[135].neuron_con_inst.LUT6_inst_0.INIT = 64'h550a55ab34ab13d2;
        defparam synapse_connection.synap_matrix.genblk1[135].neuron_con_inst.LUT6_inst_1.INIT = 64'hf6d6d69356cad60b;
        defparam synapse_connection.synap_matrix.genblk1[135].neuron_con_inst.LUT6_inst_2.INIT = 64'h92d48896a81704d7;
        defparam synapse_connection.synap_matrix.genblk1[135].neuron_con_inst.LUT6_inst_3.INIT = 64'heaa7894f08571356;
        defparam synapse_connection.synap_matrix.genblk1[136].neuron_con_inst.LUT6_inst_0.INIT = 64'hea97c61655d1b40e;
        defparam synapse_connection.synap_matrix.genblk1[136].neuron_con_inst.LUT6_inst_1.INIT = 64'hd113802aa2a2aa93;
        defparam synapse_connection.synap_matrix.genblk1[136].neuron_con_inst.LUT6_inst_2.INIT = 64'ha11bed7bff731063;
        defparam synapse_connection.synap_matrix.genblk1[136].neuron_con_inst.LUT6_inst_3.INIT = 64'h0aab6aaa2aaa2a9b;
        defparam synapse_connection.synap_matrix.genblk1[137].neuron_con_inst.LUT6_inst_0.INIT = 64'haa552aa8aaafd9e4;
        defparam synapse_connection.synap_matrix.genblk1[137].neuron_con_inst.LUT6_inst_1.INIT = 64'hb0dcb49914d433d1;
        defparam synapse_connection.synap_matrix.genblk1[137].neuron_con_inst.LUT6_inst_2.INIT = 64'ha8abaa2ba96bb3f9;
        defparam synapse_connection.synap_matrix.genblk1[137].neuron_con_inst.LUT6_inst_3.INIT = 64'h1554e557ad52292b;
        defparam synapse_connection.synap_matrix.genblk1[138].neuron_con_inst.LUT6_inst_0.INIT = 64'h952a986a2aacb790;
        defparam synapse_connection.synap_matrix.genblk1[138].neuron_con_inst.LUT6_inst_1.INIT = 64'hca2f5b56c3574916;
        defparam synapse_connection.synap_matrix.genblk1[138].neuron_con_inst.LUT6_inst_2.INIT = 64'hb0ba885a895a4b6a;
        defparam synapse_connection.synap_matrix.genblk1[138].neuron_con_inst.LUT6_inst_3.INIT = 64'haaaeabeb354a3523;
        defparam synapse_connection.synap_matrix.genblk1[139].neuron_con_inst.LUT6_inst_0.INIT = 64'ha8a92aabaaa97ec3;
        defparam synapse_connection.synap_matrix.genblk1[139].neuron_con_inst.LUT6_inst_1.INIT = 64'hb4daa64aa36a992b;
        defparam synapse_connection.synap_matrix.genblk1[139].neuron_con_inst.LUT6_inst_2.INIT = 64'h8a2beb6b2f1e2dbb;
        defparam synapse_connection.synap_matrix.genblk1[139].neuron_con_inst.LUT6_inst_3.INIT = 64'h257a1d556a9baa2e;
        defparam synapse_connection.synap_matrix.genblk1[140].neuron_con_inst.LUT6_inst_0.INIT = 64'haa0a2b8beaa9765a;
        defparam synapse_connection.synap_matrix.genblk1[140].neuron_con_inst.LUT6_inst_1.INIT = 64'h86a6ae62ac4aa912;
        defparam synapse_connection.synap_matrix.genblk1[140].neuron_con_inst.LUT6_inst_2.INIT = 64'h316a88cb40cf6eee;
        defparam synapse_connection.synap_matrix.genblk1[140].neuron_con_inst.LUT6_inst_3.INIT = 64'haaa86ab9282a812b;
        defparam synapse_connection.synap_matrix.genblk1[141].neuron_con_inst.LUT6_inst_0.INIT = 64'h90a215a9a02a3c66;
        defparam synapse_connection.synap_matrix.genblk1[141].neuron_con_inst.LUT6_inst_1.INIT = 64'ha926992aa93f928e;
        defparam synapse_connection.synap_matrix.genblk1[141].neuron_con_inst.LUT6_inst_2.INIT = 64'h5912a9aba92b0909;
        defparam synapse_connection.synap_matrix.genblk1[141].neuron_con_inst.LUT6_inst_3.INIT = 64'h9aa42aa9b283c653;
        defparam synapse_connection.synap_matrix.genblk1[142].neuron_con_inst.LUT6_inst_0.INIT = 64'h2845a9436bc6d3c5;
        defparam synapse_connection.synap_matrix.genblk1[142].neuron_con_inst.LUT6_inst_1.INIT = 64'h682aa8aaa88aa8a9;
        defparam synapse_connection.synap_matrix.genblk1[142].neuron_con_inst.LUT6_inst_2.INIT = 64'hd4c750565055c946;
        defparam synapse_connection.synap_matrix.genblk1[142].neuron_con_inst.LUT6_inst_3.INIT = 64'hcaacaaabaaabd207;
        defparam synapse_connection.synap_matrix.genblk1[143].neuron_con_inst.LUT6_inst_0.INIT = 64'hb0aa2d5cab2cad88;
        defparam synapse_connection.synap_matrix.genblk1[143].neuron_con_inst.LUT6_inst_1.INIT = 64'ha803250a90ab36ab;
        defparam synapse_connection.synap_matrix.genblk1[143].neuron_con_inst.LUT6_inst_2.INIT = 64'ha9542c34a6ac3caa;
        defparam synapse_connection.synap_matrix.genblk1[143].neuron_con_inst.LUT6_inst_3.INIT = 64'h3aad2aa9aaaca85b;
        defparam synapse_connection.synap_matrix.genblk1[144].neuron_con_inst.LUT6_inst_0.INIT = 64'h548bd16bbaa83e92;
        defparam synapse_connection.synap_matrix.genblk1[144].neuron_con_inst.LUT6_inst_1.INIT = 64'hb042b0ca902b54a2;
        defparam synapse_connection.synap_matrix.genblk1[144].neuron_con_inst.LUT6_inst_2.INIT = 64'h2096a196a8d7a057;
        defparam synapse_connection.synap_matrix.genblk1[144].neuron_con_inst.LUT6_inst_3.INIT = 64'h0aaa8ac32a4b8053;
        defparam synapse_connection.synap_matrix.genblk1[145].neuron_con_inst.LUT6_inst_0.INIT = 64'h2ab22aab2aaca2b7;
        defparam synapse_connection.synap_matrix.genblk1[145].neuron_con_inst.LUT6_inst_1.INIT = 64'haa53d152d5bad2b3;
        defparam synapse_connection.synap_matrix.genblk1[145].neuron_con_inst.LUT6_inst_2.INIT = 64'h9a1a8942aa222a93;
        defparam synapse_connection.synap_matrix.genblk1[145].neuron_con_inst.LUT6_inst_3.INIT = 64'h0aaf4d2a800a12aa;
        defparam synapse_connection.synap_matrix.genblk1[146].neuron_con_inst.LUT6_inst_0.INIT = 64'haa07a9161d53303b;
        defparam synapse_connection.synap_matrix.genblk1[146].neuron_con_inst.LUT6_inst_1.INIT = 64'hd18390a28292aada;
        defparam synapse_connection.synap_matrix.genblk1[146].neuron_con_inst.LUT6_inst_2.INIT = 64'h8d6bad6b80621123;
        defparam synapse_connection.synap_matrix.genblk1[146].neuron_con_inst.LUT6_inst_3.INIT = 64'heaafaaa8aaa9a92a;
        defparam synapse_connection.synap_matrix.genblk1[147].neuron_con_inst.LUT6_inst_0.INIT = 64'h2a4c2aa9aaa04ea5;
        defparam synapse_connection.synap_matrix.genblk1[147].neuron_con_inst.LUT6_inst_1.INIT = 64'hb4959415361184a9;
        defparam synapse_connection.synap_matrix.genblk1[147].neuron_con_inst.LUT6_inst_2.INIT = 64'haa2ba22a22aa00a1;
        defparam synapse_connection.synap_matrix.genblk1[147].neuron_con_inst.LUT6_inst_3.INIT = 64'h714022562a9720c2;
        defparam synapse_connection.synap_matrix.genblk1[148].neuron_con_inst.LUT6_inst_0.INIT = 64'hf86a682a2aaf12f2;
        defparam synapse_connection.synap_matrix.genblk1[148].neuron_con_inst.LUT6_inst_1.INIT = 64'h812b1962905b448a;
        defparam synapse_connection.synap_matrix.genblk1[148].neuron_con_inst.LUT6_inst_2.INIT = 64'h12b29a92c2d350cb;
        defparam synapse_connection.synap_matrix.genblk1[148].neuron_con_inst.LUT6_inst_3.INIT = 64'hcaa82a9a083a3272;
        defparam synapse_connection.synap_matrix.genblk1[149].neuron_con_inst.LUT6_inst_0.INIT = 64'hab4aab29eaa98297;
        defparam synapse_connection.synap_matrix.genblk1[149].neuron_con_inst.LUT6_inst_1.INIT = 64'h9553974a926bdb4a;
        defparam synapse_connection.synap_matrix.genblk1[149].neuron_con_inst.LUT6_inst_2.INIT = 64'h22eb84c2a0c61052;
        defparam synapse_connection.synap_matrix.genblk1[149].neuron_con_inst.LUT6_inst_3.INIT = 64'hd63f905a48ba00ea;
        defparam synapse_connection.synap_matrix.genblk1[150].neuron_con_inst.LUT6_inst_0.INIT = 64'h80a8aaca2aabb2ed;
        defparam synapse_connection.synap_matrix.genblk1[150].neuron_con_inst.LUT6_inst_1.INIT = 64'h92860296955a954a;
        defparam synapse_connection.synap_matrix.genblk1[150].neuron_con_inst.LUT6_inst_2.INIT = 64'h896aa94ba0d30296;
        defparam synapse_connection.synap_matrix.genblk1[150].neuron_con_inst.LUT6_inst_3.INIT = 64'h0aacea2a25573643;
        defparam synapse_connection.synap_matrix.genblk1[151].neuron_con_inst.LUT6_inst_0.INIT = 64'h21a835a8a12d9902;
        defparam synapse_connection.synap_matrix.genblk1[151].neuron_con_inst.LUT6_inst_1.INIT = 64'h19b6899ead8725af;
        defparam synapse_connection.synap_matrix.genblk1[151].neuron_con_inst.LUT6_inst_2.INIT = 64'hd64bc22baaba88bb;
        defparam synapse_connection.synap_matrix.genblk1[151].neuron_con_inst.LUT6_inst_3.INIT = 64'h3a926aab6a18724f;
        defparam synapse_connection.synap_matrix.genblk1[152].neuron_con_inst.LUT6_inst_0.INIT = 64'ha8522c536a4cadbe;
        defparam synapse_connection.synap_matrix.genblk1[152].neuron_con_inst.LUT6_inst_1.INIT = 64'h5caaeeb2ac17281e;
        defparam synapse_connection.synap_matrix.genblk1[152].neuron_con_inst.LUT6_inst_2.INIT = 64'h544b585b5a58da2a;
        defparam synapse_connection.synap_matrix.genblk1[152].neuron_con_inst.LUT6_inst_3.INIT = 64'h2aab2caa76ab52e2;
        defparam synapse_connection.synap_matrix.genblk1[153].neuron_con_inst.LUT6_inst_0.INIT = 64'ha8cfaf462928f1ff;
        defparam synapse_connection.synap_matrix.genblk1[153].neuron_con_inst.LUT6_inst_1.INIT = 64'ha123252eb5a7a4e4;
        defparam synapse_connection.synap_matrix.genblk1[153].neuron_con_inst.LUT6_inst_2.INIT = 64'ha4c680c88a64212b;
        defparam synapse_connection.synap_matrix.genblk1[153].neuron_con_inst.LUT6_inst_3.INIT = 64'h2aaf6a552ad424d4;
        defparam synapse_connection.synap_matrix.genblk1[154].neuron_con_inst.LUT6_inst_0.INIT = 64'hda3ecb29aaaea4e0;
        defparam synapse_connection.synap_matrix.genblk1[154].neuron_con_inst.LUT6_inst_1.INIT = 64'ha87aae6aa26a826a;
        defparam synapse_connection.synap_matrix.genblk1[154].neuron_con_inst.LUT6_inst_2.INIT = 64'hab25b52295dbe89a;
        defparam synapse_connection.synap_matrix.genblk1[154].neuron_con_inst.LUT6_inst_3.INIT = 64'h6aacaaaaabcb20ab;
        defparam synapse_connection.synap_matrix.genblk1[155].neuron_con_inst.LUT6_inst_0.INIT = 64'h0512153ba0ae848e;
        defparam synapse_connection.synap_matrix.genblk1[155].neuron_con_inst.LUT6_inst_1.INIT = 64'hb562d12acabaaaf2;
        defparam synapse_connection.synap_matrix.genblk1[155].neuron_con_inst.LUT6_inst_2.INIT = 64'hdb53890692a682ab;
        defparam synapse_connection.synap_matrix.genblk1[155].neuron_con_inst.LUT6_inst_3.INIT = 64'h2aa9aaabe2aac04a;
        defparam synapse_connection.synap_matrix.genblk1[156].neuron_con_inst.LUT6_inst_0.INIT = 64'hd2ab308d15544828;
        defparam synapse_connection.synap_matrix.genblk1[156].neuron_con_inst.LUT6_inst_1.INIT = 64'h929692469a8a12ab;
        defparam synapse_connection.synap_matrix.genblk1[156].neuron_con_inst.LUT6_inst_2.INIT = 64'h844b815384520253;
        defparam synapse_connection.synap_matrix.genblk1[156].neuron_con_inst.LUT6_inst_3.INIT = 64'heaaceaa8aca8022a;
        defparam synapse_connection.synap_matrix.genblk1[157].neuron_con_inst.LUT6_inst_0.INIT = 64'haaa8baa96aa54cca;
        defparam synapse_connection.synap_matrix.genblk1[157].neuron_con_inst.LUT6_inst_1.INIT = 64'hb4a5a5cd1404254d;
        defparam synapse_connection.synap_matrix.genblk1[157].neuron_con_inst.LUT6_inst_2.INIT = 64'h2aabaa2f3ea7d684;
        defparam synapse_connection.synap_matrix.genblk1[157].neuron_con_inst.LUT6_inst_3.INIT = 64'h7505a9552a176a4f;
        defparam synapse_connection.synap_matrix.genblk1[158].neuron_con_inst.LUT6_inst_0.INIT = 64'h960aa1292eac1bab;
        defparam synapse_connection.synap_matrix.genblk1[158].neuron_con_inst.LUT6_inst_1.INIT = 64'hd12a550e948f16ab;
        defparam synapse_connection.synap_matrix.genblk1[158].neuron_con_inst.LUT6_inst_2.INIT = 64'h12cbaa42aa4a404a;
        defparam synapse_connection.synap_matrix.genblk1[158].neuron_con_inst.LUT6_inst_3.INIT = 64'h6aabaaa9b81630c2;
        defparam synapse_connection.synap_matrix.genblk1[159].neuron_con_inst.LUT6_inst_0.INIT = 64'hadabaaa9aaa8a6ce;
        defparam synapse_connection.synap_matrix.genblk1[159].neuron_con_inst.LUT6_inst_1.INIT = 64'hb517b1d69897ccab;
        defparam synapse_connection.synap_matrix.genblk1[159].neuron_con_inst.LUT6_inst_2.INIT = 64'h04aaa52aa9272116;
        defparam synapse_connection.synap_matrix.genblk1[159].neuron_con_inst.LUT6_inst_3.INIT = 64'h865ef40310a380ab;
        defparam synapse_connection.synap_matrix.genblk1[160].neuron_con_inst.LUT6_inst_0.INIT = 64'haaa1a06a2aad3ed0;
        defparam synapse_connection.synap_matrix.genblk1[160].neuron_con_inst.LUT6_inst_1.INIT = 64'hd2d2925a954a092a;
        defparam synapse_connection.synap_matrix.genblk1[160].neuron_con_inst.LUT6_inst_2.INIT = 64'h906b888a949386d6;
        defparam synapse_connection.synap_matrix.genblk1[160].neuron_con_inst.LUT6_inst_3.INIT = 64'h0aab6ae8aa038b02;
        defparam synapse_connection.synap_matrix.genblk1[161].neuron_con_inst.LUT6_inst_0.INIT = 64'h8a52b1082a2f9dc7;
        defparam synapse_connection.synap_matrix.genblk1[161].neuron_con_inst.LUT6_inst_1.INIT = 64'h3917a93ead379896;
        defparam synapse_connection.synap_matrix.genblk1[161].neuron_con_inst.LUT6_inst_2.INIT = 64'h533ad34bab23892a;
        defparam synapse_connection.synap_matrix.genblk1[161].neuron_con_inst.LUT6_inst_3.INIT = 64'h9aaaaba8f48a1497;
        defparam synapse_connection.synap_matrix.genblk1[162].neuron_con_inst.LUT6_inst_0.INIT = 64'h2893a9d42b4a7bfe;
        defparam synapse_connection.synap_matrix.genblk1[162].neuron_con_inst.LUT6_inst_1.INIT = 64'h622aa2aaa28aa929;
        defparam synapse_connection.synap_matrix.genblk1[162].neuron_con_inst.LUT6_inst_2.INIT = 64'hd432555345524142;
        defparam synapse_connection.synap_matrix.genblk1[162].neuron_con_inst.LUT6_inst_3.INIT = 64'h0aa76aab2aabda93;
        defparam synapse_connection.synap_matrix.genblk1[163].neuron_con_inst.LUT6_inst_0.INIT = 64'h8552a571a8e8d7e1;
        defparam synapse_connection.synap_matrix.genblk1[163].neuron_con_inst.LUT6_inst_1.INIT = 64'hb646b6949ac62a65;
        defparam synapse_connection.synap_matrix.genblk1[163].neuron_con_inst.LUT6_inst_2.INIT = 64'hb8b5949596143676;
        defparam synapse_connection.synap_matrix.genblk1[163].neuron_con_inst.LUT6_inst_3.INIT = 64'heaa8e4573c543d8d;
        defparam synapse_connection.synap_matrix.genblk1[164].neuron_con_inst.LUT6_inst_0.INIT = 64'h92c2f4ab2aac52f1;
        defparam synapse_connection.synap_matrix.genblk1[164].neuron_con_inst.LUT6_inst_1.INIT = 64'hb083acc2a68db696;
        defparam synapse_connection.synap_matrix.genblk1[164].neuron_con_inst.LUT6_inst_2.INIT = 64'ha420a19790b22097;
        defparam synapse_connection.synap_matrix.genblk1[164].neuron_con_inst.LUT6_inst_3.INIT = 64'heaa9282a062b1222;
        defparam synapse_connection.synap_matrix.genblk1[165].neuron_con_inst.LUT6_inst_0.INIT = 64'h553ad59bb4ab99b1;
        defparam synapse_connection.synap_matrix.genblk1[165].neuron_con_inst.LUT6_inst_1.INIT = 64'ha2b22ada6a42d10a;
        defparam synapse_connection.synap_matrix.genblk1[165].neuron_con_inst.LUT6_inst_2.INIT = 64'h48a1d0a212af122f;
        defparam synapse_connection.synap_matrix.genblk1[165].neuron_con_inst.LUT6_inst_3.INIT = 64'h0aa5c0595143514b;
        defparam synapse_connection.synap_matrix.genblk1[166].neuron_con_inst.LUT6_inst_0.INIT = 64'ha8d4a4540f544249;
        defparam synapse_connection.synap_matrix.genblk1[166].neuron_con_inst.LUT6_inst_1.INIT = 64'h58b392938286aa82;
        defparam synapse_connection.synap_matrix.genblk1[166].neuron_con_inst.LUT6_inst_2.INIT = 64'h8c6bc0739ae318f1;
        defparam synapse_connection.synap_matrix.genblk1[166].neuron_con_inst.LUT6_inst_3.INIT = 64'haaad2aabaaa8a92b;
        defparam synapse_connection.synap_matrix.genblk1[167].neuron_con_inst.LUT6_inst_0.INIT = 64'haaacaaa94aa8343e;
        defparam synapse_connection.synap_matrix.genblk1[167].neuron_con_inst.LUT6_inst_1.INIT = 64'ha4851751045582a5;
        defparam synapse_connection.synap_matrix.genblk1[167].neuron_con_inst.LUT6_inst_2.INIT = 64'ha88aa08b30aa1085;
        defparam synapse_connection.synap_matrix.genblk1[167].neuron_con_inst.LUT6_inst_3.INIT = 64'h5406f09f2086e08b;
        defparam synapse_connection.synap_matrix.genblk1[168].neuron_con_inst.LUT6_inst_0.INIT = 64'hc16b19c92aaa7cf5;
        defparam synapse_connection.synap_matrix.genblk1[168].neuron_con_inst.LUT6_inst_1.INIT = 64'h9d560b5e992a5102;
        defparam synapse_connection.synap_matrix.genblk1[168].neuron_con_inst.LUT6_inst_2.INIT = 64'h0b2a882ba4ab654a;
        defparam synapse_connection.synap_matrix.genblk1[168].neuron_con_inst.LUT6_inst_3.INIT = 64'h6aacabca9147a942;
        defparam synapse_connection.synap_matrix.genblk1[169].neuron_con_inst.LUT6_inst_0.INIT = 64'h26a9aaa8aaa4228e;
        defparam synapse_connection.synap_matrix.genblk1[169].neuron_con_inst.LUT6_inst_1.INIT = 64'hb4b7ba42a32aa58a;
        defparam synapse_connection.synap_matrix.genblk1[169].neuron_con_inst.LUT6_inst_2.INIT = 64'h4aaae81a2a5ba312;
        defparam synapse_connection.synap_matrix.genblk1[169].neuron_con_inst.LUT6_inst_3.INIT = 64'h215cd6140aaa1a2b;
        defparam synapse_connection.synap_matrix.genblk1[170].neuron_con_inst.LUT6_inst_0.INIT = 64'hb48922092aafbca7;
        defparam synapse_connection.synap_matrix.genblk1[170].neuron_con_inst.LUT6_inst_1.INIT = 64'hd283902aa1a28522;
        defparam synapse_connection.synap_matrix.genblk1[170].neuron_con_inst.LUT6_inst_2.INIT = 64'h014aa057a2976297;
        defparam synapse_connection.synap_matrix.genblk1[170].neuron_con_inst.LUT6_inst_3.INIT = 64'h6aaaaa28b92a832a;
        defparam synapse_connection.synap_matrix.genblk1[171].neuron_con_inst.LUT6_inst_0.INIT = 64'h96abb2ab2aa08fcb;
        defparam synapse_connection.synap_matrix.genblk1[171].neuron_con_inst.LUT6_inst_1.INIT = 64'h1baea1aea4afb6ae;
        defparam synapse_connection.synap_matrix.genblk1[171].neuron_con_inst.LUT6_inst_2.INIT = 64'h6aabeadaaa5b19aa;
        defparam synapse_connection.synap_matrix.genblk1[171].neuron_con_inst.LUT6_inst_3.INIT = 64'haabe6a8b68812aa3;
        defparam synapse_connection.synap_matrix.genblk1[172].neuron_con_inst.LUT6_inst_0.INIT = 64'ha958a9526a4359e6;
        defparam synapse_connection.synap_matrix.genblk1[172].neuron_con_inst.LUT6_inst_1.INIT = 64'haaabaeaea4a6ad87;
        defparam synapse_connection.synap_matrix.genblk1[172].neuron_con_inst.LUT6_inst_2.INIT = 64'hc15a4a0b2a8a2a0a;
        defparam synapse_connection.synap_matrix.genblk1[172].neuron_con_inst.LUT6_inst_3.INIT = 64'haaac61aa505b5048;
        defparam synapse_connection.synap_matrix.genblk1[173].neuron_con_inst.LUT6_inst_0.INIT = 64'ha956a555aae802e6;
        defparam synapse_connection.synap_matrix.genblk1[173].neuron_con_inst.LUT6_inst_1.INIT = 64'hb6b7b4b4b4b7a916;
        defparam synapse_connection.synap_matrix.genblk1[173].neuron_con_inst.LUT6_inst_2.INIT = 64'h91b495a494b49696;
        defparam synapse_connection.synap_matrix.genblk1[173].neuron_con_inst.LUT6_inst_3.INIT = 64'h8aac351532158091;
        defparam synapse_connection.synap_matrix.genblk1[174].neuron_con_inst.LUT6_inst_0.INIT = 64'hd52680ab2aa872e9;
        defparam synapse_connection.synap_matrix.genblk1[174].neuron_con_inst.LUT6_inst_1.INIT = 64'ha8d3a282aa8bb543;
        defparam synapse_connection.synap_matrix.genblk1[174].neuron_con_inst.LUT6_inst_2.INIT = 64'hb426a467a97fad57;
        defparam synapse_connection.synap_matrix.genblk1[174].neuron_con_inst.LUT6_inst_3.INIT = 64'heaac2808f55a34b2;
        defparam synapse_connection.synap_matrix.genblk1[175].neuron_con_inst.LUT6_inst_0.INIT = 64'h22ab07682ea31de1;
        defparam synapse_connection.synap_matrix.genblk1[175].neuron_con_inst.LUT6_inst_1.INIT = 64'ha96ad16ac26bcaea;
        defparam synapse_connection.synap_matrix.genblk1[175].neuron_con_inst.LUT6_inst_2.INIT = 64'h2b52a497a6a62026;
        defparam synapse_connection.synap_matrix.genblk1[175].neuron_con_inst.LUT6_inst_3.INIT = 64'hcaa9a8a86aaa2a43;
        defparam synapse_connection.synap_matrix.genblk1[176].neuron_con_inst.LUT6_inst_0.INIT = 64'ha02b25ab55713475;
        defparam synapse_connection.synap_matrix.genblk1[176].neuron_con_inst.LUT6_inst_1.INIT = 64'hb0caaa4baa6aa86a;
        defparam synapse_connection.synap_matrix.genblk1[176].neuron_con_inst.LUT6_inst_2.INIT = 64'hd2cb8acab1dab2ca;
        defparam synapse_connection.synap_matrix.genblk1[176].neuron_con_inst.LUT6_inst_3.INIT = 64'h2a8c2aa828a9006b;
        defparam synapse_connection.synap_matrix.genblk1[177].neuron_con_inst.LUT6_inst_0.INIT = 64'ha2892aaaaaaa7b8c;
        defparam synapse_connection.synap_matrix.genblk1[177].neuron_con_inst.LUT6_inst_1.INIT = 64'hb4a4b5252d04a5d9;
        defparam synapse_connection.synap_matrix.genblk1[177].neuron_con_inst.LUT6_inst_2.INIT = 64'haa0aa142a51716b5;
        defparam synapse_connection.synap_matrix.genblk1[177].neuron_con_inst.LUT6_inst_3.INIT = 64'h331574142ab228ab;
        defparam synapse_connection.synap_matrix.genblk1[178].neuron_con_inst.LUT6_inst_0.INIT = 64'ha18a566baeaf928a;
        defparam synapse_connection.synap_matrix.genblk1[178].neuron_con_inst.LUT6_inst_1.INIT = 64'h8bd227d7a7b63f9a;
        defparam synapse_connection.synap_matrix.genblk1[178].neuron_con_inst.LUT6_inst_2.INIT = 64'h33ebbdebe3eaeb2a;
        defparam synapse_connection.synap_matrix.genblk1[178].neuron_con_inst.LUT6_inst_3.INIT = 64'heaa86daab4ab33aa;
        defparam synapse_connection.synap_matrix.genblk1[179].neuron_con_inst.LUT6_inst_0.INIT = 64'hb94aaaabaaaed092;
        defparam synapse_connection.synap_matrix.genblk1[179].neuron_con_inst.LUT6_inst_1.INIT = 64'ha496b6569142914a;
        defparam synapse_connection.synap_matrix.genblk1[179].neuron_con_inst.LUT6_inst_2.INIT = 64'hc0aba123a8aaa88f;
        defparam synapse_connection.synap_matrix.genblk1[179].neuron_con_inst.LUT6_inst_3.INIT = 64'h4559d55010d2101a;
        defparam synapse_connection.synap_matrix.genblk1[180].neuron_con_inst.LUT6_inst_0.INIT = 64'hab62aa4a2aaab4a0;
        defparam synapse_connection.synap_matrix.genblk1[180].neuron_con_inst.LUT6_inst_1.INIT = 64'hd29312d2944ab84a;
        defparam synapse_connection.synap_matrix.genblk1[180].neuron_con_inst.LUT6_inst_2.INIT = 64'ha406a6c202921296;
        defparam synapse_connection.synap_matrix.genblk1[180].neuron_con_inst.LUT6_inst_3.INIT = 64'h4aaeaaab2c2aa4a2;
        defparam synapse_connection.synap_matrix.genblk1[181].neuron_con_inst.LUT6_inst_0.INIT = 64'h80a986a92aa34848;
        defparam synapse_connection.synap_matrix.genblk1[181].neuron_con_inst.LUT6_inst_1.INIT = 64'h99aea5aeacae36af;
        defparam synapse_connection.synap_matrix.genblk1[181].neuron_con_inst.LUT6_inst_2.INIT = 64'h6a0aea4aaa5b89aa;
        defparam synapse_connection.synap_matrix.genblk1[181].neuron_con_inst.LUT6_inst_3.INIT = 64'h8abbaa8aea432aa2;
        defparam synapse_connection.synap_matrix.genblk1[182].neuron_con_inst.LUT6_inst_0.INIT = 64'ha5572551ed411d9b;
        defparam synapse_connection.synap_matrix.genblk1[182].neuron_con_inst.LUT6_inst_1.INIT = 64'h58b3a8d6aa56a917;
        defparam synapse_connection.synap_matrix.genblk1[182].neuron_con_inst.LUT6_inst_2.INIT = 64'h545756d456d5dc97;
        defparam synapse_connection.synap_matrix.genblk1[182].neuron_con_inst.LUT6_inst_3.INIT = 64'h2aaa65aad5aed48f;
        defparam synapse_connection.synap_matrix.genblk1[183].neuron_con_inst.LUT6_inst_0.INIT = 64'ha496aa112aaa22e6;
        defparam synapse_connection.synap_matrix.genblk1[183].neuron_con_inst.LUT6_inst_1.INIT = 64'ha56a95299525ab37;
        defparam synapse_connection.synap_matrix.genblk1[183].neuron_con_inst.LUT6_inst_2.INIT = 64'h89b491b5859084ca;
        defparam synapse_connection.synap_matrix.genblk1[183].neuron_con_inst.LUT6_inst_3.INIT = 64'h2aae25203d8ca933;
        defparam synapse_connection.synap_matrix.genblk1[184].neuron_con_inst.LUT6_inst_0.INIT = 64'haca63da9aaad70d8;
        defparam synapse_connection.synap_matrix.genblk1[184].neuron_con_inst.LUT6_inst_1.INIT = 64'ha8c2a92ca8aeaca6;
        defparam synapse_connection.synap_matrix.genblk1[184].neuron_con_inst.LUT6_inst_2.INIT = 64'ha0a5a183a0c330dc;
        defparam synapse_connection.synap_matrix.genblk1[184].neuron_con_inst.LUT6_inst_3.INIT = 64'heaa8aaab44aa24ab;
        defparam synapse_connection.synap_matrix.genblk1[185].neuron_con_inst.LUT6_inst_0.INIT = 64'h522acaa9a6aa0a02;
        defparam synapse_connection.synap_matrix.genblk1[185].neuron_con_inst.LUT6_inst_1.INIT = 64'haa6ac86a516bd02b;
        defparam synapse_connection.synap_matrix.genblk1[185].neuron_con_inst.LUT6_inst_2.INIT = 64'ha802ac12aca22a0b;
        defparam synapse_connection.synap_matrix.genblk1[185].neuron_con_inst.LUT6_inst_3.INIT = 64'h8aafaae8284e2816;
        defparam synapse_connection.synap_matrix.genblk1[186].neuron_con_inst.LUT6_inst_0.INIT = 64'haa02ab440d57f447;
        defparam synapse_connection.synap_matrix.genblk1[186].neuron_con_inst.LUT6_inst_1.INIT = 64'h548294daa2c32a4a;
        defparam synapse_connection.synap_matrix.genblk1[186].neuron_con_inst.LUT6_inst_2.INIT = 64'h8122d92ac3839183;
        defparam synapse_connection.synap_matrix.genblk1[186].neuron_con_inst.LUT6_inst_3.INIT = 64'heaa1eaa8aaaa28ab;
        defparam synapse_connection.synap_matrix.genblk1[187].neuron_con_inst.LUT6_inst_0.INIT = 64'hac69baa96aa3399b;
        defparam synapse_connection.synap_matrix.genblk1[187].neuron_con_inst.LUT6_inst_1.INIT = 64'haaa4a8ada505b44d;
        defparam synapse_connection.synap_matrix.genblk1[187].neuron_con_inst.LUT6_inst_2.INIT = 64'h2b2aa92ba8aad680;
        defparam synapse_connection.synap_matrix.genblk1[187].neuron_con_inst.LUT6_inst_3.INIT = 64'hd5576b582b5aeb2a;
        defparam synapse_connection.synap_matrix.genblk1[188].neuron_con_inst.LUT6_inst_0.INIT = 64'h845a0f582ea88687;
        defparam synapse_connection.synap_matrix.genblk1[188].neuron_con_inst.LUT6_inst_1.INIT = 64'hd12655b69492745b;
        defparam synapse_connection.synap_matrix.genblk1[188].neuron_con_inst.LUT6_inst_2.INIT = 64'h0242aa52ab2b2b2a;
        defparam synapse_connection.synap_matrix.genblk1[188].neuron_con_inst.LUT6_inst_3.INIT = 64'h6aad2ad9b55b3052;
        defparam synapse_connection.synap_matrix.genblk1[189].neuron_con_inst.LUT6_inst_0.INIT = 64'h2b4aaaaaaaa5b79c;
        defparam synapse_connection.synap_matrix.genblk1[189].neuron_con_inst.LUT6_inst_1.INIT = 64'hac17a89aa8832b6a;
        defparam synapse_connection.synap_matrix.genblk1[189].neuron_con_inst.LUT6_inst_2.INIT = 64'hb8aee8cba85e289a;
        defparam synapse_connection.synap_matrix.genblk1[189].neuron_con_inst.LUT6_inst_3.INIT = 64'hc3991da8d82ad8a7;
        defparam synapse_connection.synap_matrix.genblk1[190].neuron_con_inst.LUT6_inst_0.INIT = 64'hbaa880192aaa68e3;
        defparam synapse_connection.synap_matrix.genblk1[190].neuron_con_inst.LUT6_inst_1.INIT = 64'h8a138433950214a3;
        defparam synapse_connection.synap_matrix.genblk1[190].neuron_con_inst.LUT6_inst_2.INIT = 64'h244a80d382d30ad6;
        defparam synapse_connection.synap_matrix.genblk1[190].neuron_con_inst.LUT6_inst_3.INIT = 64'h0aafeaa8260b146b;
        defparam synapse_connection.synap_matrix.genblk1[191].neuron_con_inst.LUT6_inst_0.INIT = 64'hab4b302b21295348;
        defparam synapse_connection.synap_matrix.genblk1[191].neuron_con_inst.LUT6_inst_1.INIT = 64'h2a9faa6eab5f2a4f;
        defparam synapse_connection.synap_matrix.genblk1[191].neuron_con_inst.LUT6_inst_2.INIT = 64'h152b99aba9aa2a88;
        defparam synapse_connection.synap_matrix.genblk1[191].neuron_con_inst.LUT6_inst_3.INIT = 64'h8ab52aa8b0ab4516;
        defparam synapse_connection.synap_matrix.genblk1[192].neuron_con_inst.LUT6_inst_0.INIT = 64'h998a2003caf6d71d;
        defparam synapse_connection.synap_matrix.genblk1[192].neuron_con_inst.LUT6_inst_1.INIT = 64'h2aaaa2a68006817e;
        defparam synapse_connection.synap_matrix.genblk1[192].neuron_con_inst.LUT6_inst_2.INIT = 64'hf15a6a4b2a0aaaaa;
        defparam synapse_connection.synap_matrix.genblk1[192].neuron_con_inst.LUT6_inst_3.INIT = 64'haaa865a9d512d554;
        defparam synapse_connection.synap_matrix.genblk1[193].neuron_con_inst.LUT6_inst_0.INIT = 64'ha947aa142aad9296;
        defparam synapse_connection.synap_matrix.genblk1[193].neuron_con_inst.LUT6_inst_1.INIT = 64'haa4f292a29a4aa84;
        defparam synapse_connection.synap_matrix.genblk1[193].neuron_con_inst.LUT6_inst_2.INIT = 64'h98ab90a990a9885a;
        defparam synapse_connection.synap_matrix.genblk1[193].neuron_con_inst.LUT6_inst_3.INIT = 64'h2aab2084b255b805;
        defparam synapse_connection.synap_matrix.genblk1[194].neuron_con_inst.LUT6_inst_0.INIT = 64'h8aaae28aaaa81c84;
        defparam synapse_connection.synap_matrix.genblk1[194].neuron_con_inst.LUT6_inst_1.INIT = 64'hd456a052aa81aaaa;
        defparam synapse_connection.synap_matrix.genblk1[194].neuron_con_inst.LUT6_inst_2.INIT = 64'h2aa9a15b957395da;
        defparam synapse_connection.synap_matrix.genblk1[194].neuron_con_inst.LUT6_inst_3.INIT = 64'h6aa862aab2ab22ab;
        defparam synapse_connection.synap_matrix.genblk1[195].neuron_con_inst.LUT6_inst_0.INIT = 64'h544ad44a22a935d5;
        defparam synapse_connection.synap_matrix.genblk1[195].neuron_con_inst.LUT6_inst_1.INIT = 64'ha043d4dacadaaada;
        defparam synapse_connection.synap_matrix.genblk1[195].neuron_con_inst.LUT6_inst_2.INIT = 64'hf241a2a282aa824a;
        defparam synapse_connection.synap_matrix.genblk1[195].neuron_con_inst.LUT6_inst_3.INIT = 64'heaa39a2598aab88b;
        defparam synapse_connection.synap_matrix.genblk1[196].neuron_con_inst.LUT6_inst_0.INIT = 64'ha8a9a4a915b06e0b;
        defparam synapse_connection.synap_matrix.genblk1[196].neuron_con_inst.LUT6_inst_1.INIT = 64'ha26baa6bab2b292a;
        defparam synapse_connection.synap_matrix.genblk1[196].neuron_con_inst.LUT6_inst_2.INIT = 64'h286aa04ba06bb66b;
        defparam synapse_connection.synap_matrix.genblk1[196].neuron_con_inst.LUT6_inst_3.INIT = 64'hc2a8eaaaaaa8202a;
        defparam synapse_connection.synap_matrix.genblk1[197].neuron_con_inst.LUT6_inst_0.INIT = 64'h22813aa96aadcd9d;
        defparam synapse_connection.synap_matrix.genblk1[197].neuron_con_inst.LUT6_inst_1.INIT = 64'hb49512913528a149;
        defparam synapse_connection.synap_matrix.genblk1[197].neuron_con_inst.LUT6_inst_2.INIT = 64'haaaba95ba552d495;
        defparam synapse_connection.synap_matrix.genblk1[197].neuron_con_inst.LUT6_inst_3.INIT = 64'h73537565aaa22aab;
        defparam synapse_connection.synap_matrix.genblk1[198].neuron_con_inst.LUT6_inst_0.INIT = 64'hacab82d8aaacdcb3;
        defparam synapse_connection.synap_matrix.genblk1[198].neuron_con_inst.LUT6_inst_1.INIT = 64'he52355069492348b;
        defparam synapse_connection.synap_matrix.genblk1[198].neuron_con_inst.LUT6_inst_2.INIT = 64'h9a42a1528952456a;
        defparam synapse_connection.synap_matrix.genblk1[198].neuron_con_inst.LUT6_inst_3.INIT = 64'h6aa8ae7ab22ab203;
        defparam synapse_connection.synap_matrix.genblk1[199].neuron_con_inst.LUT6_inst_0.INIT = 64'ha9aaaaab2aaa98ca;
        defparam synapse_connection.synap_matrix.genblk1[199].neuron_con_inst.LUT6_inst_1.INIT = 64'hb1579152a32ba12a;
        defparam synapse_connection.synap_matrix.genblk1[199].neuron_con_inst.LUT6_inst_2.INIT = 64'h78aba92bac83ac97;
        defparam synapse_connection.synap_matrix.genblk1[199].neuron_con_inst.LUT6_inst_3.INIT = 64'h757a541596ab182a;
        defparam synapse_connection.synap_matrix.genblk1[200].neuron_con_inst.LUT6_inst_0.INIT = 64'ha4ab80ab2aaaa29e;
        defparam synapse_connection.synap_matrix.genblk1[200].neuron_con_inst.LUT6_inst_1.INIT = 64'h9a72927294738c0a;
        defparam synapse_connection.synap_matrix.genblk1[200].neuron_con_inst.LUT6_inst_2.INIT = 64'h2ad398d28ab38ae2;
        defparam synapse_connection.synap_matrix.genblk1[200].neuron_con_inst.LUT6_inst_3.INIT = 64'h8aae6aabaad2aadb;
        defparam synapse_connection.synap_matrix.genblk1[201].neuron_con_inst.LUT6_inst_0.INIT = 64'h942aa489a1a815b1;
        defparam synapse_connection.synap_matrix.genblk1[201].neuron_con_inst.LUT6_inst_1.INIT = 64'ha22f806ab523152a;
        defparam synapse_connection.synap_matrix.genblk1[201].neuron_con_inst.LUT6_inst_2.INIT = 64'ha113a9aba92aaa2a;
        defparam synapse_connection.synap_matrix.genblk1[201].neuron_con_inst.LUT6_inst_3.INIT = 64'h9aa16a9a22536316;
        defparam synapse_connection.synap_matrix.genblk1[202].neuron_con_inst.LUT6_inst_0.INIT = 64'hb6baa26b2aa01ba1;
        defparam synapse_connection.synap_matrix.genblk1[202].neuron_con_inst.LUT6_inst_1.INIT = 64'h286ba122852f35a8;
        defparam synapse_connection.synap_matrix.genblk1[202].neuron_con_inst.LUT6_inst_2.INIT = 64'h69554d450107e36a;
        defparam synapse_connection.synap_matrix.genblk1[202].neuron_con_inst.LUT6_inst_3.INIT = 64'h6aaeeaa34a520b51;
        defparam synapse_connection.synap_matrix.genblk1[203].neuron_con_inst.LUT6_inst_0.INIT = 64'ha40b28466a28a430;
        defparam synapse_connection.synap_matrix.genblk1[203].neuron_con_inst.LUT6_inst_1.INIT = 64'ha926b4ae26a8348b;
        defparam synapse_connection.synap_matrix.genblk1[203].neuron_con_inst.LUT6_inst_2.INIT = 64'ha824a8a4acacaa0f;
        defparam synapse_connection.synap_matrix.genblk1[203].neuron_con_inst.LUT6_inst_3.INIT = 64'h8aabea972a54a812;
        defparam synapse_connection.synap_matrix.genblk1[204].neuron_con_inst.LUT6_inst_0.INIT = 64'hc95211282baf4dd7;
        defparam synapse_connection.synap_matrix.genblk1[204].neuron_con_inst.LUT6_inst_1.INIT = 64'ha54ea8a2aa90ea52;
        defparam synapse_connection.synap_matrix.genblk1[204].neuron_con_inst.LUT6_inst_2.INIT = 64'hb2699146d5261552;
        defparam synapse_connection.synap_matrix.genblk1[204].neuron_con_inst.LUT6_inst_3.INIT = 64'h4aaf0aa934abb0a3;
        defparam synapse_connection.synap_matrix.genblk1[205].neuron_con_inst.LUT6_inst_0.INIT = 64'h49c95b2ba8abc89e;
        defparam synapse_connection.synap_matrix.genblk1[205].neuron_con_inst.LUT6_inst_1.INIT = 64'ha962ed4a6d838d92;
        defparam synapse_connection.synap_matrix.genblk1[205].neuron_con_inst.LUT6_inst_2.INIT = 64'h14c9c2c3ae6aab02;
        defparam synapse_connection.synap_matrix.genblk1[205].neuron_con_inst.LUT6_inst_3.INIT = 64'h8aa8472c474b664a;
        defparam synapse_connection.synap_matrix.genblk1[206].neuron_con_inst.LUT6_inst_0.INIT = 64'haa462b470955ea61;
        defparam synapse_connection.synap_matrix.genblk1[206].neuron_con_inst.LUT6_inst_1.INIT = 64'h5592948282872acf;
        defparam synapse_connection.synap_matrix.genblk1[206].neuron_con_inst.LUT6_inst_2.INIT = 64'h41269b0ac203c182;
        defparam synapse_connection.synap_matrix.genblk1[206].neuron_con_inst.LUT6_inst_3.INIT = 64'heaa7eaa82aa928aa;
        defparam synapse_connection.synap_matrix.genblk1[207].neuron_con_inst.LUT6_inst_0.INIT = 64'hab992aabaaaaf6a9;
        defparam synapse_connection.synap_matrix.genblk1[207].neuron_con_inst.LUT6_inst_1.INIT = 64'h84a4a50521e5a955;
        defparam synapse_connection.synap_matrix.genblk1[207].neuron_con_inst.LUT6_inst_2.INIT = 64'h3a4b99569096d6b4;
        defparam synapse_connection.synap_matrix.genblk1[207].neuron_con_inst.LUT6_inst_3.INIT = 64'hb1b4a40028b2fa22;
        defparam synapse_connection.synap_matrix.genblk1[208].neuron_con_inst.LUT6_inst_0.INIT = 64'ha34ac8aaaeab89b8;
        defparam synapse_connection.synap_matrix.genblk1[208].neuron_con_inst.LUT6_inst_1.INIT = 64'haa5710d6e8c626ff;
        defparam synapse_connection.synap_matrix.genblk1[208].neuron_con_inst.LUT6_inst_2.INIT = 64'ha46aa56be92a6822;
        defparam synapse_connection.synap_matrix.genblk1[208].neuron_con_inst.LUT6_inst_3.INIT = 64'h8aad6f2b152b182a;
        defparam synapse_connection.synap_matrix.genblk1[209].neuron_con_inst.LUT6_inst_0.INIT = 64'ha4aa2aaaaaaa9fa5;
        defparam synapse_connection.synap_matrix.genblk1[209].neuron_con_inst.LUT6_inst_1.INIT = 64'had0bad4ab96b91ab;
        defparam synapse_connection.synap_matrix.genblk1[209].neuron_con_inst.LUT6_inst_2.INIT = 64'h0a2a8baa88aaab4e;
        defparam synapse_connection.synap_matrix.genblk1[209].neuron_con_inst.LUT6_inst_3.INIT = 64'hef4fde1c8abb0a4b;
        defparam synapse_connection.synap_matrix.genblk1[210].neuron_con_inst.LUT6_inst_0.INIT = 64'ha9522a0baaab1c49;
        defparam synapse_connection.synap_matrix.genblk1[210].neuron_con_inst.LUT6_inst_1.INIT = 64'hcaa20e8abe432903;
        defparam synapse_connection.synap_matrix.genblk1[210].neuron_con_inst.LUT6_inst_2.INIT = 64'h906a9263daf6caa7;
        defparam synapse_connection.synap_matrix.genblk1[210].neuron_con_inst.LUT6_inst_3.INIT = 64'heaa7aaa9a92c012f;
        defparam synapse_connection.synap_matrix.genblk1[211].neuron_con_inst.LUT6_inst_0.INIT = 64'h2829ae6aa9291db5;
        defparam synapse_connection.synap_matrix.genblk1[211].neuron_con_inst.LUT6_inst_1.INIT = 64'h1b2e3b2aab2baa2a;
        defparam synapse_connection.synap_matrix.genblk1[211].neuron_con_inst.LUT6_inst_2.INIT = 64'he22af229aa3bba29;
        defparam synapse_connection.synap_matrix.genblk1[211].neuron_con_inst.LUT6_inst_3.INIT = 64'h5abc6a28ecaa282a;
        defparam synapse_connection.synap_matrix.genblk1[212].neuron_con_inst.LUT6_inst_0.INIT = 64'h20a7a1516a093be9;
        defparam synapse_connection.synap_matrix.genblk1[212].neuron_con_inst.LUT6_inst_1.INIT = 64'h622aa2aab0aea8a4;
        defparam synapse_connection.synap_matrix.genblk1[212].neuron_con_inst.LUT6_inst_2.INIT = 64'h50b355964453c143;
        defparam synapse_connection.synap_matrix.genblk1[212].neuron_con_inst.LUT6_inst_3.INIT = 64'hea876aaa2aaf4a84;
        defparam synapse_connection.synap_matrix.genblk1[213].neuron_con_inst.LUT6_inst_0.INIT = 64'ha8562916aae8e7ae;
        defparam synapse_connection.synap_matrix.genblk1[213].neuron_con_inst.LUT6_inst_1.INIT = 64'h2a432b6ea926a8ac;
        defparam synapse_connection.synap_matrix.genblk1[213].neuron_con_inst.LUT6_inst_2.INIT = 64'h920a92b894a990ab;
        defparam synapse_connection.synap_matrix.genblk1[213].neuron_con_inst.LUT6_inst_3.INIT = 64'h6aab61382088ba4c;
        defparam synapse_connection.synap_matrix.genblk1[214].neuron_con_inst.LUT6_inst_0.INIT = 64'ha28252abaaad48b0;
        defparam synapse_connection.synap_matrix.genblk1[214].neuron_con_inst.LUT6_inst_1.INIT = 64'hc157954294a290a2;
        defparam synapse_connection.synap_matrix.genblk1[214].neuron_con_inst.LUT6_inst_2.INIT = 64'ha8a28156a9568817;
        defparam synapse_connection.synap_matrix.genblk1[214].neuron_con_inst.LUT6_inst_3.INIT = 64'h6aa88a802aaaa2ab;
        defparam synapse_connection.synap_matrix.genblk1[215].neuron_con_inst.LUT6_inst_0.INIT = 64'h4aabaaa92aa744db;
        defparam synapse_connection.synap_matrix.genblk1[215].neuron_con_inst.LUT6_inst_1.INIT = 64'haa12c862d56ad4aa;
        defparam synapse_connection.synap_matrix.genblk1[215].neuron_con_inst.LUT6_inst_2.INIT = 64'ha893a812a842aa43;
        defparam synapse_connection.synap_matrix.genblk1[215].neuron_con_inst.LUT6_inst_3.INIT = 64'h0aaa62a8ba8eaabb;
        defparam synapse_connection.synap_matrix.genblk1[216].neuron_con_inst.LUT6_inst_0.INIT = 64'h9514d555d1597278;
        defparam synapse_connection.synap_matrix.genblk1[216].neuron_con_inst.LUT6_inst_1.INIT = 64'hc662b22fa2a7aad7;
        defparam synapse_connection.synap_matrix.genblk1[216].neuron_con_inst.LUT6_inst_2.INIT = 64'h355ae452d6820603;
        defparam synapse_connection.synap_matrix.genblk1[216].neuron_con_inst.LUT6_inst_3.INIT = 64'haaa7eaabae2ba44a;
        defparam synapse_connection.synap_matrix.genblk1[217].neuron_con_inst.LUT6_inst_0.INIT = 64'h2855baa82aabbee8;
        defparam synapse_connection.synap_matrix.genblk1[217].neuron_con_inst.LUT6_inst_1.INIT = 64'ha8a8a8a92555bd51;
        defparam synapse_connection.synap_matrix.genblk1[217].neuron_con_inst.LUT6_inst_2.INIT = 64'ha82aa82b2903b0a8;
        defparam synapse_connection.synap_matrix.genblk1[217].neuron_con_inst.LUT6_inst_3.INIT = 64'hfc416d452a33ea8b;
        defparam synapse_connection.synap_matrix.genblk1[218].neuron_con_inst.LUT6_inst_0.INIT = 64'hd4a945abaeaf6c06;
        defparam synapse_connection.synap_matrix.genblk1[218].neuron_con_inst.LUT6_inst_1.INIT = 64'ha92f276ab26b6a6a;
        defparam synapse_connection.synap_matrix.genblk1[218].neuron_con_inst.LUT6_inst_2.INIT = 64'ha88ba0cba80aab29;
        defparam synapse_connection.synap_matrix.genblk1[218].neuron_con_inst.LUT6_inst_3.INIT = 64'h2aabaa6a2a4bea8a;
        defparam synapse_connection.synap_matrix.genblk1[219].neuron_con_inst.LUT6_inst_0.INIT = 64'hb24b2aa9aaa7b2dd;
        defparam synapse_connection.synap_matrix.genblk1[219].neuron_con_inst.LUT6_inst_1.INIT = 64'ha496a456a45ba60a;
        defparam synapse_connection.synap_matrix.genblk1[219].neuron_con_inst.LUT6_inst_2.INIT = 64'h6a2ba12aac222484;
        defparam synapse_connection.synap_matrix.genblk1[219].neuron_con_inst.LUT6_inst_3.INIT = 64'ha55ad515030a2a0a;
        defparam synapse_connection.synap_matrix.genblk1[220].neuron_con_inst.LUT6_inst_0.INIT = 64'ha308a068a8a9a807;
        defparam synapse_connection.synap_matrix.genblk1[220].neuron_con_inst.LUT6_inst_1.INIT = 64'hdaa34a8a92e38403;
        defparam synapse_connection.synap_matrix.genblk1[220].neuron_con_inst.LUT6_inst_2.INIT = 64'h06d682a69aa70ab6;
        defparam synapse_connection.synap_matrix.genblk1[220].neuron_con_inst.LUT6_inst_3.INIT = 64'h0aaf2aa9216ea87e;
        defparam synapse_connection.synap_matrix.genblk1[221].neuron_con_inst.LUT6_inst_0.INIT = 64'h90219118a22ae6b2;
        defparam synapse_connection.synap_matrix.genblk1[221].neuron_con_inst.LUT6_inst_1.INIT = 64'hab36ad6abc0a18b7;
        defparam synapse_connection.synap_matrix.genblk1[221].neuron_con_inst.LUT6_inst_2.INIT = 64'hd543e96bab0a2a2b;
        defparam synapse_connection.synap_matrix.genblk1[221].neuron_con_inst.LUT6_inst_3.INIT = 64'hfaafeba9b08b1532;
        defparam synapse_connection.synap_matrix.genblk1[222].neuron_con_inst.LUT6_inst_0.INIT = 64'ha523a521a18d3bcd;
        defparam synapse_connection.synap_matrix.genblk1[222].neuron_con_inst.LUT6_inst_1.INIT = 64'h686ab2aaa96aa14e;
        defparam synapse_connection.synap_matrix.genblk1[222].neuron_con_inst.LUT6_inst_2.INIT = 64'hc9354d614d6fc16b;
        defparam synapse_connection.synap_matrix.genblk1[222].neuron_con_inst.LUT6_inst_3.INIT = 64'haaa92ba0cb53c9ce;
        defparam synapse_connection.synap_matrix.genblk1[223].neuron_con_inst.LUT6_inst_0.INIT = 64'ha04eaaacaaab081a;
        defparam synapse_connection.synap_matrix.genblk1[223].neuron_con_inst.LUT6_inst_1.INIT = 64'haa2ab2acb490ab57;
        defparam synapse_connection.synap_matrix.genblk1[223].neuron_con_inst.LUT6_inst_2.INIT = 64'ha4aca8ada948ab4b;
        defparam synapse_connection.synap_matrix.genblk1[223].neuron_con_inst.LUT6_inst_3.INIT = 64'haaa9a856a955a0b4;
        defparam synapse_connection.synap_matrix.genblk1[224].neuron_con_inst.LUT6_inst_0.INIT = 64'h9af69e99aaaa5ee6;
        defparam synapse_connection.synap_matrix.genblk1[224].neuron_con_inst.LUT6_inst_1.INIT = 64'hb3d3a0dab2ea9a66;
        defparam synapse_connection.synap_matrix.genblk1[224].neuron_con_inst.LUT6_inst_2.INIT = 64'haa2aaa2aa9031516;
        defparam synapse_connection.synap_matrix.genblk1[224].neuron_con_inst.LUT6_inst_3.INIT = 64'h8aaeeaaa4e130eab;
        defparam synapse_connection.synap_matrix.genblk1[225].neuron_con_inst.LUT6_inst_0.INIT = 64'h4a53c2c1aeab6094;
        defparam synapse_connection.synap_matrix.genblk1[225].neuron_con_inst.LUT6_inst_1.INIT = 64'heb56cb43c90acb42;
        defparam synapse_connection.synap_matrix.genblk1[225].neuron_con_inst.LUT6_inst_2.INIT = 64'hd56180aea0af2262;
        defparam synapse_connection.synap_matrix.genblk1[225].neuron_con_inst.LUT6_inst_3.INIT = 64'hcaa5172d550f41a3;
        defparam synapse_connection.synap_matrix.genblk1[226].neuron_con_inst.LUT6_inst_0.INIT = 64'hd517155555501621;
        defparam synapse_connection.synap_matrix.genblk1[226].neuron_con_inst.LUT6_inst_1.INIT = 64'h89438006aa87aa97;
        defparam synapse_connection.synap_matrix.genblk1[226].neuron_con_inst.LUT6_inst_2.INIT = 64'h3553c48381a3992a;
        defparam synapse_connection.synap_matrix.genblk1[226].neuron_con_inst.LUT6_inst_3.INIT = 64'h8ab16aaba3aba15a;
        defparam synapse_connection.synap_matrix.genblk1[227].neuron_con_inst.LUT6_inst_0.INIT = 64'ha0a1aaaaaaa9b0f0;
        defparam synapse_connection.synap_matrix.genblk1[227].neuron_con_inst.LUT6_inst_1.INIT = 64'hadacb96d2564a121;
        defparam synapse_connection.synap_matrix.genblk1[227].neuron_con_inst.LUT6_inst_2.INIT = 64'h294fb5ae94b704a1;
        defparam synapse_connection.synap_matrix.genblk1[227].neuron_con_inst.LUT6_inst_3.INIT = 64'h7937f8adaa97a856;
        defparam synapse_connection.synap_matrix.genblk1[228].neuron_con_inst.LUT6_inst_0.INIT = 64'hb05b4a99aaa9869a;
        defparam synapse_connection.synap_matrix.genblk1[228].neuron_con_inst.LUT6_inst_1.INIT = 64'heb424a56a2562a43;
        defparam synapse_connection.synap_matrix.genblk1[228].neuron_con_inst.LUT6_inst_2.INIT = 64'h00aa80ab8542255b;
        defparam synapse_connection.synap_matrix.genblk1[228].neuron_con_inst.LUT6_inst_3.INIT = 64'heaaa6d6b1d4b2922;
        defparam synapse_connection.synap_matrix.genblk1[229].neuron_con_inst.LUT6_inst_0.INIT = 64'ha80b2aa9aaaea4c1;
        defparam synapse_connection.synap_matrix.genblk1[229].neuron_con_inst.LUT6_inst_1.INIT = 64'ha497a4d6bd56a52a;
        defparam synapse_connection.synap_matrix.genblk1[229].neuron_con_inst.LUT6_inst_2.INIT = 64'h28a2e6aa28ab20ae;
        defparam synapse_connection.synap_matrix.genblk1[229].neuron_con_inst.LUT6_inst_3.INIT = 64'h2559155614bba40b;
        defparam synapse_connection.synap_matrix.genblk1[230].neuron_con_inst.LUT6_inst_0.INIT = 64'hb40a29a8aaa92a3e;
        defparam synapse_connection.synap_matrix.genblk1[230].neuron_con_inst.LUT6_inst_1.INIT = 64'h9a9a128292a316a3;
        defparam synapse_connection.synap_matrix.genblk1[230].neuron_con_inst.LUT6_inst_2.INIT = 64'ha08ba6b392939282;
        defparam synapse_connection.synap_matrix.genblk1[230].neuron_con_inst.LUT6_inst_3.INIT = 64'h0aa96aabab63aad3;
        defparam synapse_connection.synap_matrix.genblk1[231].neuron_con_inst.LUT6_inst_0.INIT = 64'h82aaba992aa91183;
        defparam synapse_connection.synap_matrix.genblk1[231].neuron_con_inst.LUT6_inst_1.INIT = 64'h0d16992ea12b30af;
        defparam synapse_connection.synap_matrix.genblk1[231].neuron_con_inst.LUT6_inst_2.INIT = 64'he8abeb0aab2b094a;
        defparam synapse_connection.synap_matrix.genblk1[231].neuron_con_inst.LUT6_inst_3.INIT = 64'hcaae6aba64522496;
        defparam synapse_connection.synap_matrix.genblk1[232].neuron_con_inst.LUT6_inst_0.INIT = 64'hb4ab65506a53cfef;
        defparam synapse_connection.synap_matrix.genblk1[232].neuron_con_inst.LUT6_inst_1.INIT = 64'h422a92aa82aae429;
        defparam synapse_connection.synap_matrix.genblk1[232].neuron_con_inst.LUT6_inst_2.INIT = 64'hb0926ad268535242;
        defparam synapse_connection.synap_matrix.genblk1[232].neuron_con_inst.LUT6_inst_3.INIT = 64'hcaadaaab16a2d494;
        defparam synapse_connection.synap_matrix.genblk1[233].neuron_con_inst.LUT6_inst_0.INIT = 64'h968ba4b7a8295c81;
        defparam synapse_connection.synap_matrix.genblk1[233].neuron_con_inst.LUT6_inst_1.INIT = 64'h25aba4a49697b65a;
        defparam synapse_connection.synap_matrix.genblk1[233].neuron_con_inst.LUT6_inst_2.INIT = 64'hac94a424a2042822;
        defparam synapse_connection.synap_matrix.genblk1[233].neuron_con_inst.LUT6_inst_3.INIT = 64'h2aa8235628b4a823;
        defparam synapse_connection.synap_matrix.genblk1[234].neuron_con_inst.LUT6_inst_0.INIT = 64'ha2ab00a82aabcca8;
        defparam synapse_connection.synap_matrix.genblk1[234].neuron_con_inst.LUT6_inst_1.INIT = 64'hb157f14a90aa92a2;
        defparam synapse_connection.synap_matrix.genblk1[234].neuron_con_inst.LUT6_inst_2.INIT = 64'ha816a116a4961057;
        defparam synapse_connection.synap_matrix.genblk1[234].neuron_con_inst.LUT6_inst_3.INIT = 64'heaaae8b2288aaaaa;
        defparam synapse_connection.synap_matrix.genblk1[235].neuron_con_inst.LUT6_inst_0.INIT = 64'h54c2d8d9b2af1c9a;
        defparam synapse_connection.synap_matrix.genblk1[235].neuron_con_inst.LUT6_inst_1.INIT = 64'ha2d2aac26ad2d04b;
        defparam synapse_connection.synap_matrix.genblk1[235].neuron_con_inst.LUT6_inst_2.INIT = 64'h84a9d2aa1a0b820b;
        defparam synapse_connection.synap_matrix.genblk1[235].neuron_con_inst.LUT6_inst_3.INIT = 64'h2aa3154cb5639007;
        defparam synapse_connection.synap_matrix.genblk1[236].neuron_con_inst.LUT6_inst_0.INIT = 64'hc2a95042d5549c38;
        defparam synapse_connection.synap_matrix.genblk1[236].neuron_con_inst.LUT6_inst_1.INIT = 64'hdb5aabcaab2aab2b;
        defparam synapse_connection.synap_matrix.genblk1[236].neuron_con_inst.LUT6_inst_2.INIT = 64'h314bda0acb5b535b;
        defparam synapse_connection.synap_matrix.genblk1[236].neuron_con_inst.LUT6_inst_3.INIT = 64'h4aaa6aaba6a9330b;
        defparam synapse_connection.synap_matrix.genblk1[237].neuron_con_inst.LUT6_inst_0.INIT = 64'haa612aa86aa8ac68;
        defparam synapse_connection.synap_matrix.genblk1[237].neuron_con_inst.LUT6_inst_1.INIT = 64'h829524d534a91149;
        defparam synapse_connection.synap_matrix.genblk1[237].neuron_con_inst.LUT6_inst_2.INIT = 64'h22ebb26b2aa302a1;
        defparam synapse_connection.synap_matrix.genblk1[237].neuron_con_inst.LUT6_inst_3.INIT = 64'h55443b452ad322c3;
        defparam synapse_connection.synap_matrix.genblk1[238].neuron_con_inst.LUT6_inst_0.INIT = 64'h8b2babe92aaf6893;
        defparam synapse_connection.synap_matrix.genblk1[238].neuron_con_inst.LUT6_inst_1.INIT = 64'h835a515ed3574a2e;
        defparam synapse_connection.synap_matrix.genblk1[238].neuron_con_inst.LUT6_inst_2.INIT = 64'hb81aa34ae962a96b;
        defparam synapse_connection.synap_matrix.genblk1[238].neuron_con_inst.LUT6_inst_3.INIT = 64'h0aa9e9ab8d2a382a;
        defparam synapse_connection.synap_matrix.genblk1[239].neuron_con_inst.LUT6_inst_0.INIT = 64'ha94a2b282aab41bb;
        defparam synapse_connection.synap_matrix.genblk1[239].neuron_con_inst.LUT6_inst_1.INIT = 64'h9166b126a923e92a;
        defparam synapse_connection.synap_matrix.genblk1[239].neuron_con_inst.LUT6_inst_2.INIT = 64'h88eb8852845f9542;
        defparam synapse_connection.synap_matrix.genblk1[239].neuron_con_inst.LUT6_inst_3.INIT = 64'h46eafaa982b208ea;
        defparam synapse_connection.synap_matrix.genblk1[240].neuron_con_inst.LUT6_inst_0.INIT = 64'h9d430d682aa94886;
        defparam synapse_connection.synap_matrix.genblk1[240].neuron_con_inst.LUT6_inst_1.INIT = 64'hd4428546a8932bcb;
        defparam synapse_connection.synap_matrix.genblk1[240].neuron_con_inst.LUT6_inst_2.INIT = 64'h90568086d2a2528b;
        defparam synapse_connection.synap_matrix.genblk1[240].neuron_con_inst.LUT6_inst_3.INIT = 64'h6aa92aab285f2853;
        defparam synapse_connection.synap_matrix.genblk1[241].neuron_con_inst.LUT6_inst_0.INIT = 64'ha8520288232365db;
        defparam synapse_connection.synap_matrix.genblk1[241].neuron_con_inst.LUT6_inst_1.INIT = 64'ha9b6b4cebd0fad5f;
        defparam synapse_connection.synap_matrix.genblk1[241].neuron_con_inst.LUT6_inst_2.INIT = 64'h542af26bab4baa0b;
        defparam synapse_connection.synap_matrix.genblk1[241].neuron_con_inst.LUT6_inst_3.INIT = 64'h8aaf2bab65225587;
        defparam synapse_connection.synap_matrix.genblk1[242].neuron_con_inst.LUT6_inst_0.INIT = 64'hb24a26806a818be8;
        defparam synapse_connection.synap_matrix.genblk1[242].neuron_con_inst.LUT6_inst_1.INIT = 64'h6eabbc838d46bb64;
        defparam synapse_connection.synap_matrix.genblk1[242].neuron_con_inst.LUT6_inst_2.INIT = 64'h42d6534a494beaab;
        defparam synapse_connection.synap_matrix.genblk1[242].neuron_con_inst.LUT6_inst_3.INIT = 64'haaadeea8f29256c4;
        defparam synapse_connection.synap_matrix.genblk1[243].neuron_con_inst.LUT6_inst_0.INIT = 64'ha8d7aa146aa9cdb1;
        defparam synapse_connection.synap_matrix.genblk1[243].neuron_con_inst.LUT6_inst_1.INIT = 64'haa432b6e292728a6;
        defparam synapse_connection.synap_matrix.genblk1[243].neuron_con_inst.LUT6_inst_2.INIT = 64'h140392a896a81082;
        defparam synapse_connection.synap_matrix.genblk1[243].neuron_con_inst.LUT6_inst_3.INIT = 64'h4aa2637a388c380e;
        defparam synapse_connection.synap_matrix.genblk1[244].neuron_con_inst.LUT6_inst_0.INIT = 64'h8aa9f22baaae2a99;
        defparam synapse_connection.synap_matrix.genblk1[244].neuron_con_inst.LUT6_inst_1.INIT = 64'hf15ea544a012ca92;
        defparam synapse_connection.synap_matrix.genblk1[244].neuron_con_inst.LUT6_inst_2.INIT = 64'h392896ea94dad45f;
        defparam synapse_connection.synap_matrix.genblk1[244].neuron_con_inst.LUT6_inst_3.INIT = 64'heaac0aa8baab302b;
        defparam synapse_connection.synap_matrix.genblk1[245].neuron_con_inst.LUT6_inst_0.INIT = 64'h4aeaaae822ad6683;
        defparam synapse_connection.synap_matrix.genblk1[245].neuron_con_inst.LUT6_inst_1.INIT = 64'hab6aca6a546bd0eb;
        defparam synapse_connection.synap_matrix.genblk1[245].neuron_con_inst.LUT6_inst_2.INIT = 64'hac0ba9a3aa03a952;
        defparam synapse_connection.synap_matrix.genblk1[245].neuron_con_inst.LUT6_inst_3.INIT = 64'haaa9956bdaff0c3a;
        defparam synapse_connection.synap_matrix.genblk1[246].neuron_con_inst.LUT6_inst_0.INIT = 64'hb4a995aa55f6d632;
        defparam synapse_connection.synap_matrix.genblk1[246].neuron_con_inst.LUT6_inst_1.INIT = 64'h9adbaa4aa96ba82a;
        defparam synapse_connection.synap_matrix.genblk1[246].neuron_con_inst.LUT6_inst_2.INIT = 64'hf2db82dabadabada;
        defparam synapse_connection.synap_matrix.genblk1[246].neuron_con_inst.LUT6_inst_3.INIT = 64'h8aa4aaa82029b14b;
        defparam synapse_connection.synap_matrix.genblk1[247].neuron_con_inst.LUT6_inst_0.INIT = 64'ha9492aabaaa968d7;
        defparam synapse_connection.synap_matrix.genblk1[247].neuron_con_inst.LUT6_inst_1.INIT = 64'ha949b51134518959;
        defparam synapse_connection.synap_matrix.genblk1[247].neuron_con_inst.LUT6_inst_2.INIT = 64'ha02a96afb4aa05a9;
        defparam synapse_connection.synap_matrix.genblk1[247].neuron_con_inst.LUT6_inst_3.INIT = 64'h38a27a1428562837;
        defparam synapse_connection.synap_matrix.genblk1[248].neuron_con_inst.LUT6_inst_0.INIT = 64'h83aa46a8aaab79b9;
        defparam synapse_connection.synap_matrix.genblk1[248].neuron_con_inst.LUT6_inst_1.INIT = 64'h92d25a9eeeb73b73;
        defparam synapse_connection.synap_matrix.genblk1[248].neuron_con_inst.LUT6_inst_2.INIT = 64'h2c4aa96ba92b0a2a;
        defparam synapse_connection.synap_matrix.genblk1[248].neuron_con_inst.LUT6_inst_3.INIT = 64'h0aac25ab392ba86a;
        defparam synapse_connection.synap_matrix.genblk1[249].neuron_con_inst.LUT6_inst_0.INIT = 64'haca82aa82aa8adcb;
        defparam synapse_connection.synap_matrix.genblk1[249].neuron_con_inst.LUT6_inst_1.INIT = 64'ha96ab86ab06ab0aa;
        defparam synapse_connection.synap_matrix.genblk1[249].neuron_con_inst.LUT6_inst_2.INIT = 64'h5a2aabaa39ae286e;
        defparam synapse_connection.synap_matrix.genblk1[249].neuron_con_inst.LUT6_inst_3.INIT = 64'he168585e1aba1a0b;
        defparam synapse_connection.synap_matrix.genblk1[250].neuron_con_inst.LUT6_inst_0.INIT = 64'h0000000000000000;
        defparam synapse_connection.synap_matrix.genblk1[250].neuron_con_inst.LUT6_inst_1.INIT = 64'h0000000000000000;
        defparam synapse_connection.synap_matrix.genblk1[250].neuron_con_inst.LUT6_inst_2.INIT = 64'h0000000000000000;
        defparam synapse_connection.synap_matrix.genblk1[250].neuron_con_inst.LUT6_inst_3.INIT = 64'h0000000000000000;
        defparam synapse_connection.synap_matrix.genblk1[251].neuron_con_inst.LUT6_inst_0.INIT = 64'h0000000000000000;
        defparam synapse_connection.synap_matrix.genblk1[251].neuron_con_inst.LUT6_inst_1.INIT = 64'h0000000000000000;
        defparam synapse_connection.synap_matrix.genblk1[251].neuron_con_inst.LUT6_inst_2.INIT = 64'h0000000000000000;
        defparam synapse_connection.synap_matrix.genblk1[251].neuron_con_inst.LUT6_inst_3.INIT = 64'h0000000000000000;
        defparam synapse_connection.synap_matrix.genblk1[252].neuron_con_inst.LUT6_inst_0.INIT = 64'h0000000000000000;
        defparam synapse_connection.synap_matrix.genblk1[252].neuron_con_inst.LUT6_inst_1.INIT = 64'h0000000000000000;
        defparam synapse_connection.synap_matrix.genblk1[252].neuron_con_inst.LUT6_inst_2.INIT = 64'h0000000000000000;
        defparam synapse_connection.synap_matrix.genblk1[252].neuron_con_inst.LUT6_inst_3.INIT = 64'h0000000000000000;
        defparam synapse_connection.synap_matrix.genblk1[253].neuron_con_inst.LUT6_inst_0.INIT = 64'h0000000000000000;
        defparam synapse_connection.synap_matrix.genblk1[253].neuron_con_inst.LUT6_inst_1.INIT = 64'h0000000000000000;
        defparam synapse_connection.synap_matrix.genblk1[253].neuron_con_inst.LUT6_inst_2.INIT = 64'h0000000000000000;
        defparam synapse_connection.synap_matrix.genblk1[253].neuron_con_inst.LUT6_inst_3.INIT = 64'h0000000000000000;
        defparam synapse_connection.synap_matrix.genblk1[254].neuron_con_inst.LUT6_inst_0.INIT = 64'h0000000000000000;
        defparam synapse_connection.synap_matrix.genblk1[254].neuron_con_inst.LUT6_inst_1.INIT = 64'h0000000000000000;
        defparam synapse_connection.synap_matrix.genblk1[254].neuron_con_inst.LUT6_inst_2.INIT = 64'h0000000000000000;
        defparam synapse_connection.synap_matrix.genblk1[254].neuron_con_inst.LUT6_inst_3.INIT = 64'h0000000000000000;
        defparam synapse_connection.synap_matrix.genblk1[255].neuron_con_inst.LUT6_inst_0.INIT = 64'h0000000000000000;
        defparam synapse_connection.synap_matrix.genblk1[255].neuron_con_inst.LUT6_inst_1.INIT = 64'h0000000000000000;
        defparam synapse_connection.synap_matrix.genblk1[255].neuron_con_inst.LUT6_inst_2.INIT = 64'h0000000000000000;
        defparam synapse_connection.synap_matrix.genblk1[255].neuron_con_inst.LUT6_inst_3.INIT = 64'h0000000000000000;

    end 

    default: begin 
        defparam synapse_connection.synap_matrix.genblk1[0].neuron_con_inst.LUT6_inst_0.INIT=64'h0000000000000000;
    end
    
endcase

endmodule

