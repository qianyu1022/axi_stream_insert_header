module axi_tb;

	parameter DATA_WD 		= 32;
	parameter DATA_BYTE_WD 	= DATA_WD / 8;
	parameter BYTE_CNT_WD 	= $clog2(DATA_BYTE_WD);

	reg	clk;
	reg	rst_n;
	reg 							valid_in;
	reg 	[DATA_WD-1 : 0] 		data_in;
	reg 	[DATA_BYTE_WD-1 : 0] 	keep_in;
	reg								last_in;
	wire 							ready_in;
	
	// AXI Stream output with header inserted
	wire 							valid_out;
	wire 	[DATA_WD-1 : 0] 		data_out;
	wire 	[DATA_BYTE_WD-1 : 0] 	keep_out;
	wire 							last_out;
	reg 							ready_out;
	
	// The header to be inserted to AXI Stream input
	reg 							valid_insert;
	reg 	[DATA_WD-1 : 0] 		header_insert;
	reg 	[DATA_BYTE_WD-1 : 0] 	keep_insert;
	reg 	[BYTE_CNT_WD : 0] 		byte_insert_cnt;
	wire 							ready_insert;



initial begin
	clk = 0;
	rst_n = 0;	
	#30;
	rst_n = 1'b1;
end // initial
	


initial begin
	valid_insert = 1'b0;
	header_insert = 32'd0;	
	keep_insert = 4'b0111;
	byte_insert_cnt = 3'b011;
	@(posedge rst_n);

	@(posedge clk);
		header_insert <= 32'h12345678;
		valid_insert <= 1'b1;
	//等待握手成功
	wait((valid_insert & ready_insert) == 1'b1);
	//在握手成功的下一个周期将valid置1。
	@(posedge clk);
		valid_insert <= 1'b0;		
end // initial
	

initial begin
	data_in = 32'd0;
	valid_in = 1'b0;	
	keep_in = 4'b1111;
	last_in = 1'b0;
	@(posedge rst_n);

	@(posedge clk);
		data_in <= 32'haabbccdd;
		valid_in <= 1'b1;
	wait((valid_in & ready_in) == 1'b1);
	//在握手成功的下一周期，输入新的数据。
	@(posedge clk);
		data_in <= 32'heeff0011;
		valid_in <= 1'b1;
	wait((valid_in & ready_in) == 1'b1);

	@(posedge clk);
		data_in <= 32'haabbccdd;
		valid_in <= 1'b1;
		last_in  <= 1'b1;
	wait((valid_in & ready_in) == 1'b1);

	@(posedge clk);
		valid_in <= 1'b0;
		last_in  <= 1'b0;
	#200;
// 不在此处finish，防止wait不到握手成功导致仿真卡死。
//	$finish;

end // initial
	

//设置仿真时间为50个时钟周期。
initial begin
	#500;
	$finish;
end // initial
	


//下游一直ready。
initial begin
	ready_out = 1'b1;
end




	always #5 begin
   		clk = ~clk;
	end

	axi_stream_insert_header u1 (
		.clk(clk),
		.rst_n(rst_n),
		.valid_in(valid_in),
		.data_in(data_in),
		.keep_in(keep_in),
		.last_in(last_in),
		.ready_in(ready_in),
		.valid_out(valid_out),
		.data_out(data_out),
		.keep_out(keep_out),
		.last_out(last_out),
		.ready_out(ready_out),
		.valid_insert(valid_insert),
		.header_insert(header_insert),
		.keep_insert(keep_insert),
		.byte_insert_cnt(byte_insert_cnt),
		.ready_insert(ready_insert)
		);

endmodule
