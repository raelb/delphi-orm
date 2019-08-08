program TODOManager;

uses
  Vcl.Forms,
  EditTodoForm in 'EditTodoForm.pas' {frmEditTodo},
  bo in 'bo.pas',
  MainForm in 'MainForm.pas' {frmMain},
  DORMModule in 'DORMModule.pas' {MainDORM: TDataModule},
  PresentationLogicU in 'PresentationLogicU.pas',
  Vcl.Themes,
  Vcl.Styles;

{$R *.res}


begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  TStyleManager.TrySetStyle('Light');
  Application.CreateForm(TMainDORM, MainDORM);
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;

end.
