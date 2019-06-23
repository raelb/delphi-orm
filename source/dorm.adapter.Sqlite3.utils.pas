unit dorm.adapter.Sqlite3.utils;

interface

uses
  dorm;

{ Requirements:
  1. FileName must use double backslashes
  2. dorm.loggers.Tracetool unit must be included in uses clause }

function CreateSQLiteSession(const FileName: string): TSession;

implementation

uses
  System.Classes, dorm.Commons;

function CreateSQLiteSession(const FileName: string): TSession;
var
  S: string;
begin
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