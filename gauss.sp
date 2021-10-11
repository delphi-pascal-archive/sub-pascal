{Implementation of Gauss' method for linear systems}


const
  MAXSIZE = 10;
  MAXMESSAGELEN = 40;


type
  TMatrix = array [0..MAXSIZE * (MAXSIZE + 1) - 1] of Real;
  TVector = array [0..MAXSIZE - 1] of Real;
  TMessage = string [MAXMESSAGELEN];



procedure Error(E: TMessage);
begin
Write('Error: ', E, '.', CR, LF);
ReadKey;
Halt;
end;  



function ind(i, j: Integer): Integer;                  {Linear index of a matrix element}
begin
Result := MAXSIZE * (i - 1) + (j - 1);
end;



procedure SolveLinearSystem(T: TMatrix; x: TVector; m: Integer);
var
  i, j, k: Integer;
  s: Real;
  ErrMsg: TMessage;

  procedure TriangularizeMatrix(T: TMatrix; m: Integer);
  var
    i, j, k: Integer;
    r: Real;
  begin
  for k := 1 to m - 1 do
    for i := k + 1 to m do
      begin
      if T[ind(k, k)] = 0.0 then
        begin
        ErrMsg := 'Diagonal element is zero';  Error(ErrMsg);
        end;

      r := -T[ind(i, k)] / T[ind(k, k)];

      for j := k to m + 1 do
        T[ind(i, j)] := T[ind(i, j)] + r * T[ind(k, j)];
      end;
  end;

begin
TriangularizeMatrix(T, m);

for i := m downto 1 do
  begin
  s := T[ind(i, m + 1)];
  for j := m downto i + 1 do
    s := s - T[ind(i, j)] * x[ind(1, j)];

  if T[ind(i, i)] = 0.0 then
    begin
    ErrMsg := 'Singular matrix';  Error(ErrMsg);
    end;

  x[ind(1, i)] := s / T[ind(i, i)];
  end;  {for}

end;

