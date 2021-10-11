{Prime number distribution program written in Sub-Pascal language
 The source should be compiled along with IO.SP and MATH.SP}



var
  InputNumber, TestNumber, Primes, Interval, Divisor, MaxDivisor: Integer;
  IsPrime: Boolean;



{Main program}  

begin
WriteLn;
Write('Prime number distribution density calculation', CR, LF);
WriteLn;
Write('Primes up to: '); ReadInt(@InputNumber);
Write('Interval    : '); ReadInt(@Interval); 
WriteLn;

Primes := 0;

for TestNumber := 2 to InputNumber - 1 do
  begin
  IsPrime := TRUE;

  MaxDivisor := IMin(ISqrt(TestNumber), TestNumber - 1);

  for Divisor := 2 to MaxDivisor do
    if TestNumber mod Divisor = 0 then IsPrime := FALSE;    

  if IsPrime then Primes := Primes + 1; 

  if TestNumber mod Interval = 0 then                  
    begin 
    WriteInt(TestNumber); Write(TAB); WriteInt(Primes); WriteLn; 
    Primes := 0;
    end;  {if}  

  end;  {for}

WriteLn;
Write('Done.');
WriteLn;

ReadKey;

end.
