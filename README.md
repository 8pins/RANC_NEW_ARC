# RANC New Architecture
Testing new [RANC](https://github.com/UA-RCL/RANC/tree/master) architecture of its CORE.

This project includes 2 simulation runs of 2 RANC Core networks. The first run is `single_core_sim`, which includes a core with new architecture and an output bus, to verify the behavior of the RTL code of all components in the core. The second one is ``, which is a 5-core network to classify MNIST pictures of handwritten digits.
## Dir structure
Common data include `.tcl` scripts in `constraint_sources` and Verilog cord in `rtl_source/new_core`.

Data in other directories are specified for each simulation run.

- [constraint_sources](constraint_sources): `.tcl` scripts to prepare data/parameters for simulation.
- [mem](mem): `.mem` files for initializing Core SRAM(CSRAM).
- [rtl_sources](rtl_sources): RTL code of new core architecture and core networks.
- [simulation_sources](simulation_sources): testbenches for 2 runs.

## To run the simulation:
1. Prepare input
   - Initialize CSRAM:
The original RANC core uses 368 bits in CSRAM for each Neuron to store synaptic connections (256 bits), potential, weights, leaky, ... value (9 bits each, 9 fields), reset mode(1), dx, dy (9ea), axon_destination (8), tick_instance(4). New core separates 256 bits of synaptic connection from the rest in CSRAM.

Initialized data for CSRAM is in `mem/neuron_param[].mem` and will be read by `readmem` in Verilog code. For the new core, use `constraints_sources/init_data.tcl` to split data in `mem/neuron_param[x].mem` into 2 files `core_[x]_synap_con.mem` and `hex_new_csram_[xxx].mem`. `hex_new_csram_[xxx].mem` will be read in `rtl_source/new_core/CSRAM/CSRAM.v`.  
   
   - Initialize LUTs' parameters:
LUTs in FPGA will be used to represent synaptic connections, and we need to define their parameters in simulation and synthesis(for emulation) by 2 different ways.

For simulation: 
Use `neuron_con.sv` and `synap_con.sv` in simulation mode only. Use script `constraints_sources/proc_lut_param.tcl` to convert data in `core_[x]_synap_con.mem` to hex array. Then copy new array to `synap_con.sv`.

For synthesis:
Use `neuron_con.v` and `synap_con.v` in synthesis and implementation mode only. Use script `constraints_sources/proc_init_luts.tcl` to convert data in `core_[x]_synap_con.mem` to `init_lut.xdc`, this file will be used by `VIVADO` to define LUTs parameter during synthesis step.
   
   - other inputs:
`fifo_init.mem` and `neuron_inst.mem` is used for FIFO SRAM and Core controller Neuron instructions Initialization.
  
2. Modify RTL code



4. Run
