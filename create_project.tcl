################################################################################
## create_project.tcl
## Vivado Non-Project Mode script to create the SD Card Duplicator project.
##
## Usage:
##   1. Open Vivado
##   2. In the Tcl Console: cd <path-to-SD_Card_Duplicator>
##   3. source create_project.tcl
##
## Alternatively, from the command line:
##   vivado -mode batch -source create_project.tcl
################################################################################

# -- Project settings ---------------------------------------------------------
set project_name   "sd_card_duplicator"
set project_dir    "vivado_project"
set part           "xc7a200tsbg484-1"
set top_module     "sd_card_duplicator_top"

# -- Get the directory of this script ----------------------------------------
set script_dir [file dirname [info script]]

# -- Create project -----------------------------------------------------------
create_project $project_name [file join $script_dir $project_dir] -part $part -force
set_property target_language VHDL [current_project]
set_property simulator_language VHDL [current_project]

# -- Add design sources -------------------------------------------------------
add_files -fileset sources_1 [glob [file join $script_dir "src" "*.vhd"]]
set_property top $top_module [current_fileset]

# -- Add constraints -----------------------------------------------------------
add_files -fileset constrs_1 [glob [file join $script_dir "constrs" "*.xdc"]]

# -- Add simulation sources ----------------------------------------------------
add_files -fileset sim_1 [glob [file join $script_dir "sim" "*.vhd"]]
set_property file_type {VHDL 2008} [get_files -of_objects [get_filesets sim_1]]

# -- Set simulation top --------------------------------------------------------
set_property top tb_spi_master [get_filesets sim_1]

# -- Update compile order ------------------------------------------------------
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# -- Print summary -------------------------------------------------------------
puts "============================================================"
puts " Project '$project_name' created successfully!"
puts " Part:               $part"
puts " Top module:         $top_module"
puts " Project directory:  [file join $script_dir $project_dir]"
puts ""
puts " Design sources:     [llength [get_files -of_objects [get_filesets sources_1]]] files"
puts " Constraints:        [llength [get_files -of_objects [get_filesets constrs_1]]] files"
puts " Simulation sources: [llength [get_files -of_objects [get_filesets sim_1]]] files"
puts "============================================================"
puts ""
puts " Next steps:"
puts "   1. Run synthesis:        launch_runs synth_1"
puts "   2. Run implementation:   launch_runs impl_1"
puts "   3. Generate bitstream:   launch_runs impl_1 -to_step write_bitstream"
puts "   4. Run simulation:       launch_simulation"
puts "============================================================"
