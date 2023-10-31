/*
Oliver Anderson
Univeristy of Bath
codma FYP 2023

Address Phase buffer, replicated from the buffer included by Daniel in the mem_pipelined sv file.
*/

import ip_codma_machine_states_pkg::* ;
import ip_codma_fifo_pkg::* ;

module ip_codma_ap_fifo #(
)(
    input       clk_i,
    input       reset_n_i,
	input 		fifo_rd_next_s,
	output logic [2:0] ap_fifo_count_r
);
//--------------------------------------------------
// Buffer FIFO SIGNALS
//--------------------------------------------------

logic 	[2:0]   rptr;					                    // FIFO read pointer
logic 	[2:0]   wptr;					                    // FIFO write pointer
logic			fifo_rd;					                // Read from FIFO (pop)
logic     		fifo_wr;					                // Write to FIFO (push)
logic 	[2:0]   wptr_next;

//=======================================================================================
// Buffer FIFO 
//=======================================================================================

//----------------------------------------------------------------------------------------------
// Fifo Counter
//----------------------------------------------------------------------------------------------
always_comb begin
	if (fifo_wr && fifo_rd)
		fifo_count_next_s		= ap_fifo_count_r; 			// wr and rd so count stays the same
	else if (fifo_wr)
		fifo_count_next_s		= ap_fifo_count_r + 3'b001; 		// wr only so increment count
	else if (fifo_rd)
		fifo_count_next_s		= ap_fifo_count_r - 3'b001; 		// rd only so decrement count
	else
		fifo_count_next_s		= ap_fifo_count_r;			// default stays the same
end

//----------------------------------------------------------------------------------------------
// Writing to the Fifo
//----------------------------------------------------------------------------------------------
assign fifo_wr = ((codma_ap_fifo_i.read || codma_ap_fifo_i.write) && (ap_fifo_count_r < NO_OF_AF_BUFFERS));


always_comb begin
	// defaults
	codma_ap_fifo_next_s	= codma_ap_fifo_r;
	wptr_next	        = wptr;

    // write to fifo
    if (fifo_wr) begin
        codma_ap_fifo_next_s[wptr%NO_OF_AF_BUFFERS] = codma_ap_fifo_i; // write the inputs to the fifo
        wptr_next = (wptr+'d1)%NO_OF_AF_BUFFERS; // next write pointer value
    end
end

// Clocked counter and pointer changes & reset conditions
always_ff @(posedge clk_i or negedge reset_n_i) begin
    
    if (!reset_n_i) begin
        for(int unsigned x = 0; x < NO_OF_AF_BUFFERS ; x++)
            codma_ap_fifo_r[x] <= '0;
            ap_fifo_count_r    <= '0;
            wptr            <= '0;
    
    end else begin
        codma_ap_fifo_r <= codma_ap_fifo_next_s;
        ap_fifo_count_r <= fifo_count_next_s;
        wptr         <= wptr_next;
    end

end

//----------------------------------------------------------------------------------------------
// Fifo Read
//----------------------------------------------------------------------------------------------  

// The cycle the data phase state machine captures the current FIFO output the read is pulsed high to pop it ready for the next transaction
assign fifo_rd = (fifo_rd_next_s);

always_comb
begin
	// default
	rptr_next		= rptr;
	
	// fifo read
	if (fifo_rd)
	begin
		rptr_next 	= (rptr+3'b001)%NO_OF_AF_BUFFERS;	// calculate next read pointer value
	end
end

always_ff @ (posedge clk_i or negedge reset_n_i)
begin
  	if (!reset_n_i)
		rptr     	<= '0;
  	else
		rptr		<= rptr_next;
end

//----------------------------------------------------------------------------------------------
// Fifo Outputs
//----------------------------------------------------------------------------------------------

assign codma_ap_fifo_o.read 	= codma_ap_fifo_r[rptr%NO_OF_AF_BUFFERS].read;
assign codma_ap_fifo_o.write 	= codma_ap_fifo_r[rptr%NO_OF_AF_BUFFERS].write;
assign codma_ap_fifo_o.addr 	= codma_ap_fifo_r[rptr%NO_OF_AF_BUFFERS].addr;
assign codma_ap_fifo_o.size 	= codma_ap_fifo_r[rptr%NO_OF_AF_BUFFERS].size;

endmodule