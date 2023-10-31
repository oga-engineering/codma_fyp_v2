module ip_checker(

// clock and reset
input 		clk_i,
input		reset_n_i,

// bus interface
BUS_IF.monitor	bus_if,

// interrupt input
input		irq_i,

// control interface
input		start_i,
input		stop_i,
input		busy_i,
input	[31:0]	task_pointer_i,
input	[31:0]	status_pointer_i

);

//=======================================================================================
// Assertions 
//=======================================================================================

//--------------------------------------------------
// Stable Read Address
//--------------------------------------------------
// Checks to make sure address is stable during a read request until a grant is returned

property read_address_not_stable;

	@(posedge clk_i) disable iff (!reset_n_i)
	(bus_if.read && !bus_if.grant) |-> ##1 (bus_if.addr == $past(bus_if.addr));

endproperty

assert_read_address_not_stable:assert property(read_address_not_stable);

//--------------------------------------------------
// Stable Write Address
//--------------------------------------------------
// Checks to make sure address is stable during a write request until a grant is returned

property write_address_not_stable;

	@(posedge clk_i) disable iff (!reset_n_i)
	(bus_if.write && !bus_if.grant) |-> ##1 ($stable(bus_if.addr));

endproperty

assert_write_address_not_stable:assert property(write_address_not_stable);

//--------------------------------------------------
// No Unexpected Grant
//--------------------------------------------------
// Checks to make sure grant only activates during a read or write request 

property unexpected_grant;

	@(posedge clk_i) disable iff (!reset_n_i)
	(!bus_if.read && !bus_if.write) |-> (!bus_if.grant);

endproperty

assert_unexpected_grant:assert property(unexpected_grant);

endmodule
