{Mandelbrot set fragment plot program written in Sub-Pascal language
 The source should be compiled along with IO.SP, MATH.SP and GRAPH.SP}



const
  ReCmax = 0.08; ReCmin = -0.66; 
  ImCmax = -0.3; ImCmin = -1.25;

  Inf = 500000.0;
  MaxPoints = 100;

  Scale = 320.0;



function ScreenX(x: Real): Integer;
begin
Result := 410 + RealToInt(Scale * x);
end;



function ScreenY(y: Real): Integer;
begin
Result := 420 + RealToInt(Scale * y);
end;



var
  ReC, ImC, ReZ, ImZ, ReZnew, ImZnew: Real;
  i, x, y, xmin, ymin, xmax, ymax: SmallInt;
  color: Char;
  IsInf: Boolean;
  Palette: array [0..5] of Char;



begin
{Custom palette}
Palette[0] := 12; Palette[1] := 14; Palette[2] := 10; 
Palette[3] := 11; Palette[4] := 9 ; Palette[5] := 1;  

SetScreenMode(16);   {640 x 350 pixels, 16 colors}

xmin := ScreenX(ReCmin) - 1;  ymin := ScreenY(ImCmin) - 1;
xmax := ScreenX(ReCmax) + 1;  ymax := ScreenY(ImCmax) + 1;

{Border lines}
for x := xmin to xmax do
  begin
  PutPixel(x, ymin, 15);
  PutPixel(x, ymax, 15);
  end;

for y := ymin to ymax do
  begin
  PutPixel(xmin, y, 15);
  PutPixel(xmax, y, 15);
  end;

{Mandelbrot set construction}
ReC := ReCmin;

while ReC <= ReCmax do
  begin
  ImC := ImCmin;

  while ImC <= ImCmax do
    begin
    ReZ := 0.0;  ImZ := 0.0;
    IsInf := FALSE;
    color := 0;
    i := 1;

    while (i <= MaxPoints) and not IsInf do  
      begin
      ReZnew := ReZ * ReZ - ImZ * ImZ + ReC;
      ImZnew := 2.0 * ReZ * ImZ + ImC;

      if (abs(ReZnew) > Inf) or (abs(ImZnew) > Inf) then
        begin
        IsInf := TRUE;
        color := Palette[5 - i div 17];
        end;

      ReZ := ReZnew;  ImZ := ImZnew;
      i := i + 1;
      end;  {while i...}

    PutPixel(ScreenX(ReC), ScreenY(ImC), color);

    ImC := ImC + 0.001;
    end;  {while ImC...}
  
  ReC := ReC + 0.001;
  end;  {while ReC...}

ReadKey;
SetScreenMode(3);
end.
