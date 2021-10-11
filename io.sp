{Sub-Pascal I/O routines library}



const
  CR = 13; LF = 10; TAB = 9; ESC = 27;



var
  LastCharRead: Char;
  LastNumberReadIsNeg: Boolean;




procedure WriteLn;
begin
Write(CR, LF);
end;




procedure ReadKey;
var
  ch: Char;
begin
Read(ch);
end;




procedure WriteInt(Number: Integer);
var
  Digit, Weight: Integer;
  Skip: Boolean;

begin
if Number = 0 then
  Write('0')
else
  begin
  if Number < 0 then
    begin
    Write('-');            
    Number := -Number;
    end;

  Weight := 1000000000;
  Skip := TRUE;

  while Weight >= 1 do
    begin
    if Number >= Weight then Skip := FALSE;

    if not Skip then
      begin
      Digit := Number div Weight;
      Write('0' + Digit);
      Number := Number - Weight * Digit;
      end;

    Weight := Weight div 10;
    end;  {while}
  end;  {else}

end;




procedure ReadInt(Number: Pointer);
const
  BUFSIZE = 10;
var
  ChBuf: array [0..BUFSIZE - 1] of Char;
  Ch: Char; 
  NumCh, Weight, i: Integer;
  Negative: Boolean;

begin
Number^ := 0;
Negative := FALSE;
NumCh := 0;

Read(Ch);
if Ch = '-' then   
  begin
  Negative := TRUE;
  Read(Ch);
  end;

while (Ch >= '0') and (Ch <= '9') do
  begin
  ChBuf[NumCh] := Ch;
  NumCh := NumCh + 1;
  Read(Ch);
  end;

if Ch = CR then Write(LF);

Weight := 1;    

for i := 1 to NumCh do
  begin
  Number^ := Number^ + Weight * (ChBuf[NumCh - i] - '0');
  Weight := Weight * 10;
  end;
  
if Negative then Number^ := -Number^;

LastCharRead        := Ch;
LastNumberReadIsNeg := Negative;
end;




procedure WriteReal(Number: Real);
var
  Integ, Frac, InvWeight, Digit: Integer;
begin
if Number < 0.0 then
  begin
  Write('-');
  Number := -Number;
  end;
  
Integ := Integer(Number) shr FracBits;
Frac  := Integer(Number) and FracMask;

WriteInt(Integ); Write('.');

InvWeight := 10;

while InvWeight <= 10000 do
  begin
  Digit := (Frac * InvWeight) shr FracBits;
  if Digit > 9 then Digit := 9;
  Write('0' + Digit);
  Frac := Frac - (Digit shl FracBits) div InvWeight;
  InvWeight := InvWeight * 10;
  end;  {while}
 
end;




procedure ReadReal(Number: Pointer);
var
  Integ, Frac, InvWeight: Integer;
  Ch: Char;
begin
ReadInt(@Integ);
Frac := 0;

if LastCharRead = '.' then     {Fractional part found}
  begin
  InvWeight := 10;

  Read(Ch);

  while (Ch >= '0') and (Ch <= '9') do
    begin
    Frac := Frac + ((Ch - '0') shl FracBits) / InvWeight;
    InvWeight := InvWeight * 10;
    Read(Ch);
    end;
              
  if Ch = CR then Write(LF);
  end;  {if}

if not LastNumberReadIsNeg then
  Number^ := (Integ shl FracBits) + Frac
else
  Number^ := -((-Integ shl FracBits) + Frac);
end;


