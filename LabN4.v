module LabN4;
reg [31:0] entryPoint;
reg clk, INT;

wire [31:0] PCin, ins, PCp4, PC, wd,wb,rd1, rd2, imm, z;
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

initial begin
    INT = 1; 
    entryPoint=32'h28; #1;

    repeat(43) begin
        clk = 1; #1;
        INT = 0;
        clk = 0; #1;

        #4 $display("%h: rd1=%2d rd2=%2d z=%3d zero=%b wb=%2d", ins, rd1, rd2, z, zero, wb);


    end
    $finish;
end

endmodule