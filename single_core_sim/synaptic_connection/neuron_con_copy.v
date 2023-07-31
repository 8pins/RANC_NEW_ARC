module neuron_con 
#(NUM_AXONS=256)
(
    input clk,
    input rst,
    input [$clog2(NUM_AXONS)-1:0] axon_number,

    output reg connection
);

    // wire output_connection;
    wire [3:0] lut_outs;

    // LUT6 #(
    //     .INIT(64'h0123456789abcdef)  // Specify LUT Contents
    // ) 
    LUT6 LUT6_inst_0 (
        .O(lut_outs[0]),   // LUT general output
        .I0(axon_number[0]), // LUT input
        .I1(axon_number[1]), // LUT input
        .I2(axon_number[2]), // LUT input
        .I3(axon_number[3]), // LUT input
        .I4(axon_number[4]), // LUT input
        .I5(axon_number[5])  // LUT input
    );

    // LUT6 #(
    //     .INIT(64'hfedcba9876543210)  // Specify LUT Contents
    // ) 
    LUT6 LUT6_inst_1 (
        .O(lut_outs[1]),   // LUT general output
        .I0(axon_number[0]), // LUT input
        .I1(axon_number[1]), // LUT input
        .I2(axon_number[2]), // LUT input
        .I3(axon_number[3]), // LUT input
        .I4(axon_number[4]), // LUT input
        .I5(axon_number[5])  // LUT input
    );

    // LUT6 #(
    //     .INIT(64'h76543210fedcba98)  // Specify LUT Contents
    // ) 
    LUT6 LUT6_inst_2 (
        .O(lut_outs[2]),   // LUT general output
        .I0(axon_number[0]), // LUT input
        .I1(axon_number[1]), // LUT input
        .I2(axon_number[2]), // LUT input
        .I3(axon_number[3]), // LUT input
        .I4(axon_number[4]), // LUT input
        .I5(axon_number[5])  // LUT input
    );

    // LUT6 #(
    //     .INIT(64'h89abcdef01234567)  // Specify LUT Contents
    // ) 
    LUT6 LUT6_inst_3 (
        .O(lut_outs[3]),   // LUT general output
        .I0(axon_number[0]), // LUT input
        .I1(axon_number[1]), // LUT input
        .I2(axon_number[2]), // LUT input
        .I3(axon_number[3]), // LUT input
        .I4(axon_number[4]), // LUT input
        .I5(axon_number[5])  // LUT input
    );

    always @(posedge clk) begin
        if (rst)
            connection <= 1'b0;
        else begin
            /*case(axon_number[7:6])
                00: connection <= lut_outs[0];
                01: connection <= lut_outs[1];
                10: connection <= lut_outs[2];
                11: connection <= lut_outs[3];

            endcase*/
            
            connection <= lut_outs[axon_number[7:6]];
            

        end
    end

endmodule