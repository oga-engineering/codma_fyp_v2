/*
Oliver Anderson
Univeristy of Bath
codma FYP 2023

The fifo package contains the structures for the three fifo buffers.
Two "logic" registers are also included as moving them seemed to stop
the addr phase fifo from working. Weird.
*/

package ip_codma_fifo_pkg;
//=======================================================================================
// ADDR PHASE BUFFER
//=======================================================================================
parameter NO_OF_AF_BUFFERS = 6;	// Number of FIFO buffers

typedef struct packed
{
  logic		    read;
  logic		    write;
  logic	[31:0]	addr;
  logic	[3:0]	size;
}
info_t;
info_t		    codma_ap_fifo_i;				            // FIFO inputs
info_t		    codma_ap_fifo_o;				            // FIFO outputs
info_t        codma_ap_fifo_r[NO_OF_AF_BUFFERS];	        // FIFO internal buffers
info_t        codma_ap_fifo_next_s[NO_OF_AF_BUFFERS];

logic 	[2:0]   rptr_next;	        // for some reason moving this breaks the fifo
logic 	[2:0]	  fifo_count_next_s;  // And this too...

//=======================================================================================
// TRACKER BUFFER (SAME SIZE AS AP BUFFER). Used to trigger write DP.
//=======================================================================================
typedef struct packed
{
  logic		     dp_write;
}
tk_info_t;
tk_info_t     tk_fifo_i;				            
tk_info_t     tk_fifo_o;				              
tk_info_t     tk_fifo_r[NO_OF_AF_BUFFERS];	       
tk_info_t     tk_fifo_next_s[NO_OF_AF_BUFFERS];	

//=======================================================================================
// DATA STORAGE BUFFER (LARGE - MAYBE TOO LARGE)
//=======================================================================================
parameter NO_OF_DATA_BUFFERS = 32;

typedef struct packed
{
  logic [63:0]		     data_reg; // Same size as a read double-word
}
data_info_t;
data_info_t     data_fifo_i;				            
data_info_t     data_fifo_o;				              
data_info_t     data_fifo_r[NO_OF_DATA_BUFFERS];	        
data_info_t     data_fifo_next_s[NO_OF_DATA_BUFFERS];

endpackage