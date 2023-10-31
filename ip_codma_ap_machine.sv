/*
Oliver Anderson
Univeristy of Bath
codma FYP 2023

THE READ AND WRITE MACHINES HAVE CHANGED!
This is the address phase machine. It covers the handshake.
*/

import ip_codma_machine_states_pkg::*;
import ip_codma_fifo_pkg::*;

//=======================================================================================
// ADDRESS PHASE MACHINE
//=======================================================================================
module ip_codma_ap_machine (
        input               clk_i,
        input               reset_n_i,
        input               irq_o,
        input               stop_i,
        input [31:0]        len_bytes,
        input [7:0]         data_packets,

        // state error flag
        output logic        ap_state_error,

        // transfer size info
        output logic [3:0]  rd_size,

        // fifo signals
        input [2:0]         ap_fifo_count_r,
        output logic        fifo_rd_next_s,

        // Patrice's favourite: the interface
        BUS_IF.master       bus_if
    );

    logic [7:0]  word_count_rd;
    logic [63:0] old_data;
    logic status_updated;

always_comb begin
    ap_state_next_s = ap_state_r;
    
    // Define the states of the address phase
    case(ap_state_r)
        AP_IDLE:
        begin
            // When the fifo output is requesting a write or a read then the address phase is active
            if (codma_ap_fifo_o.read && ap_fifo_count_r != 'd0 && ap_state_r == AP_IDLE) begin
                ap_state_next_s = AP_RD_ACTIVE;
            end else if (codma_ap_fifo_o.write && ap_fifo_count_r != 'd0) begin
                // CONDITION USED FOR WRITING TO STATUS
                ap_state_next_s = AP_WR_ACTIVE;
            end
            if (ap_fifo_count_r > 0 && dma_state_r != DMA_DATA_READ && dma_state_r != DMA_WRITING) begin
                fifo_rd_next_s = '1;
            end

            // Once returned to Idle, it must add the phase to the tracker fifo

        end

        AP_RD_ACTIVE:
        begin
            // If a grant is given then it will move the fifo pointer along
            // If no other requests are in the fifo, the address phase is complete
            if (bus_if.grant) begin
                if (dma_state_r != DMA_DATA_READ) begin
                    ap_state_next_s = AP_IDLE;
                    fifo_rd_next_s = '0;
                end else begin
                    fifo_rd_next_s = '1;
                end
            end else begin
                fifo_rd_next_s = '0;
            end

            // Data read stage
            if (dma_state_r ==  DMA_DATA_READ && ap_fifo_count_r == 'd0) begin
                ap_state_next_s = AP_IDLE;
            end

        end

        AP_WR_ACTIVE:
        begin
            if (bus_if.grant) begin
                if (dma_state_r != DMA_WRITING) begin
                    ap_state_next_s  = AP_IDLE;
                    fifo_rd_next_s = '0;
                end else begin
                    fifo_rd_next_s = '1;
                end
            end else begin
                fifo_rd_next_s = '0;
            end

            // Data read stage
            if (dma_state_r ==  DMA_WRITING && ap_fifo_count_r == 'd0) begin
                ap_state_next_s = AP_IDLE;
            end

        end

        AP_UNUSED:
        begin
            ap_state_next_s = AP_IDLE;
        end
    endcase
    
    // Call a return to idle when the stop signal is hit 
    if (stop_i) begin
        ap_state_next_s = AP_IDLE;
    end
end

always_ff @(posedge clk_i or negedge reset_n_i) begin
    //--------------------------------------------------
    // RESET CONDITIONS
    //--------------------------------------------------
    if (!reset_n_i) begin
        ap_state_r      <= AP_IDLE;
        ap_state_error  <= 'd0;
        rd_size         <= 'd0;
        tk_fifo_i       <= 'd0;
        status_updated  <= 'd0;

    //--------------------------------------------------
    // ERROR HANDLING
    //--------------------------------------------------
    end else if (bus_if.error || dma_state_r == DMA_ERROR) begin
        ap_state_r      <= AP_IDLE;

    //--------------------------------------------------
    // NORMAL CONDITIONS
    //--------------------------------------------------
    end else begin
        ap_state_r <= ap_state_next_s;
        
        if (ap_state_next_s == AP_IDLE) begin
            if (dma_state_r != DMA_FINISH) begin
                status_updated <= 'd0;
            end

        // Read address phase
        end else if (ap_state_next_s == AP_RD_ACTIVE && !bus_if.grant) begin
            rd_size <= codma_ap_fifo_o.size;
            tk_fifo_i.dp_write <= 'd0;

        // Write address phase
        end else if (ap_state_next_s == AP_WR_ACTIVE && !bus_if.grant) begin
            tk_fifo_i.dp_write <= 'd1;
            if (dma_state_r == DMA_FINISH) begin
                status_updated <= 'd1;
            end

        // error condition in the machine
        end else if (ap_state_next_s == AP_UNUSED) begin
            ap_state_error <= 'd1;
        end
    end
end

endmodule
