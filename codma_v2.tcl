# setup the library Path
set_db  lib_search_path /eda/AMS/liberty/c35_3.3V

# define the library to use
set_db library { c35_CORELIBD_TYP.lib c35_IOLIB_TYP.lib }

# Read in the HDL file (user defined)

read_hdl -sv ip_codma_fifo_pkg.sv
read_hdl -sv ip_codma_machine_states.sv

read_hdl -sv ip_codma_ap_machine.sv
read_hdl -sv ip_codma_dp_machine.sv
read_hdl -sv ip_codma_main_machine.sv

read_hdl -sv ip_codma_fifo.sv
read_hdl -sv ip_codma_data_fifo.sv
read_hdl -sv ip_codma_tracker_fifo.sv

read_hdl -sv ip_codma_interfaces.sv

read_hdl -sv ip_codma_top.sv

# elaborate the design
#
elaborate

# Synthesize the design
#
#
synthesize -to_mapped

# output the synthesized netlist
#
write_hdl -v2001 ip_codma_top > ip_codma_top_synth.v
gui_show;
# exit
# exit
