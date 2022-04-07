module yMux1(z, a, b, c);
	output z;
	input a, b, c;
	wire notC, upper, lower;
	not my_not(notC, c);
	and upperAnd(upper, a, notC);
	and lowerAnd(lower, c, b);
	or my_or(z, upper, lower);
endmodule

module yMux(z, a, b, c);
	parameter SIZE = 2;
	output [SIZE-1:0] z;
	input [SIZE-1:0] a, b;
	input c;
	yMux1 mine[SIZE-1:0] (z, a, b, c);
endmodule

module yMux4to1(z, a0, a1, a2, a3, c);
	parameter SIZE = 2;
	output [SIZE-1:0] z;
	input [SIZE-1:0] a0, a1, a2, a3;
	input [1:0] c;
	
	wire [SIZE-1:0] zLo, zHi;
	yMux #(SIZE) lo(zLo, a0, a1, c[0]);
	yMux #(SIZE) hi(zHi, a2, a3, c[0]);
	yMux #(SIZE) final(z, zLo, zHi, c[1]);
endmodule

module yAdder1(z, cout, a, b, cin);
	output z, cout;
	input a, b, cin;
	xor left_xor(tmp, a, b);
	xor right_xor(z, cin, tmp);
	and left_and(outL, a, b);
	and right_and(outR, tmp, cin);
	or my_or(cout, outR, outL);
endmodule

module yAdder(z, cout, a, b, cin);
	output[31:0] z;
	output cout;
	
	input[31:0] a, b;
	input cin;
	
	wire[31:0] in, out;
	
	yAdder1 mine[31:0](z, out, a, b, in);
	assign in[0] = cin;
	assign in[31:1] = out[30:0];
endmodule

module yArith(z, cout, a, b, ctrl);
	output [31:0] z;
	output cout;
	input [31:0] a, b;
	input ctrl;
	wire [31:0] notB, tmp;
	wire cin;
	assign cin = ctrl;
	not invB[31:0] (notB, b);
	yMux #(32) chooseB(tmp, b, notB, ctrl);
	yAdder arith(z, cout, a, tmp, cin);
endmodule

module yAlu(z, ex, a, b, op);
	input [31:0] a, b;
	input [2:0] op;
	output [31:0] z;
	output ex;
	
	wire [31:0] zAnd, zOr, zArith, slt;
	wire [31:0] tmp;
	
	assign slt[31:1] = 0;
	assign ex = ~(| z);
	
	and andOut[31:0] (zAnd, a, b);
	or orOut[31:0] (zOr, a, b);
	yArith arithOut (zArith, ,a, b, op[2]);
	yMux4to1 #(32) muxOut(z, zAnd, zOr, zArith, slt, op[1:0]);
	
	xor(condition, a[31], b[31]);
	yArith sltArith(tmp, , a, b, 1'b1);
	yMux1 sltMux(slt[0], tmp[31], a[31], condition);
	
endmodule

module yIF(ins, PC, PCp4, PCin, clk);
	output [31:0] ins, PCp4, PC;
	input [31:0] PCin;
	input clk;

	wire zero;
	wire read, write, enable;
	wire [31:0] a, memIn;
	wire [2:0] op;
 
	register #(32) pcReg(PC, PCin, clk, enable);
	mem myMem(ins, PC, memIn, clk, read, write);
	yAlu pcALU(PCp4, zero, a, PC, op);

	assign enable = 1'b1;
	assign a = 32'h0004;
	assign op = 3'b010;
	assign read = 1'b1;
	assign write = 1'b0;

endmodule

module yID(rd1, rd2, immOut, jTarget, branch, ins, wd, RegWrite, clk);
	output [31:0] rd1, rd2, immOut, jTarget, branch;

	input [31:0] ins, wd;
	input RegWrite, clk;

	wire [19:0] zeros, ones;
	wire [11:0] zerosj, onesj;
	wire [31:0] imm, saveImm;

	rf myRF(rd1, rd2, ins[19:15], ins[24:20], ins[11:7], wd, clk, RegWrite);

	assign imm[11:0] = ins[31:20];
	assign zeros = 20'h00000;
	assign ones = 20'hFFFFF;
	yMux #(20) se(imm[31:12], zeros, ones, ins[31]);

	assign saveImm[11:5] = ins[31:25];
	assign saveImm[4:0] = ins[11:7];

	yMux #(20) saveImmSe(saveImm[31:12], zeros, ones, ins[31]);
	yMux #(32) immSelection(immOut, imm, saveImm, ins[5]);

	assign branch[11] = ins[31];
	assign branch[10] = ins[7];
	assign branch[9:4] = ins[30:25];
	assign branch[3:0] = ins[11:8];
	yMux #(20) bra(branch[31:12], zeros, ones, ins[31]);

	assign zerosj = 12'h000;
	assign onesj = 12'hFFF;
	assign jTarget[19] = ins[31];
	assign jTarget[18:11] = ins[19:12];
	assign jTarget[10] = ins[20];
	assign jTarget[9:0] = ins[30:21];
	yMux #(12) jum(jTarget[31:20], zerosj, onesj, jTarget[19]);
endmodule

module yEX(z,zero,rd1,rd2,imm,op,ALUSrc);
	output [31:0] z;
	output zero;
	input [31:0] rd1, rd2, imm;
	input[2:0] op;
	input ALUSrc;
	wire [31:0] tmp;

	

	yMux #(32) myMux(tmp, rd2, imm, ALUSrc);
	yAlu myAlu(z,zero,rd1,tmp,op);
endmodule

module yDM(memOut, exeOut, rd2, clk, MemRead, MemWrite);
	output[31:0] memOut;
	input[31:0] exeOut, rd2;
	input clk, MemRead, MemWrite;

	mem data(memOut, exeOut, rd2, clk, MemRead, MemWrite);
endmodule

module yWB(wb, exeOut, memOut, Mem2Reg);
	output[31:0] wb;
	input [31:0] exeOut, memOut;
	input Mem2Reg;

	yMux #(32) write(wb, exeOut, memOut, Mem2Reg);
endmodule

module yPC(PCin, PC, PCp4, INT, entryPoint, branchImm, jImm, zero, isbranch, isjump);
	output [31:0] PCin;
	input [31:0] PCp4, PC, jImm, branchImm, entryPoint;
	input zero, INT, isbranch, isjump;

	wire [31:0] branchImmX4, jImmX4, jImmX4PPC4, bTarget, choiceA, choiceB;
	wire doBranch, zf;

	assign branchImmX4[31:2] = branchImm[29:0];
	assign branchImmX4[1:0] = 2'b00;

	assign jImmX4[31:2] = jImm[29:0];
	assign jImmX4[1:0] = 2'b00;

	yAlu bAlu(bTarget, zf, PC, branchImmX4,3'b010);

	yAlu jAlu(jImmX4PPC4, zf, PC, jImmX4, 3'b010);

	and decide(doBranch, isbranch, zero);
	yMux #(32) mux1(choiceA, PCp4, bTarget, doBranch);
	yMux #(32) mux2(choiceB, choiceA, jImmX4PPC4, isjump);
	yMux #(32) mux3(PCin, choiceB, entryPoint, INT);
endmodule

module yC1(isStype, isRtype, isItype, isLw, isjump, isbranch, op);
	output isStype, isRtype, isItype, isLw, isjump, isbranch;
	input [6:0] op;
	
	wire lwor, ISselect, JBSelect, sbz, sz;

	assign isjump=op[3];

	or opor(lwor, op[6], op[5], op[4], op[3], op[2]);
	not opnot(isLw, lwor);

	xor (ISselect, op[6], op[5], op[4], op[3], op[2]);
	and (isStype, ISselect, op[5]);
	and (isItype, ISelect, op[4]);

	and (isRtype, op[5], op[4]);

	and (JBSelect, op[6], op[5]);
	not (sbz, op[3]);
	and (isbranch, JBSelect, sbz);
	
endmodule

module yC2(RegWrite, ALUSrc, MemRead, MemWrite, Mem2Reg, isStype, isRtype, isItype, isLw, isjump, isbranch);
	output RegWrite, ALUSrc, MemRead, MemWrite, Mem2Reg;
	input isStype, isRtype, isItype, isLw, isjump, isbranch;

	nor (ALUSrc, isRtype, isbranch);
	nor (RegWrite, isStype, isbranch);

	assign Mem2Reg = isLw;
	assign MemRead = isLw;
	assign MemWrite = isStype;
endmodule

module yC3(ALUop, isRtype, isbranch);
	output [1:0] ALUop;
	input isRtype, isbranch;

	assign ALUop[0] = isbranch;
	assign ALUop[1] = isRtype;
endmodule

module yC4(op, ALUop, funct3);
	output [2:0] op;
	input [1:0] ALUop;
	input [2:0] funct3;

	wire xor1,xor2, andtop, andbot;

	xor topxor(xor1, funct3[2], funct3[1]);
	xor bottomxor(xor2, funct3[1], funct3[0]);

	and topand(andtop, ALUop[1], xor1);
	and bottomand(op[0], ALUop[1], xor2);

	or topor(op[2], ALUop[0], andtop);
	or bottomor(op[1], ~ALUop[1], ~funct3[1]);

endmodule

module yChip(ins, rd2, wb, entryPoint, INT, clk);
	output [31:0] ins, rd2, wb;
	input [31:0] entryPoint;
	input INT, clk;


	wire [31:0] PCin, PCp4, PC, wd, rd1, imm, z;
	wire [31:0] jTarget, branch, memOut;
	wire [6:0] opcode;
	wire [2:0] op, funct3;
	wire [1:0] ALUop;
	wire zero, isbranch, isjump, isStype, isRtype, isItype, isLw, RegWrite, ALUSrc, MemRead, MemWrite, Mem2Reg;

	yIF myIF(ins, PC, PCp4, PCin, clk);
	yID myID(rd1, rd2, imm, jTarget, branch, ins, wd, RegWrite, clk);
	yEX myEX(z, zero, rd1, rd2, imm, op, ALUSrc);
	yDM myDM(memOut, z, rd2, clk, MemRead, MemWrite);
	yWB myWB(wb, z, memOut, Mem2Reg);

	assign wd = wb;
	yPC myPC(PCin, PC, PCp4, INT, entryPoint, branch, jTarget, zero, isbranch, isjump);

	assign opcode = ins[6:0];
	yC1 myC1(isStype, isRtype, isItype, isLw, isjump, isbranch, opcode);
	yC2 myC2(RegWrite, ALUSrc, MemRead, MemWrite, Mem2Reg, isStype, isRtype, isItype, isLw, isjump, isbranch);
	yC3 myC3(ALUop, isRtype, isbranch);
	
	assign funct3=ins[14:12];
	yC4 myC4(op, ALUop, funct3);

endmodule

	//That's all folks! :)