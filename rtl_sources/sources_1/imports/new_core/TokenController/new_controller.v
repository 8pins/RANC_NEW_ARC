module Controller 
#(
    NUM_AXONS =256,
    NUM_NEURONS =256,
    NUM_WEIGHTS =4,
    FILENAME = ""
)
(
    input clk,
    input rst,

    input spike_in,
    input local_buffers_full,

    input [$clog2(NUM_AXONS)-1:0] axon_number_in,
    input axon_number_valid,
    output reg [$clog2(NUM_AXONS)-1:0] axon_number_out, // reg?
    input synap_done,

    input decoder_empty,
    output reg read_spike,

    input [$clog2(NUM_NEURONS)-1:0] neuron_number_in,
    input neuron_number_valid,
    // output reg [$clog2(NUM_NEURONS)-1] neuron_number_out,    // no need

    output reg CSRAM_write,
    output reg [$clog2(NUM_NEURONS)-1:0] CSRAM_addr,  

    output reg neuron_instruction,
    output reg spike_out,
    output reg neuron_reg_en,
    output reg next_neuron,
    output reg write_current_potential

);

    reg [$clog2(NUM_WEIGHTS)-1:0] neuron_instructions [0:NUM_AXONS-1];  // Stores all neuron instructions
    reg [3:0] state;                                                    // state of FSM

    initial begin
        // check what signals to change
        /////////////////////////////////
        // neuron_reg_en <= 0;
        // write_current_potential <= 0;
        // next_neuron <= 0;
        // row_count <= 0;
        // error <= 0;
        // scheduler_set <= 0;
        // scheduler_clr <= 0;
        CSRAM_write <= 0;
        CSRAM_addr <= 0;
        spike_out <= 0;
        neuron_instruction <= 0;
        $readmemb(FILENAME, neuron_instructions);
    end
    
    localparam  IDLE            = 0,
                AXON_CHECK      = 1,
                NEURON_CHECK    = 2,
                CSRAM_READ      = 3,
                NB_CALC         = 4,
                CSRAM_WRITE     = 5;

    // add state to read from AxonDecoder
    always @(posedge clk ) begin
        if (rst) begin
            
        end
        
        case(state)
            IDLE: begin
                if (!decoder_empty) begin
                    state <= AXON_CHECK;
                    read_spike <= 1'b1;
                end
                else begin   
                    state <= IDLE;
                    read_spike <= 1'b0;
                end
            end    

            AXON_CHECK: begin
                if (axon_number_valid) begin
                    axon_number_out <= axon_number_in;
                    read_spike <= 1'b0;

                    state <= NEURON_CHECK;
                end
                else begin
                    axon_number_out <= 1'b0;

                    state <= AXON_CHECK;
                end
            end

            NEURON_CHECK: begin
                CSRAM_write <= 1'b0;


                if (synap_done) begin
                    // logic
                    CSRAM_addr <= 'b0;

                    state <= IDLE;
                end
                else if (neuron_number_valid) begin
                    CSRAM_addr <= neuron_number_in;

                    state <= CSRAM_READ;
                end 
                else begin
                    CSRAM_addr <= CSRAM_addr;

                    state <= NEURON_CHECK;
                end
            end

            CSRAM_READ: begin
                CSRAM_write <= 1'b0; // can be set to 0 from spike_check state
                write_current_potential <= 1'b1;
                neuron_reg_en <= 1'b1;
                next_neuron <= 1'b1;

                state <= NB_CALC;
            end

            NB_CALC: begin
                next_neuron <= 1'b0;
                write_current_potential <= 1'b0;
                neuron_reg_en <= 1'b1;
                neuron_instruction <= neuron_instructions[axon_number_out];

                state <= CSRAM_WRITE;      
            end

            CSRAM_WRITE: begin
                neuron_reg_en <= 1'b0;
                if(spike_in) begin
				    if(local_buffers_full) begin
				        spike_out <= 1'b0;
				        state <= CSRAM_WRITE;
				    end
				    else begin
				        spike_out <= 1'b1;
                        CSRAM_write <= 1'b1;
				        state <= NEURON_CHECK;
				    end
				end
				else begin
				    spike_out <= 1'b0;
                    CSRAM_write <= 1'b1;
				    state <= NEURON_CHECK;
				end                
            end

        endcase
    end

endmodule