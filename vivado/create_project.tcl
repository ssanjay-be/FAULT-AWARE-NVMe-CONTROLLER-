# Create a clean Vivado project for the fault-aware storage-controller RTL.
# Run this script from the repository root in Vivado Tcl Console:
#   source vivado/create_project.tcl

set project_name "fault_aware_nvme_controller"
set project_dir "./vivado_project"
set fpga_part "xc7z020clg400-1"

create_project $project_name $project_dir -part $fpga_part -force

# Synthesizable design sources only.
add_files -fileset sources_1 [list \
    [file normalize "./rtl/top_controller.v"] \
    [file normalize "./rtl/cmd_queue_manager.v"] \
    [file normalize "./rtl/dma_engine.v"] \
    [file normalize "./rtl/fault_unit.v"] \
]

set_property top top_controller [get_filesets sources_1]
update_compile_order -fileset sources_1

# Testbench is a simulation source, NOT a synthesis design source.
add_files -fileset sim_1 [file normalize "./sim/tb_top.v"]
set_property top tb_top [get_filesets sim_1]
update_compile_order -fileset sim_1

puts "Project created: $project_name"
puts "Part: $fpga_part"
puts "Design top: top_controller"
puts "Simulation top: tb_top"
puts "Next: launch behavioral simulation from the Vivado Flow Navigator."
