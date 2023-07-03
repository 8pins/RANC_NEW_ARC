# set list_files 
set file_path "/coasiasemi/project/ds/users/tamtd/RTL/core_new_arc/mem1"
set num_cores 5
#foreach file $list_files {} {
#       set 
#       set fp [open "input.txt" r+]

#for {set current_core 0} {$current_core < $num_cores} {incr $current_core} {
#       set bin2write_file [open "${file_path}/bin_new_csram_${current_core}.mem" w]
#       set neuron_con_file [open "${file_path}/core_${current_core}_synap_con.mem" w]
#       close $neuron_con_file
#       close $bin2write_file
#}

# script to extract old mem file for new arch core
for {set current_core 0} {$current_core < $num_cores} {incr current_core} {
        set format_cur_core [format "%03d" $current_core]
        set hex_mem_file [open "${file_path}/neuron_param${current_core}.mem" r]
        set hex2write_file [open "${file_path}/hex_new_csram_${format_cur_core}.mem" w]
        set neuron_con_file [open "${file_path}/core_${current_core}_synap_con.mem" w]

        puts "${format_cur_core}"
        puts "Open file to read: ${file_path}/neuron_param${current_core}.mem"
        puts "Open file to write new csram data: ${file_path}/hex_new_csram_${format_cur_core}.mem"
        puts "Open file to write synapse connection: ${file_path}/core_${current_core}_synap_con.mem" 
        # code here
        
        while {[gets $hex_mem_file each_line] != -1} {
                set neuron_connections [string range $each_line 0 63]
                puts $neuron_con_file $neuron_connections ; # write first 256 bit/ 64 char of the line to synap connection file
                set new_csram_data [string range $each_line 64 [expr [string length $each_line] - 1]]
                puts $hex2write_file $new_csram_data; # write the rest of the line to a new file
        }
        
        puts "Done reading from filed: ${file_path}/neuron_param${current_core}.mem"
        close $neuron_con_file
        close $hex2write_file
        close $hex_mem_file
        
}


# set current core and read corresponding mem file
# open hex mem file
# read each line 
# get 256 bit (64-letter string) synap_con 
# set property to corresponding syn_con LUT
# set the rest of line to new .mem file
