unit JunctionNTFS;

interface

uses
  SysUtils, Classes, Windows;

type
  uint = Cardinal;
  int = Integer;
  ushort = smallint;

  EFileAccess =
  (
      EFileAccess_GenericRead = $80000000,
      EFileAccess_GenericWrite = $40000000,
      EFileAccess_GenericExecute = $20000000,
      EFileAccess_GenericAll = $10000000
  );

  EFileShare =
  (
      EFileShare_None = $00000000,
      EFileShare_Read = $00000001,
      EFileShare_Write = $00000002,
      EFileShare_Delete = $00000004
  );

  ECreationDisposition =
  (
      ECreationDisposition_New = 1,
      ECreationDisposition_CreateAlways = 2,
      ECreationDisposition_OpenExisting = 3,
      ECreationDisposition_OpenAlways = 4,
      ECreationDisposition_TruncateExisting = 5
  );

  EFileAttributes =
  (
      EFileAttributes_Readonly = $00000001,
      EFileAttributes_Hidden = $00000002,
      EFileAttributes_System = $00000004,
      EFileAttributes_Directory = $00000010,
      EFileAttributes_Archive = $00000020,
      EFileAttributes_Device = $00000040,
      EFileAttributes_Normal = $00000080,
      EFileAttributes_Temporary = $00000100,
      EFileAttributes_SparseFile = $00000200,
      EFileAttributes_ReparsePoint = $00000400,
      EFileAttributes_Compressed = $00000800,
      EFileAttributes_Offline = $00001000,
      EFileAttributes_NotContentIndexed = $00002000,
      EFileAttributes_Encrypted = $00004000,
      EFileAttributes_Write_Through = $80000000,
      EFileAttributes_Overlapped = $40000000,
      EFileAttributes_NoBuffering = $20000000,
      EFileAttributes_RandomAccess = $10000000,
      EFileAttributes_SequentialScan = $08000000,
      EFileAttributes_DeleteOnClose = $04000000,
      EFileAttributes_BackupSemantics = $02000000,
      EFileAttributes_PosixSemantics = $01000000,
      EFileAttributes_OpenReparsePoint = $00200000,
      EFileAttributes_OpenNoRecall = $00100000,
      EFileAttributes_FirstPipeInstance = $00080000
  );

  REPARSE_DATA_BUFFER = record
      /// <summary>
      /// Reparse point tag. Must be a Microsoft reparse point tag.
      /// </summary>
      ReparseTag : uint;

      /// <summary>
      /// Size, in bytes, of the data after the Reserved member. This can be calculated by:
      /// (4 * sizeof(ushort)) + SubstituteNameLength + PrintNameLength + 
      /// (namesAreNullTerminated ? 2 * sizeof(char) : 0);
      /// </summary>
      ReparseDataLength : ushort;

      /// <summary>
      /// Reserved; do not use. 
      /// </summary>
      Reserved : ushort;

      /// <summary>
      /// Offset, in bytes, of the substitute name string in the PathBuffer array.
      /// </summary>
      SubstituteNameOffset : ushort;

      /// <summary>
      /// Length, in bytes, of the substitute name string. If this string is null-terminated,
      /// SubstituteNameLength does not include space for the null character.
      /// </summary>
      SubstituteNameLength : ushort;

      /// <summary>
      /// Offset, in bytes, of the print name string in the PathBuffer array.
      /// </summary>
      PrintNameOffset : ushort;

      /// <summary>
      /// Length, in bytes, of the print name string. If this string is null-terminated,
      /// PrintNameLength does not include space for the null character. 
      /// </summary>
      PrintNameLength : ushort;

      /// <summary>
      /// A buffer containing the unicode-encoded path string. The path string contains
      /// the substitute name string and print name string.
      /// </summary>
      /// [MarshalAs(UnmanagedType.ByValArray, SizeConst = 0x3FF0)]
      PathBuffer : array[0..$3FF0-1] of byte;
  end;

const
  ERROR_NOT_A_REPARSE_POINT = 4390;
  /// <summary>
  /// The reparse point attribute cannot be set because it conflicts with an existing attribute.
  /// </summary>
  ERROR_REPARSE_ATTRIBUTE_CONFLICT = 4391;
  /// <summary>
  /// The data present in the reparse point buffer is invalid.
  /// </summary>
  ERROR_INVALID_REPARSE_DATA = 4392;
  /// <summary>
  /// The tag present in the reparse point buffer is invalid.
  /// </summary>
  ERROR_REPARSE_TAG_INVALID = 4393;
  /// <summary>
  /// There is a mismatch between the tag specified in the request and the tag present in the reparse point.
  /// </summary>
  ERROR_REPARSE_TAG_MISMATCH = 4394;
  /// <summary>
  /// Command to set the reparse point data block.
  /// </summary>
  FSCTL_SET_REPARSE_POINT = $000900A4;
  /// <summary>
  /// Command to get the reparse point data block.
  /// </summary>
  FSCTL_GET_REPARSE_POINT = $000900A8;
  /// <summary>
  /// Command to delete the reparse point data base.
  /// </summary>
  FSCTL_DELETE_REPARSE_POINT = $000900AC;
  /// <summary>
  /// Reparse point tag used to identify mount points and junction points.
  /// </summary>
  IO_REPARSE_TAG_MOUNT_POINT = $A0000003;
  /// <summary>
  /// This prefix indicates to NTFS that the path is to be treated as a non-interpreted
  /// path in the virtual file system.
  /// </summary>
  NonInterpretedPathPrefix : string = '\??\';

function Junction_geterror(): string;
function Junction_Create(junctionPoint : string; targetDir : string; overwrite : boolean = True): integer;
function Junction_Delete(junctionPoint : string): Integer;
function Junction_Exists(junctionPoint : string; targetDir : string = ''): Boolean;

implementation

var Junction_LastError : Integer;

function InternalGetTarget(hDev : THandle): string;
var outBuffer : REPARSE_DATA_BUFFER;
  bytesReturned : Cardinal;
  ret : LongBool;
begin
  Result := '';

  try
    ret := DeviceIoControl(hDev, FSCTL_GET_REPARSE_POINT,
                nil, 0, @outBuffer, sizeof(outBuffer), bytesReturned, nil);

    if not ret then
      if ERROR_NOT_A_REPARSE_POINT = GetLastError() then
      begin
        Junction_LastError := -61;
        Exit;
      end;

    if outbuffer.ReparseTag <> IO_REPARSE_TAG_MOUNT_POINT then
    begin
      Junction_LastError := -62;
      Exit;
    end;

    //Result := copy(StrPas(@outbuffer.PathBuffer), outbuffer.SubstituteNameOffset, outbuffer.SubstituteNameLength);
    Result := WideCharLenToString(PWideChar(Cardinal(@outbuffer.PathBuffer) + outbuffer.SubstituteNameOffset), outbuffer.SubstituteNameLength div 2);
    if pos(NonInterpretedPathPrefix, Result) = 1 then
      Result := copy(result, length(NonInterpretedPathPrefix) + 1, length(result) - length(NonInterpretedPathPrefix));
  except
  end;
end;

function OpenReparsePoint(reparsePoint : string; accessMode : EFileAccess): THandle;
begin
  OutputDebugString(PChar('OpenReparsePoint ' + reparsePoint));
  Result := CreateFile(PChar(reparsePoint), Cardinal(accessMode),
        Cardinal(EFileShare_Read) or Cardinal(EFileShare_Write) or Cardinal(EFileShare_Delete),
        nil, Cardinal(ECreationDisposition_OpenExisting),
        Cardinal(EFileAttributes_BackupSemantics) or Cardinal(EFileAttributes_OpenReparsePoint), 0);

  if GetLastError() <> 0 then
  begin
    OutputDebugString(PChar('OpenReparsePoint result ' + IntToStr(Result)));
    Result := 0;
  end;
end;

/// <summary>
/// Gets the target of the specified junction point.
/// </summary>
/// <remarks>
/// Only works on NTFS.
/// </remarks>
/// <param name="junctionPoint">The junction point path</param>
/// <returns>The target of the junction point</returns>
/// <exception cref="IOException">Thrown when the specified path does not
/// exist, is invalid, is not a junction point, or some other error occurs</exception>
function GetTarget(junctionPoint : string): string;
var hPoint : THandle;
  target : string;
begin
  Result := '';

  hPoint := OpenReparsePoint(junctionPoint, EFileAccess_GenericRead);
  target := InternalGetTarget(hPoint);
  if target = '' then
  begin
    Junction_LastError := -41;
    Exit;
  end;

  Result := target;
end;



/// <summary>
/// Creates a junction point from the specified directory to the specified target directory.
/// </summary>
/// <remarks>
/// Only works on NTFS.
/// </remarks>
/// <param name="junctionPoint">The junction point path</param>
/// <param name="targetDir">The target directory</param>
/// <param name="overwrite">If true overwrites an existing reparse point or empty directory</param>
/// <exception cref="IOException">Thrown when the junction point could not be created or when
/// an existing directory was found and <paramref name="overwrite" /> if false</exception>

function Junction_geterror(): string;
var sMsgBuf : array[0..1023] of Char;
begin
  case Junction_LastError of
  0 : result := '';
  -11 : result := '11 Target path does not exist or is not a directory.';
  -12 : result := '12 Directory already exists and overwrite parameter is false';
  -13 : Result := '13 devicecontrol error';
  -14 : Result := '14 devicecontrol error';
  -15 : Result := '15 open device error';
  -21 : Result := '21 Path is not a junction point.';
  -22 : Result := '22 devicecontrol error';
  -24 : Result := '24 devicecontrol error';
  -35 : Result := '35 open device error';
  -41 : Result := '41 Path is not a junction point.';
  -51 : Result := '51 devicecontrol error';
  -61 : Result := '61 devicecontrol error';
  -62 : Result := '62 devicecontrol error';
  else
    begin
      FillChar(sMsgBuf, sizeof(sMsgBuf), 0);
      FormatMessage( FORMAT_MESSAGE_ALLOCATE_BUFFER or FORMAT_MESSAGE_FROM_SYSTEM,
                    nil, Junction_LastError,
                    MakeLong(LANG_NEUTRAL, SUBLANG_DEFAULT),
                    sMsgBuf, 0, nil );
      Result := sMsgBuf;
    end;
  end;
end;

function Junction_Create(junctionPoint : string; targetDir : string; overwrite : boolean): integer;
var reparseDataBuffer : REPARSE_DATA_BUFFER;
  targetDirBytes : WideString;
  bytesReturned : Cardinal;
  ret : LongBool;
  hDev : THandle;
begin
  OutputDebugString(PChar('junction_create ' + junctionpoint + ' ' + targetDir));
  Result := -1;
  Junction_LastError := 0;

  if not DirectoryExists(targetDir) then
  begin
    Junction_LastError := -11;
    Result := Junction_LastError;
    Exit;
  end;

  if DirectoryExists(junctionPoint) then
  begin
    if not overwrite then
    begin
      Junction_LastError := -12;
      Result := Junction_LastError;
      Exit;
    end;
  end
  else
  begin
    CreateDirectory(PChar(junctionPoint), nil);
  end;

  with reparseDataBuffer do
  begin
    FillChar(reparseDataBuffer, sizeof(reparseDataBuffer), 0);
    targetDirBytes := NonInterpretedPathPrefix + targetDir;
    reparseDataBuffer.ReparseTag := IO_REPARSE_TAG_MOUNT_POINT;
    reparseDataBuffer.ReparseDataLength := length(targetDirBytes) * sizeof(WCHAR) + 12;
    reparseDataBuffer.SubstituteNameOffset := 0;
    reparseDataBuffer.SubstituteNameLength := Length(targetDirBytes) * sizeof(WCHAR);
    reparseDataBuffer.PrintNameOffset := Length(targetDirBytes)* sizeof(WCHAR) + 2;
    reparseDataBuffer.PrintNameLength := 0;
    //Strcopy(@reparseDataBuffer.PathBuffer, PChar(targetDirBytes));
    Move(targetDirBytes[1], reparseDataBuffer.PathBuffer, Length(targetDirBytes) * sizeof(WCHAR));
  end;

  try
    hDev := OpenReparsePoint(junctionPoint, EFileAccess_GenericWrite);
    if hDev = 0 then
    begin
      Junction_LastError := -15;
      Result := Junction_LastError;
      Exit;
    end;

    ret := DeviceIoControl(hDev, FSCTL_SET_REPARSE_POINT,
                //@reparseDataBuffer, sizeof(reparseDataBuffer), nil, 0, bytesReturned, nil);
                @reparseDataBuffer, Length(targetDirBytes) * sizeof(WCHAR) + 20, nil, 0, bytesReturned, nil);

    if not ret then
    begin
      Junction_LastError := GetLastError();
      if ERROR_NOT_A_REPARSE_POINT = Junction_LastError then
      begin
        Junction_LastError := -14;
        Result := Junction_LastError;
        Exit;
      end;
      Exit;
    end;

    Result := 0;
  except
    Junction_LastError := -13;
    Result := Junction_LastError;
  end;
end;

/// <summary>
/// Deletes a junction point at the specified source directory along with the directory itself.
/// Does nothing if the junction point does not exist.
/// </summary>
/// <remarks>
/// Only works on NTFS.
/// </remarks>
/// <param name="junctionPoint">The junction point path</param>
function Junction_Delete(junctionPoint : string): Integer;
var reparseDataBuffer : REPARSE_DATA_BUFFER;
  bytesReturned : Cardinal;
  ret : LongBool;
  hDev : THandle;
begin
  Junction_LastError := 0;

  if not DirectoryExists(junctionPoint) then
  begin
    Junction_LastError := -21;
    Result := Junction_LastError;
    Exit;
  end;

  with reparseDataBuffer do
  begin
    reparseDataBuffer.ReparseTag := IO_REPARSE_TAG_MOUNT_POINT;
    reparseDataBuffer.ReparseDataLength := 0;
  end;

  try
    hDev := OpenReparsePoint(junctionPoint, EFileAccess_GenericWrite);
    if hDev = 0 then
    begin
      Junction_LastError := -25;
      Result := Junction_LastError;
      Exit;
    end;

    ret := DeviceIoControl(hDev, FSCTL_DELETE_REPARSE_POINT,
                @reparseDataBuffer, 8, nil, 0, bytesReturned, nil);
    RemoveDir(junctionPoint);
  except
    Junction_LastError := -22;
    Result := Junction_LastError;
  end;
end;

/// <summary>
/// Determines whether the specified path exists and refers to a junction point.
/// </summary>
/// <param name="path">The junction point path</param>
/// <returns>True if the specified path represents a junction point</returns>
/// <exception cref="IOException">Thrown if the specified path is invalid
/// or some other error occurs</exception>
function Junction_Exists(junctionPoint : string; targetDir : string): Boolean;
var hDev : THandle;
  path : string;
begin
  Result := False;
  OutputDebugString(PChar('Junction_Exists begin ' + junctionPoint));

  Junction_LastError := 0;
  if not DirectoryExists(junctionPoint) then
    Exit;

  OutputDebugString(PChar('Junction_Exists 1'));
  hDev := OpenReparsePoint(junctionPoint, EFileAccess_GenericRead);
  if hDev = 0 then
  begin
    //Junction_LastError := -35;
    Exit;
  end;
  path := InternalGetTarget(hDev);

  if path <> '' then
  begin
    if targetDir = '' then
      Result := True
    else if (targetDir <> '') and (targetDir = path) then
      Result := True
    else
      Result := False;
  end;

  OutputDebugString(PChar('Junction_Exists end'));
end;

end.
