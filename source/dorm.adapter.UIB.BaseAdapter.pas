unit dorm.adapter.UIB.BaseAdapter;

interface

uses
  dorm.Commons,
  dorm.Mappings,
  classes,
  SysUtils,
  DB,
  Rtti,
  dorm,
  superobject,
  TypInfo,
  FMTBcd,
  dorm.Filters,
  Generics.Collections,
  dorm.Collections,
  dorm.adapter.UIB.Facade,
  UIB,
  dorm.adapter.Base,
  dorm.Mappings.Strategies;

type
  TUIBBaseAdapter = class(TBaseAdapter, IdormPersistStrategy)
  strict private
    function Load(ARttiType: TRttiType; ATableName: string; AMappingTable: TMappingTable;
      const Value: TValue): TObject; overload;

  private
    function GetUIBReaderFor(ARttiType: TRttiType; AMappingTable: TMappingTable;
      const Value: TValue; AMappingRelationField: TMappingField = nil): TUIBQuery;

  protected
    FFormatSettings: TFormatSettings;
    FB: TUIBFacade;
    FLogger: IdormLogger;
    FKeysGeneratorClassName: string;
    FKeysGenerator: IdormKeysGenerator;
    FKeyType: TdormKeyType;
    FNullKeyValue: TValue;
    FLastInsertOID: TValue;
    procedure InitFormatSettings;
    function CreateUIBFacade(Conf: ISuperObject): TUIBFacade; virtual; abstract;
    function CreateObjectFromUIBQuery(ARttiType: TRttiType; AReader: TUIBQuery;
      AMappingTable: TMappingTable): TObject;
    procedure LoadObjectFromDBXReader(AObject: TObject; ARttiType: TRttiType; AReader: TUIBQuery;
      AFieldsMapping: TMappingFieldList);
    function GetLogger: IdormLogger;
    procedure SetUIBParameterValue(AFieldType: string; AStatement: TUIBStatement;
      ParameterIndex: Integer; AValue: TValue; IsNullable: boolean);
    function CanBeConsideredAsNull(const AValue: TValue): boolean;
  public
    function GenerateAndFillPrimaryKeyParam(Query: TUIBStatement; ParamIndex: Integer;
      const Entity: string): TValue; overload;
    function FillPrimaryKeyParam(Query: TUIBStatement; ParamIndex: Integer;
      const Value: TValue): TValue;
    function GetLastInsertOID: TValue;
    function GetKeysGenerator: IdormKeysGenerator;
    function Insert(ARttiType: TRttiType; AObject: TObject; AMappingTable: TMappingTable): TValue;
    function Update(ARttiType: TRttiType; AObject: TObject; AMappingTable: TMappingTable;
      ACurrentVersion: Int64): Int64;
    function Delete(ARttiType: TRttiType; AObject: TObject; AMappingTable: TMappingTable;
      ACurrentVersion: Int64): Int64;
    procedure DeleteAll(AMappingTable: TMappingTable);
    function Count(AMappingTable: TMappingTable): Int64;
    function Load(ARttiType: TRttiType; AMappingTable: TMappingTable;
      AMappingRelationField: TMappingField; const Value: TValue; AObject: TObject)
      : boolean; overload;
    function Load(ARttiType: TRttiType; AMappingTable: TMappingTable; const Value: TValue;
      AObject: TObject): boolean; overload;
    function List(ARttiType: TRttiType; AMappingTable: TMappingTable; ACriteria: ICriteria)
      : TObjectList<TObject>;
    procedure LoadList(AList: TObject; ARttiType: TRttiType; AMappingTable: TMappingTable;
      ACriteria: ICriteria); overload;
    procedure ConfigureStrategy(ConfigurationInfo: ISuperObject); virtual;
    procedure InitStrategy;
    procedure StartTransaction;
    procedure Commit;
    procedure Rollback;
    function InTransaction: boolean;
    procedure SetLogger(ALogger: IdormLogger);
    destructor Destroy; override;
    class procedure register;
    function IsNullKey(const Value: TValue): boolean;
    function GetNullKeyValue: TValue;
    function GetKeyType: TdormKeyType;
    function RawExecute(SQL: string): Int64;
    function ExecuteAndGetFirst(SQL: string): Int64;
    function GetDatabaseBuilder(AEntities: TList<string>; AMappings: ICacheMappingStrategy)
      : IDataBaseBuilder;
    function ExecuteCommand(ACommand: IdormCommand): Int64;
  end;

  TUIBBaseTableSequence = class abstract(TdormInterfacedObject, IdormKeysGenerator)
  protected
    FPersistStrategy: IdormPersistStrategy;
    function GetSequenceFormatTemplate: string; virtual; abstract;

  public
    function NewStringKey(const Entity: string): string;
    function NewIntegerKey(const Entity: string): UInt64;
    procedure SetPersistStrategy(const PersistentStrategy: IdormPersistStrategy);
  end;

implementation

uses
  dorm.Utils;

procedure TUIBBaseAdapter.InitFormatSettings;
begin
  FFormatSettings.LongDateFormat := 'YYYY-MM-DD';
  FFormatSettings.ShortDateFormat := 'YYYY-MM-DD';
  FFormatSettings.LongTimeFormat := 'HH:NN:SS';
  FFormatSettings.ShortTimeFormat := 'HH:NN:SS';
  FFormatSettings.DateSeparator := '-';
  FFormatSettings.TimeSeparator := ':';
end;

function TUIBBaseAdapter.Update(ARttiType: TRttiType; AObject: TObject;
  AMappingTable: TMappingTable; ACurrentVersion: Int64): Int64;
var
  field: TMappingField;
  SQL: string;
  Query: TUIBStatement;
  I, pk_idx: Integer;
  v: TValue;
  sql_fields_names: string;
  pk_field: string;
begin
  sql_fields_names := '';
  for field in AMappingTable.Fields do
    if not field.IsPK then
      sql_fields_names := sql_fields_names + ',"' + field.FieldName + '" = ?';
  System.Delete(sql_fields_names, 1, 1);
  pk_field := AMappingTable.Fields[GetPKMappingIndex(AMappingTable.Fields)].FieldName;
  SQL := Format('UPDATE %S SET %S WHERE %S = ?', [AMappingTable.TableName, sql_fields_names,
    pk_field]);
  if ACurrentVersion >= 0 then // optlock
    SQL := SQL + ' AND OBJVERSION = ' + IntToStr(ACurrentVersion);
  // else
  // raise EdormLockingException.Create('Invalid ObjVersion');
  GetLogger.Debug(AMappingTable.Fields[GetPKMappingIndex(AMappingTable.Fields)].FieldName);
  GetLogger.Debug('PREPARING: ' + SQL);
  Query := FB.Prepare(SQL);
  try
    I := 0;
    for field in AMappingTable.Fields do
    begin
      v := TdormUtils.GetField(AObject, field.name);
      if field.IsPK then
        Continue
      else
      begin
        SetUIBParameterValue(field.FieldType, Query, I, v, field.Nullable);
      end;
      inc(I);
    end;
    pk_idx := GetPKMappingIndex(AMappingTable.Fields);
    v := ARttiType.GetProperty(AMappingTable.Fields[pk_idx].name).GetValue(AObject);
    FillPrimaryKeyParam(Query, I, v);
    GetLogger.Debug('EXECUTING PREPARED: ' + SQL);
    Result := FB.Execute(Query);
  finally
    Query.Free;
  end;
end;

function TUIBBaseAdapter.CanBeConsideredAsNull(const AValue: TValue): boolean;
var
  v: Extended;
  s: String;
begin
  case AValue.Kind of
    tkInteger:
      begin
        Result := AValue.AsInteger = Self.FNullKeyValue.AsInteger;
      end;
    tkInt64:
      begin
        Result := AValue.AsInt64 = Self.FNullKeyValue.AsInteger;
      end;
    tkFloat:
      begin
        v := AValue.AsExtended;
        Result := (Frac(v) = 0) and (Trunc(v) = Self.FNullKeyValue.AsInteger);
      end;
    tkString, tkUString, tkWString, tkLString, tkWChar, tkChar:
      begin
        Result := AValue.AsString = '';
      end
  else
    Result := false;
  end;
end;

procedure TUIBBaseAdapter.Commit;
begin
  FB.CommitTransaction;
end;

procedure TUIBBaseAdapter.ConfigureStrategy(ConfigurationInfo:
  ISuperObject);
var
  ctx: TRttiContext;
  t: TRttiType;
  obj: TObject;
begin
  FB := CreateUIBFacade(ConfigurationInfo);
  FKeysGeneratorClassName := ConfigurationInfo.s['keys_generator'];
  t := ctx.FindType(FKeysGeneratorClassName);
  if t = nil then
    raise EdormException.Create('Unknown key generator ' + FKeysGeneratorClassName);
  obj := t.AsInstance.MetaclassType.Create;
  if not Supports(obj, IdormKeysGenerator, FKeysGenerator) then
    raise EdormException.Create('Keys generator ' + FKeysGeneratorClassName +
      ' doesn''t implements ''IdormKeysGenerator''');
  FKeysGenerator.SetPersistStrategy(Self);
  Self._Release;
  if (SameText(ConfigurationInfo.s['key_type'], 'integer')) then
  begin
    FKeyType := ktInteger;
    FNullKeyValue := ConfigurationInfo.I['null_key_value']
  end
  else if (SameText(ConfigurationInfo.s['key_type'], 'string')) then
  begin
    FKeyType := ktString;
    FNullKeyValue := ConfigurationInfo.s['null_key_value']
  end
  else
    raise EdormException.Create('Unknown key type');
  inherited;
end;

function TUIBBaseAdapter.Count(AMappingTable: TMappingTable): Int64;
var
  cmd: TUIBQuery;
  SQL: string;
begin
  Result := -1;
  SQL := 'SELECT COUNT(*) FROM ' + AMappingTable.TableName;
  GetLogger.Debug('PREPARING: ' + SQL);
  cmd := FB.Prepare(SQL);
  try
    cmd.Open;
    if not cmd.Eof then
      Result := cmd.Fields.AsInt64[0];
  finally
    cmd.Free;
  end;
end;

function TUIBBaseAdapter.Delete(ARttiType: TRttiType;
  AObject:
  TObject;
  AMappingTable:
  TMappingTable;
  ACurrentVersion:
  Int64): Int64;
var
  pk_idx: Integer;
  pk_value: TValue;
  pk_attribute_name, pk_field_name, SQL: string;
  cmd: TUIBStatement;
  s: Cardinal;
  I: Cardinal;
  u: Cardinal;
  d: Cardinal;
begin
  pk_idx := GetPKMappingIndex(AMappingTable.Fields);
  if pk_idx = -1 then
    raise Exception.Create('Invalid primary key for table ' + AMappingTable.TableName);
  pk_attribute_name := AMappingTable.Fields[pk_idx].name;
  pk_field_name := AMappingTable.Fields[pk_idx].FieldName;
  pk_value := ARttiType.GetProperty(pk_attribute_name).GetValue(AObject);
  SQL := 'DELETE FROM ' + AMappingTable.TableName + ' WHERE ' + pk_field_name + ' = ?';
  if ACurrentVersion >= 0 then
    SQL := SQL + ' AND OBJVERSION = ' + IntToStr(ACurrentVersion);
  // else
  // raise EdormLockingException.Create('Invalid ObjVersion');
  GetLogger.Debug('PREPARING: ' + SQL);
  cmd := FB.Prepare(SQL);
  try
    FillPrimaryKeyParam(cmd, 0, pk_value);
    GetLogger.Debug('EXECUTING PREPARED: ' + SQL);
    cmd.Execute;
    cmd.AffectedRows(s, I, u, d);
    Result := d;
  finally
    cmd.Free;
  end;
end;

procedure TUIBBaseAdapter.DeleteAll(AMappingTable: TMappingTable);
var
  SQL: string;
begin
  SQL := 'DELETE FROM ' + AMappingTable.TableName;
  GetLogger.Debug('EXECUTING :' + SQL);
  FB.Execute(SQL);
end;

destructor TUIBBaseAdapter.Destroy;
begin
  FB.Free;
  FKeysGenerator := nil;
  inherited;
end;

function TUIBBaseAdapter.ExecuteAndGetFirst(SQL: string): Int64;
var
  cmd: TUIBQuery;
begin
  GetLogger.EnterLevel('ExecuteAndGetFirst');
  Result := 0;
  GetLogger.Info('PREPARING: ' + SQL);
  cmd := FB.Prepare(SQL);
  try
    GetLogger.Info('EXECUTING: ' + SQL);
    cmd.Open;
    if not cmd.Eof then
      Result := Int64(cmd.Fields.AsInt64[0])
    else
      raise EdormException.Create('ExecuteAndGetFirst returns o rows');
  finally
    GetLogger.ExitLevel('ExecuteAndGetFirst');
    cmd.Free;
  end;
end;

function TUIBBaseAdapter.ExecuteCommand(ACommand: IdormCommand): Int64;
var
  SQL: string;
  reader: TUIBQuery;
  CustomCriteria: ICustomCriteria;
  sr: Cardinal;
  ir: Cardinal;
  ur: Cardinal;
  dr: Cardinal;
begin
  SQL := ACommand.GetSQL;
  GetLogger.Debug('EXECUTING: ' + SQL);
  reader := FB.Prepare(SQL);
  try
    if reader.Params.ParamCount <> 0 then
      raise EdormException.Create('Parameters not replaced');
    reader.Execute;
    reader.AffectedRows(sr, ir, ur, dr);
    Result := ir + ur + dr;
  finally
    reader.Free;
  end;
end;

function TUIBBaseAdapter.GenerateAndFillPrimaryKeyParam(Query: TUIBStatement;
  ParamIndex:
  Integer;
  const
  Entity:
  string): TValue;
var
  Value: TValue;
begin
  case FKeyType of
    ktString:
      begin
        Value := FKeysGenerator.NewStringKey(Entity);
      end;
    ktInteger:
      begin
        Value := Int64(FKeysGenerator.NewIntegerKey(Entity));
      end;
  end;
  // Assert(Value.IsType<Int64>());
  Result := FillPrimaryKeyParam(Query, ParamIndex, Value);
  FLastInsertOID := Result;
end;

function TUIBBaseAdapter.FillPrimaryKeyParam(Query: TUIBStatement;
  ParamIndex:
  Integer;
  const
  Value:
  TValue): TValue;
begin
  try
    case FKeyType of
      ktString:
        begin
          Query.Params.AsString[ParamIndex] := Value.AsString;
          Result := Query.Params.AsString[ParamIndex];
          GetLogger.Debug('ParPK = ' + Value.AsString);
        end;
      ktInteger:
        begin
          Query.Params.AsInt64[ParamIndex] := Value.AsInteger;
          Result := Query.Params.AsInt64[ParamIndex];
          GetLogger.Debug('ParPK = ' + IntToStr(Value.AsInteger));
        end;
    end;
  except
    on E: Exception do
      raise EdormException.Create('Error during fill primary key for query. ' + E.Message);
  end;
end;

function TUIBBaseAdapter.GetDatabaseBuilder(AEntities: TList<string>;
  AMappings:
  ICacheMappingStrategy): IDataBaseBuilder;
begin
  AEntities.Free; // just to hide the memory leak
  raise Exception.Create('Not implemented for ' + Self.ClassName);
end;

function TUIBBaseAdapter.GetKeysGenerator: IdormKeysGenerator;
begin
  Result := FKeysGenerator;
end;

function TUIBBaseAdapter.GetKeyType: TdormKeyType;
begin
  Result := FKeyType;
end;

function TUIBBaseAdapter.GetLastInsertOID: TValue;
begin
  Result := FLastInsertOID;
end;

function TUIBBaseAdapter.GetLogger: IdormLogger;
begin
  Result := FLogger;
end;

procedure TUIBBaseAdapter.InitStrategy;
begin
  FLastInsertOID := TValue.Empty;
end;

function TUIBBaseAdapter.Insert(ARttiType: TRttiType;
  AObject:
  TObject;
  AMappingTable:
  TMappingTable): TValue;
var
  field: TMappingField;
  sql_fields_names, sql_fields_values, SQL: ansistring;
  Query: TUIBStatement;
  I, pk_idx: Integer;
  v, pk_value: TValue;
begin
  sql_fields_names := '';
  for field in AMappingTable.Fields do
  begin { todo: manage transients fields }
    sql_fields_names := sql_fields_names + ',"' + ansistring(field.FieldName) + '"';
  end;
  System.Delete(sql_fields_names, 1, 1);
  sql_fields_values := '';
  for I := 0 to AMappingTable.Fields.Count - 1 do
    // for field in AMappingTable.Fields do
    sql_fields_values := sql_fields_values + ',?';
  System.Delete(sql_fields_values, 1, 1);
  SQL := Format('INSERT INTO %s (%S) VALUES (%S)', [AMappingTable.TableName, sql_fields_names,
    sql_fields_values]);
  GetLogger.Debug('PREPARING :' + string(SQL));
  Query := FB.Prepare(string(SQL));
  try
    I := 0;
    for field in AMappingTable.Fields do
    begin
      // v := TdormUtils.GetField(AObject, field.name);
      v := TdormUtils.GetField(AObject, field.RTTICache);
      if field.IsPK then
        pk_value := GenerateAndFillPrimaryKeyParam(Query, I, AMappingTable.TableName)
      else
      begin
        SetUIBParameterValue(field.FieldType, Query, I, v, field.Nullable);
      end;
      inc(I);
    end;
    GetLogger.Debug('EXECUTING PREPARED :' + string(SQL));
    FB.Execute(Query);
  finally
    Query.Free;
  end;
  pk_idx := GetPKMappingIndex(AMappingTable.Fields);
  // TdormUtils.SetField(AObject, AMappingTable.Fields[pk_idx].name, pk_value);
  TdormUtils.SetField(AObject, AMappingTable.Fields[pk_idx].RTTICache, pk_value);
  Result := pk_value;
end;

function TUIBBaseAdapter.InTransaction: boolean;
var
  tr: TUIBTransaction;
begin
  tr := FB.GetCurrentTransaction;
  Result := assigned(tr);
  if Result then
    Result := tr.InTransaction
end;

function TUIBBaseAdapter.IsNullKey(
  const
  Value:
  TValue): boolean;
begin
  case FKeyType of
    ktInteger:
      Result := Value.AsInt64 = FNullKeyValue.AsInt64;
    ktString:
      Result := Value.AsString = FNullKeyValue.AsString;
  else
    raise EdormException.Create('Unknown key type');
  end;
end;

function TUIBBaseAdapter.GetNullKeyValue: TValue;
begin
  Result := FNullKeyValue;
end;

function TUIBBaseAdapter.List(ARttiType: TRttiType;
  AMappingTable:
  TMappingTable;
  ACriteria:
  ICriteria): TObjectList<TObject>;
begin
  Result := NewList();
  LoadList(Result, ARttiType, AMappingTable, ACriteria);
end;

function TUIBBaseAdapter.Load(ARttiType: TRttiType;
  ATableName:
  string;
  AMappingTable:
  TMappingTable;
  const
  Value:
  TValue): TObject;
var
  pk_idx: Integer;
  pk_attribute_name, pk_field_name, SQL: string;
  cmd: TUIBQuery;
begin
  Result := nil;
  pk_idx := GetPKMappingIndex(AMappingTable.Fields);
  if pk_idx = -1 then
    raise Exception.Create('Invalid primary key for table ' + ATableName);
  pk_attribute_name := AMappingTable.Fields[pk_idx].name;
  pk_field_name := AMappingTable.Fields[pk_idx].FieldName;
  SQL := 'SELECT ' + GetSelectFieldsList(AMappingTable.Fields, true) + ' FROM ' + ATableName +
    ' WHERE ' + pk_field_name + ' = ?';
  GetLogger.Debug('PREPARING: ' + SQL);
  cmd := FB.Prepare(SQL);
  try
    FillPrimaryKeyParam(cmd, pk_idx, Value);
    GetLogger.Debug('EXECUTING PREPARED: ' + SQL);
    cmd.Open;
    if not cmd.Eof then
      Result := CreateObjectFromUIBQuery(ARttiType, cmd, AMappingTable);
  finally
    cmd.Free;
  end;
end;

function TUIBBaseAdapter.GetUIBReaderFor(ARttiType: TRttiType;
  AMappingTable:
  TMappingTable;
  const
  Value:
  TValue;
  AMappingRelationField:
  TMappingField): TUIBQuery;
var
  pk_idx: Integer;
  pk_field_name, SQL: string;
begin
  if AMappingRelationField = nil then
  begin
    pk_idx := GetPKMappingIndex(AMappingTable.Fields);
    if pk_idx = -1 then
      raise Exception.Create('Invalid primary key for table ' + AMappingTable.TableName);
    pk_field_name := AMappingTable.Fields[pk_idx].FieldName;
    SQL := 'SELECT ' + GetSelectFieldsList(AMappingTable.Fields, true) + ' FROM ' +
      AMappingTable.TableName + ' WHERE ' + pk_field_name + ' = :' + pk_field_name;
  end
  else
  begin
    pk_idx := GetPKMappingIndex(AMappingTable.Fields);
    if pk_idx = -1 then
      raise Exception.Create('Invalid primary key for table ' + AMappingTable.TableName);
    pk_field_name := AMappingTable.Fields[pk_idx].FieldName;
    SQL := 'SELECT ' + GetSelectFieldsList(AMappingTable.Fields, true) + ' FROM ' +
      AMappingTable.TableName + ' WHERE ' + AMappingRelationField.FieldName + ' = :' +
      pk_field_name;
  end;
  GetLogger.Debug('PREPARING: ' + SQL);
  Result := FB.Prepare(SQL);
  FillPrimaryKeyParam(Result, 0, Value);
end;

function TUIBBaseAdapter.Load(ARttiType: TRttiType;
  AMappingTable:
  TMappingTable;
  AMappingRelationField:
  TMappingField;
  const
  Value:
  TValue;
  AObject:
  TObject): boolean;
var
  reader: TUIBQuery;
begin
  reader := GetUIBReaderFor(ARttiType, AMappingTable, Value, AMappingRelationField);
  try
    reader.Open();
    Result := not reader.Eof;
    if Result then
      LoadObjectFromDBXReader(AObject, ARttiType, reader, AMappingTable.Fields);
    reader.Next;
    if not reader.Eof then
      // there is some problem.... here I should have only one record
      raise EdormException.Create('Singleton select returns more than 1 record');
  finally
    reader.Free;
  end;
end;

procedure TUIBBaseAdapter.LoadList(AList: TObject;
  ARttiType:
  TRttiType;
  AMappingTable:
  TMappingTable;
  ACriteria:
  ICriteria);
var
  SQL: string;
  reader: TUIBQuery;
  CustomCriteria: ICustomCriteria;
begin
  if assigned(ACriteria) and TInterfacedObject(ACriteria).GetInterface(ICustomCriteria,
    CustomCriteria) then
    SQL := CustomCriteria.GetSQL
  else
    SQL := Self.GetSelectSQL(ACriteria, AMappingTable);
  GetLogger.Debug('EXECUTING: ' + SQL);
  reader := FB.Prepare(SQL);
  if reader.Params.ParamCount <> 0 then
    raise EdormException.Create('Parameters not replaced');
  reader.Open();
  try
    while not reader.Eof do
    begin
      TdormUtils.MethodCall(AList, 'Add', [CreateObjectFromUIBQuery(ARttiType, reader,
        AMappingTable)]);
      reader.Next;
    end;
  finally
    reader.Free;
  end;
end;

procedure TUIBBaseAdapter.LoadObjectFromDBXReader(AObject: TObject;
  ARttiType:
  TRttiType;
  AReader:
  TUIBQuery;
  AFieldsMapping:
  TMappingFieldList);
var
  field: TMappingField;
  v: TValue;
  s: string;
  sourceStream: TStream;
  PropTypeInfo: PTypeInfo;
begin
  try
    for field in AFieldsMapping do
    begin
      if CompareText(field.FieldType, 'string') = 0 then
      begin
        v := AReader.Fields.ByNameAsString[field.FieldName];
        s := field.FieldName + ' as string';
      end
      else if CompareText(field.FieldType, 'integer') = 0 then
      begin
        if (Field.RTTICache.RTTIProp <> nil) and
           (Field.RTTICache.RTTIProp.PropertyType.TypeKind = tkEnumeration) then
        begin
          PropTypeInfo := Field.RTTICache.RTTIProp.PropertyType.Handle;
          v := TValue.FromOrdinal(PropTypeInfo,
            AReader.Fields.ByNameAsInteger[field.FieldName]);
        end
        else
          v := AReader.Fields.ByNameAsInteger[field.FieldName];
        s := field.FieldName + ' as integer';
      end
      else if CompareText(field.FieldType, 'date') = 0 then
      begin
        v := AReader.Fields.ByNameAsDateTime[field.FieldName];
        s := field.FieldName + ' as date';
      end
      else if CompareText(field.FieldType, 'blob') = 0 then
      begin
        // targetStream := nil;
        s := field.FieldName + ' as blob';
        sourceStream := nil;
        if not AReader.Fields.ByNameIsNull[field.FieldName] then
        begin
          sourceStream := TMemoryStream.Create;
          AReader.ReadBlob(AReader.Fields.GetFieldIndex(field.FieldName), sourceStream);
        end;
        if assigned(sourceStream) then
        begin
          sourceStream.Position := 0;
          v := sourceStream;
        end
        else
          v := nil;
      end
      else if CompareText(field.FieldType, 'decimal') = 0 then
      begin
        v := AReader.Fields.ByNameAsDouble[field.FieldName];
        s := field.FieldName + ' as decimal';
      end
      else if CompareText(field.FieldType, 'boolean') = 0 then
      begin
        v := AReader.Fields.ByNameAsInteger[field.FieldName];
        v := v.AsInteger = 1;
        s := field.FieldName + ' as boolean';
      end
      else if CompareText(field.FieldType, 'datetime') = 0 then
      begin
        v := AReader.Fields.ByNameAsDateTime[field.FieldName];
        s := field.FieldName + ' as datetime';
      end
      else if CompareText(field.FieldType, 'time') = 0 then
      begin
        v := AReader.Fields.ByNameAsDateTime[field.FieldName];
        s := field.FieldName + ' as time';
      end
      else
        raise Exception.Create('Unknown field type for ' + field.FieldName);
      try
        TdormUtils.SetField(AObject, field.name, v);
      except
        on E: Exception do
        begin
          raise EdormException.Create(E.Message + sLineBreak + '. Probably cannot write ' +
            ARttiType.ToString + '.' + s);
        end;
      end;
    end;
  except
    on E: Exception do
    begin
      raise;
    end;
  end;
end;

function TUIBBaseAdapter.RawExecute(SQL: string): Int64;
begin
  GetLogger.Warning('RAW EXECUTE: ' + SQL);
  Result := FB.Execute(SQL);
end;

function TUIBBaseAdapter.CreateObjectFromUIBQuery(ARttiType: TRttiType;
  AReader:
  TUIBQuery;
  AMappingTable:
  TMappingTable): TObject;
var
  obj: TObject;
  field: TMappingField;
  v: TValue;
  s: string;
  targetStream: TMemoryStream;
  PropTypeInfo: PTypeInfo;
begin
  try
    obj := TdormUtils.CreateObject(ARttiType);
    for field in AMappingTable.Fields do
    begin
      if CompareText(field.FieldType, 'string') = 0 then
      begin
        v := AReader.Fields.ByNameAsString[field.FieldName];
        s := field.FieldName + ' as string';
      end
      else if CompareText(field.FieldType, 'integer') = 0 then
      begin
        if (Field.RTTICache.RTTIProp <> nil) and
           (Field.RTTICache.RTTIProp.PropertyType.TypeKind = tkEnumeration) then
        begin
          PropTypeInfo := Field.RTTICache.RTTIProp.PropertyType.Handle;
          v := TValue.FromOrdinal(PropTypeInfo,
            AReader.Fields.ByNameAsInteger[field.FieldName]);
        end
        else
          v := AReader.Fields.ByNameAsInteger[field.FieldName];
        s := field.FieldName + ' as integer';
      end
      else if CompareText(field.FieldType, 'date') = 0 then
      begin
        v := Trunc(AReader.Fields.ByNameAsDateTime[field.FieldName]);
        s := field.FieldName + ' as date';
      end
      else if CompareText(field.FieldType, 'blob') = 0 then
      begin
        targetStream := nil;
        if not AReader.Fields.ByNameIsNull[field.FieldName] then
        begin
          targetStream := TMemoryStream.Create;
          AReader.Fields.ReadBlob(field.FieldName, targetStream);
          targetStream.Position := 0;
        end;
        s := field.FieldName + ' as blob';
        v := targetStream;
      end
      else if CompareText(field.FieldType, 'decimal') = 0 then
      begin
        v := AReader.Fields.ByNameAsDouble[field.FieldName];
        s := field.FieldName + ' as decimal';
      end
      else if CompareText(field.FieldType, 'boolean') = 0 then
      begin
        v := AReader.Fields.ByNameAsBoolean[field.FieldName];
        s := field.FieldName + ' as boolean';
      end
      else if CompareText(field.FieldType, 'datetime') = 0 then
      begin
        v := AReader.Fields.ByNameAsDateTime[field.FieldName];
        s := field.FieldName + ' as datetime';
      end
      else if CompareText(field.FieldType, 'time') = 0 then
      begin
        v := AReader.Fields.ByNameAsDateTime[field.FieldName];
        s := field.FieldName + ' as datetime';
      end
      else
        raise Exception.Create('Unknown field type for ' + field.FieldName);
      try
        TdormUtils.SetField(obj, field.name, v);
      except
        on E: Exception do
        begin
          raise EdormException.Create(E.Message + sLineBreak + '. Probably cannot write ' +
            ARttiType.ToString + '.' + s);
        end;
      end;
    end;
  except
    on E: Exception do
    begin
      raise;
    end;
  end;
  Result := obj;
end;

class
  procedure TUIBBaseAdapter.register;
begin
  //
end;

procedure TUIBBaseAdapter.Rollback;
begin
  FB.GetCurrentTransaction.Rollback;
end;

procedure TUIBBaseAdapter.SetUIBParameterValue(AFieldType: string;
  AStatement:
  TUIBStatement;
  ParameterIndex:
  Integer;
  AValue:
  TValue; IsNullable: boolean);
var
  sourceStream: TStream;
  str: TBytesStream;
begin
  if CompareText(AFieldType, 'string') = 0 then
  begin
    if IsNullable and CanBeConsideredAsNull(AValue) then
      AStatement.Params.IsNull[ParameterIndex] := true
    else
      AStatement.Params.AsString[ParameterIndex] := AValue.AsString;
    GetLogger.Debug('Par' + IntToStr(ParameterIndex) + ' = ' + AValue.AsString);
  end
  else if CompareText(AFieldType, 'decimal') = 0 then
  begin
    if IsNullable and CanBeConsideredAsNull(AValue) then
      AStatement.Params.IsNull[ParameterIndex] := true
    else
      AStatement.Params.AsDouble[ParameterIndex] := AValue.AsExtended;
    GetLogger.Debug('Par' + IntToStr(ParameterIndex) + ' = ' + FloatToStr(AValue.AsExtended));
  end
  else if CompareText(AFieldType, 'integer') = 0 then
  begin
    if aValue.Kind = tkEnumeration then
    begin
      AStatement.Params.AsInteger[ParameterIndex] := AValue.AsOrdinal;
      GetLogger.Debug('Par' + IntToStr(ParameterIndex) + ' = ' + IntToStr(AValue.AsOrdinal));
    end
    else
    begin
      if IsNullable and CanBeConsideredAsNull(AValue) then
        AStatement.Params.IsNull[ParameterIndex] := true
      else
        AStatement.Params.AsInteger[ParameterIndex] := AValue.AsInteger;
      GetLogger.Debug('Par' + IntToStr(ParameterIndex) + ' = ' + IntToStr(AValue.AsInt64));
    end;
  end
  else if CompareText(AFieldType, 'boolean') = 0 then
  begin
    AStatement.Params.AsBoolean[ParameterIndex] := AValue.AsBoolean;
    GetLogger.Debug('Par' + IntToStr(ParameterIndex) + ' = ' + BoolToStr(AValue.AsBoolean, true));
  end
  else if CompareText(AFieldType, 'date') = 0 then
  begin
    if IsNullable and CanBeConsideredAsNull(AValue) then
      AStatement.Params.IsNull[ParameterIndex] := true
    else
      AStatement.Params.AsDate[ParameterIndex] := Trunc(AValue.AsExtended);
    GetLogger.Debug('Par' + IntToStr(ParameterIndex) + ' = ' +
      EscapeDate(Trunc(AValue.AsExtended)));
  end
  else if CompareText(AFieldType, 'datetime') = 0 then
  begin
    if IsNullable and CanBeConsideredAsNull(AValue) then
      AStatement.Params.IsNull[ParameterIndex] := true
    else
      AStatement.Params.AsDateTime[ParameterIndex] := AValue.AsExtended;
    GetLogger.Debug('Par' + IntToStr(ParameterIndex) + ' = ' + EscapeDate(AValue.AsExtended));
  end
  else if CompareText(AFieldType, 'time') = 0 then
  begin
    if IsNullable and CanBeConsideredAsNull(AValue) then
      AStatement.Params.IsNull[ParameterIndex] := true
    else
      AStatement.Params.AsDateTime[ParameterIndex] := AValue.AsExtended;
    GetLogger.Debug('Par' + IntToStr(ParameterIndex) + ' = ' + EscapeDateTime(AValue.AsExtended));
  end
  else if CompareText(AFieldType, 'blob') = 0 then
  begin
    sourceStream := TStream(AValue.AsObject);
    if sourceStream = nil then
    begin
      AStatement.Params.IsNull[ParameterIndex] := true;
      GetLogger.Debug('Par' + IntToStr(ParameterIndex) + ' = nil');
    end
    else
    begin
      str := TBytesStream.Create;
      try
        sourceStream.Position := 0;
        str.CopyFrom(sourceStream, 0);
        str.Position := 0;
        AStatement.ParamsSetBlob(ParameterIndex, str);
        GetLogger.Debug('Par' + IntToStr(ParameterIndex) + ' = <blob ' + IntToStr(str.Size) +
          ' bytes>');
      finally
        str.Free;
      end;
    end;
  end
  else
    raise EdormException.CreateFmt('Parameter type not supported: [%s]', [AFieldType]);
end;

procedure TUIBBaseAdapter.SetLogger(ALogger: IdormLogger);
begin
  FLogger := ALogger;
end;

procedure TUIBBaseAdapter.StartTransaction;
begin
  FB.GetConnection; // ensure database connected
  FB.StartTransaction;
end;
{ TFirebirdUIBBaseTableSequence }

function TUIBBaseTableSequence.NewIntegerKey(
  const
  Entity:
  string): UInt64;
var
  SequenceName: string;
begin
  SequenceName := Format(GetSequenceFormatTemplate, [Entity]);
  Result := FPersistStrategy.ExecuteAndGetFirst('SELECT GEN_ID(' + SequenceName +
    ',1) FROM RDB$DATABASE');
end;

function TUIBBaseTableSequence.NewStringKey(
  const
  Entity:
  string): string;
begin
  raise EdormException.Create('String keys not supported');
end;

procedure TUIBBaseTableSequence.SetPersistStrategy(
  const
  PersistentStrategy
  :
  IdormPersistStrategy);
begin
  FPersistStrategy := PersistentStrategy;
end;

function TUIBBaseAdapter.Load(ARttiType: TRttiType;
  AMappingTable:
  TMappingTable;
  const
  Value:
  TValue;
  AObject:
  TObject): boolean;
var
  reader: TUIBQuery;
begin
  reader := GetUIBReaderFor(ARttiType, AMappingTable, Value);
  try
    reader.Open();
    Result := not reader.Eof;
    if Result then
      LoadObjectFromDBXReader(AObject, ARttiType, reader, AMappingTable.Fields);
  finally
    reader.Free;
  end;
end;

end.
