{The Game of Life written in Sub-Pascal language
 The source should be compiled along with IO.SP, MATH.SP and GRAPH.SP}


const
  FIELDSIZE = 75;



type
  TField = array [0..FIELDSIZE * FIELDSIZE - 1] of Boolean;




function ind(i, j: Integer): Integer;              {Linear index of a cell modulo FIELDSIZE}
begin
while i > FIELDSIZE - 1 do i := i - FIELDSIZE;
while i < 0             do i := i + FIELDSIZE;
while j > FIELDSIZE - 1 do j := j - FIELDSIZE;
while j < 0             do j := j + FIELDSIZE;

Result := FIELDSIZE * i + j;
end;




procedure Redraw(Fld: TField);
const
  ORIGINX = 640 / 2 - FIELDSIZE / 2;
  ORIGINY = 350 / 2 - FIELDSIZE / 2;

var
  i, j: Integer;
  clr: Char;

begin
for i := 0 to FIELDSIZE - 1 do
  for j := 0 to FIELDSIZE - 1 do
    begin
    if Fld[ind(i, j)] then clr := 14 else clr := 1;
    PutPixel(ORIGINX + i, ORIGINY + j, clr); 
    end;

end;  {Redraw}




procedure Init(Fld: TField; Seed: Integer);
var
  i, j: Integer;
begin
Randomize(Seed);

for i := 0 to FIELDSIZE - 1 do
  for j := 0 to FIELDSIZE - 1 do
    Fld[ind(i, j)] := Random > 0;
end;  {Init}




procedure Regenerate(Fld: TField);
var
  NextFld: TField;
  i, j, ni, nj, n: Integer;
begin

for i := 0 to FIELDSIZE - 1 do
  for j := 0 to FIELDSIZE - 1 do
    begin
    {Count cell neighbors}
    n := 0;
    for ni := i - 1 to i + 1 do
      for nj := j - 1 to j + 1 do
        if Fld[ind(ni, nj)] and not ((ni = i) and (nj = j)) then n := n + 1;

    {Bear or kill the current cell in the next generation}
    if Fld[ind(i, j)] then
      NextFld[ind(i, j)] := (n > 1) and (n < 4)  {Kill the cell or keep it alive}
    else
      NextFld[ind(i, j)] := n = 3;               {Bear the cell or keep it dead}
    end;  {for j...}

{Make new generation}
for i := 0 to FIELDSIZE - 1 do
  for j := 0 to FIELDSIZE - 1 do
    Fld[ind(i, j)] := NextFld[ind(i, j)];

end;  {Regenerate}




var
  Field: TField;
  NumGen, Seed: Integer;
  Stop: Boolean;
  Ch: Char;

begin
WriteLn;
Write('Game of Life', CR, LF);
WriteLn;
Write('Random seed (any integer number): '); ReadInt(@Seed); WriteLn;
WriteLn;

{Create initial population}
Init(Field, Seed);

SetScreenMode(16);   {640 x 350 pixels, 16 colors}

{Run simulation}
repeat   
  Redraw(Field);
  Regenerate(Field);
  Read(Ch);
until Ch = ESC;

SetScreenMode(3);
end.

  




























