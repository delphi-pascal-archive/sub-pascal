{Sub-Pascal mathematical routines library
 Real numbers are internally stored as 32-bit signed fixed-point data
 20 higher bits are in the integer part, 12 lower bits are in the fractional part} 



const
  pi = 3.1415927;



function IntToReal(x: Integer): Real;
begin
if x >= 0 then
  Result :=  Real(x shl FracBits)
else
  Result := -Real((-x) shl FracBits);
end;



function RealToInt(x: Real): Integer;
begin
if x >= 0.0 then
  Result :=  Integer(x) shr FracBits
else
  Result := -(Integer(-x) shr FracBits);
end;
            


var
  RndSeed: Integer;



procedure Randomize(Seed: Integer);
begin
RndSeed := Seed;
end;



function Random: Integer;
begin
RndSeed := 1975433173 * RndSeed;
Result := RndSeed;
end;




function Min(x, y: Real): Real;
begin
if x < y then Result := x else Result := y;
end;




function IMin(x, y: Integer): Integer;
begin
if x < y then Result := x else Result := y;
end;





function Max(x, y: Real): Real;
begin
if x > y then Result := x else Result := y;
end;




function IMax(x, y: Integer): Integer;
begin
if x > y then Result := x else Result := y;
end;




function Abs(x: Real): Real;
begin
if x >= 0.0 then Result := x else Result := -x;
end;




function IAbs(x: Integer): Integer;
begin
if x >= 0 then Result := x else Result := -x;
end;




function Sqrt(x: Real): Real;
var
  Divisor: Real;
begin
{Hero's algorithm}

Result  := x; 
Divisor := 1.0;

while Abs(Result - Divisor) > 0.01 do
  begin
  Divisor := (Result + Divisor) / 2.0;
  Result := x / Divisor;
  end;
end;




function ISqrt(x: Integer): Integer;
var
  Divisor: Integer;
begin
{Hero's algorithm}

Result  := x; 
Divisor := 1;

while IAbs(Result - Divisor) > 1 do
  begin
  Divisor := (Result + Divisor) shr 1;
  Result := x / Divisor;
  end;
end;




function Exp(x: Real): Real;
var
  r: Real;
  k: Integer;
begin
Result := 0.0;
r := 1.0;

for k := 1 to 50 do
  begin
  Result := Result + r;
  r := r * x / IntToReal(k);
  end;

end;




function Sin(x: Real): Real;
var
  r: Real;
  k: Integer;
begin
while x > 2.0 * pi do x := x - 2.0 * pi;
while x < 0.0      do x := x + 2.0 * pi;

Result := 0.0;
r := x;

for k := 1 to 50 do
  begin
  Result := Result + r;
  r := -r * x * x / IntToReal(2 * k * (2 * k + 1));
  end;

end;




function Cos(x: Real): Real;
var
  r: Real;
  k: Integer;
begin
while x > 2.0 * pi do x := x - 2.0 * pi;
while x < 0.0      do x := x + 2.0 * pi;

Result := 0.0;
r := 1.0;

for k := 1 to 50 do
  begin
  Result := Result + r;
  r := -r * x * x / IntToReal((2 * k - 1) * 2 * k);
  end;

end;




function Atan(x: Real): Real;
var
  r: Real;
  k: Integer;
begin
Result := 0.0;
r := x;

for k := 1 to 50 do
  begin
  Result := Result + r / IntToReal(2 * k - 1);
  r := -r * x * x;
  end;

end;




function Ln(x: Real): Real;
var
  r, a: Real;
  k: Integer;
begin
Result := 0.0;
a := (x - 1.0) / (x + 1.0);
r := a;

for k := 1 to 50 do
  begin
  Result := Result + r / IntToReal(2 * k - 1);
  r := r * a * a;
  end;

Result := 2.0 * Result;
end;







