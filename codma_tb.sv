/*
Oliver Anderson
Univeristy of Bath
codma FYP 2023

Initial testbench provided by Infineon and heavily modified to allow a proof of concept
simulation of the codma.
For the version two, only the tasks 0 and 1 are tested and the edge cases are not fully evaluated.
*/


module codma_tb ();

import ip_codma_machine_states_pkg::*;
import tb_tasks_pkg::* ;

//=======================================================================================
// Local Signal Definition
//=======================================================================================
logic	clk, reset_n;
logic	start_s, stop_s, busy_s;
logic	[31:0]	task_pointer, status_pointer;
logic	irq_s;
BUS_IF	bus_if();

event test_done;
event check_done;

//=======================================================================================
// Clock and Reset Initialization
//=======================================================================================

//--------------------------------------------------
// Clocking Process
//----------------------------------------------  ----

always #2 clk = ~clk;

//--------------------------------------------------
// Reset Process
//--------------------------------------------------

initial begin
	status_pointer = 'd0;
	clk 	= 0;
	reset_n	= 1;
	#1
	reset_n	= 0;
	stop_s = '0;
	#30
	reset_n	= 1;
	#1000
	$display("Test Hanging");
	$stop;
end

//=======================================================================================
// Module Instantiation
//=======================================================================================

//--------------------------------------------------
// CoDMA Instantiation
//--------------------------------------------------

ip_codma_top inst_codma (
	// clock and reset
	.clk_i			(clk),
	.reset_n_i		(reset_n),
	// control interface
	.start_i		(start_s),
	.stop_i			(stop_s),
	.busy_o			(busy_s),
	.task_pointer_i		(task_pointer),
	.status_pointer_i	(status_pointer),
	// bus interface
	.bus_if			(bus_if.master),
	// interrupt output
	.irq_o			(irq_s)
);

//--------------------------------------------------
// Memory Instantiation
//--------------------------------------------------

ip_mem_pipelined #(
	.MEM_DEPTH	(32),
	.MEM_WIDTH	(8)
) inst_mem (
	// clock and reset
	.clk_i		(clk),
	.reset_n_i	(reset_n),
	// bus interface
	.bus_if		(bus_if.slave)
);

//=======================================================================================
// TB Example Stimulus 
//=======================================================================================
logic [31:0] task_type;
logic [31:0] len_bytes;
logic [31:0] source_addr_o;
logic [31:0] dest_addr_o;
logic [31:0] source_addr_l;
logic [31:0] dest_addr_l;
logic [31:0] task_type_l;
logic [31:0] len_bytes_l;
logic [31:0][7:0][7:0] int_mem;

initial 
begin

//--------------------------------------------------
// Set Default Values
//--------------------------------------------------
	dma_state_t        dma_state_r;
	dma_state_t        dma_state_next_s;

	#40	// wait for reset to finish

//--------------------------------------------------
// Setup ip_mem
//--------------------------------------------------

	// Fill Memory with random values
	@(negedge clk);
	for (int i=0; i<inst_mem.MEM_DEPTH; i++) begin
		inst_mem.mem_array[i] = {$random(),$random()};
	end
	
//--------------------------------------------------
// Co-DMA stimulus
//--------------------------------------------------
for (int i=0; i<1; i++) begin
	fork
		//--------------------------------------------------
		// DRIVE THREAD
		//--------------------------------------------------
		begin
			//#1 8 Bytes chunks
			task_type = 'd1;
			if (task_type == 'd0) begin
				len_bytes = ($urandom_range(1,6)*8);
			end else begin
				len_bytes = ($urandom_range(1,6)*32);
			end
			task_pointer = ($urandom_range(8,(inst_mem.MEM_DEPTH-4))*inst_mem.MEM_WIDTH);
			setup_data(
			inst_mem.mem_array,
			inst_mem.mem_array,
			task_pointer,
			task_type,
			len_bytes,
			source_addr_o,
			dest_addr_o,
			source_addr_l,
			dest_addr_l,
			task_type_l,
			len_bytes_l,
			int_mem
		);
		start_s = '1;
		#20
		start_s = '0;
		wait(inst_codma.busy_o == 'd0);
		-> test_done;
		end
		//--------------------------------------------------
		// VERIFICATION THREAD
		//--------------------------------------------------
		begin
			// Test #1
			@(test_done)
			#4
			check_data(
			inst_mem.mem_array,
				status_pointer,
				source_addr_o,
				dest_addr_o,
				source_addr_l,
				dest_addr_l,
				task_type,
				len_bytes,
				task_type_l,
				len_bytes_l,
				int_mem
			);
		end
	join
	#20
	$display("TESTS SEQUENCE %d PASS!",i);
end
$stop;
end

endmodule
