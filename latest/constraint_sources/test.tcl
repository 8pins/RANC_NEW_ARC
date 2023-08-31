set output_path "/home/eightpins/RANC/CORE_NEW_ARC/single_core_sim/mem/1x1"
set output_file [open ${output_path}/output.txt r]

set numb_outputs 250
set numb_classes 10
set stride [expr $numb_outputs/$numb_classes]
set line_numb 0
set count 0

for {set cl_index 0} {$cl_index < $numb_classes} {incr cl_index} {
    set vote_counts($cl_index) 0
}

gets $output_file each_line
if {[string length $each_line] != $numb_outputs} {
    puts "wrong input"
    break
}
puts $each_line

for {set string_idx 0} {$string_idx < $numb_outputs} {set string_idx [expr $string_idx + $numb_classes]} {
    # if {[string index $each_line $string_idx] == "1"} {incr $vote_counts(0)}
    puts [string index $each_line $string_idx]
    if {[string index $each_line $string_idx] == "1"} {incr vote_counts(0)}
}

puts $vote_counts(0)
    # puts $each_line
    # puts $vote_counts($cl_index)


# puts $count

# for {set string_idx 1} {$string_idx < [string length $each_line]} {expr {$string_idx + $numb_classes}} {

#     if {[string index $each_line $string_idx] == "1"} {incr count}
# }
# incr line_numb
	# for {set cl_index 0} {$cl_index < $numb_classes} {incr cl_index} {
