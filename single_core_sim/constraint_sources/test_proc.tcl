proc set_property {property value target channel} {
    set output ""
    append output "set_property " $property " " $value " \[get_cells " $target "]" 
    puts $channel $output 
    # puts [concat "set property: " $property " with value: " $value " to target: " $target]
}

proc get_cells {cells} {
    return $cells
}