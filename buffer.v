module buffer(
	input clk,
	input rst_n,

	input valid_up,
	input [38:0] data_in,
	output ready_up,


	output valid_down,
	output [38:0] data_out,
	input ready_down
);

	reg 		buffer_data_valid;
	reg [38:0] 	buffer_data;

	assign ready_up = ~buffer_data_valid;

	always@(posedge clk or negedge rst_n) begin 
		if (rst_n == 1'b0) begin 
			buffer_data_valid <= 1'b0;
		end 
		else if (valid_down & ready_down) begin
			buffer_data_valid <= 1'b0;
		end
		else if (valid_up & ready_up) begin 
			buffer_data_valid <= 1'b1;
		end
	end

	always@(posedge clk or negedge rst_n) begin 
		if (rst_n == 1'b0) begin 
			buffer_data <= 32'd0;
		end 
		else if (valid_up & ready_up) begin 
			buffer_data <= data_in;
		end
	end

	assign valid_down = buffer_data_valid;
	assign data_out = buffer_data;
endmodule