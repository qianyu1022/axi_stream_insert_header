module axi_stream_insert_header #(
	parameter DATA_WD 		= 32,
	parameter DATA_BYTE_WD 	= DATA_WD / 8,
	parameter BYTE_CNT_WD 	= $clog2(DATA_BYTE_WD)
) (
	input clk,
	input rst_n,

	// AXI Stream input original data
	input 							valid_in,
	input 	[DATA_WD-1 : 0] 		data_in,
	input 	[DATA_BYTE_WD-1 : 0] 	keep_in,
	input 							last_in,
	output 							ready_in,
	
	// AXI Stream output with header inserted
	output reg						valid_out,
	output reg	[DATA_WD-1 : 0] 	data_out,
	output reg	[DATA_BYTE_WD-1:0] 	keep_out,
	output reg						last_out,
	input 							ready_out,
	
	// The header to be inserted to AXI Stream input
	input 							valid_insert,
	input 	[DATA_WD-1 : 0] 		header_insert,
	input 	[DATA_BYTE_WD-1 : 0] 	keep_insert,
	input 	[BYTE_CNT_WD : 0] 		byte_insert_cnt,
	output 							ready_insert
);
	wire 		valid_up_buf1;
	wire 		ready_up_buf1;
	reg [38:0]	data_in_buf1;

	wire 		valid_buf;
	wire 		ready_buf;
	wire [38:0]	data_buf;

	wire 		valid_down_buf2;
	wire 		ready_down_buf2;
	wire [38:0]	data_out_buf2;

	buffer buffer1_inst1(
		.clk(clk),
		.rst_n(rst_n),
		.valid_up(valid_up_buf1),
		.ready_up(ready_up_buf1),
		.data_in(data_in_buf1),

		.valid_down(valid_buf),
		.ready_down(ready_buf),
		.data_out(data_buf)
		);

	buffer buffer2_inst2(
		.clk(clk),
		.rst_n(rst_n),
		.valid_up(valid_buf),
		.ready_up(ready_buf),
		.data_in(data_buf),

		.valid_down(valid_down_buf2),
		.ready_down(ready_down_buf2),
		.data_out(data_out_buf2)
		);
	
	wire	[38:0] 	buffer1;
	wire	[38:0]	buffer2;

	assign 	buffer1 = data_buf;
	assign	buffer2 = data_out_buf2;
	
	reg sel;
	always@ (posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			sel <= 'b0;
		end
		else if (valid_insert & ready_insert) begin
			sel <= 1'b1;
		end
		else if (last_in & ready_in & valid_in ) begin
			sel <= 'b0;
		end
	end

	assign valid_up_buf1 	= (~sel) ? valid_insert : valid_in;
	assign ready_in 		= (sel) ?  ready_up_buf1 : 0;
	assign ready_insert 	= (~sel) ? ready_up_buf1 : 0;


	wire 	start;
	wire 	inter;
	wire 	terminate;

	assign 	start 		= valid_insert & ready_insert;
	assign	inter 		= valid_in & ready_in & (~last_in);
	assign	terminate 	= valid_in & ready_in & last_in;
	
	always@ (*) begin
		case ({start,inter,terminate})
			3'b100: data_in_buf1 = {start,inter,terminate,keep_insert[3:0],header_insert[31:0]};
			3'b010: data_in_buf1 = {start,inter,terminate,4'b1111,data_in[31:0]};
			3'b001: data_in_buf1 = {start,inter,terminate,keep_in[3:0],data_in[31:0]};	
			default: data_in_buf1 = 'b0;		
		endcase
	end
	
	wire	buffer1_data_valid;
	wire 	buffer2_data_valid;
	
	wire 	buffer1_inter;
	wire	buffer1_terminate;
	wire 	buffer2_start;
	wire 	buffer2_inter;
	wire 	buffer2_terminate;

	wire 	case1_valid;
	wire 	case2_valid;
	wire 	case3_valid;
	wire	case4_valid;
	
	wire	[3:0]	buffer1_keep;
	wire 	[3:0] 	buffer2_keep;
	reg		[3:0]	keep_ff;

	reg     [3:0]   keep_ff_case3_next;

	assign 	buffer1_keep		= data_buf[35:32];
	assign	buffer1_inter 		= data_buf[37];
	assign 	buffer1_terminate 	= data_buf[36];
	assign	buffer2_keep 		= data_out_buf2[35:32];
	assign 	buffer2_start 		= data_out_buf2[38];
	assign	buffer2_inter 		= data_out_buf2[37];
	assign 	buffer2_terminate	= data_out_buf2[36];

	assign 	buffer1_data_valid 	= valid_buf;
	assign	buffer2_data_valid 	= valid_down_buf2;
	assign 	valid_out 			= case1_valid | case2_valid | case3_valid | case4_valid;
	assign 	ready_down_buf2 	= valid_out & ready_out;

	assign 	case1_valid = buffer1_data_valid & buffer2_data_valid & buffer1_inter & buffer2_start & (buffer2_keep != 4'd0);
	assign 	case2_valid = buffer1_data_valid & buffer2_data_valid & buffer1_inter & buffer2_inter;
	assign 	case3_valid = buffer1_data_valid & buffer2_data_valid & buffer1_terminate & buffer2_inter;
	assign 	case4_valid = buffer2_data_valid & buffer2_terminate & (keep_ff != 4'b0000);

	always@ (posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			keep_ff <= 4'b0;
		end
		else if (case1_valid & valid_out & ready_out) begin
			keep_ff <= buffer2_keep;
		end
		else if(case3_valid & valid_out & ready_out) begin 
			keep_ff	<= keep_ff_case3_next;
		end 
	end

	always@ (*) begin
		keep_ff_case3_next = 4'd0;
		if (case1_valid) begin
			last_out = 'b0;
			keep_out = 4'b1111;
			case (buffer2_keep)
				4'b0001: data_out = {buffer2[7:0],buffer1[31:8]};
				4'b0011: data_out = {buffer2[15:0],buffer1[31:16]};
				4'b0111: data_out = {buffer2[23:0],buffer1[31:24]};
				4'b1111: data_out =  buffer2[31:0];
				default: data_out = 32'b0;
			endcase
		end
		else if (case2_valid) begin
			last_out = 'b0;
			keep_out = 4'b1111;
			case (keep_ff)
				4'b0000: data_out =  buffer2[31:0];
				4'b0001: data_out = {buffer2[7:0],buffer1[31:8]};
				4'b0011: data_out = {buffer2[15:0],buffer1[31:16]};
				4'b0111: data_out = {buffer2[23:0],buffer1[31:24]};
				4'b1111: data_out =  buffer2[31:0];
				default: data_out = 32'b0;
			endcase
		end
		else if (case3_valid) begin
			case (buffer1_keep)
				4'b1111: begin
						case(keep_ff)
							4'b0000: begin
										keep_ff_case3_next = 4'b1111;
										data_out =  buffer2[31:0];
										keep_out =  4'b1111;
										last_out =  'b0; end
							4'b0001: begin
										keep_ff_case3_next = 4'b0001;
										data_out = {buffer2[7:0],buffer1[31:8]};
										keep_out =  4'b1111; 
										last_out =  'b0; end
							4'b0011: begin
										keep_ff_case3_next = 4'b0011;
										data_out = {buffer2[15:0],buffer1[31:16]};
										keep_out =  4'b1111; 
										last_out =  'b0; end
							4'b0111: begin	
										keep_ff_case3_next = 4'b0111;
										data_out = {buffer2[23:0],buffer1[31:24]};
										keep_out =  4'b1111; 
										last_out =  'b0; end
							4'b1111: begin	
										keep_ff_case3_next = 4'b1111;
										data_out =  buffer2[31:0];
										keep_out =  4'b1111; 
										last_out =  'b0; end
							default: begin
										data_out = 32'b0;
										last_out = 'b0;
										keep_out = 'b0; end
						endcase
				end
				4'b1110: begin
						case(keep_ff)
							4'b0000: begin
										keep_ff_case3_next = 4'b1110;
										data_out = buffer2[31:0];
										keep_out =  4'b1111; 
										last_out =  1'b0; end
							4'b0001: begin
										keep_ff_case3_next = 4'b0000;
										data_out = {buffer2[7:0],buffer1[31:8]};
										keep_out =  4'b1111; 
										last_out =  1'b1; end
							4'b0011: begin
										keep_ff_case3_next = 4'b0010;
										data_out = {buffer2[15:0],buffer1[31:16]};
										keep_out =  4'b1111; 
										last_out =  'b0; end
							4'b0111: begin	
										keep_ff_case3_next = 4'b0110;
										data_out = {buffer2[23:0],buffer1[31:24]};
										keep_out =  4'b1111; 
										last_out =  'b0; end
							4'b1111: begin	
										keep_ff_case3_next = 4'b1110;
										data_out = buffer2[31:0];
										keep_out =  4'b1111; 
										last_out =  1'b0; end
							default: begin
										data_out = 32'b0;
										last_out = 'b0;
										keep_out = 'b0; end
						endcase
				end
				4'b1100: begin
						case(keep_ff)
							4'b0000: begin
										keep_ff_case3_next = 4'b1100;
										data_out = buffer2[31:0];
										keep_out =  4'b1111; 
										last_out =  1'b0; end
							4'b0001: begin
										keep_ff_case3_next = 4'b0000;
										data_out = {buffer2[7:0],buffer1[31:16],8'b0};
										keep_out =  4'b1110; 
										last_out =  1'b1; end
							4'b0011: begin
										keep_ff_case3_next = 4'b0000;
										data_out = {buffer2[15:0],buffer1[31:16]};
										keep_out =  4'b1111; 
										last_out =  1'b1; end
							4'b0111: begin	
										keep_ff_case3_next = 4'b0100;
										data_out = {buffer2[23:0],buffer1[31:24]};
										keep_out =  4'b1111; 									
										last_out =  1'b0; end
							4'b1111: begin	
										keep_ff_case3_next = 4'b1100;
										data_out = buffer2[31:0];
										keep_out =  4'b1111; 
										last_out =  1'b0; end
							default: begin
										data_out = 32'b0;
										last_out = 'b0;
										keep_out = 'b0; end
						endcase
				end
				4'b1000: begin
						case(keep_ff)
							4'b0000: begin
										keep_ff_case3_next = 4'b1000;
										data_out = buffer2[31:0];
										keep_out =  4'b1111; 
										last_out = 'b0; end
							4'b0001: begin
										keep_ff_case3_next = 4'b0000;
										data_out = {buffer2[7:0],buffer1[31:24],16'b0};
										keep_out =  4'b1100; 
										last_out = 'b1; end
							4'b0011: begin
										keep_ff_case3_next = 4'b0000;
										data_out = {buffer2[15:0],buffer1[31:24],8'b0};
										keep_out =  4'b1110; 
										last_out = 'b1; end
							4'b0111: begin	
										keep_ff_case3_next = 4'b0000;
										data_out = {buffer2[23:0],buffer1[31:24]};
										keep_out =  4'b1111; 
										last_out = 'b1; end
							4'b1111: begin	
										keep_ff_case3_next = 4'b1000;
										data_out =  buffer2[31:0];
										keep_out =  4'b1000; 
										last_out = 'b0;end
							default: begin
										data_out = 32'b0;
										last_out = 'b0;
										keep_out = 'b0; end
						endcase
				end
				default: begin
							data_out = 32'b0;
							last_out = 'b0;
							keep_out = 'b0;
						end
			endcase
		end
		else if (case4_valid) begin
			case (keep_ff)
				4'b1000: begin 
					data_out = {buffer2[31:24], 24'd0};
					last_out = 'b1;
					keep_out = 'b1000; end
				4'b1100: begin 
					data_out = {buffer2[31:16], 16'd0};
					last_out = 'b1;
					keep_out = 'b1100; end
				4'b0100: begin 
					data_out = {buffer2[23:16], 24'd0};
					last_out = 'b1;
					keep_out = 'b1000; end
				4'b1111: begin 
					data_out =  buffer2[31:0];
					last_out = 'b1;
					keep_out = 'b1111; end
				4'b0001: begin 
					data_out = {buffer2[7:0], 24'd0};
					last_out = 'b1;
					keep_out = 'b1000;	end
				4'b0011: begin 
					data_out = {buffer2[15:0], 16'd0};
					last_out = 'b1;
					keep_out = 'b1100; end
				4'b0111: begin 
					data_out = {buffer2[23:0], 8'd0};
					last_out = 'b1;
					keep_out = 'b1110; end
				4'b1110: begin 
					data_out = {buffer2[31:8], 7'd0};
					last_out = 'b1;
					keep_out = 'b1110; end
				4'b0010: begin 
					data_out = {buffer2[15:8], 24'd0};
					last_out = 'b1;
					keep_out = 'b1000; end
				4'b0110: begin 
					data_out = {buffer2[23:8], 16'd0};
					last_out = 'b1;
					keep_out = 'b1100; end
				default: begin 
					data_out = 32'd0;
					last_out = 'b0;
					keep_out = 'b0;
				end
			endcase
		end
		else begin
			data_out = 32'b0;
			last_out = 'b0;
			keep_out = 'b0;
		end
	end

endmodule

