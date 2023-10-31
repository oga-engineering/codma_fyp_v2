/*
Oliver Anderson
Univeristy of Bath
codma FYP 2023

THE READ AND WRITE MACHINES HAVE CHANGED!
This is the data phase machine. It deals with data transfers.
*/
import ip_codma_machine_states_pkg::*;
import ip_codma_fifo_pkg::*;

module ip_codma_dp_machine (
    input           clk_i,
    input           reset_n_i,
    input           stop_i,

    // transfer size info
    input [3:0]     rd_size,

    // fifo inputs
    input [4:0]     tk_fifo_count_r,
    input [7:0]	    data_fifo_count_r,

    output logic [7:0][31:0]  data_reg_o,
    BUS_IF.master   bus_if
);

logic [7:0] word_count_rd;

always_comb begin
    dp_state_next_s = dp_state_r;
    
    
    // Call a return to idle when the stop signal is hit 
    if (stop_i) begin
        dp_state_next_s = DP_IDLE;
    end

    // Move to main dma machine or top. assigns input of the data fifo
    if (bus_if.read_valid && dma_state_r != DMA_GET_TASK) begin
        data_fifo_i.data_reg = bus_if.read_data;
    end else if (dma_state_r == DMA_GET_TASK) begin
        data_fifo_i.data_reg = 'h000000000000000f;
    end
    ////////////////////////////////////////////////
    
    case(dp_state_r)      

        DP_IDLE:
        begin
            // Follow the output of the granted tracker fifo
            if (bus_if.read_valid) begin
                dp_state_next_s = DP_RD_ACTIVE;
                // This could be replaced with tracker count ; delete fifo
            end else if (tk_fifo_o.dp_write && tk_fifo_count_r > 'd0) begin
                dp_state_next_s = DP_WR_ACTIVE;
            end   
        end

        DP_RD_ACTIVE:
        begin
            // Looking for the word count to match expected words
            if (rd_size == 9 && word_count_rd > 6 && !bus_if.read_valid) begin
                dp_state_next_s = DP_IDLE;
            end else if (rd_size == 8 && word_count_rd > 2 && !bus_if.read_valid) begin
                dp_state_next_s = DP_IDLE;
            end else if (rd_size == 3 && word_count_rd > 0 && !bus_if.read_valid) begin
                dp_state_next_s = DP_IDLE;
            end
        end

        DP_WR_ACTIVE:
        begin
            if (data_fifo_count_r == 'd0) begin
                dp_state_next_s = DP_IDLE;
            end
        end

        DP_UNUSED:
        begin
            dp_state_next_s = DP_IDLE;
        end
    endcase
end

always_ff @(posedge clk_i or negedge reset_n_i) begin
    //--------------------------------------------------
    // RESET CONDITIONS
    //--------------------------------------------------
    if (!reset_n_i) begin
        dp_state_r    <= DP_IDLE;
        word_count_rd <= 'd0;
        data_reg_o    <= 'd0;

    //--------------------------------------------------
    // ERROR HANDLING
    //--------------------------------------------------
    end else if (bus_if.error || dma_state_r == DMA_ERROR) begin
        dp_state_r      <= DP_IDLE;

    //--------------------------------------------------
    // NORMAL CONDITIONS
    //--------------------------------------------------
    end else begin
        
        dp_state_r  <= dp_state_next_s;
        if (dp_state_next_s == DP_IDLE) begin
            word_count_rd   <= 'd0;

        end else if (dp_state_next_s == DP_RD_ACTIVE) begin
            if (bus_if.read_valid) begin
                // used for finding the task (bypasses data fifo ; easier)
                data_reg_o[word_count_rd]       <= bus_if.read_data[31:0];
                data_reg_o[word_count_rd+1]     <= bus_if.read_data[63:32];
                // Word count still used even when using data fifo
                word_count_rd                   <= word_count_rd + 2;
            end

        end


    end
end


endmodule