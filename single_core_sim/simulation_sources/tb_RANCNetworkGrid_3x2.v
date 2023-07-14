module tb_RANCNetworkGrid_3x2;

parameter NUM_OUTPUT = 250; // Số spike bắn ra
parameter NUM_PICTURE = 100; // Số ảnh test
parameter NUM_PACKET = 13910; // số lượng input packet trong file


    reg clk, reset_n, tick, input_buffer_empty;
    reg [29:0] packet_in;
    wire [7:0] packet_out;
    wire packet_out_valid, ren_to_input_buffer, token_controller_error, scheduler_error;

RANCNetworkGrid uut(
    clk, reset_n, tick, input_buffer_empty, packet_in, packet_out, packet_out_valid, ren_to_input_buffer, token_controller_error, scheduler_error
);

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end
initial begin
    reset_n = 0; @(negedge clk); reset_n = 1;
end


// đọc số lượng packet trong mỗi tick
reg [9:0] num_pic [0:NUM_PICTURE - 1];
initial $readmemh("/home/eightpins/RANC/CORE_NEW_ARC/v1.1/mem/num_inputs_4.txt", num_pic);

// đọc tất cả các packet
reg [29:0] packet [0:NUM_PACKET - 1];
initial $readmemb("/home/eightpins/RANC/CORE_NEW_ARC/v1.1/mem/packet_input4.txt", packet);




integer i = 0;
integer numline = 0; integer index_end = 0;

/////////////////////////
always@(posedge clk) begin
    if(ren_to_input_buffer) begin
        packet_in <= packet[i + index_end];
        i <= i + 1;
    end
end
always @(negedge clk) begin
    if(i == num_pic[numline]) begin
        input_buffer_empty <= 1;
    end
end

// log spike ra
reg [NUM_OUTPUT - 1:0] spike_out;
always @(packet_out_valid, tick) begin
    if(tick) spike_out = {NUM_OUTPUT{1'b0}};
    if(packet_out_valid) begin
        spike_out[249 - packet_out] = 1'b1;
    end
end

reg [NUM_OUTPUT - 1:0] output_file [0:NUM_PICTURE]; //Do có 2 layer nên log thừa ra 1 tick đầu tiên
// định nghĩa hoạt động 1 vài tín hiệu và log lại output

initial begin
    input_buffer_empty = 0;
    tick = 0; repeat(300) @(negedge clk);
    forever begin
        tick = 1; 
        @(negedge clk);
        tick = 0; repeat(65420) @(negedge clk); //Thời gian này phải thỏa mãn làm sao cho current state của core cuối cùng trong mạng trở về 0
        
        index_end = index_end + i;
        i = 0;
        output_file[numline] = spike_out;
        numline = numline + 1;
        input_buffer_empty = 0;
        
        repeat(630) @(negedge clk);
    end
end

always @(numline) begin
    if(numline == NUM_PICTURE + 1) begin
        repeat(50) @(negedge clk);
        $writememb("/home/eightpins/RANC/CORE_NEW_ARC/v1.1/mem/output.txt", output_file);
    end
end


endmodule

// module tb_RANCNetworkGrid_3x2;
//     reg clk, reset_n, tick, input_buffer_empty;
//     reg [29:0] packet_in;
//     wire [7:0] packet_out;
//     wire packet_out_valid, ren_to_input_buffer, token_controller_error, scheduler_error;

// RANCNetworkGrid_3x2 uut(
//     clk, reset_n, tick, input_buffer_empty, packet_in, packet_out, packet_out_valid, ren_to_input_buffer, token_controller_error, scheduler_error
// );

// initial begin
//     input_buffer_empty <= 0;
//     clk = 0;
//     forever #5 clk = ~clk;
// end
// initial begin
//     reset_n = 0;
//     @(negedge clk); reset_n = 1;
// end

// reg [29:0] packet [0:173];
// initial $readmemb("./memfiles/input_packets_3x2.txt", packet);

// integer i = 0;
// always@(posedge clk) begin
//     if(ren_to_input_buffer) begin
//         packet_in = packet[i];
//         i = i + 1;
//     end
// end
// always @(negedge clk) begin
//     if(i == 174) input_buffer_empty <= 1;
// end

// initial begin
//     tick = 0; repeat(300) @(negedge clk);
//     tick = 1; @(negedge clk);
//     tick = 0; repeat(1200) @(negedge clk);
//     tick = 1; @(negedge clk);
//     tick = 0;
// end

// reg [255:0] spike_out;
// always @(packet_out_valid, tick) begin
//     if(tick) spike_out = 256'd0;
//     if(packet_out_valid) begin
//         spike_out[packet_out] = 1'b1;
//     end
// end

// endmodule
