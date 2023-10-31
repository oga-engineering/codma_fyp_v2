/*
Oliver Anderson
Univeristy of Bath
codma FYP 2023

This file contains the definitions of the state machine states.
*/
package ip_codma_machine_states_pkg;

  //=======================================================================================
  // ADDR PHASE MACHINE
  //=======================================================================================
  typedef enum logic [1:0]
      {
        AP_IDLE	     = 2'b00,				 
        AP_RD_ACTIVE = 2'b01,
        AP_WR_ACTIVE = 2'b10,
        AP_UNUSED    = 2'b11
      }
      ap_state_t;
      ap_state_t    ap_state_r;
      ap_state_t    ap_state_next_s;

  //=======================================================================================
  // DATA PHASE MACHINE
  //=======================================================================================
  typedef enum logic [1:0]
      {
        DP_IDLE	     = 2'b00,				 
        DP_RD_ACTIVE = 2'b01,
        DP_WR_ACTIVE = 2'b10,
        DP_UNUSED    = 2'b11
      }
      dp_state_t;
      dp_state_t  dp_state_r;
      dp_state_t  dp_state_next_s;

  //=======================================================================================
  // CORE DMA MACHINE
  //=======================================================================================
  typedef enum logic [2:0]
      {
        DMA_IDLE	    = 3'b000,				 
        DMA_GET_TASK   = 3'b001,
        DMA_TASK_READ = 3'b010,
        DMA_DATA_READ	= 3'b011,
        DMA_CRC       = 3'b100,
        DMA_WRITING   = 3'b101,
        DMA_ERROR     = 3'b110,
        DMA_FINISH    = 3'b111
      }
      dma_state_t;
      dma_state_t      dma_state_r;
      dma_state_t      dma_state_next_s;

endpackage
