module ppi (wrb, rdb, cs, reset, a0, a1, data, portA, portB, portC);

// declaration of PPI inputs and outputs

input wrb, rdb, cs, reset, a0, a1;
inout [7:0] data, portA, portB, portC;

// declaration of internals of the ppi
// 1) Control Word Register

reg [7:0] cwr;

// 2) address bus
wire [1:0] address;
assign address = {a1,a0};

// 3) reset
wire int_reset;
assign int_reset = reset | (cwr[7]==0) | (~wrb & (address == 2'b11));

// 4) latching of data and ports
reg [7:0] latch_data, latch_portA, latch_portB, latch_portC;

// 5) tri-state output bus for data and ports
reg [7:0] out_data, out_portA, out_portB, out_portC;
assign data = out_data;
assign portA = out_portA;
assign portB = out_portB;
assign portC = out_portC;

// 6) ports enable for output
reg enable_portA, enable_portB, enable_upper_portC, enable_lower_portC;

// 7) groups control for mode 0
reg groupA_mode0, groupB_mode0;

// 8) bit set/reset
//reg [2:0] pin_selected;
//reg bit_set; 

// different modes of operations
// 1] mode 0 i/o
always @(posedge reset or negedge wrb)
begin

if (reset)
begin
/* if reset .. CWR is set to active mode 0 with all 
ports as input */
cwr <= 8'b10011011;
end

else 
// data is written to the control word register
begin
if (address == 2'b11)
cwr <= data;
end

end

always @ (posedge int_reset or negedge wrb)
// if falling edge of wrb is detected data is latched
begin
if (int_reset)
latch_data <= 8'h00;
else
latch_data <= data;
end

always @(posedge int_reset or negedge rdb)
//if falling edge or rb is detected ports are latched
begin

if (int_reset)
begin
latch_portA <= 8'h00;
latch_portB <= 8'h00;
latch_portC <= 8'h00;
end

else
begin
latch_portA <= portA;
latch_portB <= portB;
latch_portC <= portC;
end

end

always @(int_reset or cwr)
// enabling or disabling ports as output upon control word register
begin

if (int_reset)
begin
enable_portA = 0;
enable_portB = 0;
enable_upper_portC = 0;
enable_lower_portC = 0;
end

else
begin

if (cwr[7]==1)
//check if active flag for mode 0 operations
begin

if (cwr[6:5]==2'b00)
//check if group A mode is mode 0
begin

groupA_mode0 = 1;

//enabling port A
if (~cwr[4])
enable_portA = 1;
else enable_portA = 0;

//enabling port C upper
if (~cwr[3])
enable_upper_portC = 1;
else enable_upper_portC = 0;

end

if (cwr[2]==0)
//check if group B mode is mode 0
begin

groupB_mode0 = 1;

//enabling port B
if (~cwr[1])
enable_portB = 1;
else enable_portB = 0;

//enabling port C lower
if (~cwr[0])
enable_lower_portC = 1;
else enable_lower_portC = 0;

end
end

/*
else
//for bit set/reset
begin
pin_selected = {cwr[3],cwr[2],cwr[1]};
bit_set = cwr[0];
out_portC[pin_selected]=bit_set;
end
*/

end
end

//driving of out_data when reading in mode 0
always @(int_reset or rdb or cwr or address
or latch_portA or enable_portA or groupA_mode0 or
latch_portB or enable_portB or groupB_mode0 or
latch_portC or enable_upper_portC or enable_lower_portC)

begin

if (int_reset)
out_data = 8'hzz;

//if port A is addressed and input
else if (~rdb & groupA_mode0 & ~enable_portA & (address==2'b00))
out_data = latch_portA;

//if port B is addressed and input
else if (~rdb & groupB_mode0 & ~enable_portB & (address==2'b01))
out_data = latch_portB;

//if port C is addressed and input
else if (~rdb & groupA_mode0 & groupB_mode0 & ~enable_upper_portC & 
~enable_lower_portC & (address==2'b10))
out_data = latch_portC;

//if port C is addressed and upper pins are input
else if (~rdb & groupA_mode0 & ~enable_upper_portC & (address==2'b10))
out_data = {latch_portC[7:4],4'hz};

//if port C is addressed and lower pins are input
else if (~rdb & groupB_mode0 & ~enable_lower_portC & (address==2'b10))
out_data = {4'hz,latch_portC[3:0]};

else out_data = 8'hzz;

end

//writing to ports in mode 0
always @ (int_reset or wrb or address or cwr or
latch_data or enable_portA or enable_portB or enable_upper_portC 
or enable_lower_portC or groupA_mode0 or groupB_mode0)

begin

if (int_reset)
begin
out_portA <= 8'hzz;
out_portB <= 8'hzz;
out_portC <= 8'hzz;
end

//if port A is addressed and output
else if (~wrb & groupA_mode0 & enable_portA & (address == 2'b00))
out_portA <=latch_data;

//if port B is addressed and output
else if (~wrb & groupB_mode0 & enable_portB & (address == 2'b01))
out_portB<= latch_data;

//if port C is addressed and output
else if (~wrb & groupA_mode0 & groupB_mode0 & 
enable_upper_portC & enable_lower_portC & (address == 2'b10))
out_portC<= latch_data;

//if port C is addressed and upper pins are output
else if (~wrb & groupA_mode0 & enable_upper_portC & (address == 2'b10))
out_portC<= {latch_data[7:4],4'hz};

//if port C is addressed and lower pins are output
else if (~wrb & groupB_mode0 & enable_lower_portC & (address == 2'b10))
out_portC<= {4'hz, latch_data[3:0]};

else
begin
out_portA <= 8'hzz;
out_portB <= 8'hzz;
out_portC <= 8'hzz;
end

end

endmodule



module ppi_testbench1();

wire[7:0] pA, pB, pC, D;
wire a1,a0;
reg rdb, wrb, rst, cs;
reg [7:0] drive_pA, drive_pB, drive_pC, drive_D, temp_D;

parameter cycle = 100;

assign pA = drive_pA;
assign pB = drive_pB;
assign pC = drive_pC;
assign D = drive_D;

reg [1:0] address;
assign a1 = address [1];
assign a0 = address [0];

initial
begin
     // for reset
     drive_pA = 8'hzz;
     drive_pB = 8'hzz;
     drive_pC = 8'hzz;
     rdb = 1;
     wrb = 1;
     cs=0;
     address = 0;
     drive_D = 8'hzz;
     rst = 0;

     #cycle;

     task_reset;

     // testing for mode 0 with all portA, portB,
     // portCU, portCL
     // input

     temp_D = 8'b10011011;
     CWR_write(temp_D);
     drive_D = 8'hzz;

     // read from portA
     address = 0;
     drive_pA = 8'ha5;
     read_port;
     drive_pA = 8'hzz;
     
     // read portB
     address = 1;
     drive_pB = 8'h35;
     read_port;
     drive_pB = 8'hzz;

     // read portC
     address = 2;
     drive_pC = 8'h98;
     read_port;
     drive_pC = 8'hzz;

    // change portA to output
    temp_D = 8'b10001011;
    CWR_write(temp_D);
    drive_D = 8'hzz;

    // write to portA
    address = 0;
    drive_D = 8'hbc;
    write_port;
    drive_D = 8'hzz;

    // change portB to output
    temp_D = 8'b10001001;
    CWR_write(temp_D);
    drive_D = 8'hzz;

    // write to portB
    address = 1;
    drive_D = 8'h67;
    write_port;
    drive_D = 8'hzz;

    // change portC to output
    temp_D = 8'b10000000;
    CWR_write(temp_D);
    drive_D = 8'hzz;

    // write to portC
    address = 2;
    drive_D = 8'h32;
    write_port;
    drive_D = 8'hzz;

end
task write_port;
begin
     wrb = 1;
     rdb = 1;
     #cycle;
     wrb = 0;
     #cycle;
     wrb = 1;
     #cycle;
end
endtask

task read_port;
begin
     wrb = 1;
     rdb = 1;
     #cycle;
     rdb = 0;
     #cycle;
     rdb = 1;
     #cycle;
end
endtask

task CWR_write;
input [7:0] temp_D;
begin
     rst = 0;
     address = 2'b11;
     rdb = 1;
     wrb = 1;
     #cycle;
     drive_D = temp_D;
     wrb = 0;
     #cycle;
     wrb = 1;
     #cycle;
end
endtask

task task_reset;
begin
     rst = 0;
     #cycle;
     rst = 1;
     #cycle;
     rst = 0;
     #cycle;
end
endtask

ppi ppi_instance (.portA(pA), .portB(pB),
.portC(pC), .rdb(rdb),
.wrb(wrb), .a1(a1), .a0(a0),
.reset(rst),
.data(D), .cs(cs));

endmodule
