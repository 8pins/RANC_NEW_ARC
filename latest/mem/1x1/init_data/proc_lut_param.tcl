set mem_file_path "/home/eightpins/RANC/CORE_NEW_ARC/single_core_sim/mem/1x1/init_data"
set num_cores 1

proc proc_lut_param {current_core current_neuron neu_cons channel {num_luts 4}} {
	set stride [expr [string length $neu_cons] / $num_luts]
	for {set index 0} {$index < $num_luts} {incr index} {
		set bottom_index($index) [expr 63 + 1 - $stride*[expr $index + 1]]
		set top_index($index) [expr 63 - $stride*$index]
	}
	puts $channel "{"
	for {set index 0} {$index < $num_luts} {incr index} {
		set init_value [string range $neu_cons $bottom_index($index) $top_index($index)]

		#set current_cell "gencore\[${current_core}].Core/synapse_connection/synap_matrix/genblk1\[${current_neuron}].neuron_con_inst/LUT6_inst_${index}"
		#append current_cell "gencore\[" $current_core "].Core/synapse_connection/synap_matrix/genblk1\[" $current_neuron "].neuron_con_inst/LUT6_inst_" $index; 
		if {$index == 3} {
			set value "64'h${init_value}"
		} else {
			set value "64'h${init_value},"
		}
		#append value "64'h" $init_value
		puts $channel $value
		#set_property INIT $value [get_cells $current_cell] $channel;
		# change order of LUT6_inst_* in neuron_con.v so that lut0 has 
		# connection value of the highest axon_num 
		# lut4 has the connection value of the lowest axon_num
        # synapse_connection/synap_matrix/genblk1[1].neuron_con_inst/LUT6_inst_0]
	}
	puts $channel "},"
	
}

#set xdc_file_path "/coasiasemi/project/ds/users/tamtd/RTL/ranc_core_v2/constraint_sources"
set out_file [open ${mem_file_path}/lut_param_array w]

for {set current_core 0} {$current_core < $num_cores} {incr current_core} {
	set neuron_con_file "${mem_file_path}/core_${current_core}_synap_con.mem"
	#append neuron_con_file $mem_file_path "/core_" $current_core "_synap_con.mem"
	set neuron_con_file [open $neuron_con_file r]
	set line_numb 0

	
	while {[gets $neuron_con_file each_line] != -1} {
		proc_lut_param $current_core $line_numb $each_line $out_file; # init lut
		incr line_numb
	}
	
	
	close $neuron_con_file

}

close $out_file;

# change proc_init_lut loop to write a new xdc file and source it 
