/*
Oliver Anderson
Univeristy of Bath
codma FYP 2023

This module will define the tracker used to keep track of the address phases
This means the data phase knows where it is.
*/
import ip_codma_fifo_pkg::*;
import ip_codma_machine_states_pkg::*;

module ip_codma_tracker_fifo #(
)(
    input   			clk_i,
    input				reset_n_i,
	output logic [4:0]  tk_fifo_count_r
);

//--------------------------------------------------
// Buffer FIFO (from ex)
//--------------------------------------------------
logic           tk_fifo_wr;					                // Write to FIFO (push)
logic			tk_fifo_rd;					                // Read from FIFO (pop)
logic 	[2:0]   tk_rptr;					                    // FIFO read pointer
logic 	[2:0]   tk_wptr;					                    // FIFO write pointer
logic 	[2:0]   tk_wptr_next;
logic 	[2:0]   tk_rptr_next;	
logic 	[2:0]	tk_fifo_count_next_s;

//----------------------------------------------------------------------------------------------
// Fifo Counter
//----------------------------------------------------------------------------------------------
always_comb begin
	if (tk_fifo_wr && tk_fifo_rd)
		tk_fifo_count_next_s		= tk_fifo_count_r; 			// wr and rd so count stays the same
	else if (tk_fifo_wr)
		tk_fifo_count_next_s		= tk_fifo_count_r + 3'b001; 		// wr only so increment count
	else if (tk_fifo_rd)
		tk_fifo_count_next_s		= tk_fifo_count_r - 3'b001; 		// rd only so decrement count
	else
		tk_fifo_count_next_s		= tk_fifo_count_r;			// default stays the same
end

// conditions for the fifo to be written to:
// - When the addr phase machine returns to IDLE after being granted
assign tk_fifo_wr = ((ap_state_next_s == AP_IDLE) && ((ap_state_r == AP_RD_ACTIVE) || (ap_state_r == AP_WR_ACTIVE)));  

always_comb begin
	// defaults
	tk_fifo_next_s	= tk_fifo_r;
	tk_wptr_next	= tk_wptr;

    // write to fifo
    if (tk_fifo_wr) begin
        tk_fifo_next_s[tk_wptr%NO_OF_AF_BUFFERS] = tk_fifo_i; // write the inputs to the fifo
        tk_wptr_next = (tk_wptr+'d1)%NO_OF_AF_BUFFERS; // next write pointer value
    end
end

// Clocked counter and pointer changes & reset conditions
always_ff @(posedge clk_i or negedge reset_n_i) begin
    
    if (!reset_n_i) begin
        for(int unsigned x = 0; x < NO_OF_AF_BUFFERS ; x++)
            tk_fifo_r[x]    <= '0;
            tk_fifo_count_r <= '0;
            tk_wptr         <= '0;
    
    end else begin
        tk_fifo_r  		<= tk_fifo_next_s;
        tk_fifo_count_r <= tk_fifo_count_next_s;
        tk_wptr    		<= tk_wptr_next;
    end
end

//----------------------------------------------------------------------------------------------
// Fifo Read
//----------------------------------------------------------------------------------------------  

// The fifo is read when:
// - The data phase returns to idle, and the buffer is not empty 
assign tk_fifo_rd = ((dp_state_next_s == DP_IDLE) && ((dp_state_r == DP_RD_ACTIVE) || (dp_state_r == DP_WR_ACTIVE)) && (tk_fifo_count_r != 'd0));

always_comb
begin
	// default
	tk_rptr_next = tk_rptr;
	
	// fifo read
	if (tk_fifo_rd)
	begin
		tk_rptr_next = (tk_rptr+3'b001)%NO_OF_AF_BUFFERS;	// calculate next read pointer value
	end
end

always_ff @ (posedge clk_i or negedge reset_n_i)
begin
  	if (!reset_n_i)
		tk_rptr <= '0;
  	else
		tk_rptr <= tk_rptr_next;
end

//----------------------------------------------------------------------------------------------
// Fifo Outputs
//----------------------------------------------------------------------------------------------
assign tk_fifo_o.dp_write = tk_fifo_r[tk_rptr%NO_OF_AF_BUFFERS].dp_write;


endmodule