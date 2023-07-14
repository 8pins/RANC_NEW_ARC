// Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2018.3 (lin64) Build 2405991 Thu Dec  6 23:36:41 MST 2018
// Date        : Sat Jul  8 15:24:13 2023
// Host        : 3ightpins running 64-bit Ubuntu 22.04.2 LTS
// Command     : write_verilog -force -mode synth_stub
//               /home/eightpins/RANC/CORE_NEW_ARC/single_core_sim/rtl_sources/ip/fifo_generator_0/fifo_generator_0_stub.v
// Design      : fifo_generator_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7k325tffg900-2
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "fifo_generator_v13_2_3,Vivado 2018.3" *)
module fifo_generator_0(clk, srst, din, wr_en, rd_en, dout, full, wr_ack, empty, 
  valid, data_count)
/* synthesis syn_black_box black_box_pad_pin="clk,srst,din[11:0],wr_en,rd_en,dout[11:0],full,wr_ack,empty,valid,data_count[6:0]" */;
  input clk;
  input srst;
  input [11:0]din;
  input wr_en;
  input rd_en;
  output [11:0]dout;
  output full;
  output wr_ack;
  output empty;
  output valid;
  output [6:0]data_count;
endmodule
