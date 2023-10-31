/*
Oliver Anderson
Univeristy of Bath
codma FYP 2023

Main machine driving the codma. State changes here mostly dictate the operation of the codma. 
*/

import ip_codma_machine_states_pkg::*; 
import ip_codma_fifo_pkg::*; 

module ip_codma_main_machine (
        // Main control signals   
        input               clk_i,
        input               reset_n_i,    
        input               start_i,
        input               stop_i,
        output logic        busy_o,
        output logic        irq_o,

        // Input addr
        input [31:0]        task_pointer_i,
        input [31:0]        status_pointer_i,

        // Error flags from the machines
        input               dp_state_error,
        input               ap_state_error, 

        // Used for the task data
        input [7:0][31:0]   data_reg,

        // Used to track the transfer
        output logic [31:0] len_bytes,
        output logic [7:0]  data_packets,

        // Fifo Signals
        input [2:0]         ap_fifo_count_r,
        input [4:0]         tk_fifo_count_r,
        input [7:0]	        data_fifo_count_r,
        output logic        stat_data,

        BUS_IF.master       bus_if
       
    );
    // internal registers
    logic [3:0][31:0] task_dependant_data;
    logic [31:0] task_type;
    logic [31:0] destin_addr;
    logic [31:0] source_addr;
    logic [31:0] task_pointer_s; // Used to increment after a rd (link task)

    //ip_codma_ap_fifo inst_fifo(
    //    .clk_i(clk_i),
    //    .reset_n_i(reset_n_i)
    //);

    //=======================================================================================
    // WELCOME TO THE MACHINE 
    //=======================================================================================
    always_comb begin
        dma_state_next_s    = dma_state_r;
        if (stop_i) begin
            dma_state_next_s = DMA_IDLE;
        end

        case(dma_state_r)

            //--------------------------------------------------
            // DMA IDLING
            //--------------------------------------------------
            DMA_IDLE:
            begin
                if (!busy_o && start_i) begin
                    dma_state_next_s = DMA_GET_TASK;
                end
            end

            //--------------------------------------------------
            // DMA READING THE POINTER ADDR & UPDATE STATUS
            //--------------------------------------------------
            DMA_GET_TASK:
            begin
                /*
                Move coditions:
                    - Read of Status pointer is complete
                    - The writing to the status pointer is complete
                Actions: 
                    - Read and complete data phase (dp) for the task pointer
                    - Complete status write ; via data fifo
                */
                if (ap_state_next_s == AP_IDLE && dp_state_next_s == DP_IDLE && data_fifo_count_r == 'd0 && len_bytes > 'd1) begin
                    dma_state_next_s = DMA_DATA_READ;
                end
            end

            //--------------------------------------------------
            // READING THE DATA AT THE SOURCE ADDR
            //--------------------------------------------------
            DMA_DATA_READ: // reads the source data
            begin
                /* Goes to Write addr phase when data from source is gathered
                    - len bytes i 0
                    - ap fifo is empty
                    - tracker fifo is empty
                    - dataphase machine is Idle
                */ 
                // needs to be len_bytes == 'd0 || data_fifo is full
                if (len_bytes == 'd0 && ap_fifo_count_r == 'd0 && tk_fifo_count_r != 'd0 && dp_state_next_s == DP_IDLE) begin
                    if (task_type != 'd3) begin
                        dma_state_next_s = DMA_WRITING;
                    end
                end
            end


            //--------------------------------------------------
            // DMA READING THE INFO AT THE SECOND POINTER (LINK TASK)
            //--------------------------------------------------
            DMA_TASK_READ:
            begin
                /* 
                !!! INCOMPLETE FEATURE !!!
                if (ap_state_next_s == AP_IDLE && ap_fifo_count_r < NO_OF_AF_BUFFERS && dp_state_next_s == DP_IDLE) begin
                    dma_state_next_s = DMA_DATA_READ;
                end */
            end        

            
            //--------------------------------------------------
            // WRITING THE DATA TO THE DEST ADDR
            //--------------------------------------------------
            DMA_WRITING:
            begin
                // Return to idle once the data fifo is empty
                if (data_fifo_count_r == 'd0) begin
                    // If all the data was transferred in one go
                    if (len_bytes == 'd0) begin
                        // End task; LINKED TASK NOT SUPPORTED
                        if(task_type != 'd2) begin
                            dma_state_next_s = DMA_FINISH;
                        end else if (task_type == 'd2) begin
                            //dma_state_next_s = DMA_TASK_READ;
                            dma_state_next_s = DMA_FINISH;
                        end

                    // If not all the bytes were transferred due to data fifo being filled, in theory return to data read
                    // UNTESTED FEATURE 
                    end else begin
                        dma_state_next_s = DMA_DATA_READ;
                    end
                end
            end

            
            //--------------------------------------------------
            // DMA COMPUTE PROVISIONS; NOT SUPPORTED
            //--------------------------------------------------
            DMA_CRC:
            begin
                dma_state_next_s = DMA_IDLE;
            end

            
            //--------------------------------------------------
            // ERROR CASE FOR THE DMA
            //--------------------------------------------------
            DMA_ERROR:
            begin
                // once status has been updated to failed, return to Idle
                if(ap_state_next_s == AP_IDLE)begin
                    dma_state_next_s = DMA_IDLE;
                end
            end
            
            //--------------------------------------------------
            // FINISH CASE FOR THE DMA
            //--------------------------------------------------
            DMA_FINISH:
            begin
                // can add condition to go straight into next task. Saves cycles ; "performance optimisation"
                if (!busy_o && irq_o) begin
                    dma_state_next_s = DMA_IDLE;
                end
            end

        endcase
    end

    always_ff @(posedge clk_i, negedge reset_n_i) begin
        //--------------------------------------------------
        // RESET CONDITIONS
        //--------------------------------------------------
        if (!reset_n_i) begin
            dma_state_r         <= DMA_IDLE;
            busy_o              <= 'd0;
            irq_o               <= 'd0;
            destin_addr         <= 'd0;
            len_bytes           <= 'd0;
            task_dependant_data <= 'd0;
            source_addr         <= 'd0;   
            task_type           <= 'd0;
            task_pointer_s      <= 'd0;
            data_packets        <= 'd0;
            stat_data           <= 'd0;

        //--------------------------------------------------
        // ERROR HANDLING (FROM BUS)
        //--------------------------------------------------
        end else if (bus_if.error || dp_state_error || ap_state_error) begin
            dma_state_r     <= DMA_ERROR;
            data_fifo_i.data_reg     <= 'd1;
            codma_ap_fifo_i.addr     <= status_pointer_i;

        //--------------------------------------------------
        // RUNTIME OPERATIONS
        //--------------------------------------------------
        end else begin
            // MACHINE STATES
            dma_state_r <= dma_state_next_s;
    
            
            //------------------------------------------------------------------------
            // DMA IDLING
            //------------------------------------------------------------------------
            if (dma_state_next_s == DMA_IDLE) begin
                destin_addr <= 'd0;
                len_bytes   <= 'd0;
                irq_o       <= 'd0;
                stat_data   <= 'd0;
                
            //------------------------------------------------------------------------
            // DMA GET TASK
            //------------------------------------------------------------------------
            end else if (dma_state_next_s == DMA_GET_TASK) begin
                
                
                // When the dma first moves to the pending state (rd gets priority)
                if (dma_state_r == DMA_IDLE) begin
                    busy_o          <= 'd1;          
                    len_bytes       <= 'd1; // sets to 1 as a marker that the process has started
                    // Send info to the fifo
                    codma_ap_fifo_i.addr <= task_pointer_i;
                    codma_ap_fifo_i.size <= 'd9;
                    codma_ap_fifo_i.read <= 'd1;
                    codma_ap_fifo_i.write <= 'd0;

                // Queue the status write ap
                end else if (ap_fifo_count_r < NO_OF_AF_BUFFERS && ap_state_r == AP_RD_ACTIVE) begin

                    // Send info to the fifo
                    codma_ap_fifo_i.addr <= status_pointer_i;
                    codma_ap_fifo_i.size <= 'd3;
                    codma_ap_fifo_i.read <= 'd0;
                    codma_ap_fifo_i.write <= 'd1;
                    stat_data   <= 'd1;
                
                // once the DP is moving to the write process, the task data will have been read
                end else if (dp_state_r == DP_IDLE && dp_state_next_s == DP_WR_ACTIVE) begin
                    task_type   <= data_reg[0];
                    source_addr <= data_reg[1];
                    destin_addr <= data_reg[2];
                    len_bytes   <= data_reg[3];
                
                // once both addr phases have been requested - don't fill buffer!
                end else begin
                    codma_ap_fifo_i.read <= 'd0;
                    codma_ap_fifo_i.write <= 'd0;
                    stat_data   <= 'd0;
                end           

            //------------------------------------------------------------------------
            // TASK 2 SPECIFIC STATE: READING LAST POINTER + 'd32
            //------------------------------------------------------------------------
            end else if (dma_state_next_s == DMA_TASK_READ) begin
                // Send info to the fifo
                codma_ap_fifo_i.addr <= task_pointer_s;
                codma_ap_fifo_i.size <= 'd9;
                codma_ap_fifo_i.read <= 'd1;
                codma_ap_fifo_i.write <= 'd0;

                if (dma_state_r == DMA_WRITING) begin
                    task_pointer_s  <= task_pointer_s + 'd32;
                end

            //------------------------------------------------------------------------
            // READING THE INFO AT THE SOURCE ADDR
            //------------------------------------------------------------------------
            end else if (dma_state_next_s == DMA_DATA_READ) begin
                
                // When there is still data to gather ; push to the ap fifo
                if (len_bytes > 'd0) begin
                    codma_ap_fifo_i.addr <= source_addr;
                    codma_ap_fifo_i.read <= 'd1;
                    codma_ap_fifo_i.write <= 'd0;
                    // Set size parameter
                    if (task_type == 'd0) begin
                        codma_ap_fifo_i.size <= 'd3;
                    end else if (task_type < 'd3) begin
                        codma_ap_fifo_i.size <= 'd9;
                    end

                    // If room in the fifo and the read addressing has started: increment
                    if (ap_fifo_count_r < NO_OF_AF_BUFFERS) begin
                        if(task_type == 'd0) begin
                            source_addr <= source_addr + 'd8;
                            len_bytes   <= len_bytes   - 'd8;
                            data_packets <= data_packets + 'd1; 
                        end else if (task_type < 'd3) begin
                            source_addr <= source_addr + 'd32;
                            len_bytes   <= len_bytes   - 'd32;
                            data_packets <= data_packets + 'd1;
                        end
                    end
                end else begin
                    // Set to 0 to stop writing to ap fifo
                    codma_ap_fifo_i.read <= 'd0;
                end

                // Error Check - unrecognised task type
                if (task_type > 'd3) begin
                    // Update the status addr
                    dma_state_r <= DMA_ERROR;
                    data_fifo_i.data_reg <= 'd1;
                    codma_ap_fifo_i.addr <= status_pointer_i;
                    codma_ap_fifo_i.read <= 'd0;
                    codma_ap_fifo_i.write <= 'd1;
                    codma_ap_fifo_i.size <= 'd3;
                end

            //------------------------------------------------------------------------
            // PERFORM THE WRITE OPERATION
            //------------------------------------------------------------------------
            end else if (dma_state_next_s == DMA_WRITING) begin

                // Send info to the fifo
                if (data_packets > 'd0) begin
                    codma_ap_fifo_i.addr <= destin_addr;
                    codma_ap_fifo_i.read <= 'd0;
                    codma_ap_fifo_i.write <= 'd1;
                    
                    // Set the write size
                    if (task_type == 'd0) begin
                        codma_ap_fifo_i.size <= 'd3;
                    end else if (task_type < 'd3) begin
                        codma_ap_fifo_i.size <= 'd9;
                    end
                
                // If room in the fifo increment
                    data_packets <= data_packets - 'd1;
                    if(task_type == 'd0) begin
                        destin_addr <= destin_addr + 'd8;
                    end else if (task_type < 'd3) begin
                        destin_addr <= destin_addr + 'd32;
                    end
                //end



                // Don't force write signals to the fifo once done
                end else begin
                    codma_ap_fifo_i.write <= 'd0;
                end

            //------------------------------------------------------------------------
            // DMA FINISHING
            //------------------------------------------------------------------------    
            end else if (dma_state_next_s == DMA_FINISH) begin
                
                // If statement in place so this only happens the one time
                if (dma_state_r != DMA_FINISH) begin
                codma_ap_fifo_i.addr <= status_pointer_i;
                codma_ap_fifo_i.size <= 'd3;
                codma_ap_fifo_i.read <= 'd0;
                codma_ap_fifo_i.write <= 'd1;
                data_fifo_i.data_reg <= 'h0000000000000000;
                stat_data   <= 'd1;
                end else begin
                    stat_data               <= 'd0;
                    codma_ap_fifo_i.write   <= 'd0;
                    
                    // once the write status phase is complete
                    if (dp_state_next_s == DP_IDLE && dp_state_r == DP_WR_ACTIVE) begin
                        irq_o   <= 'd1;
                        busy_o  <= 'd0;
                    end
                end

            end
        end
    end

endmodule