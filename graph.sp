{Sub-Pascal graphics routines library}


const
  AX = 0; BX = 1; CX = 2; DX = 3;


type
  TRegisters = array [0..3] of Integer;


var
  Reg: TRegisters;



procedure SetScreenMode(mode: Integer);
begin
Reg[AX] := 0 shl 8 + mode;
Intr(16, Reg);
end;



procedure PutPixel(x, y, clr: Integer);
begin
Reg[AX] := 12 shl 8 + clr;
Reg[BX] := 0;
Reg[CX] := x;
Reg[DX] := y;
Intr(16, Reg);
end;


