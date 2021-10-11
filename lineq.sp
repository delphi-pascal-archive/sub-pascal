{Linear equations solver written in Sub-Pascal language
 The source should be compiled along with IO.SP and GAUSS.SP}


var
  A: TMatrix;
  x: TVector;
  m, i, j: Integer;


begin
WriteLn;
Write('Linear equations solver', CR, LF);
WriteLn;
Write('System size: '); ReadInt(@m);
WriteLn;
Write('Augmented '); WriteInt(m); Write(' x '); WriteInt(m + 1); Write(' matrix: ', CR, LF);                   
WriteLn;

for i := 1 to m do
  begin
  Write('|', TAB);
  for j := 1 to m + 1 do
    ReadReal(A + ind(i, j) shl 2);
  Write('|', CR, LF);
  end;

SolveLinearSystem(A, x, m);

WriteLn;
Write('Triangularized matrix:', CR, LF);
WriteLn;

for i := 1 to m do
  begin
  Write('|', TAB);
  for j := 1 to m + 1 do
    begin
    WriteReal(A[ind(i, j)]); Write(TAB, TAB);
    end;
  Write('|', CR, LF);
  end;

WriteLn;
WriteLn;
Write('Solution: ');

for i := 1 to m do
  begin
  Write('x'); WriteInt(i); Write(' = '); WriteReal(x[ind(1, i)]); Write(';  ');
  end;

WriteLn;
ReadKey;

end.
