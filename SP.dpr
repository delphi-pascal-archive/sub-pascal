// Sub-Pascal 32-bit real mode compiler for 80386+ processors v. 2.0 by Vasiliy Tereshkov, 2009


program SP;


{$APPTYPE CONSOLE}


uses
  SysUtils, Math;  


const
  // Token codes

  CONSTTOK              = 1;
  TYPETOK               = 2;
  VARTOK                = 3;
  PROCEDURETOK          = 4;
  FUNCTIONTOK           = 5;

  BEGINTOK              = 12;
  ENDTOK                = 13;
  IFTOK                 = 14;
  THENTOK               = 15;
  ELSETOK               = 16;
  WHILETOK              = 17;
  DOTOK                 = 18;
  REPEATTOK             = 19;
  UNTILTOK              = 20;
  FORTOK                = 21;
  TOTOK                 = 22;
  DOWNTOTOK             = 23;
  ASSIGNTOK             = 24;
  WRITETOK              = 25;
  READTOK               = 26;
  HALTTOK               = 27;
  INTRTOK               = 28;
  ARRAYTOK              = 29;
  OFTOK                 = 30;
  STRINGTOK             = 31;

  RANGETOK              = 35;

  EQTOK                 = 41;
  NETOK                 = 42;
  LTTOK                 = 43;
  LETOK                 = 44;
  GTTOK                 = 45;
  GETOK                 = 46;

  DOTTOK                = 51;
  COMMATOK              = 52;
  SEMICOLONTOK          = 53;
  OPARTOK               = 54;
  CPARTOK               = 55;
  DEREFERENCETOK        = 56;
  ADDRESSTOK            = 57;
  OBRACKETTOK           = 58;
  CBRACKETTOK           = 59;
  COLONTOK              = 60;

  PLUSTOK               = 61;
  MINUSTOK              = 62;
  MULTOK                = 63;
  DIVTOK                = 64;
  IDIVTOK               = 65;
  MODTOK                = 66;
  SHLTOK                = 67;
  SHRTOK                = 68;
  ORTOK                 = 69;
  XORTOK                = 70;
  ANDTOK                = 71;
  NOTTOK                = 72;

  INTEGERTOK            = 81;
  SMALLINTTOK           = 82;
  CHARTOK               = 83;
  BOOLEANTOK            = 84;
  POINTERTOK            = 85;
  REALTOK               = 86;

  IDENTTOK              = 91;
  INTNUMBERTOK          = 92;
  FRACNUMBERTOK         = 93;
  CHARLITERALTOK        = 94;
  STRINGLITERALTOK      = 95;

  // Identifier kind codes

  CONSTANT              = 1;
  USERTYPE              = 2;
  VARIABLE              = 3;
  PROC                  = 4;
  FUNC                  = 5;

  // Compiler parameters

  MAXSTRLENGTH          = 80;
  MAXSTRLITERALLENGTH   = 256;
  MAXTOKENS             = 10000;
  MAXTOKENNAMES         = 100;
  MAXIDENTS             = 1000;
  MAXBLOCKS             = 200;
  MAXPARAMS             = 8;
  MAXUNITS              = 20;

  SEGMENTSIZE           = $10000;
  PSPSIZE               = $100;

  CODEORIGIN            = PSPSIZE;
  DATAORIGIN            = $8000;
  STACKORIGIN           = $F000;

  CALLDETERMPASS        = 1;
  CODEGENERATIONPASS    = 2;       

  // Indirection levels

  ASVALUE                       = 0;
  ASPOINTER                     = 1;
  ASPOINTERTOPOINTER            = 2;
  ASPOINTERTOARRAYORIGIN        = 3;

  // Fixed-point 32-bit real number storage

  FRACBITS                = 12;
  TWOPOWERFRACBITS        = 4096;

  // Data sizes

  DataSize: array [INTEGERTOK..REALTOK] of Byte = (4, 2, 1, 1, 4, 4);

 

type
  TString = string [MAXSTRLENGTH];

  TParam = record
    Name: TString;
    DataType: Integer;
    NumAllocElements: Word;
    AllocElementType: Byte;
    end;

  TParamList = array [1..MAXPARAMS] of TParam;
  
  TToken = record
    UnitIndex: Integer;
    Line: Integer;
    case Kind: Byte of
      IDENTTOK:
        (Name: ^TString);
      INTNUMBERTOK:
        (Value: LongInt);
      FRACNUMBERTOK:
        (FracValue: Single);
      STRINGLITERALTOK:
        (StrAddress: Word;
         StrLength: Word);
    end;

  TIdentifier = record
    Name: TString;
    Value: LongInt;                     // Value for a constant, address for a variable, procedure or function
    Block: Byte;                        // Index of a block in which the identifier is defined
    DataType: Byte;
    case Kind: Byte of
      PROC, FUNC:
        (NumParams: Word;
         ParamType: array [1..MAXPARAMS] of Byte;
         ProcAsBlock: Byte;
         IsNotDead: Boolean;);
      VARIABLE, USERTYPE:
        (NumAllocElements: Word;
         AllocElementType: Byte);
    end;

  TCallGraphNode = record
    ChildBlock: array [1..MAXBLOCKS] of Integer;
    NumChildren: Word;
    end;



var
  Tok: array [1..MAXTOKENS] of TToken;
  Ident: array [1..MAXIDENTS] of TIdentifier;
  StaticStringData: array [0..DATAORIGIN - CODEORIGIN - 5] of Char;
  Spelling: array [1..MAXTOKENNAMES] of TString;
  UnitName: array [1..MAXUNITS] of TString;
  Code: array [0..SEGMENTSIZE - PSPSIZE - 1] of Byte;
  CodePosStack: array [0..1023] of Word;
  BlockStack: array [0..MAXBLOCKS - 1] of Byte;
  CallGraph: array [1..MAXBLOCKS] of TCallGraphNode;    // For dead code elimination

  NumTok, NumIdent, NumPredefIdent, NumStaticStrChars, NumUnits, NumBlocks,
  BlockStackTop, CodeSize, CodePosStackTop, VarDataSize, Pass: Integer;

  InFile: file of Char;
  OutFile: file of Byte;
  DiagFile: TextFile;

  OutputDisabled: Boolean;




procedure FreeTokens;
var
  i: Integer;
begin
for i := 1 to NumTok do
  if (Tok[i].Kind = IDENTTOK) and (Tok[i].Name <> nil) then Dispose(Tok[i].Name);
end;




procedure Error(ErrTokenIndex: Integer; Msg: string);
begin
if NumTok = 0 then
  WriteLn('[Error] Program is empty')
else
  begin
  if ErrTokenIndex > NumTok then ErrTokenIndex := NumTok;
  WriteLn('[Error] ' + UnitName[Tok[ErrTokenIndex].UnitIndex] + '.sp, ' + IntToStr(Tok[ErrTokenIndex].Line) + '. ' + Msg);
  end;
WriteLn;
FreeTokens;
Halt;
end;




procedure Warning(WarnTokenIndex: Integer; Msg: string);
begin
WriteLn('[Warning] ' + UnitName[Tok[WarnTokenIndex].UnitIndex] + '.sp, ' + IntToStr(Tok[WarnTokenIndex].Line) + '. ' + Msg);
end;




function GetStandardToken(S: TString): Integer;
var
  i: Integer;
begin
Result := 0;

for i := 1 to MAXTOKENNAMES do
  if S = Spelling[i] then
    begin
    Result := i;
    Break;
    end;
end;



function GetIdent(S: TString): Integer;
var
  IdentIndex, BlockStackIndex: Integer;
begin
Result := 0;

for BlockStackIndex := BlockStackTop downto 0 do       // search all nesting levels from the current one to the most outer one
  begin
  for IdentIndex := 1 to NumIdent do
    if (S = Ident[IdentIndex].Name) and (BlockStack[BlockStackIndex] = Ident[IdentIndex].Block) then
      begin
      Result := IdentIndex;
      Break;
      end;

  if Result > 0 then Break;
  end;// for
end;



function GetSpelling(i: Integer): TString;
begin
if i > NumTok then
  Result := 'no token'
else if Tok[i].Kind < IDENTTOK then
  Result := Spelling[Tok[i].Kind]
else if Tok[i].Kind = IDENTTOK then
  Result := 'identifier'
else if (Tok[i].Kind = INTNUMBERTOK) or (Tok[i].Kind = FRACNUMBERTOK) then
  Result := 'number'
else if (Tok[i].Kind = CHARLITERALTOK) or (Tok[i].Kind = STRINGLITERALTOK) then
  Result := 'literal'
else
  Result := 'unknown token';
end;



procedure AddToken(Kind: Byte; UnitIndex, Line: Integer; Value: LongInt);
begin
Inc(NumTok);
Tok[NumTok].UnitIndex := UnitIndex;
Tok[NumTok].Line := Line;
Tok[NumTok].Kind := Kind;
Tok[NumTok].Value := Value;
end;




procedure DefineIdent(ErrTokenIndex: Integer; Name: TString; Kind: Byte; DataType: Byte; NumAllocElements: Integer; AllocElementType: Byte; Data: LongInt);
var
  i: Integer;
begin
i := GetIdent(Name);
if (i > 0) and (Ident[i].Block = BlockStack[BlockStackTop]) then
  Error(ErrTokenIndex, 'Identifier ' + Name + ' is already defined')
else
  begin
  Inc(NumIdent);
  Ident[NumIdent].Name := Name;
  Ident[NumIdent].Kind := Kind;
  Ident[NumIdent].DataType := DataType;
  Ident[NumIdent].Block := BlockStack[BlockStackTop];
  Ident[NumIdent].NumParams := 0;
  
  case Kind of
    PROC, FUNC:
      Ident[NumIdent].Value := CodeSize;                                // Procedure entry point address
    VARIABLE:
      begin
      Ident[NumIdent].Value := DATAORIGIN + VarDataSize;                // Variable address
      if not OutputDisabled then
        VarDataSize := VarDataSize + DataSize[DataType];
      Ident[NumIdent].NumAllocElements := NumAllocElements;             // Number of array elements (0 for single variable)
      if not OutputDisabled then
        VarDataSize := VarDataSize + NumAllocElements * DataSize[AllocElementType];
      Ident[NumIdent].AllocElementType := AllocElementType;
      end;
    CONSTANT:
      Ident[NumIdent].Value := Data;                                    // Constant value
    USERTYPE:
      begin
      Ident[NumIdent].NumAllocElements := NumAllocElements;
      Ident[NumIdent].AllocElementType := AllocElementType;
      end;
  end;// case
  end;// else
end;




procedure DefineStaticString(StrTokenIndex: Integer; StrValue: TString);
var
  i: Integer;
begin
Tok[StrTokenIndex].StrAddress := CODEORIGIN + 3 + NumStaticStrChars;
Tok[StrTokenIndex].StrLength := Length(StrValue);

StrValue := StrValue + '$';     // Add string termination character 

for i := 1 to Length(StrValue) do
  begin
  StaticStringData[NumStaticStrChars] := StrValue[i];
  Inc(NumStaticStrChars);
  end;
end;  




function GetCommonType(ErrTokenIndex: Integer; LeftType, RightType: Byte): Byte;
begin
if (LeftType = REALTOK) and (RightType = REALTOK) then
  Result := REALTOK
else if (LeftType = REALTOK) xor (RightType = REALTOK) then
  Error(ErrTokenIndex, 'Incompatible types: ' + Spelling[LeftType] + ' and ' + Spelling[RightType])
else
  Result := LeftType;
end;




procedure AddCallGraphChild(ParentBlock, ChildBlock: Integer);
begin
Inc(CallGraph[ParentBlock].NumChildren);
CallGraph[ParentBlock].ChildBlock[CallGraph[ParentBlock].NumChildren] := ChildBlock;
end;




procedure TokenizeProgram;
var
  Text, Num, Frac: TString;
  ch, ch2: Char;
  CurToken: Byte;
  OldNumTok, UnitIndex, Line: Integer;

  procedure ReadChar(var c: Char);
  begin
  Read(InFile, c);
  if c = '{' then
    begin
    repeat                                             // Skip comments
      Read(InFile, c);
      if c = #10 then Inc(Line);
    until c = '}';             
    Read(InFile, c);
    end;
  if c = #10 then Inc(Line);                           // Increment current line number
  end;

  procedure SafeReadChar(var c: Char);
  begin
  ReadChar(c);
  c := UpCase(c);
  if not (c in [' ', #9, #10, #13, '{', '}', 'A'..'Z', '_', '0'..'9', '=', '.', ',', ';', '(', ')', '*', '/', '+', '-', ':', '>', '<', '^', '@', '[', ']']) then
    begin
    CloseFile(InFile);
    Error(NumTok, 'Unknown character: ' + ch);
    end;
  end;  

begin
// Token spelling definition

Spelling[CONSTTOK       ] := 'CONST';
Spelling[TYPETOK        ] := 'TYPE';
Spelling[VARTOK         ] := 'VAR';
Spelling[PROCEDURETOK   ] := 'PROCEDURE';
Spelling[FUNCTIONTOK    ] := 'FUNCTION';

Spelling[BEGINTOK       ] := 'BEGIN';
Spelling[ENDTOK         ] := 'END';
Spelling[IFTOK          ] := 'IF';
Spelling[THENTOK        ] := 'THEN';
Spelling[ELSETOK        ] := 'ELSE';
Spelling[WHILETOK       ] := 'WHILE';
Spelling[DOTOK          ] := 'DO';
Spelling[REPEATTOK      ] := 'REPEAT';
Spelling[UNTILTOK       ] := 'UNTIL';
Spelling[FORTOK         ] := 'FOR';
Spelling[TOTOK          ] := 'TO';
Spelling[DOWNTOTOK      ] := 'DOWNTO';
Spelling[ASSIGNTOK      ] := ':=';
Spelling[WRITETOK       ] := 'WRITE';
Spelling[READTOK        ] := 'READ';
Spelling[HALTTOK        ] := 'HALT';
Spelling[INTRTOK        ] := 'INTR';
Spelling[ARRAYTOK       ] := 'ARRAY';
Spelling[OFTOK          ] := 'OF';
Spelling[STRINGTOK      ] := 'STRING';

Spelling[RANGETOK       ] := '..';

Spelling[EQTOK          ] := '=';
Spelling[NETOK          ] := '<>';
Spelling[LTTOK          ] := '<';
Spelling[LETOK          ] := '<=';
Spelling[GTTOK          ] := '>';
Spelling[GETOK          ] := '>=';

Spelling[DOTTOK         ] := '.';
Spelling[COMMATOK       ] := ',';
Spelling[SEMICOLONTOK   ] := ';';
Spelling[OPARTOK        ] := '(';
Spelling[CPARTOK        ] := ')';
Spelling[DEREFERENCETOK ] := '^';
Spelling[ADDRESSTOK     ] := '@';
Spelling[OBRACKETTOK    ] := '[';
Spelling[CBRACKETTOK    ] := ']';
Spelling[COLONTOK       ] := ':';

Spelling[PLUSTOK        ] := '+';
Spelling[MINUSTOK       ] := '-';
Spelling[MULTOK         ] := '*';
Spelling[DIVTOK         ] := '/';
Spelling[IDIVTOK        ] := 'DIV';
Spelling[MODTOK         ] := 'MOD';
Spelling[SHLTOK         ] := 'SHL';
Spelling[SHRTOK         ] := 'SHR';
Spelling[ORTOK          ] := 'OR';
Spelling[XORTOK         ] := 'XOR';
Spelling[ANDTOK         ] := 'AND';
Spelling[NOTTOK         ] := 'NOT';

Spelling[INTEGERTOK     ] := 'INTEGER';
Spelling[SMALLINTTOK    ] := 'SMALLINT';
Spelling[CHARTOK        ] := 'CHAR';
Spelling[BOOLEANTOK     ] := 'BOOLEAN';
Spelling[POINTERTOK     ] := 'POINTER';
Spelling[REALTOK        ] := 'REAL';


for UnitIndex := 1 to NumUnits do
  begin
  // Read input file and get tokens
  AssignFile(InFile, UnitName[UnitIndex] + '.sp');
  Reset(InFile);
  Line := 1;
  
  try
    while TRUE do
      begin
      OldNumTok := NumTok;

      repeat
        ReadChar(ch);
      until not (ch in [' ', #9, #10, #13, '{', '}']);    // Skip space, tab, line feed, carriage return, comment braces
      ch := UpCase(ch);


      Num := '';
      while ch in ['0'..'9'] do           // Number suspected
        begin
        Num := Num + ch;
        SafeReadChar(ch);
        end;

      if Length(Num) > 0 then             // Number found
        begin
        AddToken(INTNUMBERTOK, UnitIndex, Line, StrToInt(Num));

        if ch = '.' then                  // Fractional part suspected
          begin
          SafeReadChar(ch);
          if ch = '.' then
            Seek(InFile, FilePos(InFile) - 1)   // Range ('..') token
          else
            begin                         // Fractional part found
            Frac := '.';

            while ch in ['0'..'9'] do
              begin
              Frac := Frac + ch;
              SafeReadChar(ch);
              end;

            Tok[NumTok].Kind := FRACNUMBERTOK;
            Tok[NumTok].FracValue := StrToFloat(Num + Frac);
            end;
          end;

        Num := '';
        Frac := '';
        end;

      if ch in ['A'..'Z', '_'] then         // Keyword or identifier suspected
        begin
        Text := '';
        repeat
          Text := Text + ch;
          SafeReadChar(ch);
        until not (ch in ['A'..'Z', '_', '0'..'9']);
        end;

      if Length(Text) > 0 then
        begin
        AddToken(0, UnitIndex, Line, 0);

        CurToken := GetStandardToken(Text);
        if CurToken <> 0 then               // Keyword found
          Tok[NumTok].Kind := CurToken
        else
          begin                             // Identifier found
          Tok[NumTok].Kind := IDENTTOK;
          New(Tok[NumTok].Name);
          Tok[NumTok].Name^ := Text;
          end;
        Text := '';
        end;


      if ch in ['=', ',', ';', '(', ')', '*', '/', '+', '-', '^', '@', '[', ']'] then
        AddToken(GetStandardToken(ch), UnitIndex, Line, 0);


      if ch in [':', '>', '<', '.'] then                                                          // Double-character token suspected
        begin
        SafeReadChar(ch2);
        if (ch2 = '=') or ((ch = '<') and (ch2 = '>')) or ((ch = '.') and (ch2 = '.')) then       // Double-character token found
          AddToken(GetStandardToken(ch + ch2), UnitIndex, Line, 0)
        else
          begin
          Seek(InFile, FilePos(InFile) - 1);
          if ch in ['>', '<', '.', ':'] then                                                      // Single-character token found
            AddToken(GetStandardToken(ch), UnitIndex, Line, 0)
          else
            begin
            CloseFile(InFile);
            Error(NumTok, 'Unknown character: ' + ch);
            end;
          end;
        end;


        if ch = '''' then                                 // Literal suspected
          begin
          Text := '';
          repeat
            Read(InFile, ch);
            if ch = #10 then Inc(Line);
            if ch <> '''' then Text := Text + ch;
          until ch = '''';
          if Length(Text) = 1 then
            AddToken(CHARLITERALTOK, UnitIndex, Line, Ord(Text[1]))
          else
            begin
            AddToken(STRINGLITERALTOK, UnitIndex, Line, 0);
            DefineStaticString(NumTok, Text);
            end;
          Text := '';
          end;



      if NumTok = OldNumTok then         // No token found
        begin
        CloseFile(InFile);
        Error(NumTok, 'Token expected');
        end;

      end;// while

  except
    CloseFile(InFile);
  end;// try
  
  end;// for

end;// TokenizeProgram




// The following procedures implement machine code patterns
// BX register serves as the expression stack top pointer




procedure Gen(b: Byte);
begin
Code[CodeSize] := b;
if not OutputDisabled then Inc(CodeSize);
end;



procedure GenDWord(dw: LongInt);
begin
Gen(Lo(dw)); Gen(Hi(dw));
dw := dw shr 16;
Gen(Lo(dw)); Gen(Hi(dw));
end;



procedure ExpandWord;
begin
Gen($66); Gen($C1); Gen($E0); Gen(16);                          // shl eax, 16
Gen($66); Gen($C1); Gen($F8); Gen(16);                          // sar eax, 16
end;



procedure ExpandByte;
begin
Gen($98);                                                       // cbw
ExpandWord;
end;



procedure Push(Value: LongInt; IndirectionLevel: Byte; Size: Byte);
begin
case IndirectionLevel of
  ASVALUE:
    begin
    Gen($83); Gen($C3); Gen($04);                                         // add bx, 4
    Gen($66); Gen($C7); Gen($07); GenDWord(Value);                        // mov dword ptr [bx], Value
    end;
  ASPOINTER:
    begin
    case Size of
      1: begin
         Gen($A0); Gen(Lo(Value)); Gen(Hi(Value));                        // mov al, [Value]
         ExpandByte;
         end;
      2: begin
         Gen($A1); Gen(Lo(Value)); Gen(Hi(Value));                        // mov ax, [Value]
         ExpandWord;
         end;
      4: begin
         Gen($66); Gen($A1); Gen(Lo(Value)); Gen(Hi(Value));              // mov eax, [Value]
         end;
      end;
    Gen($83); Gen($C3); Gen($04);                                         // add bx, 4
    Gen($66); Gen($89); Gen($07);                                         // mov [bx], eax
    end;
  ASPOINTERTOPOINTER:
    begin
    Gen($8B); Gen($2E); Gen(Lo(Value)); Gen(Hi(Value));                   // mov bp, [Value]
    case Size of
      1: begin
         Gen($8A); Gen($46); Gen($00);                                    // mov al, [bp]
         ExpandByte;
         end;
      2: begin
         Gen($8B); Gen($46); Gen($00);                                    // mov ax, [bp]
         ExpandWord;
         end;
      4: begin
         Gen($66); Gen($8B); Gen($46); Gen($00);                          // mov eax, [bp]
         end;
      end;
    Gen($83); Gen($C3); Gen($04);                                         // add bx, 4
    Gen($66); Gen($89); Gen($07);                                         // mov [bx], eax
    end;
  ASPOINTERTOARRAYORIGIN:
    begin
    Gen($8B); Gen($2E); Gen(Lo(Value)); Gen(Hi(Value));                   // mov bp, [Value]
    Gen($8B); Gen($37);                                                   // mov si, [bx]
    case Size of
      1: begin
         Gen($8A); Gen($02);                                              // mov al, [bp + si]
         ExpandByte;
         end;
      2: begin
         Gen($C1); Gen($E6); Gen($01);                                    // shl si, 1
         Gen($8B); Gen($02);                                              // mov ax, [bp + si]
         ExpandWord;
         end;
      4: begin
         Gen($C1); Gen($E6); Gen($02);                                    // shl si, 2
         Gen($66); Gen($8B); Gen($02);                                    // mov eax, [bp + si]
         end;
      end;
    Gen($66); Gen($89); Gen($07);                                         // mov [bx], eax
    end;
end;// case
end;



procedure SaveToSystemStack;
begin
Gen($66); Gen($FF); Gen($37);                                     // push dword ptr [bx]
end;




procedure RestoreFromSystemStack;
begin
Gen($83); Gen($C3); Gen($04);                           // add bx, 4
Gen($66); Gen($8F); Gen($07);                           // pop dword ptr [bx]
end;




procedure RemoveFromSystemStack;
begin
Gen($66); Gen($58);                                     // pop eax
end;




procedure GenerateAssignment(Address: LongInt; IndirectionLevel: Byte; Size: Byte);
begin
Gen($66); Gen($8B); Gen($07);                                             // mov eax, [bx]
Gen($83); Gen($EB); Gen($04);                                             // sub bx, 4

case IndirectionLevel of
  ASPOINTERTOARRAYORIGIN:
    begin
    Gen($8B); Gen($2E); Gen(Lo(Address)); Gen(Hi(Address));               // mov bp, [Address]
    Gen($8B); Gen($37);                                                   // mov si, [bx]
    Gen($83); Gen($EB); Gen($04);                                         // sub bx, 4
    case Size of
      1: begin
         Gen($88); Gen($02);                                              // mov [bp + si], al
         end;
      2: begin
         Gen($C1); Gen($E6); Gen($01);                                    // shl si, 1
         Gen($89); Gen($02);                                              // mov [bp + si], ax
         end;
      4: begin
         Gen($C1); Gen($E6); Gen($02);                                    // shl si, 2
         Gen($66); Gen($89); Gen($02);                                    // mov [bp + si], eax
         end;
      end;   
    end;
  ASPOINTERTOPOINTER:
    begin
    Gen($8B); Gen($2E); Gen(Lo(Address)); Gen(Hi(Address));               // mov bp, [Address]
    case Size of
      1: begin
         Gen($88); Gen($46); Gen($00);                                    // mov [bp], al
         end;
      2: begin
         Gen($89); Gen($46); Gen($00);                                    // mov [bp], ax
         end;
      4: begin
         Gen($66); Gen($89); Gen($46); Gen($00);                          // mov [bp], eax
         end;
      end;   
    end;
  ASPOINTER:
    begin
    case Size of
      1: begin
         Gen($A2); Gen(Lo(Address)); Gen(Hi(Address));                    // mov [Address], al
         end;
      2: begin
         Gen($A3); Gen(Lo(Address)); Gen(Hi(Address));                    // mov [Address], ax
         end;
      4: begin
         Gen($66); Gen($A3); Gen(Lo(Address)); Gen(Hi(Address));          // mov [Address], eax
         end;
      end;
    end;
end;// case

end;





procedure GenerateCall(Entry: LongInt);
var
  CodePos: Word;
begin
CodePos := CodeSize;
Gen($E8); Gen(Lo(Entry - (CodePos + 3))); Gen(Hi(Entry - (CodePos + 3)));           // call Entry
end;




procedure GenerateReturn;
begin
Gen($C3);                                                               // ret
end;




procedure GenerateIfThenCondition;
begin
Gen($66); Gen($8B); Gen($07);                                           // mov eax, [bx]
Gen($83); Gen($EB); Gen($04);                                           // sub bx, 4
Gen($66); Gen($83); Gen($F8); Gen($00);                                 // cmp eax, 0
Gen($75); Gen($03);                                                     // jne +3
end;




procedure GenerateElseCondition;
begin
Gen($66); Gen($8B); Gen($07);                                           // mov eax, [bx]
Gen($83); Gen($EB); Gen($04);                                           // sub bx, 4
Gen($66); Gen($83); Gen($F8); Gen($00);                                 // cmp eax, 0
Gen($74); Gen($03);                                                     // je  +3
end;




procedure GenerateWhileDoCondition;
begin
GenerateIfThenCondition;
end;



procedure GenerateRepeatUntilCondition;
begin
GenerateIfThenCondition;
end;




procedure GenerateForToDoCondition(CounterAddress: Word; CounterSize: Byte; Down: Boolean);
begin
Gen($66); Gen($8B); Gen($0F);                                                           // mov ecx, [bx]
Gen($83); Gen($EB); Gen($04);                                                           // sub bx, 4
case CounterSize of
  1: begin
     Gen($A0); Gen(Lo(CounterAddress)); Gen(Hi(CounterAddress));                        // mov al, [CounterAddress]
     ExpandByte;
     end;
  2: begin
     Gen($A1); Gen(Lo(CounterAddress)); Gen(Hi(CounterAddress));                        // mov ax, [CounterAddress]
     ExpandWord;
     end;
  4: begin
     Gen($66); Gen($A1); Gen(Lo(CounterAddress)); Gen(Hi(CounterAddress));              // mov eax, [CounterAddress]
     end;
  end;
Gen($66); Gen($3B); Gen($C1);                                                           // cmp eax, ecx
if Down then
  begin
  Gen($7D); Gen($03);                                                                   // jge +3
  end
else
  begin
  Gen($7E); Gen($03);                                                                   // jle +3
  end;
end;




procedure GenerateIfThenProlog;
begin
Inc(CodePosStackTop);
CodePosStack[CodePosStackTop] := CodeSize;

Gen($90);                                                               // nop   ; jump to the IF..THEN block end will be inserted here
Gen($90);                                                               // nop
Gen($90);                                                               // nop
end;




procedure GenerateIfThenEpilog;
var
  CodePos: Word;
begin
CodePos := CodePosStack[CodePosStackTop];
Dec(CodePosStackTop);

Code[CodePos] := $E9; Code[CodePos + 1] := Lo(CodeSize - (CodePos + 3)); Code[CodePos + 2] := Hi(CodeSize - (CodePos + 3));  // jmp (IF..THEN block end)
end;




procedure GenerateWhileDoProlog;
begin
GenerateIfThenProlog;
end;




procedure GenerateWhileDoEpilog;
var
  CodePos, CurPos, ReturnPos: Word;
begin
CodePos := CodePosStack[CodePosStackTop];
Dec(CodePosStackTop);

Code[CodePos] := $E9; Code[CodePos + 1] := Lo(CodeSize - (CodePos + 3) + 3); Code[CodePos + 2] := Hi(CodeSize - (CodePos + 3) + 3);  // jmp (WHILE..DO block end)

ReturnPos := CodePosStack[CodePosStackTop];
Dec(CodePosStackTop);

CurPos := CodeSize;

Gen($E9); Gen(Lo(ReturnPos - (CurPos + 3))); Gen(Hi(ReturnPos - (CurPos + 3)));             // jmp ReturnPos
end;




procedure GenerateRepeatUntilProlog;
begin
Inc(CodePosStackTop);
CodePosStack[CodePosStackTop] := CodeSize;
end;




procedure GenerateRepeatUntilEpilog;
var
  CurPos, ReturnPos: Word;
begin
ReturnPos := CodePosStack[CodePosStackTop];
Dec(CodePosStackTop);

CurPos := CodeSize;

Gen($E9); Gen(Lo(ReturnPos - (CurPos + 3))); Gen(Hi(ReturnPos - (CurPos + 3)));             // jmp ReturnPos
end;





procedure GenerateForToDoProlog;
begin
GenerateWhileDoProlog;
end;




procedure GenerateForToDoEpilog(CounterAddress: Word; CounterSize: Byte; Down: Boolean);
begin
case CounterSize of
  1: begin
     Gen($FE);                                          // ... byte ptr ...
     end;
  2: begin
     Gen($FF);                                          // ... word ptr ...
     end;
  4: begin
     Gen($66); Gen($FF);                                // ... dword ptr ...
     end;
  end;

if Down then
  Gen($0E)                                              // dec ...
else
  Gen($06);                                             // inc ...

Gen(Lo(CounterAddress)); Gen(Hi(CounterAddress));       // ... [CounterAddress]

GenerateWhileDoEpilog;
end;




procedure GenerateProgramProlog;
var
  i: Integer;
begin
Gen($E9); Gen(Lo(NumStaticStrChars)); Gen(Hi(NumStaticStrChars));       // jmp +NumStaticStrChars

// Build static string data table
for i := 0 to NumStaticStrChars - 1 do
  Gen(Ord(StaticStringData[i]));                                        // db StaticStringData[i]

Gen($BB); Gen(Lo(STACKORIGIN)); Gen(Hi(STACKORIGIN));                   // mov bx, STACKORIGIN
end;




procedure GenerateProgramEpilog;
begin
Gen($B4); Gen($4C);                                                     // mov ah, 4Ch
Gen($B0); Gen($00);                                                     // mov al, 0
Gen($CD); Gen($21);                                                     // int 21h
end;




procedure GenerateDeclarationProlog;
begin
GenerateIfThenProlog;
end;




procedure GenerateDeclarationEpilog;
begin
GenerateIfThenEpilog;
end;




procedure GenerateRead;
begin
Gen($8B); Gen($2F);                                                     // mov bp, [bx]
Gen($83); Gen($EB); Gen($04);                                           // sub bx, 4
Gen($B4); Gen($01);                                                     // mov ah, 01h
Gen($CD); Gen($21);                                                     // int 21h
Gen($88); Gen($46); Gen($00);                                           // mov [bp], al
end;// GenerateRead




procedure GenerateWrite;
begin
Gen($B4); Gen($02);                                                     // mov ah, 02h
Gen($8A); Gen($17);                                                     // mov dl, [bx]
Gen($CD); Gen($21);                                                     // int 21h
Gen($83); Gen($EB); Gen($04);                                           // sub bx, 4
end;// GenerateWrite




procedure GenerateWriteString(Address: Word; IndirectionLevel: Byte);
begin
Gen($B4); Gen($09);                                                     // mov ah, 09h
case IndirectionLevel of
  ASPOINTER:
    begin
    Gen($BA); Gen(Lo(Address)); Gen(Hi(Address));                       // mov dx, Address
    end;
  ASPOINTERTOPOINTER:
    begin
    Gen($8B); Gen($16); Gen(Lo(Address)); Gen(Hi(Address));             // mov dx, [Address]
    end;
  end;      
Gen($CD); Gen($21);                                                     // int 21h
end;// GenerateWriteString




procedure GenerateInterrupt(InterruptNumber: Byte);
begin
Gen($53);                                                               // push bx
Gen($8B); Gen($2F);                                                     // mov bp, [bx]
Gen($8B); Gen($46); Gen($00);                                           // mov ax, [bp]
Gen($8B); Gen($5E); Gen($04);                                           // mov bx, [bp + 4]
Gen($8B); Gen($4E); Gen($08);                                           // mov cx, [bp + 8]
Gen($8B); Gen($56); Gen($0C);                                           // mov dx, [bp + 12]
Gen($CD); Gen(InterruptNumber);                                         // int InterruptNumber
Gen($89); Gen($46); Gen($00);                                           // mov [bp], ax
Gen($89); Gen($5E); Gen($04);                                           // mov [bp + 4], bx
Gen($89); Gen($4E); Gen($08);                                           // mov [bp + 8], cx
Gen($89); Gen($56); Gen($0C);                                           // mov [bp + 12], dx
Gen($5B);                                                               // pop bx
Gen($83); Gen($EB); Gen($04);                                           // sub bx, 4
end;// GenerateInterrupt




procedure GenerateUnaryOperation(op: Byte);
begin
case op of
  PLUSTOK:
    begin
    end;
  MINUSTOK:
    begin
    Gen($66); Gen($F7); Gen($1F);                                       // neg dword ptr [bx]
    end;
  NOTTOK:
    begin
    Gen($66); Gen($F7); Gen($17);                                       // not dword ptr [bx]
    end;
end;// case
end;




procedure GenerateBinaryOperation(op: Byte; ResultType: Byte);
begin
Gen($66); Gen($8B); Gen($0F);                                           // mov ecx, [bx]
Gen($83); Gen($EB); Gen($04);                                           // sub bx, 4
Gen($66); Gen($8B); Gen($07);                                           // mov eax, [bx]

case op of
  PLUSTOK:
    begin
    Gen($66); Gen($03); Gen($C1);                                       // add eax, ecx
    end;
  MINUSTOK:
    begin
    Gen($66); Gen($2B); Gen($C1);                                       // sub eax, ecx
    end;
  MULTOK:
    begin
    if ResultType = REALTOK then      // Real fixed-point multiplication
      begin
      Gen($66); Gen($F7); Gen($E9);                                     // imul ecx
      Gen($66); Gen($C1); Gen($E2); Gen(32 - FRACBITS);                 // shl edx, 32 - FRACBITS
      Gen($66); Gen($C1); Gen($E8); Gen(FRACBITS);                      // shr eax, FRACBITS
      Gen($66); Gen($0B); Gen($C2);                                     // or eax, edx
      end
    else                              // Integer multiplication
      begin
      Gen($66); Gen($F7); Gen($E9);                                     // imul ecx
      end;
    end;
  DIVTOK, IDIVTOK, MODTOK:
    begin
    if ResultType = REALTOK then      // Real fixed-point division
      begin
      Gen($66); Gen($8B); Gen($D0);                                       // mov edx, eax           ; scale numerator
      Gen($66); Gen($C1); Gen($FA); Gen(32 - FRACBITS);                   // sar edx, 32 - FRACBITS
      Gen($66); Gen($C1); Gen($E0); Gen(FRACBITS);                        // shl eax, FRACBITS
      Gen($66); Gen($F7); Gen($F9);                                       // idiv ecx
      end
    else                              // Integer division
      begin
      Gen($66); Gen($99);                                                 // cdq
      Gen($66); Gen($F7); Gen($F9);                                       // idiv ecx
      if op = MODTOK then
        begin
        Gen($66); Gen($8B); Gen($C2);                                     // mov eax, edx         ; save remainder
        end;
      end;
    end;  
  SHLTOK:
    begin
    Gen($66); Gen($D3); Gen($E0);                                       // shl eax, cl
    end;
  SHRTOK:
    begin
    Gen($66); Gen($D3); Gen($E8);                                       // shr eax, cl
    end;
  ANDTOK:
    begin
    Gen($66); Gen($23); Gen($C1);                                       // and eax, ecx
    end;
  ORTOK:
    begin
    Gen($66); Gen($0B); Gen($C1);                                       // or eax, ecx
    end;
  XORTOK:
    begin
    Gen($66); Gen($33); Gen($C1);                                       // xor eax, ecx
    end;

end;// case

Gen($66); Gen($89); Gen($07);                                           // mov [bx], eax
end;




procedure GenerateRelation(rel: Byte);
begin
Gen($66); Gen($8B); Gen($0F);                                           // mov ecx, [bx]
Gen($83); Gen($EB); Gen($04);                                           // sub bx, 4
Gen($66); Gen($8B); Gen($07);                                           // mov eax, [bx]

Gen($66); Gen($BA); GenDWord($FFFFFFFF);                                // mov edx, FFFFFFFFh
Gen($66); Gen($89); Gen($17);                                           // mov [bx], edx
Gen($66); Gen($BA); GenDWord($00000000);                                // mov edx, 00000000h

Gen($66); Gen($3B); Gen($C1);                                           // cmp eax, ecx

case rel of
  EQTOK:
    begin
    Gen($74); Gen($03);                                                 // je +3
    end;
  NETOK:
    begin
    Gen($75); Gen($03);                                                 // jne +3
    end;
  GTTOK:
    begin
    Gen($7F); Gen($03);                                                 // jg +3
    end;
  GETOK:
    begin
    Gen($7D); Gen($03);                                                 // jge +3
    end;
  LTTOK:
    begin
    Gen($7C); Gen($03);                                                 // jl +3
    end;
  LETOK:
    begin
    Gen($7E); Gen($03);                                                 // jle +3
    end;
end;// case

Gen($66); Gen($89); Gen($17);                                           // mov [bx], edx

end;




// The following functions implement recursive descent parser in accordance with Sub-Pascal EBNF
// Parameter i is the index of the first token of the current EBNF symbol, result is the index of the last one




function CompileConstExpression(i: Integer; var ConstVal: LongInt; var ConstValType: Byte): Integer; forward;
function CompileExpression(i: Integer; var ValType: Byte): Integer; forward;




function CompileConstFactor(i: Integer; var ConstVal: LongInt; var ConstValType: Byte): Integer;
var
  IdentIndex, j: Integer;
begin
case Tok[i].Kind of
  IDENTTOK:
    begin
    IdentIndex := GetIdent(Tok[i].Name^);
    if IdentIndex > 0 then
      if Ident[IdentIndex].Kind <> CONSTANT then
        Error(i, 'Constant expected but ' + Ident[IdentIndex].Name + ' found')
      else
        begin
        ConstVal := Ident[IdentIndex].Value;
        ConstValType := Ident[IdentIndex].DataType;
        end
    else
      Error(i, 'Unknown identifier: ' + Tok[i].Name^);
    Result := i;
    end;


  INTNUMBERTOK:
    begin
    ConstVal := Tok[i].Value;
    ConstValType := INTEGERTOK;
    Result := i;
    end;


  FRACNUMBERTOK:
    begin
    ConstVal := Round(Tok[i].FracValue * TWOPOWERFRACBITS);
    ConstValType := REALTOK;
    Result := i;
    end;


  CHARLITERALTOK:
    begin
    ConstVal := Tok[i].Value;
    ConstValType := CHARTOK;
    Result := i;
    end;


  OPARTOK:       // a whole expression in parentheses suspected
    begin
    j := CompileConstExpression(i + 1, ConstVal, ConstValType);
    if Tok[j + 1].Kind <> CPARTOK then
      Error(j + 1, ') expected but ' + GetSpelling(j + 1) + ' found');
    Result := j + 1;
    end;


  NOTTOK:
    begin
    Result := CompileConstFactor(i + 1, ConstVal, ConstValType);
    ConstVal := not ConstVal;
    end; 

else
  Error(i, 'Identifier, number or expression expected but ' + GetSpelling(i) + ' found');
end;// case

end;// CompileConstFactor




function CompileConstTerm(i: Integer; var ConstVal: LongInt; var ConstValType: Byte): Integer;
var
  j, k: Integer;
  RightConstVal: LongInt;
  RightConstValType: Byte;

begin
j := CompileConstFactor(i, ConstVal, ConstValType);

while Tok[j + 1].Kind in [MULTOK, DIVTOK, IDIVTOK, MODTOK, SHLTOK, SHRTOK, ANDTOK] do
  begin
  k := CompileConstFactor(j + 2, RightConstVal, RightConstValType);
  case Tok[j + 1].Kind of
    MULTOK:          ConstVal := ConstVal  *  RightConstVal;
    DIVTOK, IDIVTOK: ConstVal := ConstVal div RightConstVal;
    MODTOK:          ConstVal := ConstVal mod RightConstVal;
    SHLTOK:          ConstVal := ConstVal shl RightConstVal;
    SHRTOK:          ConstVal := ConstVal shr RightConstVal;
    ANDTOK:          ConstVal := ConstVal and RightConstVal;
  end;
  ConstValType := GetCommonType(j + 1, ConstValType, RightConstValType);

  j := k;
  end;

Result := j;
end;// CompileConstTerm



function CompileSimpleConstExpression(i: Integer; var ConstVal: LongInt; var ConstValType: Byte): Integer;
var
  j, k: Integer;
  RightConstVal: LongInt;
  RightConstValType: Byte;

begin
if Tok[i].Kind in [PLUSTOK, MINUSTOK] then j := i + 1 else j := i;

j := CompileConstTerm(j, ConstVal, ConstValType);

if Tok[i].Kind = MINUSTOK then ConstVal := -ConstVal;     // Unary minus

while Tok[j + 1].Kind in [PLUSTOK, MINUSTOK, ORTOK, XORTOK] do
  begin
  k := CompileConstTerm(j + 2, RightConstVal, RightConstValType);
  case Tok[j + 1].Kind of
    PLUSTOK:  ConstVal := ConstVal  +  RightConstVal;
    MINUSTOK: ConstVal := ConstVal  -  RightConstVal;
    ORTOK:    ConstVal := ConstVal  or RightConstVal;
    XORTOK:   ConstVal := ConstVal xor RightConstVal;
  end;
  ConstValType := GetCommonType(j + 1, ConstValType, RightConstValType);

  j := k;
  end;

Result := j;
end;// CompileSimpleConstExpression



function CompileConstExpression(i: Integer; var ConstVal: LongInt; var ConstValType: Byte): Integer;
var
  j: Integer;
  RightConstVal: LongInt;
  RightConstValType: Byte;
  Yes: Boolean;

begin
i := CompileSimpleConstExpression(i, ConstVal, ConstValType);

if Tok[i + 1].Kind in [EQTOK, NETOK, LTTOK, LETOK, GTTOK, GETOK] then
  begin
  j := CompileSimpleConstExpression(i + 2, RightConstVal, RightConstValType);
  case Tok[i + 1].Kind of
    EQTOK: Yes := ConstVal =  RightConstVal;
    NETOK: Yes := ConstVal <> RightConstVal;
    LTTOK: Yes := ConstVal <  RightConstVal;
    LETOK: Yes := ConstVal <= RightConstVal;
    GTTOK: Yes := ConstVal >  RightConstVal;
    GETOK: Yes := ConstVal >= RightConstVal;
  end;
  if Yes then ConstVal := -1 else ConstVal := 0;
  ConstValType := GetCommonType(j + 1, ConstValType, RightConstValType);

  i := j;
  end;

Result := i;
end;// CompileConstExpression





function CompileFactor(i: Integer; var ValType: Byte): Integer;
var
  IdentIndex, NumActualParams, j: Integer;
  ArrayIndexType, ActualParamType: Byte;
begin
case Tok[i].Kind of
  IDENTTOK:
    begin
    IdentIndex := GetIdent(Tok[i].Name^);
    if IdentIndex > 0 then
      if Ident[IdentIndex].Kind = PROC then
        Error(i, 'Variable, constant or function name expected but procedure ' + Ident[IdentIndex].Name + ' found')
      else if Ident[IdentIndex].Kind = FUNC then       // Function call
        begin
        NumActualParams := 0;
        if Tok[i + 1].Kind = OPARTOK then              // Actual parameter list found
          begin
          repeat
            i := CompileExpression(i + 2, ActualParamType);  // Evaluate actual parameters and push them onto the stack
            Inc(NumActualParams);
            GetCommonType(i, Ident[IdentIndex].ParamType[NumActualParams], ActualParamType);
          until Tok[i + 1].Kind <> COMMATOK;

          if Tok[i + 1].Kind <> CPARTOK then
            Error(i + 1, ') expected but ' + GetSpelling(i + 1) + ' found');

          i := i + 1;
          end;// if Tok[i + 1].Kind = OPARTOR

        if NumActualParams <> Ident[IdentIndex].NumParams then
          Error(i, 'Wrong number of actual parameters in ' + Ident[IdentIndex].Name + ' call');

        if Pass = CALLDETERMPASS then
          AddCallGraphChild(BlockStack[BlockStackTop], Ident[IdentIndex].ProcAsBlock);
          
        GenerateCall(Ident[IdentIndex].Value);
        ValType := Ident[IdentIndex].DataType;
        Result := i;
        end // FUNC
      else
        begin
        if Tok[i + 1].Kind = DEREFERENCETOK then
          if (Ident[IdentIndex].Kind <> VARIABLE) or (Ident[IdentIndex].DataType <> POINTERTOK) then
            Error(i, 'Incompatible type of ' + Ident[IdentIndex].Name)
          else
            begin
            Push(Ident[IdentIndex].Value, ASPOINTERTOPOINTER, DataSize[INTEGERTOK]);
            ValType := INTEGERTOK;
            Result := i + 1;
            end
        else if Tok[i + 1].Kind = OBRACKETTOK then                    // Array element access
          if (Ident[IdentIndex].Kind <> VARIABLE) or (Ident[IdentIndex].DataType <> POINTERTOK) then
            Error(i, 'Incompatible type of ' + Ident[IdentIndex].Name)
          else
            begin
            i := CompileExpression(i + 2, ArrayIndexType);            // Array index
            if ArrayIndexType = REALTOK then
              Error(i, 'Array index must be integer');
            Push(Ident[IdentIndex].Value, ASPOINTERTOARRAYORIGIN, DataSize[Ident[IdentIndex].AllocElementType]);
            if Tok[i + 1].Kind <> CBRACKETTOK then
              Error(i + 1, '] expected but ' + GetSpelling(i + 1) + ' found');
            ValType := Ident[IdentIndex].AllocElementType;
            Result := i + 1;
            end
        else                                                          // Usual variable or constant
          begin
          Push(Ident[IdentIndex].Value, Ord(Ident[IdentIndex].Kind = VARIABLE), DataSize[Ident[IdentIndex].DataType]);
          ValType := Ident[IdentIndex].DataType;
          Result := i;
          end;
        end
    else
      Error(i, 'Unknown identifier: ' + Tok[i].Name^);
    end;


  ADDRESSTOK:
    if Tok[i + 1].Kind <> IDENTTOK then
      Error(i + 1, 'Identifier expected but ' + GetSpelling(i + 1) + ' found')
    else
      begin
      IdentIndex := GetIdent(Tok[i + 1].Name^);
      if IdentIndex > 0 then
        begin
        if Ident[IdentIndex].Kind = CONSTANT then
          Error(i + 1, 'Unable to get address of constant ' + Ident[IdentIndex].Name)
        else
          begin
          Push(Ident[IdentIndex].Value, ASVALUE, DataSize[POINTERTOK]);
          ValType := POINTERTOK;
          Result := i + 1;
          end
        end
      else
        Error(i + 1, 'Unknown identifier: ' + Tok[i + 1].Name^);
      end;// else


  INTNUMBERTOK:
    begin
    Push(Tok[i].Value, ASVALUE, DataSize[INTEGERTOK]);
    ValType := INTEGERTOK;
    Result := i;
    end;


  FRACNUMBERTOK:
    begin
    Push(Round(Tok[i].FracValue * TWOPOWERFRACBITS), ASVALUE, DataSize[REALTOK]);
    ValType := REALTOK;
    Result := i;
    end;


  CHARLITERALTOK:
    begin
    Push(Tok[i].Value, ASVALUE, DataSize[CHARTOK]);
    ValType := CHARTOK;
    Result := i;
    end;


  OPARTOK:       // a whole expression in parentheses suspected
    begin
    j := CompileExpression(i + 1, ValType);
    if Tok[j + 1].Kind <> CPARTOK then
      Error(j + 1, ') expected but ' + GetSpelling(j + 1) + ' found');
    Result := j + 1;
    end;


  NOTTOK:
    begin
    Result := CompileFactor(i + 1, ValType);
    GenerateUnaryOperation(NOTTOK);
    end;


  INTEGERTOK, SMALLINTTOK, CHARTOK, BOOLEANTOK, POINTERTOK, REALTOK:       // type conversion operations
    begin
    if Tok[i + 1].Kind <> OPARTOK then
      Error(i + 1, '( expected but ' + GetSpelling(i + 1) + ' found');
    j := CompileExpression(i + 2, ValType);
    if Tok[j + 1].Kind <> CPARTOK then
      Error(j + 1, ') expected but ' + GetSpelling(j + 1) + ' found');

    ValType := Tok[i].Kind;
    Result := j + 1;
    end;

else
  Error(i, 'Identifier, number or expression expected but ' + GetSpelling(i) + ' found');
end;// case

end;// CompileFactor




function CompileTerm(i: Integer; var ValType: Byte): Integer;
var
  j, k: Integer;
  RightValType: Byte;
begin
j := CompileFactor(i, ValType);

while Tok[j + 1].Kind in [MULTOK, DIVTOK, IDIVTOK, MODTOK, SHLTOK, SHRTOK, ANDTOK] do
  begin
  k := CompileFactor(j + 2, RightValType);
  ValType := GetCommonType(j + 1, ValType, RightValType);
  GenerateBinaryOperation(Tok[j + 1].Kind, ValType);
  j := k;
  end;

Result := j;
end;// CompileTerm



function CompileSimpleExpression(i: Integer; var ValType: Byte): Integer;
var
  j, k: Integer;
  RightValType: Byte;
begin
if Tok[i].Kind in [PLUSTOK, MINUSTOK] then j := i + 1 else j := i;

j := CompileTerm(j, ValType);

if Tok[i].Kind = MINUSTOK then GenerateUnaryOperation(MINUSTOK);     // Unary minus

while Tok[j + 1].Kind in [PLUSTOK, MINUSTOK, ORTOK, XORTOK] do
  begin
  k := CompileTerm(j + 2, RightValType);
  ValType := GetCommonType(j + 1, ValType, RightValType);
  GenerateBinaryOperation(Tok[j + 1].Kind, ValType);
  j := k;
  end;

Result := j;
end;// CompileSimpleExpression



function CompileExpression(i: Integer; var ValType: Byte): Integer;
var
  j: Integer;
  RightValType: Byte;
begin
i := CompileSimpleExpression(i, ValType);

if Tok[i + 1].Kind in [EQTOK, NETOK, LTTOK, LETOK, GTTOK, GETOK] then
  begin
  j := CompileSimpleExpression(i + 2, RightValType);
  ValType := GetCommonType(j + 1, ValType, RightValType);
  GenerateRelation(Tok[i + 1].Kind);
  i := j;
  end;

Result := i;
end;// CompileExpression




function CompileStatement(i: Integer): Integer;
var
  j, IdentIndex, CharIndex, NumActualParams, IndirectionLevel, InterruptNumber, NumCharacters: Integer;
  ArrayIndexType, ExpressionType, ActualParamType, VarType: Byte;
  Down: Boolean;                                                        // To distinguish TO / DOWNTO loops
  StringOutput: Boolean;
begin

case Tok[i].Kind of
  IDENTTOK:
    begin
    IdentIndex := GetIdent(Tok[i].Name^);
    if IdentIndex > 0 then
      case Ident[IdentIndex].Kind of
      
        VARIABLE:                                        // Variable or array element assignment
          begin
          if Tok[i + 1].Kind = DEREFERENCETOK then       // With dereferencing
            begin
            if Ident[IdentIndex].DataType <> POINTERTOK then
              Error(i + 1, 'Incompatible type of ' + Ident[IdentIndex].Name);

            VarType := INTEGERTOK;
            IndirectionLevel := ASPOINTERTOPOINTER;
            i := i + 1;
            end
          else if Tok[i + 1].Kind = OBRACKETTOK then     // With indexing
            begin
            if Ident[IdentIndex].DataType <> POINTERTOK then
              Error(i + 1, 'Incompatible type of ' + Ident[IdentIndex].Name);
              
            i := CompileExpression(i + 2, ArrayIndexType);               // Array index
            if ArrayIndexType = REALTOK then
              Error(i, 'Array index must be integer');

            if Tok[i + 1].Kind <> CBRACKETTOK then
              Error(i + 1, '] expected but ' + GetSpelling(i + 1) + ' found');

            VarType := Ident[IdentIndex].AllocElementType;
            IndirectionLevel := ASPOINTERTOARRAYORIGIN;
            i := i + 1;
            end
          else                                           // Without dereferencing or indexing
            begin
            VarType := Ident[IdentIndex].DataType;
            IndirectionLevel := ASPOINTER;
            end;

          if Tok[i + 1].Kind <> ASSIGNTOK then
            Error(i + 1, ':= expected but ' + GetSpelling(i + 1) + ' found')
          else
            if (Ident[IdentIndex].DataType = POINTERTOK) and
               (Ident[IdentIndex].AllocElementType = CHARTOK) and
               (Ident[IdentIndex].NumAllocElements > 0) and
               (IndirectionLevel = ASPOINTER) and
               ((Tok[i + 2].Kind = STRINGLITERALTOK) or (Tok[i + 2].Kind = CHARLITERALTOK)) then
              begin
              if Tok[i + 2].Kind = CHARLITERALTOK then                                  // Character assignment to pointer
                begin
                Push(Tok[i + 2].Value, ASVALUE, DataSize[CHARTOK]);
                GenerateAssignment(Ident[IdentIndex].Value, ASPOINTERTOPOINTER, DataSize[CHARTOK]);

                Push(1, ASVALUE, DataSize[INTEGERTOK]);                                 // String element index
                Push(Ord('$'), ASVALUE, DataSize[CHARTOK]);                             // String termination character
                GenerateAssignment(Ident[IdentIndex].Value, ASPOINTERTOARRAYORIGIN, DataSize[CHARTOK]);

                Result := i + 2;
                end // if
              else                                                                      // String assignment to pointer
                begin
                NumCharacters := Min(Tok[i + 2].StrLength, Ident[IdentIndex].NumAllocElements - 1);
                for CharIndex := 1 to NumCharacters do
                  begin
                  Push(CharIndex - 1, ASVALUE, DataSize[INTEGERTOK]);                   // String element index
                  Push(Ord(StaticStringData[Tok[i + 2].StrAddress - (CODEORIGIN + 3) + (CharIndex - 1)]), ASVALUE, DataSize[CHARTOK]);
                  GenerateAssignment(Ident[IdentIndex].Value, ASPOINTERTOARRAYORIGIN, DataSize[CHARTOK]);
                  end; // for

                Push(NumCharacters, ASVALUE, DataSize[INTEGERTOK]);                      // String element index
                Push(Ord('$'), ASVALUE, DataSize[CHARTOK]);                             // String termination character
                GenerateAssignment(Ident[IdentIndex].Value, ASPOINTERTOARRAYORIGIN, DataSize[CHARTOK]);

                Result := i + 2;
                end; // else
              end // if
            else
              begin                                                                     // Usual assignment
              Result := CompileExpression(i + 2, ExpressionType);                       // Right-hand side expression

              if IndirectionLevel = ASPOINTERTOARRAYORIGIN then
                GetCommonType(i + 1, Ident[IdentIndex].AllocElementType, ExpressionType)
              else
                GetCommonType(i + 1, Ident[IdentIndex].DataType, ExpressionType);

              GenerateAssignment(Ident[IdentIndex].Value, IndirectionLevel, DataSize[VarType]);
              end
          end;// VARIABLE

        PROC:                                            // Procedure call
          begin
          NumActualParams := 0;
          if Tok[i + 1].Kind = OPARTOK then              // Actual parameter list found
            begin
            repeat
              i := CompileExpression(i + 2, ActualParamType);     // Evaluate actual parameters and push them onto the stack
              Inc(NumActualParams);
              GetCommonType(i, Ident[IdentIndex].ParamType[NumActualParams], ActualParamType);
            until Tok[i + 1].Kind <> COMMATOK;

            if Tok[i + 1].Kind <> CPARTOK then
              Error(i + 1, ') expected but ' + GetSpelling(i + 1) + ' found');

            i := i + 1;  
            end;// if Tok[i + 1].Kind = OPARTOR

          if NumActualParams <> Ident[IdentIndex].NumParams then
            Error(i, 'Wrong number of actual parameters in ' + Ident[IdentIndex].Name + ' call');

          if Pass = CALLDETERMPASS then
            AddCallGraphChild(BlockStack[BlockStackTop], Ident[IdentIndex].ProcAsBlock);

          GenerateCall(Ident[IdentIndex].Value);
          Result := i;
          end;// PROC
      else
        Error(i, 'Assignment or procedure call expected but ' + Ident[IdentIndex].Name + ' found');
      end// case Ident[IdentIndex].Kind
    else
      Error(i, 'Unknown identifier: ' + Tok[i].Name^);
    end;

  BEGINTOK:
    begin
    j := CompileStatement(i + 1);
    while Tok[j + 1].Kind = SEMICOLONTOK do
      j := CompileStatement(j + 2);
    if Tok[j + 1].Kind <> ENDTOK then
      Error(j + 1, 'END expected but ' + GetSpelling(j + 1) + ' found');
    Result := j + 1;
    end;

  IFTOK:
    begin
    j := CompileExpression(i + 1, ExpressionType);
    if Tok[j + 1].Kind <> THENTOK then
      Error(j + 1, 'THEN expected but ' + GetSpelling(j + 1) + ' found')
    else
      begin
      SaveToSystemStack;                      // Save conditional expression at expression stack top onto the system stack
      GenerateIfThenCondition;                // Satisfied if expression is not zero
      GenerateIfThenProlog;
      j := CompileStatement(j + 2);
      GenerateIfThenEpilog;
      Result := j;

      if Tok[j + 1].Kind = ELSETOK then
        begin
        RestoreFromSystemStack;               // Restore conditional expression
        GenerateElseCondition;                // Satisfied if expression is zero
        GenerateIfThenProlog;
        j := CompileStatement(j + 2);
        GenerateIfThenEpilog;
        Result := j;
        end
      else
        RemoveFromSystemStack;                // Remove conditional expression
      end;// else
    end;

  WHILETOK:
    begin
    Inc(CodePosStackTop);
    CodePosStack[CodePosStackTop] := CodeSize;          // Save return address used by GenerateWhileDoEpilog

    j := CompileExpression(i + 1, ExpressionType);
    if Tok[j + 1].Kind <> DOTOK then
      Error(j + 1, 'DO expected but ' + GetSpelling(j + 1) + ' found')
    else
      begin
      GenerateWhileDoCondition;                         // Satisfied if expression is not zero
      GenerateWhileDoProlog;
      j := CompileStatement(j + 2);
      GenerateWhileDoEpilog;
      Result := j;
      end;
    end;

  REPEATTOK:
    begin
    GenerateRepeatUntilProlog;

    j := CompileStatement(i + 1);
    while Tok[j + 1].Kind = SEMICOLONTOK do
      j := CompileStatement(j + 2);
    if Tok[j + 1].Kind <> UNTILTOK then
      Error(j + 1, 'UNTIL expected but ' + GetSpelling(j + 1) + ' found');

    j := CompileExpression(j + 2, ExpressionType);
    GenerateRepeatUntilCondition;
    GenerateRepeatUntilEpilog;

    Result := j;
    end;

  FORTOK:
    begin
    if Tok[i + 1].Kind <> IDENTTOK then
      Error(i + 1, 'Identifier expected but ' + GetSpelling(i + 1) + ' found')
    else
      begin
      IdentIndex := GetIdent(Tok[i + 1].Name^);
      if IdentIndex > 0 then
        if (Ident[IdentIndex].Kind <> VARIABLE) or (Ident[IdentIndex].DataType = REALTOK) then
          Error(i + 1, 'Only integer variable can be used as counter but ' + Ident[IdentIndex].Name + ' found')
        else
          if Tok[i + 2].Kind <> ASSIGNTOK then
            Error(i + 2, ':= expected but ' + GetSpelling(i + 2) + ' found')
          else
            begin
            j := CompileExpression(i + 3, ExpressionType);
            if ExpressionType = REALTOK then
              Error(j, 'Integer expression expected as FOR loop counter value');
              
            GenerateAssignment(Ident[IdentIndex].Value, ASPOINTER, DataSize[Ident[IdentIndex].DataType]);

            if not (Tok[j + 1].Kind in [TOTOK, DOWNTOTOK]) then
              Error(j + 1, 'TO or DOWNTO expected but ' + GetSpelling(j + 1) + ' found')
            else
              begin
              Down := Tok[j + 1].Kind = DOWNTOTOK;

              Inc(CodePosStackTop);
              CodePosStack[CodePosStackTop] := CodeSize;                // Save return address used by GenerateForToDoEpilog

              j := CompileExpression(j + 2, ExpressionType);
              if ExpressionType = REALTOK then
                Error(j, 'Integer expression expected as FOR loop counter value');
                
              GenerateForToDoCondition(Ident[IdentIndex].Value, DataSize[Ident[IdentIndex].DataType], Down);  // Satisfied if counter does not reach the second expression value

              if Tok[j + 1].Kind <> DOTOK then
                Error(j + 1, 'DO expected but ' + GetSpelling(j + 1) + ' found')
              else
                begin
                GenerateForToDoProlog;
                j := CompileStatement(j + 2);
                GenerateForToDoEpilog(Ident[IdentIndex].Value, DataSize[Ident[IdentIndex].DataType], Down);
                Result := j;
                end;
              end
            end
      else
        Error(i + 1, 'Unknown identifier: ' + Tok[i + 1].Name^);
      end;
    end;  

  READTOK:
    if Tok[i + 1].Kind <> OPARTOK then
      Error(i + 1, '( expected but ' + GetSpelling(i + 1) + ' found')
    else
      if Tok[i + 2].Kind <> IDENTTOK then
        Error(i + 2, 'Identifier expected but ' + GetSpelling(i + 2) + ' found')
      else
        begin
        IdentIndex := GetIdent(Tok[i + 2].Name^);
        if IdentIndex > 0 then
          if (Ident[IdentIndex].Kind <> VARIABLE) or (Ident[IdentIndex].DataType <> CHARTOK) then
            Error(i + 2, 'Incompatible type of ' + Ident[IdentIndex].Name)
          else
            begin
            Push(Ident[IdentIndex].Value, ASVALUE, DataSize[CHARTOK]);
            GenerateRead;
            if Tok[i + 3].Kind <> CPARTOK then
              Error(i + 3, ') expected but ' + GetSpelling(i + 3) + ' found');
            Result := i + 3;
            end
        else
          Error(i + 2, 'Unknown identifier: ' + Tok[i + 2].Name^);
        end;

  WRITETOK:
    begin
    if Tok[i + 1].Kind <> OPARTOK then
      Error(i + 1, '( expected but ' + GetSpelling(i + 1) + ' found');
    i := i + 1;
    repeat
      if Tok[i + 1].Kind = STRINGLITERALTOK then
        begin
        GenerateWriteString(Tok[i + 1].StrAddress, ASPOINTER);
        i := i + 2;
        end
      else
        begin
        StringOutput := FALSE;
        if Tok[i + 1].Kind = IDENTTOK then      // Check if a string is given
          begin
          IdentIndex := GetIdent(Tok[i + 1].Name^);
          if IdentIndex = 0 then
            Error(i + 1, 'Unknown identifier: ' + Tok[i + 1].Name^);
          StringOutput := (Ident[IdentIndex].Kind = VARIABLE) and
                          (Ident[IdentIndex].DataType = POINTERTOK) and
                          (Ident[IdentIndex].AllocElementType = CHARTOK) and
                          (Ident[IdentIndex].NumAllocElements > 0);
          end;// if IDENTTOK

        if StringOutput then
          begin
          GenerateWriteString(Ident[IdentIndex].Value, ASPOINTERTOPOINTER);
          i := i + 2;
          end
        else
          begin
          i := CompileExpression(i + 1, ExpressionType);
          if ExpressionType = REALTOK then
            Error(i, 'Unable to output a real expression');
            
          GenerateWrite;
          i := i + 1;
          end;// else
        end;// else
    until Tok[i].Kind <> COMMATOK;
    if Tok[i].Kind <> CPARTOK then
      Error(i, ') expected but ' + GetSpelling(i) + ' found');
    Result := i;
    end;

  HALTTOK:
    begin
    GenerateProgramEpilog;
    Result := i;
    end;

  INTRTOK:
    begin
    if Tok[i + 1].Kind <> OPARTOK then
      Error(i + 1, '( expected but ' + GetSpelling(i + 1) + ' found');
    i := CompileConstExpression(i + 2, InterruptNumber, ActualParamType);
    GetCommonType(i, INTEGERTOK, ActualParamType);

    if Tok[i + 1].Kind <> COMMATOK then
      Error(i + 1, ', expected but ' + GetSpelling(j + 1) + ' found');
    i := CompileExpression(i + 2, ActualParamType);
    GetCommonType(i, POINTERTOK, ActualParamType);

    if Tok[i + 1].Kind <> CPARTOK then
      Error(i + 1, ') expected but ' + GetSpelling(i + 1) + ' found');

    GenerateInterrupt(InterruptNumber);
    Result := i + 1;
    end;

else
  Result := i - 1;
end;// case

end;// CompileStatement




function CompileType(i: Integer; var DataType: Byte; var NumAllocElements: LongInt; var AllocElementType: Byte): Integer;
var
  LowerBound, UpperBound, IdentIndex, NestedNumAllocElements: LongInt;
  NestedDataType, ExpressionType, NestedAllocElementType: Byte;
begin
if Tok[i].Kind in [INTEGERTOK, SMALLINTTOK, CHARTOK, BOOLEANTOK, POINTERTOK, REALTOK] then
  begin
  DataType := Tok[i].Kind;
  NumAllocElements := 0;
  AllocElementType := 0;
  Result := i;
  end
else if Tok[i].Kind = STRINGTOK then
  begin
  DataType := POINTERTOK;
  AllocElementType := CHARTOK;

  if Tok[i + 1].Kind <> OBRACKETTOK then
    Error(i + 1, '[ expected but ' + GetSpelling(i + 1) + ' found');

  i := CompileConstExpression(i + 2, UpperBound, ExpressionType);
  if ExpressionType = REALTOK then
    Error(i, 'String length must be integer');

  NumAllocElements := UpperBound + 1;  

  if Tok[i + 1].Kind <> CBRACKETTOK then
    Error(i + 1, '] expected but ' + GetSpelling(i + 1) + ' found');

  Result := i + 1;
  end // if STRINGTOK
else if Tok[i].Kind = ARRAYTOK then
  begin
  DataType := POINTERTOK;

  if Tok[i + 1].Kind <> OBRACKETTOK then
    Error(i + 1, '[ expected but ' + GetSpelling(i + 1) + ' found');

  i := CompileConstExpression(i + 2, LowerBound, ExpressionType);
  if ExpressionType = REALTOK then
    Error(i, 'Array lower bound must be integer');

  if LowerBound <> 0 then
    Error(i, 'Array lower bound is not zero');

  if Tok[i + 1].Kind <> RANGETOK then
    Error(i + 1, '.. expected but ' + GetSpelling(i + 3) + ' found');

  i := CompileConstExpression(i + 2, UpperBound, ExpressionType);
  if ExpressionType = REALTOK then
    Error(i, 'Array upper bound must be integer');

  NumAllocElements := UpperBound - LowerBound + 1;

  if Tok[i + 1].Kind <> CBRACKETTOK then
    Error(i + 1, '] expected but ' + GetSpelling(i + 1) + ' found');

  if Tok[i + 2].Kind <> OFTOK then
    Error(i + 2, 'OF expected but ' + GetSpelling(i + 2) + ' found');

  i := CompileType(i + 3, NestedDataType, NestedNumAllocElements, NestedAllocElementType);

  if NestedNumAllocElements > 0 then
    Error(i, 'Multidimensional arrays are not supported');

  AllocElementType := NestedDataType;

  Result := i;
  end // if ARRAYTOK
else if Tok[i].Kind = IDENTTOK then
  begin
  IdentIndex := GetIdent(Tok[i].Name^);

  if IdentIndex = 0 then
    Error(i, 'Unknown identifier: ' + Tok[i].Name^);
  if Ident[IdentIndex].Kind <> USERTYPE then
    Error(i + 4, 'Type expected but ' + Tok[i + 4].Name^ + ' found');

  DataType := Ident[IdentIndex].DataType;
  NumAllocElements := Ident[IdentIndex].NumAllocElements;
  AllocElementType := Ident[IdentIndex].AllocElementType;
  Result := i;
  end // if IDENTTOK
else
  Error(i, 'Unknown type');

end;// CompileType




function CompileBlock(i: Integer; BlockIdentIndex: Integer; NumParams: Integer; var Param: TParamList; IsFunction: Boolean; FunctionResultType: Byte): Integer;
var
  NestedBlockParam, VarOfSameType: TParamList;
  j, ParamIndex, NumVarOfSameType, VarOfSameTypeIndex, IdentIndex: Integer;
  NumAllocElements, ConstVal: LongInt;
  IsNestedFunction: Boolean;
  VarType, NestedFunctionResultType, ConstValType, AllocElementType: Byte;

begin
Inc(NumBlocks);
Inc(BlockStackTop);
BlockStack[BlockStackTop] := NumBlocks;
Ident[BlockIdentIndex].ProcAsBlock := NumBlocks;

// Allocate parameters as local variables of the current block if necessary
for ParamIndex := 1 to NumParams do
  begin
  DefineIdent(i, Param[ParamIndex].Name, VARIABLE, Param[ParamIndex].DataType, 0, 0, 0);
  Ident[GetIdent(Param[ParamIndex].Name)].NumAllocElements := Param[ParamIndex].NumAllocElements;
  Ident[GetIdent(Param[ParamIndex].Name)].AllocElementType := Param[ParamIndex].AllocElementType;
  end;

// Allocate Result variable if the current block is a function
if IsFunction then DefineIdent(i, 'RESULT', VARIABLE, FunctionResultType, 0, 0, 0);

// Load parameters from the stack
for ParamIndex := NumParams downto 1 do
  GenerateAssignment(Ident[GetIdent(Param[ParamIndex].Name)].Value, ASPOINTER, DataSize[Param[ParamIndex].DataType]);

GenerateDeclarationProlog;

while Tok[i].Kind in [CONSTTOK, TYPETOK, VARTOK, PROCEDURETOK, FUNCTIONTOK] do
  begin
  if Tok[i].Kind = CONSTTOK then
    begin
    repeat
      if Tok[i + 1].Kind <> IDENTTOK then
        Error(i + 1, 'Constant name expected but ' + GetSpelling(i + 1) + ' found')
      else
        if Tok[i + 2].Kind <> EQTOK then
          Error(i + 2, '= expected but ' + GetSpelling(i + 2) + ' found')
        else
          begin
          j := CompileConstExpression(i + 3, ConstVal, ConstValType);
          DefineIdent(i + 1, Tok[i + 1].Name^, CONSTANT, ConstValType, 0, 0, ConstVal);
          i := j;
          end;

      if Tok[i + 1].Kind <> SEMICOLONTOK then
        Error(i + 1, '; expected but ' + GetSpelling(i + 1) + ' found');

      i := i + 1;
    until Tok[i + 1].Kind <> IDENTTOK;

    i := i + 1;
    end;// if TYPETOK
    


  if Tok[i].Kind = TYPETOK then
    begin
    repeat
      if Tok[i + 1].Kind <> IDENTTOK then
        Error(i + 1, 'Type name expected but ' + GetSpelling(i + 1) + ' found')
      else
        if Tok[i + 2].Kind <> EQTOK then
          Error(i + 2, '= expected but ' + GetSpelling(i + 2) + ' found')
        else
          begin
          j := CompileType(i + 3, VarType, NumAllocElements, AllocElementType);
          DefineIdent(i + 1, Tok[i + 1].Name^, USERTYPE, VarType, NumAllocElements, AllocElementType, 0);
          end;

      if Tok[j + 1].Kind <> SEMICOLONTOK then
        Error(j + 1, '; expected but ' + GetSpelling(j + 1) + ' found');

      i := j + 1;
    until Tok[i + 1].Kind <> IDENTTOK;

    i := i + 1;
    end;// if CONSTTOK



  if Tok[i].Kind = VARTOK then
    begin
    repeat
      NumVarOfSameType := 0;
      repeat
        if Tok[i + 1].Kind <> IDENTTOK then
          Error(i + 1, 'Variable name expected but ' + GetSpelling(i + 1) + ' found')
        else
          begin
          Inc(NumVarOfSameType);
          VarOfSameType[NumVarOfSameType].Name := Tok[i + 1].Name^;
          end;
        i := i + 2;
      until Tok[i].Kind <> COMMATOK;

      if Tok[i].Kind <> COLONTOK then
        Error(i, ': expected but ' + GetSpelling(i) + ' found');

      i := CompileType(i + 1, VarType, NumAllocElements, AllocElementType);

      for VarOfSameTypeIndex := 1 to NumVarOfSameType do
        DefineIdent(i, VarOfSameType[VarOfSameTypeIndex].Name, VARIABLE, VarType, NumAllocElements, AllocElementType, 0);

      if Tok[i + 1].Kind <> SEMICOLONTOK then
        Error(i + 1, '; expected but ' + GetSpelling(i + 1) + ' found');

    i := i + 1;
    until Tok[i + 1].Kind <> IDENTTOK;

    i := i + 1;
    end;// if VARTOK



  if Tok[i].Kind in [PROCEDURETOK, FUNCTIONTOK] then
    if Tok[i + 1].Kind <> IDENTTOK then
      Error(i + 1, 'Procedure name expected but ' + GetSpelling(i + 1) + ' found')
    else
      begin
      if Tok[i].Kind = PROCEDURETOK then
        begin
        DefineIdent(i + 1, Tok[i + 1].Name^, PROC, 0, 0, 0, 0);
        IsNestedFunction := FALSE;
        end
      else
        begin
        DefineIdent(i + 1, Tok[i + 1].Name^, FUNC, 0, 0, 0, 0);
        IsNestedFunction := TRUE;
        end;

      if Tok[i + 2].Kind = OPARTOK then                           // Formal parameter list found
        begin
        i := i + 2;
        repeat
          NumVarOfSameType := 0;
            repeat
            if Tok[i + 1].Kind <> IDENTTOK then
              Error(i + 1, 'Formal parameter name expected but ' + GetSpelling(i + 1) + ' found')
            else
              begin
              Inc(NumVarOfSameType);
              VarOfSameType[NumVarOfSameType].Name := Tok[i + 1].Name^;
              end;
            i := i + 2;
            until Tok[i].Kind <> COMMATOK;

          if Tok[i].Kind <> COLONTOK then
            Error(i, ': expected but ' + GetSpelling(i) + ' found');

          i := CompileType(i + 1, VarType, NumAllocElements, AllocElementType);

          for VarOfSameTypeIndex := 1 to NumVarOfSameType do
            begin
            Inc(Ident[NumIdent].NumParams);
            if Ident[NumIdent].NumParams > MAXPARAMS then
              Error(i, 'Too many formal parameters in ' + Ident[NumIdent].Name)
            else
              begin
              VarOfSameType[VarOfSameTypeIndex].DataType                   := VarType;
              Ident[NumIdent].ParamType[Ident[NumIdent].NumParams]         := VarType;
              NestedBlockParam[Ident[NumIdent].NumParams].DataType         := VarType;
              NestedBlockParam[Ident[NumIdent].NumParams].Name             := VarOfSameType[VarOfSameTypeIndex].Name;
              NestedBlockParam[Ident[NumIdent].NumParams].NumAllocElements := NumAllocElements;
              NestedBlockParam[Ident[NumIdent].NumParams].AllocElementType := AllocElementType;
              end;
            end;

          i := i + 1;
        until Tok[i].Kind <> SEMICOLONTOK;

        if Tok[i].Kind <> CPARTOK then
          Error(i, ') expected but ' + GetSpelling(i) + ' found');

        i := i + 1;
        end// if Tok[i + 2].Kind = OPARTOR
      else
        i := i + 2;  

      NestedFunctionResultType := 0;  

      if IsNestedFunction then
        begin
        if Tok[i].Kind <> COLONTOK then
          Error(i, ': expected but ' + GetSpelling(i) + ' found');

        i := CompileType(i + 1, VarType, NumAllocElements, AllocElementType);

        NestedFunctionResultType := VarType;
        Ident[NumIdent].DataType := NestedFunctionResultType;

        i := i + 1;
        end;// if IsNestedFunction  

      if Tok[i].Kind <> SEMICOLONTOK then
        Error(i, '; expected but ' + GetSpelling(i) + ' found')
      else
        begin
        if (Pass = CODEGENERATIONPASS) and not Ident[NumIdent].IsNotDead then   // Do not compile dead procedures and functions
          begin
          OutputDisabled := TRUE;
          Warning(i, Ident[NumIdent].Name + ' is never called. Deleted');
          end;

        j := CompileBlock(i + 1, NumIdent, Ident[NumIdent].NumParams, NestedBlockParam, IsNestedFunction, NestedFunctionResultType);

        if Tok[j + 1].Kind <> SEMICOLONTOK then
          Error(j + 1, '; expected but ' + GetSpelling(j + 1) + ' found');

        GenerateReturn;
        
        if OutputDisabled then OutputDisabled := FALSE;

        i := j + 2;
        end;// else
      end;// else
  end;// while

GenerateDeclarationEpilog;  // Make jump to block entry point

// Initialize array origin pointers if the current block is the main program body
if BlockStack[BlockStackTop] = 1 then
  for IdentIndex := 1 to NumIdent do
    if (Ident[IdentIndex].Kind = VARIABLE) and (Ident[IdentIndex].DataType = POINTERTOK) and (Ident[IdentIndex].NumAllocElements > 0) then
      begin
      Push(Ident[IdentIndex].Value + SizeOf(LongInt), ASVALUE, DataSize[POINTERTOK]);     // Array starts immediately after the pointer to its origin
      GenerateAssignment(Ident[IdentIndex].Value, ASPOINTER, DataSize[POINTERTOK]);
      end;

j := CompileStatement(i);

// Return Result value
if IsFunction then Push(Ident[GetIdent('RESULT')].Value, ASPOINTER, DataSize[FunctionResultType]);
  
Dec(BlockStackTop);

Result := j;
end;// CompileBlock




procedure CompileProgram;
var
  j: Integer;
  Param: TParamList;     // Actually empty since no parameters are passed to the program itself
begin
DefineIdent(1, 'MAIN', PROC, 0, 0, 0, 0);

GenerateProgramProlog;

j := CompileBlock(1, NumIdent, 0, Param, FALSE, 0);

if NumTok > j + 1 then
  Error(NumTok, 'Text after end of program');
if NumTok < j + 1 then
  Error(NumTok, 'Program body not found (possibly no blank line after END.)');
if Tok[j + 1].Kind <> DOTTOK then
  Error(j + 1, '. expected but ' + GetSpelling(j + 1) + ' found');


GenerateProgramEpilog;

end;// CompileProgram




procedure OptimizeProgram;

  procedure MarkNotDead(IdentIndex: Integer);
  var
    ChildIndex, ChildIdentIndex: Integer;
  begin
  Ident[IdentIndex].IsNotDead := TRUE;
  for ChildIndex := 1 to CallGraph[Ident[IdentIndex].ProcAsBlock].NumChildren do
    for ChildIdentIndex := 1 to NumIdent do
      if Ident[ChildIdentIndex].ProcAsBlock = CallGraph[Ident[IdentIndex].ProcAsBlock].ChildBlock[ChildIndex] then
        MarkNotDead(ChildIdentIndex);
  end;

begin
// Perform dead code elimination
MarkNotDead(GetIdent('MAIN'));
end;






var
  i, CharIndex, UnitIndex, ChildIndex: Integer;
  DiagMode: Boolean;


// Main program
begin
WriteLn;
WriteLn('Sub-Pascal 32-bit real mode compiler v. 2.0 by Vasiliy Tereshkov, 2009');
WriteLn;

if ParamCount = 0 then
  begin
  WriteLn('Usage: sp { <unit> } <program> [ /d ]');
  Halt;
  end;

if ParamStr(ParamCount) = '/d' then
  begin
  NumUnits := ParamCount - 1;
  DiagMode := TRUE;
  end
else
  begin
  NumUnits := ParamCount;
  DiagMode := FALSE;
  end;

for UnitIndex := 1 to NumUnits do
  if not FileExists(ParamStr(UnitIndex) + '.sp') then
    begin
    WriteLn('File ' + ParamStr(UnitIndex) + '.sp not found.');
    Halt;
    end
  else
    UnitName[UnitIndex] := ParamStr(UnitIndex);
    

DecimalSeparator := '.';


TokenizeProgram;
               

// Predefined constants
DefineIdent(1, 'TRUE',     CONSTANT, BOOLEANTOK, 0, 0, $FFFFFFFF);
DefineIdent(1, 'FALSE',    CONSTANT, BOOLEANTOK, 0, 0, $00000000);
DefineIdent(1, 'FRACBITS', CONSTANT, INTEGERTOK, 0, 0, FRACBITS);
DefineIdent(1, 'FRACMASK', CONSTANT, INTEGERTOK, 0, 0, TWOPOWERFRACBITS - 1);


// First pass: compile the program and build call graph
NumPredefIdent := NumIdent;
Pass := CALLDETERMPASS;
CompileProgram;


// Visit call graph nodes and mark all procedures that are called as not dead 
OptimizeProgram;


// Second pass: compile the program and generate output (IsNotDead fields are preserved since the first pass)
NumIdent := NumPredefIdent; NumBlocks := 0; BlockStackTop := 0; CodeSize := 0; CodePosStackTop := 0; VarDataSize := 0;
Pass := CODEGENERATIONPASS;
CompileProgram;


// Diagnostics
if DiagMode then
  begin
  AssignFile(DiagFile, UnitName[NumUnits] + '.dat');
  Rewrite(DiagFile);

  WriteLn(DiagFile);
  WriteLn(DiagFile, 'Token list: ');
  WriteLn(DiagFile);
  WriteLn(DiagFile, '#': 6, 'Unit': 30, 'Line': 6, 'Token': 30);
  WriteLn(DiagFile);
  
  for i := 1 to NumTok do
    begin
    Write(DiagFile, i: 6, UnitName[Tok[i].UnitIndex]: 30, Tok[i].Line: 6, GetSpelling(i): 30);
    if Tok[i].Kind = INTNUMBERTOK then
      WriteLn(DiagFile, ' = ', Tok[i].Value)
    else if Tok[i].Kind = FRACNUMBERTOK then
      WriteLn(DiagFile, ' = ', Tok[i].FracValue: 8: 4)
    else if Tok[i].Kind = IDENTTOK then
      WriteLn(DiagFile, ' = ', Tok[i].Name^)
    else if Tok[i].Kind = CHARLITERALTOK then
      WriteLn(DiagFile, ' = ', Chr(Tok[i].Value))
    else if Tok[i].Kind = STRINGLITERALTOK then
      begin
      Write(DiagFile, ' = ');
      for CharIndex := 1 to Tok[i].StrLength do
        Write(DiagFile, StaticStringData[Tok[i].StrAddress - (CODEORIGIN + 3) + (CharIndex - 1)]);
      WriteLn(DiagFile);
      end  
    else
      WriteLn(DiagFile);
    end;// for

  WriteLn(DiagFile);
  WriteLn(DiagFile, 'Identifier list: ');
  WriteLn(DiagFile);
  WriteLn(DiagFile, '#': 6, 'Block': 6, 'Name': 30, 'Kind': 15, 'Type': 15, 'Items/Params': 15, 'Value/Addr': 15, 'Dead': 5);
  WriteLn(DiagFile);

  for i := 1 to NumIdent do
    begin
    Write(DiagFile, i: 6, Ident[i].Block: 6, Ident[i].Name: 30, Spelling[Ident[i].Kind]: 15);
    if Ident[i].DataType <> 0 then Write(DiagFile, Spelling[Ident[i].DataType]: 15) else Write(DiagFile, 'N/A': 15);
    Write(DiagFile, Ident[i].NumAllocElements: 15, IntToHex(Ident[i].Value, 8): 15);
    if ((Ident[i].Kind = PROC) or (Ident[i].Kind = FUNC)) and not Ident[i].IsNotDead then WriteLn(DiagFile, 'Yes': 5) else WriteLn(DiagFile, '': 5);
    end;

  WriteLn(DiagFile);
  WriteLn(DiagFile, 'Call graph: ');
  WriteLn(DiagFile);

  for i := 1 to NumBlocks do
    begin
    Write(DiagFile, i: 6, '  ---> ');
    for ChildIndex := 1 to CallGraph[i].NumChildren do
      Write(DiagFile, CallGraph[i].ChildBlock[ChildIndex]: 5);
    WriteLn(DiagFile);
    end;

  WriteLn(DiagFile);
  CloseFile(DiagFile);
  end;// if
  

// Output program
AssignFile(OutFile, UnitName[NumUnits] + '.com');  
Rewrite(OutFile);
for i := 0 to CodeSize - 1 do
  Write(OutFile, Code[i]);
CloseFile(OutFile);

WriteLn('Compilation complete. Code size: ', CodeSize, ' bytes. Data size: ', VarDataSize, ' bytes.');

FreeTokens;

end.


