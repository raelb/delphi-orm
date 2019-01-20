{ *******************************************************************************
  Copyright 2010-2016 Daniele Teti

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
  ******************************************************************************** }

unit dorm.loggers.TraceTool;

interface

uses
  dorm.Commons,
  TraceTool,
  Classes;

type
  TdormTraceToolLog = class abstract(TdormInterfacedObject, IdormLogger)
  protected
  public
    class procedure register;
    destructor Destroy; override;
    procedure EnterLevel(const Value: string);
    procedure ExitLevel(const Value: string);
    procedure Error(const Value: string);
    procedure Warning(const Value: string);
    procedure Info(const Value: string);
    procedure Debug(const Value: string);
    procedure AfterConstruction; override;
  end;


resourcestring
   SISessionName = 'dorm';


implementation


{ TdormTraceToolLog }

procedure TdormTraceToolLog.AfterConstruction;
begin
  inherited;
  Info(ClassName + ' Logger is starting up');
end;

procedure TdormTraceToolLog.Debug(const Value: string);
begin
  TTrace.Debug.Send(Value);
end;

destructor TdormTraceToolLog.Destroy;
begin
  Info(ClassName + ' Logger is shutting down');
  inherited;
end;

procedure TdormTraceToolLog.EnterLevel(const Value: string);
begin
  TTrace.Debug.EnterMethod(value);
end;

procedure TdormTraceToolLog.Error(const Value: string);
begin
  TTrace.Error.Send(Value);
end;

procedure TdormTraceToolLog.ExitLevel(const Value: string);
begin
  TTrace.Debug.ExitMethod(Value);
end;

procedure TdormTraceToolLog.Info(const Value: string);
begin
  TTrace.Debug.Send(Value);
end;

class procedure TdormTraceToolLog.register;
begin
  //
end;

procedure TdormTraceToolLog.Warning(const Value: string);
begin
  TTrace.Warning.Send(Value);
end;


initialization
  TdormTraceToolLog.register;

end.
