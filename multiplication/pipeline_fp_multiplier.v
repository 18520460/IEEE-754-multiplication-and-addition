//`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Created by: Nguyen Pham The Anh 
// 
// Create Date: 03/12/2021 08:15:04 PM
// Module Name: fp_mul
// Project Name: FPGA implement for exponential fuction
// Description: single-cycle fp32 multiplier
//////////////////////////////////////////////////////////////////////////////////


module pipeline_fp_multiplier(
    clk,
    rst,
    input_valid,
    output_valid,
	A,     /*float32 A input*/
	B,     /*float32 B input*/
	OUT    /*float32 output*/
);
    input             clk, rst, input_valid;
	input      [31:0] A, B; 
	output wire output_valid;  
	output     [31:0] OUT;
    /*------------------------------------------------------*/
    /*------------------stage 1(load input)-----------------*/
    /*------------------------------------------------------*/
    reg [31:0] stage_1_A, stage_1_B;
    reg        stage_1_input_valid;
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            stage_1_A <= 32'd0;
            stage_1_B <= 32'd0;  
            stage_1_input_valid <= 1'd0;
        end else if(input_valid) begin
            stage_1_A <= A;
            stage_1_B <= B;
            stage_1_input_valid <= input_valid;
        end else begin
            stage_1_A <= 32'dz;
            stage_1_B <= 32'dz; 
            stage_1_input_valid <= input_valid; 
        end
    end
    /*------------------------------------------------------*/
    /*---------stage 2(exp calculate and sign)--------------*/
    /*------------------------------------------------------*/
    reg stage_2_input_valid, stage_2_z_s;
    reg [31:0] stage_2_A, stage_2_B;
    reg [23:0] stage_2_a_m, stage_2_b_m;
    reg [9:0] stage_2_a_e, stage_2_b_e;
    always @(posedge clk or posedge rst) begin
        if(rst) begin 
            stage_2_input_valid <= 1'd0;
            stage_2_a_e <= 10'd0;
            stage_2_b_e <= 10'd0;
            stage_2_a_m <= 24'd0;
            stage_2_b_m <= 24'd0;
            stage_2_z_s <= 1'd0;
            stage_2_A <= 32'd0;
            stage_2_B <= 32'd0;
        end else begin
            stage_2_input_valid <= stage_1_input_valid;
            stage_2_a_e <= stage_1_A[30:23] - 10'd127;
            stage_2_b_e <= stage_1_B[30:23] - 10'd127;
            stage_2_a_m[22:0] = stage_1_A[22:0];
            stage_2_b_m[22:0] = stage_1_B[22:0];
            stage_2_z_s <= stage_1_A[31] ^ stage_1_B[31];
            stage_2_A <= stage_1_A;
            stage_2_B <= stage_1_B;
        end
    end
    /*------------------------------------------------------*/
    /*-----------------stage 3(check a_e, b_e)--------------*/
    /*------------------------------------------------------*/
    reg stage_3_input_valid, stage_3_z_s;
    reg [31:0] stage_3_A, stage_3_B;
    reg [23:0] stage_3_a_m, stage_3_b_m;
    reg [9:0]  stage_3_a_e, stage_3_b_e;
    always @(posedge clk or posedge rst) begin
        if(rst) begin 
            stage_3_input_valid <= 1'd0;
            stage_3_a_e <= 10'd0;
            stage_3_b_e <= 10'd0;
            stage_3_a_m <= 24'd0;
            stage_3_b_m <= 24'd0;
            stage_3_z_s <= 1'd0;
            stage_3_A <= 32'd0;
            stage_3_B <= 32'd0;
        end else begin
            stage_3_input_valid <= stage_2_input_valid;
            //assign     {a_m[23] , a_e} = ($signed(tmp_a_e) == -127) ? {1'b0, -10'sd126} : {1'b1, tmp_a_e};
            //assign     {b_m[23] , b_e} = ($signed(tmp_b_e) == -127) ? {1'b0, -10'sd126} : {1'b1, tmp_b_e};
            stage_3_a_e <= ($signed(stage_2_a_e) == -127) ? -10'sd126 : stage_2_a_e; 
            stage_3_b_e <= ($signed(stage_2_b_e) == -127) ? -10'sd126 : stage_2_b_e; //fix bug v1.0
            stage_3_a_m[23] <= ($signed(stage_2_a_e) == -127) ? 1'b0 : 1'b1;
            stage_3_b_m[23] <= ($signed(stage_2_b_e) == -127) ? 1'b0 : 1'b1;
            stage_3_a_m[22:0] <= stage_2_a_m[22:0];
            stage_3_b_m[22:0] <= stage_2_b_m[22:0];
            stage_3_z_s <= stage_2_z_s;
            stage_3_A <= stage_2_A;
            stage_3_B <= stage_2_B;
        end
    end
    /*------------------------------------------------------*/
    /*-------------------stage 4(check matisa)--------------*/
    /*------------------------------------------------------*/
    reg stage_4_input_valid, stage_4_z_s;
    reg [31:0] stage_4_A, stage_4_B;
    reg [23:0] stage_4_a_m, stage_4_b_m;
    reg [9:0]  stage_4_a_e, stage_4_b_e;
    always @(posedge clk or posedge rst) begin
        if(rst) begin 
            stage_4_input_valid <= 1'b0;
            stage_4_z_s <= 1'b0;
            stage_4_a_e <= 10'd0;
            stage_4_b_e <= 10'd0;
            stage_4_a_m <= 24'd0;
            stage_4_b_m <= 24'd0;
            stage_4_A <= 32'd0;
            stage_4_B <= 32'd0;
        end else begin
            stage_4_input_valid <= stage_3_input_valid;
            stage_4_z_s <= stage_3_z_s;
            stage_4_a_e <= (!stage_3_a_m[23]) ? stage_3_a_e - 10'd1 : stage_3_a_e;
            stage_4_b_e <= (!stage_3_b_m[23]) ? stage_3_b_e - 10'd1 : stage_3_b_e;
            stage_4_a_m <= (!stage_3_a_m[23]) ? stage_3_a_m << 1 : stage_3_a_m;
            stage_4_b_m <= (!stage_3_b_m[23]) ? stage_3_b_m << 1 : stage_3_b_m;
            stage_4_A <= stage_3_A;
            stage_4_B <= stage_3_B;
        end
    end
    /*------------------------------------------------------*/
    /*-------------------stage 5(check matisa)--------------*/
    /*------------------------------------------------------*/
    reg stage_5_z_s, stage_5_input_valid;
    reg [31:0] stage_5_A, stage_5_B;
    reg [23:0] stage_5_a_m, stage_5_b_m;
    reg [9:0] stage_5_z_e;
    always @(posedge clk or posedge rst) begin
        if(rst) begin 
            stage_5_input_valid <= 1'b0;
            stage_5_z_s <= 1'b0;
            stage_5_z_e <= 10'd0;
            stage_5_a_m <= 24'd0;
            stage_5_b_m <= 24'd0;
            stage_5_A <= 32'd0;
            stage_5_B <= 32'd0;
        end else begin
            stage_5_input_valid <= stage_4_input_valid;
            stage_5_z_s <= stage_4_z_s;
            stage_5_z_e <= stage_4_a_e + stage_4_b_e + 10'd1;
            stage_5_a_m <= stage_4_a_m;
            stage_5_b_m <= stage_4_b_m;
            stage_5_A <= stage_4_A;
            stage_5_B <= stage_4_B;
        end
    end
    /*------------------------------------------------------*/
    /*-------------------stage 6(mul)-----------------------*/
    /*------------------------------------------------------*/
    reg stage_6_input_valid, stage_6_z_s;
    reg [31:0] stage_6_A, stage_6_B;
    reg [9:0] stage_6_z_e;
    reg [49:0] stage_6_product; 
    always @(posedge clk or posedge rst) begin
        if(rst) begin 
            stage_6_input_valid <= 1'b0;
            stage_6_z_s <= 1'b0;
            stage_6_z_e <= 10'd0;
            stage_6_product <= 50'd0;
            stage_6_A <= 32'd0;
            stage_6_B <= 32'd0;
        end else begin
            stage_6_input_valid <= stage_5_input_valid;
            stage_6_z_s <= stage_5_z_s;
            stage_6_z_e <= stage_5_z_e;
            stage_6_product <= stage_5_a_m * stage_5_b_m; 
            stage_6_A <= stage_5_A;
            stage_6_B <= stage_5_B;
        end
    end
    /*------------------------------------------------------*/
    /*-------------------stage 7(product * 4)---------------*/
    /*------------------------------------------------------*/
    reg stage_7_input_valid, stage_7_z_s;
    reg [31:0] stage_7_A, stage_7_B;
    reg [9:0] stage_7_z_e;
    reg [49:0] stage_7_product; 
    always @(posedge clk or posedge rst) begin
        if(rst) begin 
            stage_7_input_valid <= 1'b0;
            stage_7_z_s <= 1'b0;
            stage_7_z_e <= 10'd0;
            stage_7_product <= 50'd0;
            stage_7_A <= 32'd0;
            stage_7_B <= 32'd0;
        end else begin
            stage_7_input_valid <= stage_6_input_valid;
            stage_7_z_s <= stage_6_z_s;
            stage_7_z_e <= stage_6_z_e;
            stage_7_product <= stage_6_product << 2;
            stage_7_A <= stage_6_A;
            stage_7_B <= stage_6_B;
        end
    end
    /*------------------------------------------------------*/
    /*---stage 8(z_e, z_m, guard, round_bit, sticky)--------*/
    /*------------------------------------------------------*/
    reg stage_8_input_valid, stage_8_z_s, stage_8_guard, stage_8_round_bit, stage_8_sticky;
    reg [31:0] stage_8_A, stage_8_B;
    reg [23:0] stage_8_z_m;
    reg [9:0]  stage_8_z_e;
    always @(posedge clk or posedge rst) begin
        if(rst) begin 
            stage_8_input_valid <= 1'b0;
            stage_8_z_s <= 1'b0;
            stage_8_z_e <= 10'd0;
            stage_8_z_m <= 24'd0;
            stage_8_guard <= 1'b0;
            stage_8_round_bit <= 1'b0;
            stage_8_sticky <= 1'b0;
            stage_8_A <= 32'd0;
            stage_8_B <= 32'd0;
        end else begin
            stage_8_input_valid <= stage_7_input_valid;
            stage_8_z_s <= stage_7_z_s;
            stage_8_z_e <= (stage_7_product[49] == 0) ? stage_7_z_e - 10'd1 : stage_7_z_e;
            stage_8_z_m <= (stage_7_product[49] == 0) ? (stage_7_product[49:26] << 1) + stage_7_product[25] : stage_7_product[49:26];
            stage_8_guard <= (stage_7_product[49] == 0) ? stage_7_product[24] : stage_7_product[25];
            stage_8_round_bit <= (stage_7_product[49] == 0) ? 1'b0 : stage_7_product[24];
            stage_8_sticky <= (stage_7_product[23:0] != 0);
            stage_8_A <= stage_7_A;
            stage_8_B <= stage_7_B;
        end
    end
    /*------------------------------------------------------*/
    /*---------stage 9(z_e, z_m, guard, round_bit, sticky)--*/
    /*------------------------------------------------------*/
    reg stage_9_input_valid, stage_9_z_s, stage_9_guard, stage_9_round_bit, stage_9_sticky;
    reg [31:0] stage_9_A, stage_9_B;
    reg [23:0] stage_9_z_m;
    reg [9:0]  stage_9_z_e;
    always @(posedge clk or posedge rst) begin
        if(rst) begin 
            stage_9_input_valid <= 1'b0;
            stage_9_z_s <= 1'b0;
            stage_9_z_e <= 10'd0;
            stage_9_z_m <= 24'd0;
            stage_9_guard <= 1'b0;
            stage_9_round_bit <= 1'b0;
            stage_9_sticky <= 1'b0;
            stage_9_A <= 32'd0;
            stage_9_B <= 32'd0;
        end else begin
            stage_9_input_valid <= stage_8_input_valid;
            stage_9_z_s <= stage_8_z_s;
            stage_9_z_e <= ($signed(stage_8_z_e) < -126) ? stage_8_z_e + 10'd1 : stage_8_z_e;
            stage_9_z_m <= ($signed(stage_8_z_e) < -126) ? stage_8_z_m >> 1 : stage_8_z_m;
            stage_9_guard <= ($signed(stage_8_z_e) < -126) ? stage_8_z_m[0] : stage_8_guard;
            stage_9_round_bit <= ($signed(stage_8_z_e) < -126) ? stage_8_guard : stage_8_round_bit;
            stage_9_sticky <= ($signed(stage_8_z_e) < -126) ? stage_8_sticky | stage_8_round_bit : stage_8_sticky;
            stage_9_A <= stage_8_A;
            stage_9_B <= stage_8_B;
        end
    end
    /*------------------------------------------------------*/
    /*--------stage 10(z_e, z_m, guard, round_bit, sticky)--*/
    /*------------------------------------------------------*/
    reg stage_10_input_valid, stage_10_z_s;
    reg [23:0] stage_10_z_m;
    reg [9:0]  stage_10_z_e;
    always @(posedge clk or posedge rst) begin
        if(rst) begin 
            stage_10_input_valid <= 1'b0;
            stage_10_z_s <= 1'b0;
            stage_10_z_e <= 10'd0;
            stage_10_z_m <= 24'd0;
        end else begin
            stage_10_input_valid <= stage_9_input_valid;
            stage_10_z_s <= stage_9_z_s;
            stage_10_z_e <= (stage_9_guard && (stage_9_round_bit | stage_9_sticky | stage_9_z_m[0]) && stage_9_z_m == 24'hffffff) ? stage_9_z_e + 10'd1 : stage_9_z_e;
            stage_10_z_m <= (stage_9_guard && (stage_9_round_bit | stage_9_sticky | stage_9_z_m[0])) ? stage_9_z_m + 24'd1 : stage_9_z_m;
        end
    end
    /*------------------------------------------------------*/
    /*------------------stage 11(z_e)-----------------------*/
    /*------------------------------------------------------*/
    reg stage_11_input_valid, stage_11_z_s;
    reg [31:0] stage_11_A, stage_11_B;
    reg [23:0] stage_11_z_m;
    reg [9:0]  stage_11_z_e, stage_11_z_e_1;
    always @(posedge clk or posedge rst) begin
        if(rst) begin 
            stage_11_input_valid <= 1'b0;
            stage_11_z_s <= 1'b0;
            stage_11_z_e <= 10'd0;
            stage_11_z_e_1 <= 10'd0;
            stage_11_z_m <= 24'd0;
            stage_11_A <= 32'd0;
            stage_11_B <= 32'd0;
        end else begin
            stage_11_input_valid <= stage_10_input_valid;
            stage_11_z_s <= stage_10_z_s;
            stage_11_z_e <= stage_10_z_e[7:0] + 8'd127;
            stage_11_z_e_1 <= stage_10_z_e;
            stage_11_z_m <= stage_10_z_m;
            stage_11_A <= stage_9_A;
            stage_11_B <= stage_9_B;
        end
    end
     /*-----------------------------------------------------*/
    /*------------------stage 12----------------------------*/
    /*------------------------------------------------------*/
    reg [31:0] stage_12_OUT;
    wire [31:0] RESULT;
    reg stage_12_input_valid;
    assign RESULT = ($signed(stage_11_z_e_1) == -10'sd126 && stage_11_z_m[23] == 1'b0) ? {stage_11_z_s, 8'h00, stage_11_z_m[22:0]} :
					($signed(stage_11_z_e_1) > 10'sd127)                        ? {stage_11_z_s, 8'hff, 23'd0} /*overflow*/ : 
							                                             {stage_11_z_s, stage_11_z_e[7:0], stage_11_z_m[22:0]};
    always @(posedge clk or posedge rst) begin
        if(rst) begin 
            stage_12_OUT <= 32'd0;
            stage_12_input_valid <= 1'b0;
        end else begin
            stage_12_input_valid <= stage_11_input_valid;
            stage_12_OUT <= (((stage_11_A[31:23] == {1'b0, 8'hff}) && stage_11_A[22:0] != 0) || ((stage_11_B[31:23] == {1'b0, 8'hff}) && stage_11_B[22:0] != 0 /*v1.5*/)) ? {1'b0, 8'hff, 1'b1, 22'd0} : /*nan*/
					 ((stage_11_A[30-:8] == 8'hff && A[22:0] == 0) || (stage_11_B[30-:8] == 8'hff && stage_11_B[22:0] == 0) /*v1.5*/) ? {stage_11_z_s, 8'hff, 23'd0} : /*inf*/
					 ((stage_11_A == 0) || (B == 0)) ? {32'd0} : /*zero*/
					 RESULT;
        end
    end
    assign OUT = stage_12_OUT;
    assign output_valid = stage_12_input_valid;
endmodule

