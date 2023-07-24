// module tb_RANCNetworkGrid_1x1;

// parameter NUM_OUTPUT = 250; // Số spike bắn ra
// parameter NUM_PICTURE = 100; // Số ảnh test
// parameter NUM_PACKET = 3058; // số lượng input packet trong file


// reg clk, reset_n, tick, input_buffer_empty;
// reg [29:0] packet_in;
// wire [7:0] packet_out;
// wire packet_out_valid, ren_to_input_buffer, token_controller_error, scheduler_error;

// RANCNetworkGrid_1x1 uut(
//     clk, reset_n, tick, input_buffer_empty, packet_in, packet_out, packet_out_valid, ren_to_input_buffer, token_controller_error, scheduler_error
// );

// initial begin
//     clk = 0;
//     forever #5 clk = ~clk;
// end
// initial begin
//     reset_n = 0; @(negedge clk); reset_n = 1;
// end


// // đọc số lượng packet trong mỗi tick
// reg [6:0] num_pic [0:NUM_PICTURE - 1];
// initial $readmemh("./memfiles/1x1/tb_num_inputs.txt", num_pic);

// // đọc tất cả các packet
// reg [29:0] packet [0:NUM_PACKET - 1];
// initial $readmemb("./memfiles/1x1/tb_input.txt", packet);




// integer i = 0;
// integer numline = 0; integer index_end = 0;

// /////////////////////////
// always@(posedge clk) begin
//     if(ren_to_input_buffer) begin
//         packet_in <= packet[i + index_end];
//         i <= i + 1;
//     end
// end
// always @(negedge clk) begin
//     if(i == num_pic[numline]) begin
//         input_buffer_empty <= 1;
//     end
// end

// // log spike ra
// reg [NUM_OUTPUT - 1:0] spike_out;
// always @(packet_out_valid, tick) begin
//     if(tick) spike_out = {NUM_OUTPUT{1'b0}};
//     if(packet_out_valid) begin
//         spike_out[249 - packet_out] = 1'b1;
//     end
// end


// reg [NUM_OUTPUT - 1:0] output_file [0:NUM_PICTURE - 1];
// // định nghĩa hoạt động 1 vài tín hiệu và log lại output
// initial begin
//     input_buffer_empty = 0;
//     tick = 0; repeat(51) @(negedge clk);
//     forever begin
//         tick = 1; @(negedge clk);
//         tick = 0; repeat(700) @(negedge clk); //Thời gian này phải thỏa mãn làm sao cho current state của core cuối cùng trong mạng trở về 0
//         index_end = index_end + i;
//         i = 0;
//         output_file[numline] = spike_out;
//         numline = numline + 1;
//         input_buffer_empty = 0;
        
//         repeat(140) @(negedge clk);
//     end
// end


// //     if(uut.Core0.neuron_grid.controller.current_state == 0 & input_buffer_empty == 1) begin


// always @(numline) begin
//     if(numline == 100) begin
//         repeat(50) @(negedge clk);
//         $writememb("./memfiles/1x1/output.txt", output_file);
//     end
// end


// endmodule

//Feed đầu mỗi tick
module tb_RANCNetworkGrid_1x1;

parameter NUM_OUTPUT = 250; // Số spike bắn ra
parameter NUM_PICTURE = 100;//10000; // Số ảnh test
parameter NUM_PACKET = 3058;//341397; // số lượng input packet trong file

parameter MEMORY_FILEPATH = "/home/eightpins/RANC/CORE_NEW_ARC/single_core_sim/mem"; 


reg clk, reset, tick, input_buffer_empty;
reg [29:0] packet_in;
wire [7:0] packet_out;
wire packet_out_valid, ren_to_input_buffer, token_controller_error, scheduler_error;
wire cores_done;

RANCNetworkGrid_1x1 uut(
    .clk(clk),
    .rst(reset),
    .tick(tick),
    .input_buffer_empty(input_buffer_empty),
    .packet_in(packet_in),
    .packet_out(packet_out),
    .packet_out_valid(packet_out_valid),
    .ren_to_input_buffer(ren_to_input_buffer),
    .token_controller_error(token_controller_error),
    .scheduler_error(scheduler_error),
    .cores_done(cores_done)
);

initial begin
    clk = 0;
    forever #2.5 clk = ~clk;
end
initial begin
    reset = 1; repeat(2) @(negedge clk); reset = 0;
end


// đọc số lượng packet trong mỗi tick
reg [6:0] num_pic [0:NUM_PICTURE - 1];
initial $readmemh({MEMORY_FILEPATH,"/1x1/tb_num_inputs.txt"}, num_pic);

// đọc tất cả các packet
reg [29:0] packet [0:NUM_PACKET - 1];
initial $readmemb({MEMORY_FILEPATH,"/1x1/tb_input.txt"}, packet);




integer i = 0;
integer numline = 0; integer index_end = 0;//76641 - 38;

/////////////////////////
always@(posedge clk) begin
    if(ren_to_input_buffer) begin
        packet_in <= packet[i + index_end];
        i <= i + 1;
    end
end
always @(negedge clk) begin
    if(numline == NUM_PICTURE) input_buffer_empty <= 1;
    else if(i == num_pic[numline]) begin
        input_buffer_empty <= 1;
    end
    
end

// log spike ra
reg [NUM_OUTPUT - 1:0] spike_out;
always @(packet_out_valid, reset, cores_done) begin
    if(reset) spike_out = {NUM_OUTPUT{1'b0}};
    if(cores_done) #5 spike_out = {NUM_OUTPUT{1'b0}};
    
    if(packet_out_valid) begin
        spike_out[249 - packet_out] = 1'b1;
    end
end


reg [NUM_OUTPUT - 1:0] output_file [0:NUM_PICTURE - 1];
// định nghĩa hoạt động 1 vài tín hiệu và log lại output
initial begin
    input_buffer_empty = 0;
    tick = 0; repeat(51) @(negedge clk);
    forever begin
        // tick = 1;
        @(cores_done);
        index_end = index_end + i;
        i = 0;
        if(numline >= 1) output_file[numline - 1] = spike_out; //do mạng này có 1 layer
        numline = numline + 1;
        input_buffer_empty = 0;
        @(negedge clk);
        // tick = 0;
        // repeat(66050) @(negedge clk);
    end
end

reg finish;
initial finish = 0;
always @(numline) begin
    if(numline == NUM_PICTURE + 1) begin //do mạng này có 1 layer
        repeat(50) @(negedge clk);
        $writememb({MEMORY_FILEPATH,"/1x1/output.txt"}, output_file);
        finish = 1;
        #(20);
        $stop;
    end
end

///////compare with output from software////////////////////////////
reg [NUM_OUTPUT - 1:0] output_soft [0:NUM_PICTURE - 1];
reg wrong;
initial wrong = 0;
initial $readmemb({MEMORY_FILEPATH,"/1x1/simulator_output.txt"}, output_soft);
integer in, j;
always @(finish) begin
    if(finish) begin
        for(in = 0; in < NUM_PICTURE; in = in + 1) begin
            for(j = 0; j < NUM_OUTPUT; j = j + 1) begin
                if(output_file[in][j] != output_soft[in][j]) begin
                    $display("Error at neuron %d, picture %d", j, in);
                    wrong = 1;
                end
            end
        end
    end
end
always @(finish) begin
    if(finish) begin
        #1; if(~wrong) $display("Test pass without error");
    end
    
end

endmodule