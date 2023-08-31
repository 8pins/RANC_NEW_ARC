proc proc_decode_output {numb_outputs numb_classes input input_index} {
	if {[string length $input] != $numb_outputs} {
        puts "wrong data format \n"
        return
    }

	for {set cl_index 0} {$cl_index < $numb_classes} {incr cl_index} {

        set vote_counts($cl_index) 0
        
        for {set string_idx $cl_index} {$string_idx < $numb_outputs} {set string_idx [expr $string_idx + $numb_classes]} {
            if {[string index $input $string_idx] == "1"} {incr vote_counts($cl_index)}
        }
	}

    # foreach {class count} [array get vote_counts] {
    #     puts "at output $input_index, Class: $class Count: $count "   
    # }
    set max 0
    set pr_class ""
    
	foreach class [lsort [array names vote_counts]] {
        puts "at output $input_index, Class: $class Count: $vote_counts($class)"
        
        if {$max < $vote_counts($class)} {
            set max $vote_counts($class)
            set pr_class $class    
        }
    }
    puts "class prediction: $pr_class"
    puts "end decoding output $input_index \n"
}

set output_path "/home/eightpins/RANC/CORE_NEW_ARC/single_core_sim/mem/1x1"
set output_file [open ${output_path}/simulator_output.txt r]

set numb_outputs 250
set numb_classes 10

set line_numb 0

while {[gets $output_file each_line] != -1} {
	proc_decode_output $numb_outputs $numb_classes $each_line $line_numb
    incr line_numb
}
