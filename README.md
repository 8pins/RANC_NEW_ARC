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
The original RANC core uses 368 bits in CSRAM for each Neuron to store synaptic connections (256 bits), potiential, weights, leaky, ... value (9 bits each, 9 fields), reset mode(1), dx, dy (9ea), axon_destination (8), tick_instance(4). New core separates 256 bits of synaptic connection from the rests in CSRAM.

Initialized data for 
3. Modify RTL code

4. Run
