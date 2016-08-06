Program RockEd;

{$M 16384,0,32768}

{$A+ Word Align Data}
{$B- Short boolean evaluation}
{$I- No I/O checking}
{$R- No range checking}
{$S- No stack checking}
{$V- No string checking}


uses dos,crt,disk2,screen,win, chrono, Chartool;

{This program allows the user to edit the maps in the 'ROCKFORD' game

 in order to design new maps

 Author: N. Kendrick (nigel.kendrick@gmail.com)

 Last edit : 13 June 1992
           : 06 Aug 2016. Various text messages changed when code released into the Public Domain

 Description: This is V1.5A with directory lister added - call it 1.60

This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

In jurisdictions that recognize copyright laws, the author or authors
of this software dedicate any and all copyright interest in the
software to the public domain. We make this dedication for the benefit
of the public at large and to the detriment of our heirs and
successors. We intend this dedication to be an overt act of
relinquishment in perpetuity of all present and future rights to this
software under copyright law.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

For more information, please refer to <http://unlicense.org/> 

 E&OE. This code is supplied 'as is' with no support.
 
 This code will compile with Turbo Pascal 7.0 on FreeDOS in a VirtualBOX VM, provided that the TP7 CRT patch is installed;
 if not, the program will stop immediately with a Runtime 200 error - see
 http://www.filewatcher.com/m/bp7patch.zip.62550-0.html

 The code will also compile with TP7 running in DOSBOX on Windows 10. See
 http://techapple.net/2014/04/turbo-pascal-7-windows-7-windows-8-8-132bit-64bit-fullscreen-single-installer/
 
 If you want to compile this code, you will also need to download and compile the custom (TPU) units: disk2, screen, win,
 chrono and chartool. The win unit files may need to be grabbed from TP6.

}

{$DEFINE REGISTERED}  {If Defined, compiles the registered version}

{$DEFINE NOTSPECIAL}   {If Defined, compiles the version that can take}
                      {new constants from the command line}

{$DEFINE NODEBUG}

Const

  Version  = 'V1.6A' + {This line MUST only have 5 chrs on it}

{$IFDEF REGISTERED}

  'FV'

{$ELSE}

  'PD'

{$ENDIF}

{$IFDEF SPECIAL}

  + 'S';
{$ELSE}
  ;
{$ENDIF}

{$IFDEF SPECIAL}

  Game_File_Size         : Longint = 29963;

  Game_File_Ident_Pos    : Longint = 598;

  Game_File_Time_Pos     : Longint = 3838;

  Game_File_Coin_Pos     : Longint = 3358;

  Game_File_Map_Name_Pos : Longint = 2293;

{$ELSE}

  Game_File_Size         = 29963;

  Game_File_Ident_Pos    = 598;

  Game_File_Time_Pos     = 3838;

  Game_File_Coin_Pos     = 3358;

  Game_File_Map_Name_Pos = 2293;

{$ENDIF}

  Regterms = 'œ5.00 (œ8.00 overseas)';



  XR = $25;

  CRLF = ^M^J;

  M_Array : Array [0..16] of byte = ($70,$84,$74,$1,$28,$20,$7c,$78,$88,$34,$2C,$3,
                                     $8,$c,$4,$10,$38);

  Unreg   : Set of byte = [$20,$74,$78,$7C]; {Items that unregistered users can't touch}


  XOff : Byte = 1; {Offsets for grid positioning}
  YOff : Byte = 3;

type

   Multi_Map_Type = record
                M : Array [0..21] of array [0..39] of byte; {Each map is 40x22 cells}
              end;

   Main_Map_Type = Record

              I  : String[6];  {Ident String}
              CR : Integer;    {Number of coins required}
              CC : Integer;    {Coin_Count - coins in map}
              T  : Integer;    {Time allowed}
              M  : Array [0..21] of array [0..39] of byte; {Each map is 40x22 cells}

            end;

  TitleStrPtr = ^TitleStr;

  WinRecPtr = ^WinRec;

  WinRec = record
             Next      : WinRecPtr;
             State     : WinState;
             Title     : TitleStrPtr;
             TitleAttr, FrameAttr: Byte;
             Buffer    : Pointer;
  end;

Var Cmsg : String[25];
    RMsg : String[80];
    AMsg : String[77];

    KBSTAT    : integer absolute $0:$0417;

    TopWindow : WinRecPtr;

    Esc             : Boolean;
    Err             : Integer;
    Map_Num         : Integer;
    Game_File_Name  : PathStr; {Current Game (.EXE file) name}
    Map_File_Name   : PathStr;
    Map             : Main_Map_Type;

{---------------------------------------------------------------------------}
{---------------------------------------------------------------------------}

procedure ActiveWindow(Active: Boolean);
begin
  if TopWindow <> nil then
  begin
    UnFrameWin;
    with TopWindow^ do
      if Active then
        FrameWin(Title^, DoubleFrame, TitleAttr, FrameAttr)
      else
        FrameWin(Title^, SingleFrame, FrameAttr, FrameAttr);
  end;
end;

procedure OpenWindow(X1, Y1, X2, Y2: Byte; T: TitleStr;
  TAttr, FAttr: Byte);
var
  W: WinRecPtr;
begin
  ActiveWindow(False);
  New(W);
  with W^ do
  begin
    Next := TopWindow;
    SaveWin(State);
    GetMem(Title, Length(T) + 1);
    Title^ := T;
    TitleAttr := TAttr;
    FrameAttr := FAttr;
    Window(X1, Y1, X2, Y2);
    GetMem(Buffer, WinSize);
    ReadWin(Buffer^);
    FrameWin(T, DoubleFrame, TAttr, FAttr);
  end;
  TopWindow := W;
  Clrscr;
end;

procedure CloseWindow;
var
  W: WinRecPtr;
begin
  if TopWindow <> nil then
  begin
    W := TopWindow;
    with W^ do
    begin
      UnFrameWin;
      WriteWin(Buffer^);
      FreeMem(Buffer, WinSize);
      FreeMem(Title, Length(Title^) + 1);
      RestoreWin(State);
      TopWindow := Next;
    end;
    Dispose(W);
    ActiveWindow(True);
  end;
end;

{---------------------------------------------------------------------------}

{---------------------------------------------------------------------------}

procedure clearMap (Var MF : Main_Map_Type); {Clear the map file}

var X2,Y2 : Byte;

begin
  For X2 := 0 to 39 do
  for Y2 := 0 to 21 do

  If (X2 in [0,39]) or (Y2 in [0,21]) then MF.M[Y2,X2] := $02 else
  MF.M[Y2,X2] := 0;

  MF.CC := 0;
  MF.T  := 0;
  MF.CR := 0;

end;

{---------------------------------------------------------------------------}

Function Get_Map_Name (Gname : String) : String;

Var S     : String;
    I     : Integer;
    Dfile : File of Char;
    FPath : DirStr;
    FName : NameStr;
    Fext  : ExtStr;

begin

  S[0] := Chr(12);

  Assign (Dfile,Gname);

  {$I-} reset (Dfile); {$I+}

  If IoResult = 0 then
  begin
    Seek (Dfile,Game_File_Map_Name_Pos); {12 byte cellmaps file name stored here}
    For I:= 1 to 12 do
      Read (Dfile,S[I]);
  Close (Dfile);
  Fsplit (GName,FPath,Fname,Fext); {Find path to map file}
  end;

Get_Map_Name := FPath + S;

end;

{---------------------------------------------------------------------------}

Procedure GetSolo (Mfile : String; Var MF : Main_Map_Type);

Var
  Map_FIle : File of Main_Map_Type;
  X,Y      : Integer;

begin

  Assign (Map_File,MFile);

  {$I-} Reset(Map_File); {$I+}

  If (Ioresult = 0) then
  begin
    Read(Map_File,MF);
    Close(Map_File);

    For X := 0 to 39 do for Y := 0 to 21 do MF.M[Y,X] := MF.M[Y,X] Xor XR;

  end;
end;


{---------------------------------------------------------------------------}

Procedure Write_Solo (Var Map : Main_Map_Type; Map_File_Name : String; Var Err : Integer);

{Write a Solo map file to disk}

Var

  Outfile : File of Main_Map_Type;
  FPath : DirStr;
  FName : NameStr;
  Fext  : ExtStr;
  TMap  : Main_Map_Type;
  X,Y   : Integer;

begin

  Err := 0;

  Map.I := 'ROCKED'; {Map file ident - DO NOT CHANGE!!!}

  FSplit (Map_File_Name,FPath,FName,FExt); {Split the filename up}

  If exist (Map_File_Name) then {There is an existing file to take care of}
  begin
    Del (Fname + '.BAK',Err); {Delete any existing backup}
    Ren (Map_File_name,Fname+'.BAK',Err); {Rename existing to .BAK}
    Err := 0;
  end;

  If (Err = 0) then
  begin

    {$I-}

    Assign (Outfile,Map_File_Name);
    Rewrite (Outfile);
    Err := IoResult;

    If (Err = 0) then
    begin

      Tmap := Map;

      For X := 0 to 39 do for Y := 0 to 21 do Tmap.M[Y,X] := Map.M[Y,X] Xor XR;

      Write (OutFile,TMap);
      Close (OutFile);
      Err := IoResult;

    end;

    {$I+}

  end;

end;

{---------------------------------------------------------------------------}

procedure Get_Multi (Var Map : Main_map_Type; Game_File_Name : String;
                       Map_File_Name : String; Map_Num : Integer;
                       Var Err : Integer);

Var
  Map_File  : File of Multi_Map_Type;
  Game_File : File of Byte;
  MMT       : Multi_Map_Type;
  X2,Y2     : Integer;
  B,BLo,BHi : Byte;

begin

  Map.CC := 0;

  Assign (Map_File,Map_File_Name);
  {$I-}
  Reset (Map_File);
  {$I+}

  Err := Ioresult;

  If (Err = 0) and (Filesize(Map_File) = 40) and (Map_Num in [1..40]) then
  begin
    Seek (Map_File,Map_Num-1);
    Read (Map_FIle,MMT);
    close (Map_File);

    For X2 := 0 to 39 do
      for Y2 := 0 to 21 do
      begin
        B:= MMT.M[Y2,X2];
        Map.M[Y2,X2] := B;

        If (B = $88) then inc (Map.CC) {How many coins in map?}

      end;
  end
  else
  Err := 1; {Problems with Map file}

  If (Err = 0) and (Game_File_name <> '') then {Get time/coins required from .EXE file}
  begin
    Assign (Game_File,Game_File_Name);

  {$I-} reset (Game_File); {$I+}

    Err := IoResult;

    If (Err = 0) then
    begin

      Seek (Game_File,Game_File_Coin_Pos-2+(Map_Num*2)); {Coins required for specified map in integer format}

      Read(Game_File,BLo);
      Read(Game_File,BHi);

      Map.CR := BLo + (BHi SHL 4);

      Seek (Game_File,Game_File_Time_Pos-2+(Map_Num*2));

      Read(Game_File,BLo);
      Read(Game_File,BHi);

      Map.T := BLo + (BHi SHL 4);

      close (Game_File);

    end;
  end;

end;

{---------------------------------------------------------------------------}

procedure Write_Multi (Var Map : Main_map_Type; Game_File_Name : String;
                       Map_File_Name : String; Map_Num : Integer;
                       Var Err : Integer);

Var

  SMap      : Multi_Map_Type;
  Game_File : File of Byte;
  Map_File  : File of Multi_map_Type;
  Ch        : Char;
  X2,Y2     : Integer;
  B         : Byte;

begin

  Err := 0;

  Assign (Map_File,Map_File_Name);

  {$I-}

  Reset (Map_File);

  Err := IoResult;

  If (Err <> 0) then Err := 1;

  If (Err = 0) and (Filesize(Map_File) <> 40) then Err := 1; {Bad map file}

  If (Err = 0) then
  begin

    For X2 := 0 to 39 do
      for Y2 := 0 to 21 do
        SMap.M[Y2,X2] := Map.M[Y2,X2]; {Transfer map to writeable type}

    Seek (Map_File,Map_Num -1);
    Write (Map_File,SMap);
    Close (Map_File);

    Err := Ioresult;

  end;

{$IFDEF REGISTERED} {Only registered users can update coin/time coint in .EXE file}

  If (Err = 0) then
  begin {Update game file}

    Assign (Game_File,Game_File_Name);
    Reset (Game_File);

    Err := IoResult;

    If (Err = 0) and (FileSize(Game_File) = Game_File_Size) then {OK, save map}
    begin
      Seek (Game_File,Game_File_Coin_Pos-2+(Map_Num*2)); {Coins required for specified map in integer format}

      B := Lo(Map.CR);

      Write(Game_FIle,B);

      Err := Ioresult;

      If (Err = 0) then
      begin
        B := Hi(Map.CR);
        Write(Game_FIle,B);

        Seek (Game_File,Game_File_Time_Pos-2+(Map_Num*2));

        B := Lo(Map.T);
        Write (Game_File,B);
        B := Hi(Map.T);
        Write (Game_FIle,B);

        Err := Ioresult;

      end
      else Err := 2;
      close (Game_File);
      Err := Ioresult;
    end
    else Err := 2; {No open/Wrong size}
  end;

  {$I+}

{$ENDIF}

end;

{---------------------------------------------------------------------------}

Function Validate (Fname : String) : Integer;

{This function checks the named file to ensure it is a valid Solo cellmap
 or that its length is correct for a cellmaps.bin file

 Returns : -2 = File is read only

           -1 = File is wrong size

            1 = File not found

            2 = File is a rockford program file

            3 = File is a Solo cellmap file

}

var

  InFile : File of char;

  S      : String;
  Err    : Integer;
  I      : Longint;

begin

  If Fname = '' then err := 1 {File not found/New file??}
  else
  begin
    Assign (InFile,Fname);

    {$I-}
      Reset (Infile); {Open for read???}

    Err := IoResult;

    If err <> 0 then
    begin
      if Err = 2 then Err := 1 else Err := -2 {New file/Read only}
    end

    else {File open - check it}

    begin

      Err := -1; {Assume incorrect file type}

      I := Filesize(Infile);

      If (I = Game_File_Size) then
      Begin {Looks like .EXE file size}
	Seek (Infile,Game_File_Ident_Pos); {Look for ROCKFORD string}
	For I := 1 to 8 do read (Infile,S[I]); {Try reading ident string}
	S[0]  := Chr(8); {Ensure string length is 8 chrs only}
	If S = 'ROCKFORD' then err := 2 {Looks like the rockford program}
      end

{$IFDEF REGISTERED}

      else
      If (I = 893) then
      Begin
	For I := 0 to 6 do read (Infile,S[I]); {Try reading ident string}
	S[0]  := Chr(6); {Ensure string length is 6 chrs only}
	If S = 'ROCKED' then err := 3; {Looks like the rockford program}
      end;
{$ELSE}
      ;
{$ENDIF}

      Close (InFIle);

      {$I+}

    end;
  end;

  Validate := Err;

end;


{---------------------------------------------------------------------------}

{$IFDEF REGISTERED}

Procedure ShDir (S : String);

Var


    Asczname  : String   ;
    matchname : String   ;
    size      : LongInt  ;
    date      : DS10     ;
    time      : DS5      ;
    attribute : Integer  ;
    Derror    : Integer;
    FPath     : DirStr;
    FPath2    : DirStr;
    FName     : NameStr;
    Fext      : ExtStr;

    Defdrive  : Byte;

    Dircount  : Integer;
    Filecount : Integer;
    GameCount : Integer;
    Solocount : Integer;
    LCount    : Integer;
    XPos      : Integer;
    Smode     : Integer;
    Df        : Real;
    Dft       : String[2];
    MName     : String;

    ECh       : Char;

{...........................................................................}

  Procedure Shentry;

  Var I : Integer;

  begin
    If (Attribute = 16) then
    begin
      I := 99;
      Matchname := '[' + Matchname + ']';
    end
    else I := validate (Fpath+MatchName);

    Inc(LCount);
    MName := '';

    Case I of

     99 :  Begin
	     Textcolor(Lightgray);
             If (Matchname <> '[.]') and (Matchname <> '[..]') then
	       Inc (Dircount);
	   end;

      2 :  Begin
	     Textcolor(Yellow);
             Inc (GameCount);
             MName := Get_Map_Name(Fpath+Matchname);
             Fsplit (Mname,FPath2,Fname,Fext); {Find path}
	   end;

      3 :  Begin
	     Textcolor(LightGreen);
             Inc (Solocount);
	   end;

      Else Begin
	     Textcolor(LightGray);
             Inc (FileCount);
	   end;

    end;

    While (MatchName[0] <> #12) do Matchname := Matchname + ' ';
    Write (' ',Matchname,'  ',Date,'  ',Time,' ');

    Case I of

      2 : Writeln ('<'+Fname+Fext+'>');

      3 : Writeln ('SOLO MAP FILE');

      else Writeln;

    end;

  end;

{...........................................................................}


begin

  LCount    := 0;
  Dircount  := 0;
  GameCount := 0;
  SoloCount := 0;
  Filecount := 0;
  XPos      := 0;
  ECh       := 'x';

  If (S = '') or (S[Length(S)] = ':') or (S[Length(S)] = '\')
  then S := S + '*.*';

  S := Upstring(S);

  Fsplit (S,FPath,Fname,Fext); {Find path}

  If S[2] = ':' then Defdrive := ord (S[1]) - 64
    else defdrive := 0;

{First, verify whether named filespec is file or directory}

  Dir (0,S,Matchname,Directory,Size,Date,Time,Attribute,Derror);

  OpenWindow (1,1,50,22,'',Yellow,Yellow);

  If (Derror = 0) then
  begin

    Smode := 0;

    If (Attribute = Directory) and (Matchname = FName+Fext)
    then
    begin
      S := S+'\*.*';
      FSplit (S,FPath,Fname,Fext); {Find path}
    end;

    While (Derror = 0) and (ECh <> ^[) do
    begin
      Dir (Smode,S,Matchname,16,Size,Date,Time,Attribute,Derror);

      If (Derror = 0) then
      begin
        Shentry;
        Smode := 1;

        If (Lcount = 19) then
        begin
          Textcolor (white);
          Write (' PRESS A KEY');
          Repeat until keypressed;
          ECh := Readkey;
          Clrscr;

          Lcount := 0;
        end;

     end;
    end;
  end;

  If (Ech <> ^[) then
  begin
    OpenWindow (51,14,80,25,'',Yellow,Yellow);
    Textcolor (Lightgreen);

    Writeln (' Game  Files : ',GameCount);
    Writeln (' Solo  Files : ',SoloCount);
    Writeln (' Other Files : ',FileCount);
    Writeln (' Total Files : ',GameCount+Solocount+Filecount,CRLF);
    Writeln (' Sub-Directories : ',DirCount);
    Writeln;
    Textcolor(Yellow);

    Dft := 'Kb';
    Df  := Diskfree(DefDrive)/1024;

    If (Df > 1024) then
    begin
      Df := Df /1024;
      Dft := 'Mb';
    end;


    Write (' ',Df:0:1,Dft,' FREE'+CRLF+CRLF);
    Write (' PRESS A KEY');
    Repeat until keypressed;
    Clrkbd;
    Closewindow;
  end;

  CloseWindow;

end;

{$ENDIF}

{---------------------------------------------------------------------------}


Procedure Showchar (N : Integer);


Var Character : Char;
    C,T         : Byte;

begin

  C := Lightgray;
  Character := #254;

  Case N of


    $00 : Character := ' ';        {Space}

    $01 : begin                    {Grass}
            Character := #176;
            c := Brown;
          end;

    $02 : begin
            character := #178;     {Solid wall}
            C := White;
          end;

    $03 : Begin
            character := #177;       {Partition}
            C := White;
          end;

    $04 : character := #240;       {Mutating wall}

    $08 : character := #247;       {Growing partition}

    $0C : character := #176;       {Porus wall}

    $10 : Begin
            Character := #21;      {Lava}
            C := Brown;
          end;

    $20 : Begin                    {Start point}
            Character := ^B;
            C := White;
          end;

    $28 : Begin
            character := #254;     {Rock}
            C := Brown;
          end;

    $2C : Begin
            character := #24;      {Bug 2 ^}
            C := Yellow;
          end;

    $30 : Begin
            character := #27;      {Bug 2 <}
            C := Yellow;
          end;

    $2e : Begin
            character := #25;      {Bug 2 V}
            C := Yellow;
          end;


    45  : Begin
            Character := #26;      {Bug 2 > }
            C := Yellow;
          end;

    $34 : begin
            character := #24;      {Bug ^}
            C := White;
          end;

    $35 : Begin
            character := #26;      {Bug >}
            C := White;
          end;

    $36 : Begin
            character := #25;      {Bug V}
            C := White;
          end;

    $37 : Begin
            character := #27;      {Bug <}
            C := White;
          end;

    $38 : character := #30;        {Tap Upwards}

    $70 : Begin
            character := '@';      {Snake A - Coins > Rocks > Bugs}
            C := Lightred;
          end;

    $74 : Begin                    {Door}
            character := '#';
            C := White;
          end;

    $7C : character := 'T';        {Extra time}

    $78 : Begin
            character := '?';      {Mystery points}
            C := Yellow;
          end;

    $84 : character := #235;       {Snake B - Rocks > Coins}

    $88 : Begin
            character := '*';      {Coin}
            C := Yellow;
          end;

    $C4 : character := #31;        {Tap downwards}

{$IFDEF DEBUG}
    else Character := '+'
{$ENDIF}

  end;

  T := TextAttr;
  TextAttr := C;
  Write (Character);
  TextAttr := T;

end;


{---------------------------------------------------------------------------}

Procedure showmap (Var MF : Main_Map_Type; Offset : Integer);

var R,C : Integer;
    Character : Char;
    Colour : Byte;

begin

  Gotoxy(1,Offset);

  For R := 0 to 21 do
  begin
    For C := 0 to 39 do
      Showchar (MF.m[R,C]);
  Writeln;
  end;
end;

{---------------------------------------------------------------------------}

Procedure viewmap (MName : String; Var Err : Integer; var S : String); {View maps from a game cellmaps file}

Var M          : Integer;
    Ch         : Char;
    Esc, DoneWin : Boolean;
    MF         : Main_Map_Type;

begin
  M := 1;
  Esc := false;
  DoneWin := False;

  repeat

    Get_Multi(MF,'',MName,M,Err);

    If not DoneWIn and (Err = 0) then
    begin
      DoneWin := True;
      OpenWindow (7,1,69,25,MName,Yellow,Yellow);
    end;

    If (Err = 0) then
    begin

      Showmap(MF,1);

      Gotoxy (45,1);
      Write ('Map Number ',m:3);

      Gotoxy (45,3);
      Write ('+ - or ESC : ');

      Select ('',['+','-',^[],Ch);

        Case Ch of

        '+' : begin
               Inc (m);
               If (M > 40) then M :=  1;
              end;

        '-' : begin
                Dec (m);
                If (M < 1) then M := 40;
              end;

        ^[  : Esc := True;

      end;
    end;
  until esc or (Err <> 0);
  If DoneWIn then Closewindow;
  Str (M,S);
 end;

{---------------------------------------------------------------------------}

procedure editmap (Var Map : Main_Map_Type; Game_File_Name, Map_File_Name : String;
                   Map_Num : Integer);

var X , Y        : Byte;
    key          : Char;
    charmode     : Byte;
    Key2         : byte;
    Ch           : Char;
    Err          : Integer;

    Esc          : Boolean;

    S,S2         : String;

    Start_Flag   : Boolean; {True if we have set a start point}

{...........................................................................}


Procedure CheckStart; {See whether we have already set a start point}

Var X2,Y2 : Integer;

begin
  Start_Flag := False;
    For X2 := 0 to 39 do
      for Y2 := 0 to 21 do
        If Map.M[Y2,X2] = $20 Then Start_Flag := True;
end;

{...........................................................................}

Procedure Update (X,Y,N : Byte);

{The map cell X,Y is updated with the value of N

}

var
    Colour    : Byte;
    Character : Char;

begin


    If
{Unregistered users cannot certain things}
{$IFDEF REGISTERED}
{$ELSE}
    (not (Map.M[Y,X] in unreg)) and
{$ENDIF}

    ((N <> 32) or ((N = 32) and (Start_Flag = false))) {No mulltiple starts}
    then
    begin

      If Map.M[Y,X] = $88 then dec(Map.CC)
      else
      If map.M[Y,X] = 32  then Start_flag := False;

      map.M[Y,X] := N;

      If N = $88 then Inc(Map.CC)
      else
      if N = 32 then Start_Flag := True;

      Gotoxy (X+Xoff,Y+Yoff);  {Update cell on screen}
      Showchar (N);
    end;
end;

{...........................................................................}

Procedure cleartop; {Clear the top line}
begin
  Textcolor(White);
  Gotoxy(1,1);
  Writec (' ');
  Gotoxy(1,1);
end;

{...........................................................................}


Procedure Showtop;
{Show the information on the top line}
begin
  Gotoxy(1,1);
  Textcolor (White);
  Write ('Map ',Map_Num:2,'  Time ',Map.T:3,'  Treasure Req''d ',Map.CR:3,
  '  Treasure set ',Map.CC:3);
  Gotoxy(59,1);
  Write ('X:',X:2,' Y:',Y:2);
  Gotoxy (70,1);
  Write ('Mode : ');
  Showchar (Charmode);
end;

{...........................................................................}

Procedure dokey;

Var X2,Y2 : byte;
    Tch   : byte;
    Ch    : Char;
    S     : String;

    TimeString1,
    TimeString2 : CSt11;

begin

  Tch := 255;

  case Upcase(key) of

{$IFDEF REGISTERED}

    'L' : Begin {Load a solo map file}
            S := '';
            Cleartop;
            Write ('Solo map file to load : ');
            Getstring (S,30,-1,-1,F_Valid+[^[],esc,'_');

            If not esc and (S <> '') then
            begin
              Err := Validate (S); {if this the right type of file?}

              If (Err = 3) then {OK..}
              begin
                GetSolo (S,Map);
                Showmap (Map,3);
                X := 1;
                Y := 1;
              end
              else
              begin
                Cleartop;
                Write ('File not found/Incorrect type. Press a key');
                Presskey(0);
              end
            end;
            Showtop
          end;

    '/' : begin {Directory Listing}
            Cleartop;
            Write ('Filespec : ');
	    S := '*.*';
	    GetString (S,32,-1,-1,D_Valid,esc,' ');
            If not Esc and (S <> '') then
              Shdir (S);
            Showtop;
          end;

{$ENDIF}

    '!' : begin {Show debug information}

            TimeString1 := '';


{$IFDEF SPECIAL}
           OpenWindow (4,5,70,20,'File Info',Yellow,white);
{$ELSE}
           OpenWindow (4,5,60,13,'File Info',Yellow,white);
{$ENDIF}
           Textcolor (Yellow);

           Write (' It''s ', Systime(0)
{$IFDEF DEBUG} ,  '      Character @ cursor = ',Map.M[Y,X]
{$ENDIF}

           );
           Writeln (CRLF + CRLF +
                   ' Game file       : ',Game_File_Name+CRLF + CRLF +
                   ' Map file        : ',Map_File_Name+CRLF );
{$IFDEF SPECIAL}

           Writeln (' Game file Size       : ',Game_File_Size:6,CRLF,
                    ' Ident offset         : ',Game_File_Ident_Pos:6,CRLF,
                    ' Time offset          : ',Game_File_Time_Pos:6,CRLF,
                    ' Treasure offset      : ',Game_File_Coin_Pos:6,CRLF,
                    ' Map file name Offset : ',Game_File_Map_name_pos:6,CRLF);
{$ENDIF}

           CH := #01;

           Write(' PRESS A KEY');

           Repeat

             TimeString1 := Systime(1);
             If TimeString1 <> TimeString2 then
             begin
               TimeString2 := TimeString1;
               Gotoxy (7,1);
               Write (TimeString1);
{$IFDEF SPECIAL}
               Gotoxy (13,13)
{$ELSE}
	       Gotoxy (13,7)
{$ENDIF}
             end;
             If Keypressed then Ch := readkey;
           Until (Ch <> #01);



           CloseWindow;
          end;


    'M': TCh := $2e;

    'J': TCh := $30;

    'I': TCh := $2c;

    'K': TCh := 45;

    '8': TCh := $34;

    '6': TCh := $35;

    '2': TCh := $36;

    '4': TCh := $37;

    ' ': TCh := $00;

{$IFDEF REGISTERED} {Only registered users may change door/Start/Ex Time/Mystery points}

    'S': TCh := 32;

    'D': TCh := $74;

    '?': TCh := 120;

    'T': TCh := $7C;

{$ENDIF}


    'A': TCh := 112;

    'B': TCh := 132;

    'G': TCh := $01;

    'R': TCh := $28;

    'X': TCh := $88;


    ^@ : Begin
           Key := Readkey;

{$IFDEF REGISTERED}  {AUTO KEY REPEAT}

           If ((Key2 AND 3) <> 0) and (Key in ['K','M','H','P']) Then
           begin
             Update (X,Y,Charmode);
             TCh := Charmode;
           end;

{$ENDIF}

           Case key of


             'G' : Begin {Home}
                     X := 1;
                   end;

             'O' : Begin {End}
                     X := 38;
                   end;

             'I' : Begin {Pgup}
                     X := 1;
                     Y := 1;
                   end;

             'K' : Begin {Cursor left}
                    Dec (X);
                    If X < 1 then X := 38;
                   end;

             'M' : Begin {Cursor Right}
                     Inc (X);
                     If X > 38 then X := 1;
                   end;

             'H' : Begin {Cursor Up}
                    Dec (Y);
                    If Y < 1 then Y := 20;
                   end;

             'P' : Begin {Cursor Down}
                    Inc (Y);
                    If Y > 20 then Y := 1;
                   end;

             ';': TCh := $03;   {F1 - Partition}

             'T': TCh := $02;   {Sh-F1 - Solid Wall}

             '<': TCh := $08;   {F2 - Growing partition}

             '=': TCh := $0C;   {F3 - Porus Wall}

             '>': TCh := $04;   {F4 - Wall that eats coins}

             '?': TCh := $10;   {F5 - Growing slime}

             '@': TCh := ord('8');

             'A': TCh := 196;


             'B': begin {F8 - Clear map}

                    Cleartop;
                    Select ('Clear Map (Y/N)? : ',['Y','N',^[],Ch);
                    Showtop;
                    If (Ch = 'Y') then
                    begin
                      Charmode := $00;
                      For X2 := 1 to 38 do
                      for Y2 := 1 to 20 do
                        Update(X2,y2,Charmode);
                       X := 1; Y := 1;
                     end
                    end;
{$IFDEF REGISTERED}

             'C': begin {F9 - New time}
                    Cleartop;
                    Write ('Enter new time (10-199) : ');
                    GetInt(Map.T,10,199,esc,' ');
                    Showtop;
                    end;

             'D': begin {F10- New points}
                    Cleartop;
                    Write ('Treasure required (1-500) : ');
                    GetInt(Map.CR,1,500,Esc,' ');
                    Showtop;
                  end;
{$ENDIF}

           end; {FKeys case}

         end; {Fkeys}

  end; {Case}

  If TCh <> 255 then  {Update required cell}
  begin
    Charmode := TCh;
    Update (X,Y,Charmode);
  end;

end;


{...........................................................................}

procedure drawmenu;

Var I : Integer;

begin

  For I := 0 to 16 do  {Display the character symbols next to the user menu}
  begin
    Gotoxy(42,3+I);
    ShowChar (M_Array[I]);
  end;

  Window (45,3,80,25);

  Textcolor (Lightgreen);

  Write ('A       Snake A (Pt  > Rock > Bug)' + CRLF +
         'B       Snake B (Bug > Rock > Pt)'  + CRLF);

{$IFDEF REGISTERED}
{$ELSE}
  Textcolor (DarkGray);
{$ENDIF}

  Write ('D       Door' + CRLF);
  Textcolor (Lightgreen);
  Write ('G/SPC   Dirt/Clear' + CRLF +
           'R       Rock' + CRLF );

{$IFDEF REGISTERED}

{$ELSE}

  Textcolor (DarkGray);

{$ENDIF}

  Write ('S       Start point' + CRLF +
         'T       Extra Time'  + CRLF +
         '?       Mystery Treasure' + CRLF );
  Textcolor (LightGreen);

  Write ('X       Treasure'            + CRLF +
         '8 6 4 2 Enemy 1'            + CRLF +
         'I J M K Enemy 2'            + CRLF +
         'F1/SF1  Wall/Solid Wall'  + CRLF +
         'F2      Growing Wall'     + CRLF +
         'F3      Porus Wall'       + CRLF +
         'F4      Magic Wall'       + CRLF +
         'F5      Lava'             + CRLF +
         'F6/F7   Taps up/dn'       + CRLF +
         'F8      Clear map'        + CRLF );

{$IFDEF REGISTERED}
{$ELSE}
  Textcolor (DarkGray);
{$ENDIF}

  Write ('F9/F10  New time/Treasure'  + CRLF +
         'L       Load solo map file' + CRLF +
         '/       Directory listing'+ CRLF +
         '!       File info' + CRLF);

  Textcolor (Lightgreen);

  Write ('SHIFT + CURSOR = Repeat last key');

  Window (1,1,80,25);

  Gotoxy (12,25);
  Write ('PRESS ESC WHEN DONE');

{$IFDEF REGISTERED} {$ELSE}

  Textcolor (Black);
  Textbackground (White);
  Gotoxy (3,3);
  Writeln ('Look at all those missing features!!');
  Gotoxy(4,24);
  Writeln ('Why not register for a full copy??');
  Textbackground(Black);
  {$ENDIF}
end; {Drawmenu}

{...........................................................................}

Procedure CheckSave; {Save map - if required}


Var CH                  : Char;
    New_Game_File_Name,
    New_Map_File_Name   : String;
    Map_Mode            : Integer; {Holds result of validate process}

begin
  Cleartop;
  Write ('Game (.EXE) or solo map file : ');

  New_Game_File_Name := Game_File_Name; {Use old file??}

  GetString (New_Game_File_Name,30,-1,-1,F_Valid,esc,'_');

  If not esc then
  begin

    Map_Mode := Validate (New_Game_File_Name); {Check out this file - .EXE or map file??}

    Case Map_Mode of

      2 : Begin {Write Game file/Multi map}
            Cleartop;
            Write ('Overwrite map 1-40, or ESC to cancel save : ');
            S := '';
            Esc := false;
            GetInt (Map_Num,1,40,esc,'_');

            if not esc then
            Begin
              New_Map_File_Name := Get_Map_Name(New_Game_File_Name);
              Write_Multi (Map, New_Game_File_Name,New_Map_File_Name,Map_Num,Err);
              If (Err <> 0) then
              begin
                Cleartop;

                Write ('File Open/Write error - ');
                Case Err of
                  1 : Write (New_Map_File_Name);
                  2 : Write (New_Game_File_Name);
                end;
                Write ('. Press a key');
                Presskey(0);
                ShowTop;
              end;
            end;
          end;

{$IFDEF REGISTERED}

   1, 3 : begin
            Ch := 'Y';
            If Exist (New_Game_File_Name) then
            begin
              Cleartop;
              Write ('Overwrite existing file - (Y/N)? ');
              Select ('',['Y','N',^[],Ch);
            end;
            If Ch = 'Y' then Write_Solo (Map, New_Game_File_Name,Err);

            If (Err <> 0) then
            begin
              Cleartop;
              Write ('Error during write. Press a key');
              Presskey(0);
              Showtop;
            end;
          end;

{$ENDIF}

    else  begin
            Cleartop;
            Write ('Invalid file/Error opening file. Press a key');
            Presskey(0);
          end;

    end; {Case}
  end;
end; {CheckSave}

{...........................................................................}

begin {Editing map}

  CheckStart; {See if we already have a start point - only 1 allowed}

  Clrscr;
  Showmap(Map,3);

  Charmode := 0;

  Drawmenu;

  X := 1;
  Y := 1;

  repeat
    Showtop;


    repeat

      Esc := False;
      Textcolor(White);
      Gotoxy(59,1);
      Write ('X:',X:2,' Y:',Y:2);

      Gotoxy (77,1);
      Showchar(Charmode);

      Gotoxy(X+Xoff,Y+Yoff);

      repeat until keypressed;

      Key2 := Keystat;
      Key  := Readkey;

      If Key <> ^[ then
      begin
        dokey;
        Gotoxy(52,1);
        Write (Map.CC:3);
      end;

    until Key = ^[;

    Cleartop;
    Write ('(S)ave map, E(X)it or Esc to resume edit : ');
    Select ('',['S','X',^[],Ch);

    If ch = 'S' then CheckSave {Go save it?}
    else
    if ch = 'X' then Key := 'Q';

    Showtop;

  until (Key in ['q','Q']);
end;

{---------------------------------------------------------------------------}

procedure intro;


Var Ch: Char;

begin

  CMsg :=  'ú‘ûòœüò™·¼¶ »±¹òãëêêýãëëâ'; {234, 56}
  RMsg :=  '`GIKB'+#14+'eK@J\GME'+#2+#14+'lO\@FOC'+#14+#3+#14+'yK]Z'+#14+'}[]]KV'; {9, 39 }
  AMsg :=

'-MC('+#6+#13+#7+#17+#10+#0+#8+'CCRWC&'+#15+#14+'C'''+#2+#15+#6+'CC&'+#15+#14+'C$'+#17+#12+#21+#6+'C0'+#12+#22+#23+#11+
'CC!'+#2+#17+#13+#11+#2+#14+'CC4'+#6+#16+#23+'C0'+#22+#16+#16+#6+#27+'CC6(CC3,QQCS&"'; {8, 107}

  Textbackground(Black);
  Textcolor (Lightgreen);
  Clrscr;

  Writeln ('RockEd - The Rockford EDitor                 ' + Version + ' ' +

  Crypt(234,56,Cmsg) + CRLF +

           '~~~~~~~~~~~~~~~~~~~~~~~~~~~~'+CRLF);
  Textcolor (White);
  Writeln ('Use this program to design your own maps for the ROCKFORD computer game!'+CRLF);

  {$IFDEF REGISTERED}

  Textcolor (Yellow);
(*  Centre ('Registered to '+ crypt(9,39,RMsg) + CRLF);*)
  Centre ('Released into the Public Domain August 2016.' + CRLF );  
  Textcolor (Lightgreen);
(*  Writeln ('You are using the FULL version of this program. If you are not the person' + CRLF +
           'to whom it has been registered, you may use this program for THREE DAYS'    + CRLF +
           'solely for evaluation purposes. Should you subsequently continue to use');
  Writeln ('it, you are requested to register for your own copy - see ROCKED.DOC for'   + CRLF +
          'full details.'+CRLF);
*)
{$ELSE}

  Textcolor (Yellow);

  Writeln ('You are using the PUBLIC DOMAIN version of RockEd - why not register for the' + CRLF +
           'FULL COPY and get the following extra features (and more):'+CRLF + CRLF +
           '* Move the START and DOOR positions!' + CRLF +
           '* Change the TIME allowed & amount of TREASURE required per map!');
  Writeln ('* Multiple exit DOORS!' + CRLF +
           '* Add MYSTERY TREASURE and EXTRA TIME tokens!' + CRLF +
           '* Load and Save SOLO MAP files!'+CRLF+
           '* Inbuilt DIR feature!'+CRLF+CRLF+
           'Register for only ' + RegTerms + '. See ROCKED.DOC for full details.'+CRLF);
{$ENDIF}

  Textcolor(White);
(*  Writeln (Crypt(8,107,AMsg)); *)
    Centre ('Released under the terms of the Unlicence' + CRLF);
    Centre ('For more information, please refer to <http://unlicense.org/>' + CRLF);
    Centre ('nigel.kendrick@gmail.com' + CRLF);

end;

{---------------------------------------------------------------------------}

Procedure Choosemap (Var Map : Main_Map_Type; Var GFNAME,MFNAME : PathStr;
                     Var MapNum : integer; Var Esc : Boolean); {Select a map to edit}

Var

    Err,
    Err2,
    Mode : Integer;
    Ch   : Char;
    S    : String;


begin

  MFNAME := '';
  GFNAME := '';
  Err := 0;
  Err2:= 0;
  ClearMap (Map);

{$IFDEF SPECIAL}
{$ELSE}
  If (ParamCount <> 0) then GFNAME := ParamStr(1);
{$ENDIF}
  Repeat {Find out which set of maps or Solo map we want to edit}

    Gotoxy (1,22);

{$IFDEF REGISTERED}
    Write ('Game/Solo map file or ESC to exit : ');
{$ELSE}
    Write ('Game file to edit or ESC to exit : ');
{$ENDIF}

    Getstring (GFName,30,-1,-1,F_Valid+[^[],esc,'_');

     If not esc then
     begin
       Mode := Validate(GFName); {Check file type - is it a game file??}

{$IFDEF REGISTERED}
       If (Mode > 0) then {OK, is a valid file, or maybe a new one??}
{$ELSE}
       If (Mode = 2) then
{$ENDIF}

       begin

         Case Mode of

{$IFDEF REGISTERED}

           1 : Begin {New file???}
                 Gotoxy (1,23);
		 Select ('(N)ew file, (L)ist or ESC : ',['N','L',^[],Ch);

		 If (Ch = 'L') Then {Directory list...}
		 begin
		   Gotoxy (1,23);
		   Write ('Filespec : ');
		   S := '*.*';
		   GetString (S,32,-1,-1,D_Valid,esc,' ');

		   If esc then
		   begin
		     Esc := False;
		     mode := -1
		   end
		   else ShDir(S);
		 end
		 else
		 If (Ch = ^[) then mode := -1 {Force try again}
                 else
		 begin
                   If GFNAME = '' then GFNAME := 'SOLO.MAP';
                   MFNAME := GFNAME;
                   MapNum := 0;
                 end;
                 Gotoxy (1,23);
                 WriteC ('');
               end;

           3 : Begin
                 GFNAME := UpString(GFNAME);
                 MFName := GFName; {Editing a Solo map file}
                 GetSolo (MFName,Map);
                 MapNum := 0;
               end;

{$ENDIF}

           2 : Begin

                 MFName := UpString(Get_Map_name(GFName)); {Get name of map file from .EXE file}

                 While MFName[Length(MFName)] = ' ' do MFname[0] := Pred (Mfname[0]) ;

                 Textcolor (Lightgreen);
                 Gotoxy (1,23);
                 Write ('Map file = ',MFNAME);
                 S := '';
                 repeat
                   Textcolor(WHite);
                   Gotoxy (1,24);
                   Write ('Map number (1-40), V to view or ESC : ');
                   Esc := False;
                   Getstring (S,2,-1,-1,['0'..'9','V','v'],esc,' ');

                   If Not Esc and (S[1] in ['v','V']) then
                   begin
                     Viewmap(MFNAME,Err,S);
                     Err2 := 1; {So we don't drop through}
                   end
                   else
                   Val (S,MapNum,err2);

                 until (Err2 = 0) or Esc or (err <> 0);

                 If not esc
                 then
                 begin
                   if (Err = 0) then {Ok, get map...}
                     Get_Multi (Map,GFName,MFName,MapNum,Err);

                   If (Err <> 0) then
                   begin
                     TextColor(White);
                     Gotoxy(1,24);
                     Writec('Map file error. Press a key');
                     Presskey(0);
                     Mode := 0;
                   end;
                 end
                 else
                 begin
                  Mode := 0;
                  Esc := False;
                 end;

                 Gotoxy(1,23);
                 Writec('');
                 Writeln;
                 Writec('');

               end; {Case 2}


         end; {case}

       end
       else {Wrong file type}
       Begin
         Gotoxy (1,24);
         Writec('Wrong file type/Error opening file. Press a key');
         Presskey(0);
         Gotoxy(1,24);
         WriteC ('');
       end;
     end;

   Until (Mode > 0) or esc;

end;


{---------------------------------------------------------------------------}

{$IFDEF SPECIAL}

Procedure Getparams;

Var S : String;
    Err : Integer;

Begin

  If Paramcount <> 0 then
  begin
    If Paramcount <> 5 then
    begin
      Writeln ;
      Writeln ('Invalid number of parameters (Should be 5)');
      Writeln;
      halt(1);
    end;

    Err := 0;


    S := paramStr(1);
    Val (S,Game_File_Size,Err);

    If (Err = 0) then
    begin
      S := paramStr(2);
      Val (S,Game_File_Ident_Pos,Err);
    end;

    If (Err = 0) then
    begin
      S := paramStr(3);
      Val (S,Game_File_Time_Pos,Err);
    end;

    If (Err = 0) then
    begin
      S := paramStr(4);
      Val (S,Game_File_Coin_Pos,Err);
    end;

    If (Err = 0) then
    begin
      S := paramStr(5);
      Val (S,Game_File_Map_Name_Pos,Err);
    end;

    If (Err <> 0) or

       (Game_File_Ident_Pos >= game_File_Size - 8)  or
       (Game_File_Time_Pos  >= game_File_Size - 40) or
       (Game_File_Coin_Pos  >= game_File_Size - 40) or
       (Game_File_Map_Name_Pos  >= game_File_Size - 14) or
       (Game_File_Size < 0) or
       (Game_File_Ident_Pos < 0) or
       (game_File_Time_Pos < 0) or
       (Game_File_Coin_Pos < 0)
       then
    begin
      Writeln;
      Writeln ('Invalid parameter(s) Supplied');
      Writeln;
      Halt(1);
    end;
  end;
end;

{$ENDIF}

{***************************************************************************}

begin


{$IFDEF SPECIAL}
  GetParams;
{$ENDIF}

  Checksnow   := False;
  TopWindow   := nil;

  Directvideo := true;

  KbStat := Kbstat and 223;

  Esc := keypressed;

  repeat;

    Esc  := False;

    Intro;

    Choosemap (Map,Game_File_Name,Map_File_Name,Map_Num,Esc);

    If Not esc and (Map_File_Name <> '') then
    begin

      Game_File_Name := UpString(Game_File_name);

      editmap (Map,Game_File_Name,Map_File_Name,Map_Num);
      Esc := False;

    end;

  until Esc;

end.
