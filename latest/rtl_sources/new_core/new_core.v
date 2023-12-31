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
    output core_done
    // output token_controller_error,
    // output scheduler_error                  
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
    // wire CSRAM_complete; // dont need
    wire [$clog2(NUM_NEURONS)-1:0] CSRAM_addr;
    
    // Token Controller
    wire CSRAM_write; // only need CSRAM_write
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
    
    // assign scheduler_error = core_full;
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

endmodule

