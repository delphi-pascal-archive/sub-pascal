{Cannabola plot program written in Sub-Pascal language
 The source should be compiled along with MATH.SP, IO.SP and GRAPH.SP}


const
  dt = 0.0005;
  scale = 120.0;


var
  r, t, x, y: Real;


begin
SetScreenMode(16);   {640 x 350 pixels, 16 colors}

t := 0.0;

while t <= 2.0 * pi do
  begin
  r := (1.0 + sin(t)) * (1.0 + 0.9 * cos(8.0 * t)) * (1.0 + 0.1 * cos(24.0 * t)) * (0.5 + 0.05 * cos(200.0 * t));

  x := r * cos(t);
  y := r * sin(t);

  PutPixel(320 + RealToInt(scale * x), 290 - RealToInt(scale * y), 10);
  
  t := t + dt;
  end;

ReadKey;
SetScreenMode(3);
end.



