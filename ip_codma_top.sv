/*
Oliver Anderson
Univeristy of Bath
codma FYP 2023

Top level module file for the codma. This file connects the codma, read and write machine modules.
It is the ONLY module to drive the bus interface signals to avoid contentions.
The unknown states have been defined for a "belt and braces" approach to eliminate this as a point of failure.

!!! NO SUPPORT FOR CRC !!!
Known bugs:
- When the buffer size is smaller than the number N of bytes to transfer.
- Buffer size of 1 and others are untested and may have more bugs
*/

import ip_codma_machine_states_pkg::* ;
import ip_codma_fifo_pkg::* ;

//=======================================================================================
// CODMA MODULE START
//=======================================================================================
module ip_codma_top
#()(
    // clock and reset
    input 		clk_i,
    input		reset_n_i,

    // control interface
    input		    start_i,
    input		    stop_i,
    output logic	busy_o,
    input [31:0]    task_pointer_i,
    input [31:0]    status_pointer_i,

    // bus interface
    BUS_IF.master	bus_if,

    // interrupt output
    output logic	irq_o

);

//=======================================================================================
// INTERNAL SIGNALS AND MARKERS
//=======================================================================================

logic dp_state_error, ap_state_error;

logic [7:0][31:0] data_reg;
logic [7:0][31:0] crc_code;
logic [31:0] len_bytes;
logic [7:0]  data_packets;

//--------------------------------------------------
// TRANSFER SIZE INFO
//--------------------------------------------------
logic [3:0] rd_size_s;

//--------------------------------------------------
// FIFO SHARED SIGNALS
//--------------------------------------------------
logic           fifo_rd_next_s;
logic 	[2:0]	ap_fifo_count_r;	// FIFO count of stored transactions
logic 	[4:0]	tk_fifo_count_s;
logic 	[7:0]	data_fifo_count_s;
logic           stat_data_s;

//=======================================================================================
// CONNECT THE MODULES
//=======================================================================================

ip_codma_dp_machine inst_dp_machine(
    .clk_i(clk_i),
    .reset_n_i(reset_n_i),
    .stop_i(stop_i),
    .data_reg_o(data_reg),
    .rd_size(rd_size_s),
    .tk_fifo_count_r(tk_fifo_count_s),
    .data_fifo_count_r(data_fifo_count_s),
    .bus_if(bus_if)
);

ip_codma_ap_machine inst_ap_machine(
    .clk_i(clk_i),
    .reset_n_i(reset_n_i),
    .irq_o(irq_o),
    .ap_state_error(ap_state_error),
    .stop_i(stop_i),
    .bus_if(bus_if),
    .len_bytes(len_bytes),
    .rd_size(rd_size_s),
    .ap_fifo_count_r(ap_fifo_count_r),
    .fifo_rd_next_s(fifo_rd_next_s),
    .data_packets(data_packets)
);

ip_codma_main_machine inst_dma_machine(
    .clk_i(clk_i),
    .reset_n_i(reset_n_i),
    .start_i(start_i),
    .stop_i(stop_i),
    .busy_o(busy_o),
    .irq_o(irq_o),
    .dp_state_error(dp_state_error),
    .ap_state_error(ap_state_error),    
    .task_pointer_i(task_pointer_i),
    .status_pointer_i(status_pointer_i),
    .data_reg(data_reg),    
    .len_bytes(len_bytes),
    .data_packets(data_packets),
    .ap_fifo_count_r(ap_fifo_count_r),
    .tk_fifo_count_r(tk_fifo_count_s),
    .data_fifo_count_r(data_fifo_count_s),
    .stat_data(stat_data_s),
    .bus_if(bus_if)
);

ip_codma_ap_fifo inst_fifo(
    .clk_i(clk_i),
    .reset_n_i(reset_n_i),
    .fifo_rd_next_s(fifo_rd_next_s),
    .ap_fifo_count_r(ap_fifo_count_r)
);

ip_codma_tracker_fifo inst_tk_fifo(
    .clk_i(clk_i),
    .reset_n_i(reset_n_i),
    .tk_fifo_count_r(tk_fifo_count_s)
);

ip_codma_data_fifo inst_data_fifo(
    .clk_i(clk_i),
    .reset_n_i(reset_n_i),
    .bus_if(bus_if),
    .data_fifo_count_r(data_fifo_count_s),
    .stat_data(stat_data_s)
);






// track the changes of states for the dma - error checking
logic [3:0] prev_dma_state;
always_ff @(posedge clk_i) begin
    if (!reset_n_i) begin
        prev_dma_state <= DMA_IDLE;
    end else begin
        prev_dma_state <= dma_state_r;
    end
end

//=======================================================================================
//      DRIVE THE BUS. BRUM BRUM
//      .-------------------------------------------------------------.
//      '------..-------------..----------..----------..----------..--.|
//      |       \\            ||          ||          ||          ||  ||
//      |        \\           ||          ||          ||          ||  ||
//      |    ..   ||  _    _  ||    _   _ || _    _   ||    _    _||  ||
//      |    ||   || //   //  ||   //  // ||//   //   ||   //   //|| /||
//      |_.------"''----------''----------''----------''----------''--'|
//       |)|      |       |       |       |    |         |      ||==|  |
//       | |      |  _-_  |       |       |    |  .-.    |      ||==| C|
//       | |  __  |.'.-.' |   _   |   _   |    |.'.-.'.  |  __  | "__=='
//       '---------'|( )|'----------------------'|( )|'----------""
//                   '-'                          '-'
//=======================================================================================

always_comb begin
    // Connect the fifo output to the bus interface
    if (ap_fifo_count_r > 'd0) begin 
    bus_if.size     = codma_ap_fifo_o.size;
    bus_if.addr     = codma_ap_fifo_o.addr;
    bus_if.read     = codma_ap_fifo_o.read;
    bus_if.write    = codma_ap_fifo_o.write;
    end else begin
        bus_if.size     = 'd0;
        bus_if.addr     = 'd0;
        bus_if.read     = 'd0;
        bus_if.write    = 'd0;
    end

    // Error condition abort all - But allow for writing to the status pointer
    if (dma_state_r == DMA_ERROR && prev_dma_state != DMA_ERROR) begin
        bus_if.read         = 'd0;
        bus_if.write        = 'd0;
        bus_if.write_valid  = 'd0;
    end else if (dp_state_next_s == DP_WR_ACTIVE) begin
        if (data_fifo_count_s != 'd0) begin
            bus_if.write_data  = data_fifo_o.data_reg;
            bus_if.write_valid = 'd1;
        end
    end else begin
        bus_if.write_valid = 'd0;
    end

end

endmodule
