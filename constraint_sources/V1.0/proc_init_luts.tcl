set mem_file_path "/coasiasemi/project/ds/users/tamtd/RTL/core_new_arc/mem1"
set num_cores 5

proc proc_init_lut {current_core current_neuron neu_cons channel {num_luts 4}} {
	set stride [expr [string length $neu_cons] / $num_luts]
	for {set index 0} {$index < $num_luts} {incr index} {
		set bottom_index($index) [expr 63 + 1 - $stride*[expr $index + 1]]
		set top_index($index) [expr 63 - $stride*$index]
	}

	for {set index 0} {$index < $num_luts} {incr index} {
		set init_value [string range $neu_cons $bottom_index($index) $top_index($index)]

		set current_cell "gencore\[${current_core}].Core/synapse_connection/synap_matrix/genblk1\[${current_neuron}].neuron_con_inst/LUT6_inst_${index}"
		#append current_cell "gencore\[" $current_core "].Core/synapse_connection/synap_matrix/genblk1\[" $current_neuron "].neuron_con_inst/LUT6_inst_" $index; 
		
		set value "64'h${init_value}"
		#append value "64'h" $init_value
		
		set_property INIT $value [get_cells $current_cell] $channel;
		# change order of LUT6_inst_* in neuron_con.v so that lut0 has 
		# connection value of the highest axon_num 
		# lut4 has the connection value of the lowest axon_num
        # synapse_connection/synap_matrix/genblk1[1].neuron_con_inst/LUT6_inst_0]
	}
	
}

set init_luts_file "${mem_file_path}/init_luts.xdc"
set xdc_file [open $init_luts_file w]

for {set current_core 0} {$current_core < $num_cores} {incr current_core} {
	set neuron_con_file "${mem_file_path}/core_${current_core}_synap_con.mem"
	#append neuron_con_file $mem_file_path "/core_" $current_core "_synap_con.mem"
	set neuron_con_file [open $neuron_con_file r]
	set line_numb 0

	
	while {[gets $neuron_con_file each_line] != -1} {
		proc_init_lut $current_core $line_numb $each_line $xdc_file; # init lut
		incr line_numb
	}
	
	
	close $neuron_con_file

}

close $xdc_file;

# change proc_init_lut loop to write a new xdc file and source it 