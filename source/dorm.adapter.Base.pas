unit dorm.adapter.Base;

interface

uses
  dorm.Commons,
  dorm.Filters,
  dorm.Mappings;

type
  TBaseAdapter = class abstract(TdormInterfacedObject)
  protected
    function GetWhereSQL(ACriteria: ICriteria; AMappingTable: TMappingTable)
      : string; overload;
    function GetWhereSQL(ACriteriaItem: ICriteriaItem;
      AMappingTable: TMappingTable): string; overload;
    // function GetFieldMappingByAttribute(AttributeName: string;
    // AMappingTable: TMappingTable): TMappingField;
    function EscapeString(const Value: string): string; virtual;
    function EscapeDate(const Value: TDate): string; virtual;
    function EscapeDateTime(const Value: TDate): string; virtual;
    function EscapeTime(const Value: TTime): string; virtual;
    //
    function GetBooleanValueAsString(Value: Boolean): string; virtual;

    // iso related functions
    class function ISODateTimeToString(ADateTime: TDateTime): string;
    class function ISODateToString(ADate: TDateTime): string;
    class function ISOTimeToString(ATime: TTime): string;

    class function ISOStrToDateTime(DateTimeAsString: string): TDateTime;
    class function ISOStrToDate(DateAsString: string): TDate;
    class function ISOStrToTime(TimeAsString: string): TTime;

  public
    function GetSelectSQL(Criteria: ICriteria; AMappingTable: TMappingTable)
      : string; overload; virtual;
    function GetSelectSQL(Criteria: ICustomCriteria): string; overload;
    function GetCountSQL(ACriteria: ICriteria;
      AMappingTable: TMappingTable): string;
    function GetRawDatabaseObj: TObject; virtual;
  end;

implementation

uses
  SysUtils,
  System.DateUtils;

{ TBaseAdapter }

class function TBaseAdapter.ISOTimeToString(ATime: TTime): string;
var
  fs: TFormatSettings;
begin
  fs.TimeSeparator := ':';
  Result := FormatDateTime('hh:nn:ss', ATime, fs);
end;

class function TBaseAdapter.ISODateToString(ADate: TDateTime): string;
begin
  Result := FormatDateTime('YYYY-MM-DD', ADate);
end;

class function TBaseAdapter.ISODateTimeToString(ADateTime: TDateTime): string;
var
  fs: TFormatSettings;
begin
  fs.TimeSeparator := ':';
  Result := FormatDateTime('yyyy-mm-dd hh:nn:ss', ADateTime, fs);
end;

class function TBaseAdapter.ISOStrToDateTime(DateTimeAsString: string): TDateTime;
begin
  Result := EncodeDateTime(StrToInt(Copy(DateTimeAsString, 1, 4)),
    StrToInt(Copy(DateTimeAsString, 6, 2)),
    StrToInt(Copy(DateTimeAsString, 9, 2)),
    StrToInt(Copy(DateTimeAsString, 12, 2)),
    StrToInt(Copy(DateTimeAsString, 15, 2)),
    StrToInt(Copy(DateTimeAsString, 18, 2)), 0);
end;

class function TBaseAdapter.ISOStrToTime(TimeAsString: string): TTime;
begin
  Result := EncodeTime(StrToInt(Copy(TimeAsString, 1, 2)),
    StrToInt(Copy(TimeAsString, 4, 2)), StrToInt(Copy(TimeAsString, 7, 2)), 0);
end;

class function TBaseAdapter.ISOStrToDate(DateAsString: string): TDate;
begin
  Result := EncodeDate(StrToInt(Copy(DateAsString, 1, 4)),
    StrToInt(Copy(DateAsString, 6, 2)), StrToInt(Copy(DateAsString, 9, 2)));
end;

function TBaseAdapter.GetWhereSQL(ACriteria: ICriteria;
  AMappingTable: TMappingTable): string;
var
  I: Integer;
  SQL: string;
  CritItem: ICriteriaItem;
  Crit: ICriteria;
begin
  if ACriteria.Count > 0 then
    for I := 0 to ACriteria.Count - 1 do
    begin
      CritItem := ACriteria.GetCriteria(I);
      if I > 0 then
        case CritItem.GetLogicRelation of
          lrAnd:
            SQL := SQL + ' AND ';
          lrOr:
            SQL := SQL + ' OR ';
        end;
      if TInterfacedObject(CritItem).GetInterface(ICriteria, Crit) then
      begin
        if Crit.Count > 0 then
          SQL := SQL + ' (' + GetWhereSQL(Crit, AMappingTable) + ') '
        else
          SQL := SQL + GetWhereSQL(CritItem, AMappingTable);
      end
      else
        SQL := SQL + GetWhereSQL(CritItem, AMappingTable);
    end
  else
  begin
    if ACriteria.GetAttribute = '' then
      SQL := ''
    else
    begin
      CritItem := TdormCriteriaItem.Create(ACriteria.GetAttribute,
        ACriteria.GetCompareOperator, ACriteria.GetValue);
      SQL := GetWhereSQL(CritItem, AMappingTable);
    end;
  end;
  Result := SQL;
end;

function TBaseAdapter.GetSelectSQL(Criteria: ICriteria;
  AMappingTable: TMappingTable): string;
var
  SQL: string;
  _fields: TMappingFieldList;
  select_fields: string;
  WhereSQL: string;
begin
  _fields := AMappingTable.Fields;
  select_fields := GetSelectFieldsList(_fields, true);
  if Assigned(Criteria) then
  begin
    SQL := 'SELECT ' + select_fields + ' FROM ' + AMappingTable.TableName;
    WhereSQL := GetWhereSQL(Criteria, AMappingTable);
    if WhereSQL <> EmptyStr then
      SQL := SQL + ' WHERE ' + WhereSQL;
  end
  else // Criteria is nil or is empty
    SQL := 'SELECT ' + select_fields + ' FROM ' + AMappingTable.TableName + ' ';
  Result := SQL;
end;

function TBaseAdapter.GetBooleanValueAsString(Value: Boolean): string;
begin
  Result := BoolToStr(Value, true);
end;

function TBaseAdapter.GetCountSQL(ACriteria: ICriteria;
  AMappingTable: TMappingTable): string;
var
  SQL: string;
  // _fields: TMappingFieldList;
  // select_fields: string;
  WhereSQL: string;
begin
  Assert(ACriteria <> nil);
  SQL := 'SELECT COUNT(*) FROM ' + AMappingTable.TableName;
  WhereSQL := GetWhereSQL(ACriteria, AMappingTable);
  if WhereSQL <> EmptyStr then
    SQL := SQL + ' WHERE ' + WhereSQL;
  Result := SQL;
end;

function TBaseAdapter.GetRawDatabaseObj: TObject;
begin
  Result := nil;
end;

function TBaseAdapter.GetSelectSQL(Criteria: ICustomCriteria): string;
begin
  Result := Criteria.GetSQL;
end;

function TBaseAdapter.GetWhereSQL(ACriteriaItem: ICriteriaItem;
  AMappingTable: TMappingTable): string;
var
  SQL: string;
  fm: TMappingField;
  d: TDate;
  dt: TDateTime;
begin
  fm := AMappingTable.FindByName(ACriteriaItem.GetAttribute);
  if not Assigned(fm) then
    raise EdormException.CreateFmt('Unknown field attribute "%s"."%s"',
      [AMappingTable.TableName, ACriteriaItem.GetAttribute]);
  SQL := fm.FieldName;
  case ACriteriaItem.GetCompareOperator of
    coEqual:
      SQL := SQL + ' = ';
    coGreaterThan:
      SQL := SQL + ' > ';
    coLowerThan:
      SQL := SQL + ' < ';
    coGreaterOrEqual:
      SQL := SQL + ' >= ';
    coLowerOrEqual:
      SQL := SQL + ' <= ';
    coNotEqual:
      SQL := SQL + ' != ';
    coLike:
      SQL := SQL + ' LIKE ';
    coIsNull:
      SQL := SQL + ' IS NULL';
    coIsNotNull:
      SQL := SQL + ' IS NOT NULL';
    coIN:
      SQL := SQL + ' IN (';

  end;

  if Not(ACriteriaItem.GetCompareOperator in [coIsNull, coIsNotNull, coIN]) then
  begin
    if fm.FieldType = 'string' then
      SQL := SQL + '''' + EscapeString(ACriteriaItem.GetValue.AsString) + ''''
    else if fm.FieldType = 'uniqueidentifier' then
      SQL := SQL + '''' + EscapeString(ACriteriaItem.GetValue.AsString) + ''''
    else if fm.FieldType = 'integer' then
      SQL := SQL + inttostr(ACriteriaItem.GetValue.AsInteger)
    else if fm.FieldType = 'boolean' then
      SQL := SQL + GetBooleanValueAsString(ACriteriaItem.GetValue.AsBoolean)
    else if fm.FieldType = 'float' then
      SQL := SQL + FloatToStr(ACriteriaItem.GetValue.AsExtended)
    else if fm.FieldType = 'date' then
    begin
      d := ACriteriaItem.GetValue.AsExtended;
      SQL := SQL + '''' + EscapeDate(d) + ''''
    end
    else if (fm.FieldType = 'timestamp') or (fm.FieldType = 'datetime') then
    begin
      dt := ACriteriaItem.GetValue.AsExtended;
      SQL := SQL + '''' + EscapeDateTime(dt) + ''''
    end
    else
      raise EdormException.CreateFmt('Unknown type %s in criteria',
        [fm.FieldType]);
  end else if ACriteriaItem.GetCompareOperator = coIN then begin
    SQL := SQL + EscapeString(ACriteriaItem.GetValue.AsString);
    SQL := SQL + ')';
  end;

  Result := SQL;
end;

function TBaseAdapter.EscapeDate(const Value: TDate): string;
begin
  Result := FormatDateTime('YYYY-MM-DD', Value);
end;

function TBaseAdapter.EscapeDateTime(const Value: TDate): string;
begin
  Result := FormatDateTime('YYYY-MM-DD HH:NN:SS', Value);
end;

function TBaseAdapter.EscapeString(const Value: string): string;
begin
  Result := StringReplace(Value, '''', '''''', [rfReplaceAll]);
end;

function TBaseAdapter.EscapeTime(const Value: TTime): string;
begin
  Result := FormatDateTime('HH:NN:SS', Value);
end;

end.
