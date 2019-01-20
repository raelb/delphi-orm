unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, dorm.loggers.TraceTool, Vcl.StdCtrls;

type
  TForm1 = class(TForm)
    Memo1: TMemo;
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

uses
  dorm,
  dorm.commons,
  dorm.loggers,
  BObjectsU,
  RandomUtilsU, PathU;

procedure SimpleInsert;
var
  dormSession: TSession;
  Customer: TCustomer;
begin
  dormSession := TSession.CreateConfigured(
    TStringReader.Create(Form1.Memo1.Lines.Text), TdormEnvironment.deDevelopment);
  try
    Customer := TCustomer.Create;
    Customer.Name := 'Daniele Teti Inc.';
    Customer.Address := 'Via Roma, 16';
    Customer.EMail := 'daniele@danieleteti.it';
    Customer.CreatedAt := Now;
    dormSession.Insert(Customer);
    Customer.Free;
  finally
    dormSession.Free;
  end;
end;

procedure SimpleCRUD;
var
  dormSession: TSession;
  Customer: TCustomer;
  id: Integer;
begin
  dormSession := TSession.CreateConfigured(
    TStringReader.Create(Form1.Memo1.Lines.Text), TdormEnvironment.deDevelopment);
  try
    Customer := TCustomer.Create;
    Customer.Name := 'Daniele Teti Inc.';
    Customer.Address := 'Via Roma, 16';
    Customer.EMail := 'daniele@danieleteti.it';
    Customer.CreatedAt := date;
    dormSession.Insert(Customer);
    id := Customer.id;
    Customer.Free;

    // update data
    Customer := dormSession.Load<TCustomer>(id);
    Customer.Address := 'Piazza Roma,1';
    dormSession.Update(Customer);
    Customer.Free;

    // delete data
    Customer := dormSession.Load<TCustomer>(id);
    dormSession.Delete(Customer);
    Customer.Free;

  finally
    dormSession.Free;
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  SimpleInsert;
  SimpleCRUD;
  ShowMessage('Done');
end;

end.
