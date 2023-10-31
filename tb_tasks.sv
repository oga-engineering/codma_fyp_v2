/*
Oliver Anderson
Univeristy of Bath
codma FYP 2023

Set of Tasks used by the testbench (codma_tb.sv). Tasks include a setup data task that sets up the memory array
and a task to verify the data has been copied from the correct location to the correct destination location and the number
of copied bytes match up.
*/

package tb_tasks_pkg;

parameter MEM_DEPTH = 32;
parameter MEM_WIDTH = 8;

//=======================================================================================
// SETUP THE POINTERS IN THE MEM ARRAY
//=======================================================================================
task setup_data(
    input [31:0][7:0][7:0] mem_array_in,
    output [31:0][7:0][7:0] mem_array_out,
    input [31:0]    task_pointer,
    input [31:0]    task_type,
    input [31:0]    len_bytes,
    output [31:0]   source_addr_o,
    output [31:0]   dest_addr_o,
    output [31:0]   source_addr_l,
    output [31:0]   dest_addr_l,
    output [31:0]   task_type_l,
    output [31:0]   len_bytes_l,
    output [31:0][7:0][7:0] int_mem
    );
    begin
	    logic [31:0] source_addr;
	    logic [31:0] dest_addr;

	mem_array_out = mem_array_in;

        // this randomisation method needs refining. May causes clashes.
        source_addr     = $urandom_range(8,((MEM_DEPTH*MEM_WIDTH)-(len_bytes)));
        source_addr_o   = source_addr;
        // add +32 so it doesn not overwrite the linked task. Not the smartest way, but it works
        dest_addr       = $urandom_range(8,((MEM_DEPTH*MEM_WIDTH)-(len_bytes)))/*+32*/;
        dest_addr_o     = dest_addr;

        // assign to shape for memory module
        mem_array_out[(task_pointer/MEM_WIDTH)] = {source_addr,task_type};
        mem_array_out[((task_pointer/MEM_WIDTH)+1)] = {len_bytes,dest_addr};

        // SETUP A LINK TASK 
        if (task_type == 'd2) begin
            task_type_l     = 0;
            if (task_type_l == 'd0) begin
                len_bytes_l = ($urandom_range(1,4)*8);
            end else begin
                len_bytes_l = ($urandom_range(1,3)*32);
            end
            source_addr     = $urandom_range(0,((MEM_DEPTH*MEM_WIDTH)-(len_bytes_l)));
            source_addr_l   = source_addr;
            dest_addr       = $urandom_range((dest_addr_o+len_bytes),((MEM_DEPTH*MEM_WIDTH)-(len_bytes_l)));
            dest_addr_l     = dest_addr;
            mem_array_out[(task_pointer/MEM_WIDTH)+4] = {source_addr,task_type_l};
            mem_array_out[((task_pointer/MEM_WIDTH)+5)] = {len_bytes_l,dest_addr};
        end else begin
            source_addr_l   = 'd0;
			dest_addr_l     = 'd0;
            len_bytes_l     = 'd0;
            task_type_l     = 'd0;
        end

        // Make a copy of the mem_array in case a source and destination address overlap (eg in a 4 write burst)
        int_mem = mem_array_out;

    end
endtask

//=======================================================================================
// TEST THE DATA
//=======================================================================================
task check_data(
    input [31:0][7:0][7:0] mem_array_in,
    input        status_pointer,
    input [31:0] source_addr,
    input [31:0] dest_addr,
    input [31:0] source_addr_l,
    input [31:0] dest_addr_l,
    input [31:0] task_type,
    input [31:0] len_bytes,
    input [31:0] task_type_l,
    input [31:0] len_bytes_l,
    input [31:0][7:0][7:0] int_mem
    );
    // ALL _L INPUTS ARE FOR LINKED TASKS
    begin
        logic [31:0] src_location;
        logic [31:0] dst_location;
        
        $display("//-------------------------------------------------------------------------------------------------------",task_type);
        $display("Begin Check: task type %d",task_type);

        

        src_location = source_addr/MEM_WIDTH;
        dst_location = dest_addr/MEM_WIDTH;
        #10
        if ( (source_addr + len_bytes) > (MEM_DEPTH*MEM_WIDTH) || (dest_addr + len_bytes) > (MEM_DEPTH*MEM_WIDTH)) begin
            if (mem_array_in[status_pointer] == 'd1) begin
                $display("Task type %d succesfully flagged an error - mem addr did not exist",task_type);
            end else begin
                $display("Task type %d did not flag error - but should have",task_type);
            end
        end else if (task_type == 'd0) begin
            for (int i=0; i<(len_bytes/8); i++ ) begin
                if (int_mem[src_location] == mem_array_in[dst_location]) begin
                    pass_message(task_type, len_bytes,i);
                    src_location = src_location + i;
                    dst_location = dst_location + i;
                end else begin
                    fail_message(mem_array_in, len_bytes, task_type, src_location, dst_location,int_mem);
                    src_location = src_location + i;
                    dst_location = dst_location + i;
                end
            end
        end else if (task_type == 'd1) begin
            for (int i=0; i<(len_bytes/32); i++ ) begin
                if (int_mem[src_location] == mem_array_in[dst_location]) begin
                    pass_message(task_type, len_bytes,i);
                    src_location = src_location + i;
                    dst_location = dst_location + i;
                end else begin
                    fail_message(mem_array_in, len_bytes, task_type, src_location, dst_location,int_mem);
                    src_location = src_location + i;
                    dst_location = dst_location + i;
                end
            end
        end else if (task_type == 'd2) begin
            for (int i=0; i<(len_bytes/32); i++ ) begin
                if (int_mem[src_location] == mem_array_in[dst_location]) begin
                    pass_message(task_type, len_bytes,i);
                    src_location = src_location + i;
                    dst_location = dst_location + i;
                end else begin
                    fail_message(mem_array_in, len_bytes, task_type, src_location, dst_location,int_mem);
                    src_location = src_location + i;
                    dst_location = dst_location + i;
                end
            end
            // check the linked task
            $display("Check Linked Task: task type %d",task_type_l);
            check_data(
	    mem_array_in,
                status_pointer,
				source_addr_l,   //source_addr,
				dest_addr_l,     //dest_addr,
                'd0,             //source_addr_l,
                'd0,             //dest_addr_l,
                task_type_l,     //task_type,
				len_bytes_l,     //len_bytes,
                'd0,             //task_type_l,
                'd0,             //len_bytes_l,
				int_mem        //int_mem
			);
        end

        // check the status
        if (mem_array_in[status_pointer] == 'd0) begin
            $display("status pointer updated correctly %d",'d0);
        end else begin
            $display("status pointer incorrect ; not %d",'d0);
        end

    end
endtask

//=======================================================================================
// PRINT A FAIL MESSAGE (HELPS THE DEBUG)
//=======================================================================================
task fail_message(
    input [31:0][7:0][7:0] mem_array_in,
    input [31:0] len_bytes,
    input [31:0] task_type,
    input [31:0] src_location,
    input [31:0] dst_location,
    input [31:0][7:0][7:0] int_mem
    );
    begin
    $display("test failed: test type %d ; len_bytes %d", task_type, len_bytes);
    $display("src content %h, at location %d",mem_array_in[src_location], src_location);
    $display("dst content %h, at location %d",mem_array_in[dst_location], dst_location);
    $stop;
    end
endtask

//=======================================================================================
// PRINT A PASS MESSAGE (HELPS CELEBRATE. WOO.)
//=======================================================================================
task pass_message(
    input [31:0] task_type,
    input [31:0] len_bytes,
    input int    i
    );
    logic [31:0] transf;
    begin
        if (task_type == 'd0) begin
            transf = (i+1) * 'd8;
        end else if (task_type == 'd1) begin
            transf = (i+1) * 'd32;
        end else if (task_type == 'd2) begin
            transf = (i+1) * 'd32;
        end
        $display("Bytes transfered %d of %d: SUCCESS", transf, len_bytes);
    end
endtask

endpackage
