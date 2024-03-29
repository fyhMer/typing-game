module keyboard(clk, clrn, ps2_clk, ps2_data, data, ascii, d_digit, a_digit, c_digit, count, ctrl, shift, up, caps);
input clk,clrn;
input ps2_clk;
input ps2_data;
output reg [7:0] data;
output [7:0] ascii;
output [13:0] d_digit,a_digit,c_digit;
output reg [15:0] count;
output reg ctrl;
output reg shift;
output reg up;
output reg caps;

reg caps_f;
reg shift_f;
reg ctrl_f;
reg clk_t;
reg [7:0] count_clk;
reg nextdata_n;
wire ready;
wire overflow;
wire [7:0] temp_data;
wire [7:0] ascii_u;
wire [7:0] ascii_l;
reg [15:0] temp;
reg pre; //0xf0

initial
begin
	clk_t=0;
	count_clk=0;
	nextdata_n=1;
	count=8'b00000000;
	data=8'b00000000;
	pre=1;
	ctrl=0;
	ctrl_f=0;
	up=0;
	shift=0;
	shift_f=0;
	caps=0;
	caps_f=0;
end

task trans;
input [3:0]A;
output [6:0]B;
case (A)
		0 	: B <= 7'b1000000;//0
		1 	: B <= 7'b1111001;	//1
		2 	: B <= 7'b0100100;	//2
		3 	: B <= 7'b0110000;	//3
		4 	: B <= 7'b0011001;	//4
		5 	: B <= 7'b0010010;	//5
		6 	: B <= 7'b0000010;	//6
		7 	: B <= 7'b1111000;	//7
		8 	: B <= 7'b0000000;	//8
		9 	: B <= 7'b0010000;	//9
		10 : B <= 7'b0001000;	//A
		11 : B <= 7'b0000011;	//B
		12	: B <= 7'b1000110;	//C
		13 : B <= 7'b0100001;	//D
		14 : B <= 7'b0000110;	//E
		15 : B <= 7'b0001110;	//F
		default : B <= 7'b11111111; 	//error
	endcase
endtask

always @ (posedge clk)
begin
	if(count_clk>=100)
	begin
		count_clk <= 0;
		clk_t <= ~clk_t;
	end
	else
		count_clk<=count_clk + 1;
end


ps2_keyboard ps2(
	.clk(clk),
	.clrn(clrn),
	.ps2_clk(ps2_clk),
	.ps2_data(ps2_data),
	.nextdata_n(nextdata_n),
	.data(temp_data),
	.ready(ready),
	.overflow(overflow)
);

ram1 ram(
	.address(data),
	.clock(clk),
	.data(8'b00000000),
	.wren(1'b0),
	.rden(1'b1),
	.q(ascii_l)
);

ram1_up ram_up(
	.address(data),
	.clock(clk),
	.data(8'b00000000),
	.wren(1'b0),
	.rden(1'b1),
	.q(ascii_u)
);

assign ascii = up? ascii_u:ascii_l;

always @ (posedge clk)
begin	
	trans(data[3:0],d_digit[6:0]);
	trans(data[7:4],d_digit[13:7]);
	
	if (up==0) begin
		trans(ascii[3:0],a_digit[6:0]);
		trans(ascii[7:4],a_digit[13:7]);
	end else begin
		trans(ascii_u[3:0],a_digit[6:0]);
		trans(ascii_u[7:4],a_digit[13:7]);
	end
	
	trans(count[3:0],c_digit[6:0]);
	trans(count[7:4],c_digit[13:7]);
end

always @ (posedge clk_t)
begin
	if (ready==1) 
	begin
	
		if(temp_data[7:0] == 8'h58)    //caps
			begin
				if((pre == 1) && (caps_f == 0))
				begin
					up = ~up;
					caps = 1;
					caps_f = 1;
				end
				else if(pre == 0)
					caps = 0;
					caps_f = 0;
			end
	
		if(temp_data[7:0] == 8'h12 || temp_data[7:0] == 8'h59)    //shift
			begin
				if((pre == 1) && (shift_f == 0))
				begin
					up = ~up;
					shift = 1;
					shift_f = 1;
				end
				else if(pre == 0) //0xf0
				begin
					up = ~up;
					shift = 0;
					shift_f = 0;
				end
			end
			
		if(temp_data[7:0] == 8'h14)         //ctrl
			begin
				if((pre == 1) && (ctrl_f == 0))
				begin
					ctrl = 1; 
					ctrl_f = 1;
				end
				else if(pre == 0) //0xf0
				begin
					ctrl = 0;
					ctrl_f = 0;
				end
			end
		
		if((temp_data[7:0] != 8'hf0) && (pre == 1)) //base case
			begin
				pre = 1;
				data = temp_data;
				
			end
			else if(temp_data[7:0] == 8'hf0)
			begin
				pre = 0;
				count = count + 1;
				data = temp_data;
			end
			else if(pre == 0)    
			begin
				pre = 1;
			end

		nextdata_n = 0;
		
	end
	
	else
	begin 
		nextdata_n=1;
	end
end

endmodule
