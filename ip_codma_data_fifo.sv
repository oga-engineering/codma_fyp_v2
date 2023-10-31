/*
Oliver Anderson
Univeristy of Bath
codma FYP 2023

Module that contains the fifo for saving the data from the sequential reads.
If 7 read phases can be performed before any data is written, then it must be stored.
This makes the codma larger, but faster.
*/
import ip_codma_fifo_pkg::*;
import ip_codma_machine_states_pkg::*;

module ip_codma_data_fifo #(
)(
    input               clk_i,
    input               reset_n_i,
    input               stat_data,          // This signal allows a write for the status update
    output logic [7:0]	data_fifo_count_r,
    BUS_IF.master       bus_if
);
logic           data_fifo_wr;					                // Write to FIFO (push)
logic			data_fifo_rd;					                // Read from FIFO (pop)
logic 	[23:0]   data_rptr;					                    // FIFO read pointer
logic 	[23:0]   data_wptr;					                    // FIFO write pointer
logic 	[23:0]   data_wptr_next;
logic 	[23:0]   data_rptr_next;
logic 	[23:0]	data_fifo_count_next_s;


//----------------------------------------------------------------------------------------------
// Fifo Counter
//----------------------------------------------------------------------------------------------
always_comb begin
	if (data_fifo_wr && data_fifo_rd)
		data_fifo_count_next_s		= data_fifo_count_r; 			// wr and rd so count stays the same
	else if (data_fifo_wr)
		data_fifo_count_next_s		= data_fifo_count_r + 3'b001; 		// wr only so increment count
	else if (data_fifo_rd)
		data_fifo_count_next_s		= data_fifo_count_r - 3'b001; 		// rd only so decrement count
	else
		data_fifo_count_next_s		= data_fifo_count_r;			// default stays the same
end

//----------------------------------------------------------------------------------------------
// Writing to the Fifo
//----------------------------------------------------------------------------------------------
assign data_fifo_wr = (stat_data || (data_fifo_count_r < NO_OF_DATA_BUFFERS) && (bus_if.read_valid) && (dma_state_r == DMA_DATA_READ));

always_comb begin
	// defaults
	data_fifo_next_s    = data_fifo_r;
	data_wptr_next	    = data_wptr;

    // write to fifo
    if (data_fifo_wr) begin
        data_fifo_next_s[data_wptr%NO_OF_DATA_BUFFERS] = data_fifo_i; // write the inputs to the fifo
        data_wptr_next = (data_wptr+'d1)%NO_OF_DATA_BUFFERS; // next write pointer value
    end
end

// Clocked counter and pointer changes & reset conditions
always_ff @(posedge clk_i or negedge reset_n_i) begin
    
    if (!reset_n_i) begin
        for(int unsigned x = 0; x < NO_OF_DATA_BUFFERS ; x++)
            data_fifo_r[x] <= '0;
            data_fifo_count_r    <= '0;
            data_wptr            <= '0;
    
    end else begin
        data_fifo_r <= data_fifo_next_s;
        data_fifo_count_r <= data_fifo_count_next_s;
        data_wptr         <= data_wptr_next;
    end
end

//----------------------------------------------------------------------------------------------
// Fifo Read
//----------------------------------------------------------------------------------------------  

// The cycle the data phase state machine captures the current FIFO output the read is pulsed high to pop it ready for the next transaction
assign data_fifo_rd = bus_if.write_valid;

always_comb
begin
	// default
	data_rptr_next		= data_rptr;
	
	// fifo read
	if (data_fifo_rd)
	begin
		data_rptr_next 	= (data_rptr+3'b001)%NO_OF_DATA_BUFFERS;	// calculate next read pointer value
	end
end

always_ff @ (posedge clk_i or negedge reset_n_i)
begin
  	if (!reset_n_i)
		data_rptr     	<= '0;
  	else
		data_rptr		<= data_rptr_next;
end

//----------------------------------------------------------------------------------------------
// Fifo Outputs
//----------------------------------------------------------------------------------------------

assign data_fifo_o.data_reg 	= data_fifo_r[data_rptr%NO_OF_DATA_BUFFERS].data_reg;

endmodule