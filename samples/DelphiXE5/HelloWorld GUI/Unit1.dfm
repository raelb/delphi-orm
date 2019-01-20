object Form1: TForm1
  Left = 0
  Top = 0
  BorderWidth = 8
  Caption = 'Form1'
  ClientHeight = 433
  ClientWidth = 707
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  PixelsPerInch = 115
  TextHeight = 16
  object Memo1: TMemo
    Left = 0
    Top = 0
    Width = 707
    Height = 233
    Align = alTop
    Lines.Strings = (
      '{'
      '  "persistence": {'
      '  '#9'"development": {        '
      
        #9'    "database_adapter": "dorm.adapter.Sqlite3.TSqlite3PersistSt' +
        'rategy",'
      #9'    "database_connection_string":"dorm_hw.db3",'
      #9'    "key_type":"integer", '
      #9'    "null_key_value": 0}'
      '    },'
      '  "config": {'
      
        '    "logger_class_name": "dorm.loggers.TraceTool.TdormTraceToolL' +
        'og"'
      '  }'
      '}')
    TabOrder = 0
  end
end
