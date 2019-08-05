unit dorm.adapter.Sqlite3.utils;

interface

uses
  dorm;

{ Requirements:
  dorm.loggers.Tracetool unit must be included in uses clause }

function CreateSQLiteSession(FileName: string; Escaped: Boolean = False):
    TSession;

implementation

uses
  System.Classes, dorm.Commons, System.SysUtils;

function CreateSQLiteSession(FileName: string; Escaped: Boolean = False):
    TSession;
var
  S: string;
begin
  if not Escaped then
    FileName := StringReplace(FileName, '\', '\\', [rfReplaceAll]);

  S :=
    '{ ' +
    '  "persistence": { ' +
    '  	"development": { ' +
    '	    "database_adapter": "dorm.adapter.Sqlite3.TSqlite3PersistStrategy", ' +
    '	    "database_connection_string":"' + FileName + '", ' +
    '	    "key_type":"integer", ' +
    '	    "null_key_value": 0} ' +
    '    }, ' +
    '  "config": { ' +
    '    "logger_class_name": "dorm.loggers.TraceTool.TdormTraceToolLog" ' +
    '  } ' +
    '}';

  Result := TSession.CreateConfigured(
    TStringReader.Create(S), TdormEnvironment.deDevelopment);
end;

end.