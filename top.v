module top(
	input clk,
	input ps2_clk,
	input ps2_data,
	input key_0,
	output [7:0] vga_r,
	output [7:0] vga_g,
	output [7:0] vga_b,
	output vga_blank_n,
	output vga_clk,
	output vga_hs,
	output vga_vs,
	output reg [1:0] state,//2'b00=start, 2'b01=run, 2'b10=stop, 2'b11=finish

	output reg vga_sync_n);

parameter MAX_SPEED = 3; //最大移动速度
parameter MIN = 0; //最小边界
parameter CHAR_NUM = 32 - 1; //缓存中的点的数量
parameter BUF_SIZE = 38400;

wire [7:0] ascii;
wire [9:0] h_addr;
wire [9:0] v_addr;
wire [23:0] vga_data;
wire ctrl;

clkgen #(25000000) my_vgaclk(clk, 1'b0, 1'b1, vga_clk);

vga_ctrl my_vga(vga_clk,1'b0,vga_data,h_addr,v_addr,vga_hs,vga_vs,vga_blank_n,vga_r,vga_g,vga_b);

keyboard mykey(
	.clk(clk), 
	.clrn(1'b1), 
	.ps2_clk(ps2_clk), 
	.ps2_data(ps2_data), 
	.data(), 
	.ascii(ascii), 
	.d_digit(), 
	.a_digit(), 
	.c_digit(), 
	.count(), 
	.ctrl(ctrl), 
	.shift(), 
	.up(), 
	.caps()
);

// integer x, y;
reg [15:0] cont_wr;
reg [15:0] cont;
reg [31:0] clear_num; // 先将显存清零
reg buf_choice; // 选择使用哪一个显存
reg [7:0] buf_text;
reg  [15:0] write_addr;
wire [15:0] read_addr;
reg [11:0] char_x  	 [0:CHAR_NUM];
reg [11:0] char_y    [0:CHAR_NUM];
reg [11:0] temp_y;
reg [2:0]  char_v    [0:CHAR_NUM]; //每个char移动的速度
reg [7:0]  char_text [0:CHAR_NUM]; //每个char的ASCII码
reg [CHAR_NUM:0] char_valid; //每个char是否有效
reg [7:0] num_valid; //当前有效的char的数量，若等于CHAR_NUM，则不再生成
reg is_char; //当前像素点在一个有效的char的显示范围内为1；若为0，则当前显示的vga_ascii为0
reg [7:0] vga_ascii; //当前像素点要显示的char的ASCII码

// 字体的颜色
reg [3:0] char_color [0:CHAR_NUM];
reg [3:0] buf_color;

// FPS, HIT, MISS, TIME等标志信息显示
parameter LABEL_NUM = 32 - 1;
reg [11:0] LABEL_x [0:LABEL_NUM];
reg [11:0] LABEL_y [0:LABEL_NUM];
reg [7:0]  LABEL_text [0:LABEL_NUM];
reg [3:0]  LABEL_color [0:LABEL_NUM];
reg [LABEL_NUM:0] LABEL_valid;
reg [7:0] cont_LABEL;

// GAME OVER 等结束信息
parameter END_NUM = 24 - 1;
reg [11:0] END_x [0:END_NUM];
reg [11:0] END_y [0:END_NUM];
reg [7:0] END_text [0:END_NUM];
reg [3:0] END_color [0:END_NUM];
reg [END_NUM:0] END_valid;
reg [7:0] cont_END;

initial begin
	state = 2'b00;
	buf_choice = 0;
	buf_color = 0;
	num_valid  = 0;
	char_valid = 0;
	is_char = 0;
	clear_num = 0;
	cont = 0;
	cont_wr = 0;
	cont_LABEL = 0;
	cont_END = 0;
end                         
// vga显示
always @ (posedge vga_clk) begin
	if (v_addr == 479 && h_addr == 639) begin
		buf_choice <= ~buf_choice;
		cont <= 0;
		clear_num <= 0;
		cont_LABEL <= 0;
		cont_END <= 0;
	end
	if (clear_num < BUF_SIZE) begin
		clear_num <= clear_num + 1;
		is_char <= 0;
		write_addr <= clear_num;
	end else begin
		if (cont <= CHAR_NUM) begin
			if (char_valid[cont]==1) begin
				//temp_y <= char_y[cont] + char_v[cont]; //下一帧中char_y的位置
				if(state == 2'b10) temp_y <= char_y[cont];
				else temp_y <= char_y[cont] + char_v[cont];
				buf_text <= char_text[cont];
				buf_color <= char_color[cont];
				if (cont_wr<8) begin
					write_addr <= (char_x[cont]>>3) + (temp_y*64) + (temp_y*16) + cont_wr*64 + cont_wr*16;
					cont_wr <= cont_wr + 1;
					is_char <= 1;
				end else begin
					if (temp_y <= 472)
						char_y[cont] <= temp_y; //进行更新
					else
						char_y[cont] <= 472; //可能要删掉
					buf_text <= 0;
					write_addr <= 0;
					cont <= cont + 1;
					cont_wr <= 0;
					is_char <= 0;
				end
			end else begin
				char_y[cont] <= 0; //当前结点无效，直接把char_y置0
				buf_text <= 0;
				write_addr <= 0;
				cont <= cont + 1;
				cont_wr <= 0;
				is_char <= 0;
			end
		end else if (cont_END<=END_NUM) begin
			if (END_valid[cont_END]==1) begin
				buf_text <= END_text[cont_END];
				buf_color <= END_color[cont_END];
				if (cont_wr<8) begin
					write_addr <= (END_x[cont_END]>>3) + (END_y[cont_END]*64) + (END_y[cont_END]*16) + cont_wr*64 + cont_wr*16;
					cont_wr <= cont_wr + 1;
					is_char <= 1;
				end else begin
					buf_text <= 0;
					write_addr <= 0;
					cont_END <= cont_END + 1;
					cont_wr <= 0;
					is_char <= 0;
				end
			end else begin
				buf_text <= 0;
				write_addr <= 0;
				cont_END <= cont_END + 1;
				cont_wr <= 0;
				is_char <= 0;
			end
		end else if (cont_LABEL<=LABEL_NUM) begin
			if (LABEL_valid[cont_LABEL]==1) begin
				buf_text <= LABEL_text[cont_LABEL];
				buf_color <= LABEL_color[cont_LABEL];
				if (cont_wr<8) begin
					write_addr <= (LABEL_x[cont_LABEL]>>3) + (LABEL_y[cont_LABEL]*64) + (LABEL_y[cont_LABEL]*16) + cont_wr*64 + cont_wr*16;
					cont_wr <= cont_wr + 1;
					is_char <= 1;
				end else begin
					buf_text <= 0;
					write_addr <= 0;
					cont_LABEL <= cont_LABEL + 1;
					cont_wr <= 0;
					is_char <= 0;
				end
			end
		end
	end
end

wire [7:0] row;
char_trans ct((buf_text*8)+cont_wr-1, ~vga_clk, row);

wire [11:0] buf_write;

assign buf_write = {buf_color, row};
assign read_addr = ((h_addr+2)>>3) + (v_addr*64) + (v_addr*16);

wire y_boader;
assign y_boader = (h_addr == 116);

wire hit_boader;
wire miss_boader;
assign hit_boader = ((h_addr>116) && v_addr==320);
assign miss_boader= ((h_addr>116) && v_addr==400);

wire [11:0] out_data_1;
wire [11:0] out_data_2;
vga_buf   fb(vga_clk, buf_write, read_addr, write_addr, buf_choice, out_data_1);
vga_buf_t fb1(vga_clk, buf_write, read_addr, write_addr, ~buf_choice, out_data_2);

wire [11:0] out_data;
assign out_data = y_boader? 12'h0ff : hit_boader? 12'h2ff: miss_boader? 12'h1ff : buf_choice? out_data_2 : out_data_1;
wire [23:0] run_data;
assign run_data = (out_data[h_addr - (h_addr>>3)*8]==0)? 24'h000000: (out_data[11:8]==1)? 24'hff0000: (out_data[11:8]==2)? 24'h00ff00: (out_data[11:8]==3)? 24'h00f0ff:24'hffffff;

/*========== game ==========*/
reg [31:0] rand_num1, rand_num2, rand_num3;
wire [7:0] rand_ascii;
wire [7:0] rand_char_x;
wire [2:0] rand_speed;
reg [25:0]gen_cnt;
reg [5:0] idx; 
reg new_char;
reg [25:0] cnt_max;

reg [4:0] scan_idx;
reg [4:0] init_idx;
reg [4:0] m_idx;
reg [10:0] timer;
reg [10:0] miss_num;
reg [10:0] hit_num;
reg hit_or_badhit;
reg [7:0] last_ascii;
reg [7:0] cur_ascii;
reg [255:0] ascii_valid;
reg [25:0] state_hit_cnt [0:CHAR_NUM];//
reg [25:0] state_miss_cnt [0:CHAR_NUM];//
reg [CHAR_NUM:0] miss_sign;
reg [25:0] cnt_1s;
wire [10:0] TIME_0, TIME_1, TIME_2;
reg init;


parameter UPPER_BOUND = 320;
parameter LOWER_BOUND = 400; 
integer i;

initial begin
	cnt_1s = 1;
	rand_num1 = 32'h938ab4e1;
	rand_num2 = 32'h2a912bdf;
	rand_num3 = 32'hea57d2ac;
	cnt_max = 20000000 - 1;
	gen_cnt = 0;
	idx = 0;
	m_idx = 0;
	new_char = 0;
	scan_idx = 0;
	init_idx = 0;
	miss_num = 0;
	hit_num = 0;
	timer = 0;
	hit_or_badhit = 0;
	last_ascii = 0;
	cur_ascii = 0;
	for(i = 0; i < 256; i = i + 1) begin
		ascii_valid[i] = 1;
	end
	for(i = 0; i <= CHAR_NUM; i = i +1) begin
		state_hit_cnt[i] = 0;
		state_miss_cnt[i] = 0;
		miss_sign[i] = 0;
	end
	init = 0;
end

assign rand_ascii = 8'h41 + rand_num1[4:0] % 26;
assign rand_char_x = rand_num2[7:0] % 64;// time 8 to get char_x
assign rand_speed = 1 + rand_num3[1:0];

assign TIME_0 = timer % 10;
assign TIME_1 = timer % 100 - TIME_0;
assign TIME_2 = timer / 100;

always @(posedge clk) begin
// 标志信息设定
	// FPS
	LABEL_x[0] <= 16;
	LABEL_y[0] <= 16;
	LABEL_text[0] <= 8'h46; // F
	LABEL_color[0] <= 4'h0; // white
	LABEL_valid[0] <= 1;

	LABEL_x[1] <= 24;
	LABEL_y[1] <= 16;
	LABEL_text[1] <= 8'h50; // P
	LABEL_color[1] <= 4'h0; // white
	LABEL_valid[1] <= 1;

	LABEL_x[2] <= 32;
	LABEL_y[2] <= 16;
	LABEL_text[2] <= 8'h53; // S
	LABEL_color[2] <= 4'h0; // white
	LABEL_valid[2] <= 1;

	LABEL_x[3] <= 40;
	LABEL_y[3] <= 16;
	LABEL_text[3] <= 8'h3A; // :
	LABEL_color[3] <= 4'h0; // white
	LABEL_valid[3] <= 1;

	LABEL_x[4] <= 56;
	LABEL_y[4] <= 16;
	LABEL_text[4] <= 8'h30; // 0
	LABEL_color[4] <= 4'h0; // white
	LABEL_valid[4] <= 1;

	LABEL_x[5] <= 64;
	LABEL_y[5] <= 16;
	LABEL_text[5] <= 8'h36; // 6
	LABEL_color[5] <= 4'h0; // white
	LABEL_valid[5] <= 1;

	LABEL_x[6] <= 72;
	LABEL_y[6] <= 16;
	LABEL_text[6] <= 8'h30; // 0
	LABEL_color[6] <= 4'h0; // white
	LABEL_valid[6] <= 1;

	// TIME
	LABEL_x[7] <= 16;
	LABEL_y[7] <= 32;
	LABEL_text[7] <= 8'h54; // T
	LABEL_color[7] <= 4'h3; // blue
	LABEL_valid[7] <= 1;

	LABEL_x[8] <= 24;
	LABEL_y[8] <= 32;
	LABEL_text[8] <= 8'h49; // I
	LABEL_color[8] <= 4'h3; // blue
	LABEL_valid[8] <= 1;

	LABEL_x[9] <= 32;
	LABEL_y[9] <= 32;
	LABEL_text[9] <= 8'h4D; // M
	LABEL_color[9] <= 4'h3; // blue
	LABEL_valid[9] <= 1;

	LABEL_x[10] <= 40;
	LABEL_y[10] <= 32;
	LABEL_text[10] <= 8'h45; // E
	LABEL_color[10] <= 4'h3; // blue
	LABEL_valid[10] <= 1;

	LABEL_x[11] <= 48;
	LABEL_y[11] <= 32;
	LABEL_text[11] <= 8'h3A; // :
	LABEL_color[11] <= 4'h3; // blue
	LABEL_valid[11] <= 1;

	LABEL_x[12] <= 56;
	LABEL_y[12] <= 32;
	if (LABEL_text[12] < 8'h30) LABEL_text[12] <= 8'h30; // 0
	LABEL_color[12] <= 4'h3; // blue
	LABEL_valid[12] <= 1;

	LABEL_x[13] <= 64;
	LABEL_y[13] <= 32;
	if (LABEL_text[13] < 8'h30) LABEL_text[13] <= 8'h30; // 0
	LABEL_color[13] <= 4'h3; // blue
	LABEL_valid[13] <= 1;

	LABEL_x[14] <= 72;
	LABEL_y[14] <= 32;
	if (LABEL_text[14] < 8'h30) LABEL_text[14] <= 8'h30; // 0
	LABEL_color[14] <= 4'h3; // blue
	LABEL_valid[14] <= 1;

	// HIT
	LABEL_x[15] <= 16;
	LABEL_y[15] <= 64;
	LABEL_text[15] <= 8'h48; // H
	LABEL_color[15] <= 4'h2; // green
	LABEL_valid[15] <= 1;

	LABEL_x[16] <= 24;
	LABEL_y[16] <= 64;
	LABEL_text[16] <= 8'h49; // I
	LABEL_color[16] <= 4'h2; // green
	LABEL_valid[16] <= 1;

	LABEL_x[17] <= 32;
	LABEL_y[17] <= 64;
	LABEL_text[17] <= 8'h54; // T
	LABEL_color[17] <= 4'h2; // green
	LABEL_valid[17] <= 1;

	LABEL_x[18] <= 40;
	LABEL_y[18] <= 64;
	LABEL_text[18] <= 8'h3A; // :
	LABEL_color[18] <= 4'h2; // green
	LABEL_valid[18] <= 1;

	LABEL_x[19] <= 56;
	LABEL_y[19] <= 64;
	if (LABEL_text[19] < 8'h30) LABEL_text[19] <= 8'h30; // 0
	LABEL_color[19] <= 4'h2; // green
	LABEL_valid[19] <= 1;

	LABEL_x[20] <= 64;
	LABEL_y[20] <= 64;
	if (LABEL_text[20] < 8'h30) LABEL_text[20] <= 8'h30; // 0
	LABEL_color[20] <= 4'h2; // green
	LABEL_valid[20] <= 1;

	LABEL_x[21] <= 72;
	LABEL_y[21] <= 64;
	if (LABEL_text[21] < 8'h30) LABEL_text[21] <= 8'h30; // 0
	LABEL_color[21] <= 4'h2; // green
	LABEL_valid[21] <= 1;

	// MISS
	LABEL_x[22] <= 16;
	LABEL_y[22] <= 80;
	LABEL_text[22] <= 8'h4D; // M
	LABEL_color[22] <= 4'h1; // red
	LABEL_valid[22] <= 1;

	LABEL_x[23] <= 24;
	LABEL_y[23] <= 80;
	LABEL_text[23] <= 8'h49; // I
	LABEL_color[23] <= 4'h1; // red
	LABEL_valid[23] <= 1;

	LABEL_x[24] <= 32;
	LABEL_y[24] <= 80;
	LABEL_text[24] <= 8'h53; // S
	LABEL_color[24] <= 4'h1; // red
	LABEL_valid[24] <= 1;

	LABEL_x[25] <= 40;
	LABEL_y[25] <= 80;
	LABEL_text[25] <= 8'h53; // S
	LABEL_color[25] <= 4'h1; // red
	LABEL_valid[25] <= 1;

	LABEL_x[26] <= 48;
	LABEL_y[26] <= 80;
	LABEL_text[26] <= 8'h3A; // :
	LABEL_color[26] <= 4'h1; // red
	LABEL_valid[26] <= 1;

	LABEL_x[27] <= 56;
	LABEL_y[27] <= 80;
	if (LABEL_text[27] < 8'h30) LABEL_text[27] <= 8'h30;// 0
	LABEL_color[27] <= 4'h1; // red
	LABEL_valid[27] <= 1;

	LABEL_x[28] <= 64;
	LABEL_y[28] <= 80;
	if (LABEL_text[28] < 8'h30) LABEL_text[28] <= 8'h30; // 0
	LABEL_color[28] <= 4'h1; // red
	LABEL_valid[28] <= 1;

	LABEL_x[29] <= 72;
	LABEL_y[29] <= 80;
	if (LABEL_text[29] < 8'h30) LABEL_text[29] <= 8'h30; // 0
	LABEL_color[29] <= 4'h1; // red
	LABEL_valid[29] <= 1;

	// Ctrl+T : Pause

	// Enter : Run

if(state == 2'b01) begin 
	//count 1s
	if (cnt_1s == 50000000) begin
		timer <= timer + 1;
		cnt_1s <= 1;
		//updata TIME -12-13-14-
		if(LABEL_text[14] == 8'h39) begin
			LABEL_text[14] <= 8'h30;
			if(LABEL_text[13] == 8'h39) begin 				
				LABEL_text[13] <= 8'h30;
				LABEL_text[12] <= LABEL_text[12] + 1;
			end
			else begin
				LABEL_text[13] <= LABEL_text[13] + 1;
				LABEL_text[12] <= LABEL_text[12];
			end
		end
		else begin
			LABEL_text[14] <= LABEL_text[14] + 1; 
			LABEL_text[13] <= LABEL_text[13];
			LABEL_text[12] <= LABEL_text[12];
		end	
		LABEL_valid[14] <= 1;
		LABEL_valid[13] <= 1;
		LABEL_valid[12] <= 1;
		
	end
	else begin
		cnt_1s <= cnt_1s + 1;
	end

    //generate new character
	if (gen_cnt == 10000000) begin
		rand_num1[31:0] <= {rand_num1[22]^rand_num1[2]^rand_num1[1]^rand_num1[0], rand_num1[31:1]};
		rand_num2[31:0] <= {rand_num2[22]^rand_num2[2]^rand_num2[1]^rand_num2[0], rand_num2[31:1]};
		rand_num3[31:0] <= {rand_num3[22]^rand_num3[2]^rand_num3[1]^rand_num3[0], rand_num3[31:1]};			
	end
	 
	if (gen_cnt >= cnt_max) begin 
		if (num_valid < CHAR_NUM) begin 			
			new_char <= 1;
		end
		gen_cnt <= 0;
	end
	else begin
		gen_cnt <= gen_cnt + 1;
	end
	if (new_char) begin
		if (char_valid[idx] == 0) begin //available idx found
			char_valid[idx] <= 1;
			char_x[idx] <= (15 + rand_char_x) * 8;
			//char_y[idx] <= 0;
			char_v[idx] <= rand_speed;
			char_text[idx] <= rand_ascii;
			char_color[idx] <= 4'h0;
			new_char <= 0; //stop searching
			idx <= 0;
		end
		else begin 
			idx <= idx + 1;
		end
	end

    //miss/hit judge	
	if(scan_idx <= CHAR_NUM && char_valid[scan_idx]) begin
		if (char_valid[scan_idx]) begin
			if(char_color[scan_idx] == 4'h2) begin//color==green, hit
				if (state_hit_cnt[scan_idx] == 200000) begin
					state_hit_cnt[scan_idx] <= 0;
					char_color[scan_idx] <= 4'h0;
					char_valid[scan_idx] <= 0;				
				end
				else begin
					state_hit_cnt[scan_idx] <= state_hit_cnt[scan_idx] + 1;
				end
			end
			else if (char_color[scan_idx] == 4'h1) begin //color==red, miss
				if (state_miss_cnt[scan_idx] == 200000) begin
					state_miss_cnt[scan_idx] <= 0;
					char_color[scan_idx] <= 4'h0;
					char_valid[scan_idx] <= 0;	
					miss_sign[scan_idx] <= 0;			
				end
				else begin
					state_miss_cnt[scan_idx] <= state_miss_cnt[scan_idx] + 1;
				end
			end
		end
	
		if (char_text[scan_idx] == cur_ascii & char_color[scan_idx] == 4'h0 ) begin
			hit_or_badhit <= 1; 
			if (char_y[scan_idx] > char_y[m_idx]) begin
				m_idx <= scan_idx;
			end
		end
		//else if ((char_y[scan_idx] >= LOWER_BOUND | ((char_text[scan_idx] == cur_ascii) & (char_y[scan_idx] < UPPER_BOUND)))& char_color[scan_idx] != 4'h2) begin			
		
		
		else if (char_y[scan_idx] >= LOWER_BOUND & char_color[scan_idx] != 4'h2) begin	
			char_color[scan_idx] <= 4'h1;
			//char_valid[scan_idx] <= 0;//

			if(miss_sign[scan_idx] == 0) begin
				miss_num <= miss_num + 1;
				//update MISS# -27-28-29-
				if(LABEL_text[29] == 8'h39) begin
					LABEL_text[29] <= 8'h30;
					if(LABEL_text[28] == 8'h39) begin 				
						LABEL_text[28] <= 8'h30;
						LABEL_text[27] <= LABEL_text[27] + 1;
					end
					else begin
						LABEL_text[28] <= LABEL_text[28] + 1;
						LABEL_text[27] <= LABEL_text[27];
					end
				end
				else begin
					LABEL_text[29] <= LABEL_text[29] + 1; 
					LABEL_text[28] <= LABEL_text[28];
					LABEL_text[27] <= LABEL_text[27];
				end	
				LABEL_valid[29] <= 1;
				LABEL_valid[28] <= 1;
				LABEL_valid[27] <= 1;
			end
			
			if(miss_sign[scan_idx] == 0) miss_sign[scan_idx] <= 1;
			
		end
		
		
/*		else if ((ascii_valid[cur_ascii]) & (char_text[scan_idx] == cur_ascii) & (char_y[scan_idx] < UPPER_BOUND) & char_color[scan_idx] != 4'h2) begin	
			char_color[scan_idx] <= 4'h1;
			//char_valid[scan_idx] <= 0;//

			if(miss_sign[scan_idx] == 0) begin
				miss_num <= miss_num + 1;
				//update MISS# -27-28-29-
				if(LABEL_text[29] == 8'h39) begin
					LABEL_text[29] <= 8'h30;
					if(LABEL_text[28] == 8'h39) begin 				
						LABEL_text[28] <= 8'h30;
						LABEL_text[27] <= LABEL_text[27] + 1;
					end
					else begin
						LABEL_text[28] <= LABEL_text[28] + 1;
						LABEL_text[27] <= LABEL_text[27];
					end
				end
				else begin
					LABEL_text[29] <= LABEL_text[29] + 1; 
					LABEL_text[28] <= LABEL_text[28];
					LABEL_text[27] <= LABEL_text[27];
				end	
				LABEL_valid[29] <= 1;
				LABEL_valid[28] <= 1;
				LABEL_valid[27] <= 1;
			end
			*/
			//ascii_valid[cur_ascii] <= 0;//

	end	
	if(scan_idx >= CHAR_NUM) begin
		if (hit_or_badhit) begin
			if(char_y[m_idx] >= UPPER_BOUND & char_y[m_idx] < LOWER_BOUND) begin//hit
				hit_num <= hit_num + 1;
				//char_valid[m_idx] <= 0;
				char_color[m_idx] <= 4'h2;
	
				//update HIT# -19-20-21-
				if(LABEL_text[21] == 8'h39) begin
					LABEL_text[21] <= 8'h30;
					if(LABEL_text[20] == 8'h39) begin 				
						LABEL_text[20] <= 8'h30;
						LABEL_text[19] <= LABEL_text[19] + 1;
					end
					else begin
						LABEL_text[20] <= LABEL_text[20] + 1;
						LABEL_text[19] <= LABEL_text[19];
					end
				end
				else begin
					LABEL_text[21] <= LABEL_text[21] + 1; 
					LABEL_text[20] <= LABEL_text[20];
					LABEL_text[19] <= LABEL_text[19];
				end
					LABEL_valid[21] <= 1;
					LABEL_valid[20] <= 1;
					LABEL_valid[19] <= 1;			
			end
			else begin//badhit -> miss
				char_color[m_idx] <= 4'h1;
				//char_valid[scan_idx] <= 0;//
	
				if(miss_sign[m_idx] == 0) begin
					miss_num <= miss_num + 1;
					//update MISS# -27-28-29-
					if(LABEL_text[29] == 8'h39) begin
						LABEL_text[29] <= 8'h30;
						if(LABEL_text[28] == 8'h39) begin 				
							LABEL_text[28] <= 8'h30;
							LABEL_text[27] <= LABEL_text[27] + 1;
						end
						else begin
							LABEL_text[28] <= LABEL_text[28] + 1;
							LABEL_text[27] <= LABEL_text[27];
						end
					end
					else begin
						LABEL_text[29] <= LABEL_text[29] + 1; 
						LABEL_text[28] <= LABEL_text[28];
						LABEL_text[27] <= LABEL_text[27];
					end	
					LABEL_valid[29] <= 1;
					LABEL_valid[28] <= 1;
					LABEL_valid[27] <= 1;
				end
			end			
		end	
		scan_idx <= 0;
		hit_or_badhit <= 0;
		if (ascii_valid[ascii]) cur_ascii <= ascii;
		else cur_ascii <= 0;
		
		ascii_valid[cur_ascii] <= 0;
	end
	else begin
		scan_idx <= scan_idx + 1;
	end
	
	if (ascii != last_ascii) ascii_valid[last_ascii] <= 1;
	last_ascii <= ascii;
end
else if(state == 2'b11) begin
	//init <= 0;
	timer <= 0;
	hit_num <= 0;
	miss_num <= 0;
	LABEL_text[12] <= 8'h30;
	LABEL_text[13] <= 8'h30;
	LABEL_text[14] <= 8'h30;
	LABEL_text[19] <= 8'h30;
	LABEL_text[20] <= 8'h30;
	LABEL_text[21] <= 8'h30;
	LABEL_text[27] <= 8'h30;
	LABEL_text[28] <= 8'h30;
	LABEL_text[29] <= 8'h30;	
	char_valid <= 32'd0;
	
end
		
end


/*==========================*/

always @ (posedge clk) begin
	// GAME OVER
	END_x[0] <= 320;
	END_y[0] <= 200;
	END_text[0] <= 8'h47; // G
	END_color[0] <= 0;

	END_x[1] <= 328;
	END_y[1] <= 200;
	END_text[1] <= 8'h41; // A
	END_color[1] <= 3;

	END_x[2] <= 336;
	END_y[2] <= 200;
	END_text[2] <= 8'h4D; // M
	END_color[2] <= 0;

	END_x[3] <= 344;
	END_y[3] <= 200;
	END_text[3] <= 8'h45; // E
	END_color[3] <= 3;

	END_x[4] <= 360;
	END_y[4] <= 200;
	END_text[4] <= 8'h4F; // O
	END_color[4] <= 0;

	END_x[5] <= 368;
	END_y[5] <= 200;
	END_text[5] <= 8'h56; // V
	END_color[5] <= 3;

	END_x[6] <= 376;
	END_y[6] <= 200;
	END_text[6] <= 8'h45; // E
	END_color[6] <= 0;

	END_x[7] <= 384;
	END_y[7] <= 200;
	END_text[7] <= 8'h52; // R
	END_color[7] <= 3;

	// HIT
	END_x[8] <= 328;
	END_y[8] <= 216;
	END_text[8] <= 8'h48; // H
	END_color[8] <= 2;

	END_x[9] <= 336;
	END_y[9] <= 216;
	END_text[9] <= 8'h49; // I
	END_color[9] <= 2;

	END_x[10] <= 344;
	END_y[10] <= 216;
	END_text[10] <= 8'h54; // T
	END_color[10] <= 2;

	END_x[11] <= 360;
	END_y[11] <= 216;
	END_color[11] <= 2;

	END_x[12] <= 368;
	END_y[12] <= 216;
	END_color[12] <= 2;

	END_x[13] <= 376;
	END_y[13] <= 216;
	END_color[13] <= 2;

	// MISS
	END_x[14] <= 320;
	END_y[14] <= 232;
	END_text[14] <= 8'h4D; // M
	END_color[14] <= 1;

	END_x[15] <= 328;
	END_y[15] <= 232;
	END_text[15] <= 8'h49; // I
	END_color[15] <= 1;

	END_x[16] <= 336;
	END_y[16] <= 232;
	END_text[16] <= 8'h53; // S
	END_color[16] <= 1;

	END_x[17] <= 344;
	END_y[17] <= 232;
	END_text[17] <= 8'h53; // S
	END_color[17] <= 1;

	END_x[18] <= 360;
	END_y[18] <= 232;
	END_color[18] <= 1;

	END_x[19] <= 368;
	END_y[19] <= 232;
	END_color[19] <= 1;

	END_x[20] <= 376;
	END_y[20] <= 232;
	END_color[20] <= 1;

	if (state!=2'b11) begin
		END_valid <= 24'h000000;

		END_text[11] <= LABEL_text[19];
		END_text[12] <= LABEL_text[20];
		END_text[13] <= LABEL_text[21];

		END_text[18] <= LABEL_text[27];
		END_text[19] <= LABEL_text[28];
		END_text[20] <= LABEL_text[29];
	end else begin
		END_valid <= 24'hffffff;
		
		END_text[11] <= END_text[11];
		END_text[12] <= END_text[12];
		END_text[13] <= END_text[13];

		END_text[18] <= END_text[18];
		END_text[19] <= END_text[19];
		END_text[20] <= END_text[20];
	end
end


/*state : 2'b00=start, 2'b01=run, 2'b10=stop, 2'b11=finish
 *press ENTER to start game
 *press CTRL+T/t to stop; press ENTER to resume
 *when time == 60(s), game over, press ENTER to restart
 */

always @ (posedge clk) begin
	if ((state == 2'b00 | state == 2'b10 | state == 2'b11) & ascii == 8'h0d) begin// ENTER
		state <= 2'b01;//run
	end
	else if(state == 2'b01 & ctrl & (ascii == 8'h54 | ascii == 8'h74)) begin //CTRL+T/t
		state <= 2'b10;//stop
	end
	else if(state == 2'b01 & timer == 60 ) begin
		state <= 2'b11; //finish
		//init <= 1;//flag, init game settings
	end 

	else state <= state;
end

wire start_pixel;
start_vga st_buf(v_addr+512*h_addr, vga_clk, start_pixel);
wire [23:0] st_data, end_data;
assign st_data = start_pixel==0? 24'hffffff:24'h000000;

assign end_data = 24'hffffff;

// assign vga_data = (state == 2'b00)? st_data : (state == 2'b11) ? end_data : run_data;
assign vga_data = (state == 2'b00)? st_data : run_data;

endmodule
