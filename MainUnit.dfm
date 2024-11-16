object MainForm: TMainForm
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu, biMinimize]
  Caption = 'MP4 Meta Data Remover'
  ClientHeight = 222
  ClientWidth = 555
  Color = clBtnFace
  Constraints.MinHeight = 260
  Constraints.MinWidth = 500
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnShow = FormShow
  DesignSize = (
    555
    222)
  TextHeight = 15
  object lblFolderText: TLabel
    Left = 13
    Top = 53
    Width = 36
    Height = 15
    Caption = 'Folder:'
  end
  object lblSelectedFolder: TLabel
    Left = 66
    Top = 53
    Width = 438
    Height = 15
    Anchors = [akLeft, akTop, akRight]
    AutoSize = False
    Caption = 'lblSelectedFolder'
    EllipsisPosition = epPathEllipsis
    ExplicitWidth = 400
  end
  object lblFileCount: TLabel
    Left = 76
    Top = 81
    Width = 64
    Height = 15
    Caption = 'lblFileCount'
  end
  object lblFileCountText: TLabel
    Left = 13
    Top = 81
    Width = 55
    Height = 15
    Caption = 'File count:'
  end
  object lblProgress: TLabel
    Left = 13
    Top = 110
    Width = 58
    Height = 15
    Caption = 'lblProgress'
  end
  object lblFilesText: TLabel
    Left = 13
    Top = 22
    Width = 34
    Height = 15
    Caption = 'File(s):'
  end
  object lblSelectedFiles: TLabel
    Left = 66
    Top = 22
    Width = 438
    Height = 15
    Anchors = [akLeft, akTop, akRight]
    AutoSize = False
    Caption = 'lblSelectedFiles'
    ExplicitWidth = 400
  end
  object lblOutputFolder: TLabel
    Left = 200
    Top = 193
    Width = 206
    Height = 15
    Anchors = [akLeft, akRight, akBottom]
    AutoSize = False
    Caption = 'lblOutputFolder'
    EllipsisPosition = epPathEllipsis
    ExplicitWidth = 217
  end
  object btnSelectFolder: TButton
    Left = 522
    Top = 49
    Width = 25
    Height = 25
    Anchors = [akTop, akRight]
    Caption = '...'
    TabOrder = 1
    OnClick = btnSelectFolderClick
    ExplicitLeft = 518
  end
  object btnStart: TButton
    Left = 452
    Top = 189
    Width = 95
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = '&Start'
    TabOrder = 7
    OnClick = btnStartClick
    ExplicitLeft = 448
    ExplicitTop = 188
  end
  object cbSetFileDate: TCheckBox
    Left = 13
    Top = 168
    Width = 140
    Height = 17
    Anchors = [akLeft, akBottom]
    Caption = 'Set file name date'
    TabOrder = 3
    OnClick = cbSetFileDateClick
    ExplicitTop = 167
  end
  object dtpFileDate: TDateTimePicker
    Left = 13
    Top = 191
    Width = 140
    Height = 23
    Anchors = [akLeft, akBottom]
    Date = 45428.000000000000000000
    Time = 0.885134097225091000
    Kind = dtkDateTime
    TabOrder = 6
    ExplicitTop = 190
  end
  object pbProgress: TProgressBar
    Left = 13
    Top = 131
    Width = 534
    Height = 17
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 2
    ExplicitWidth = 530
  end
  object btnSelectFiles: TButton
    Left = 522
    Top = 18
    Width = 25
    Height = 25
    Anchors = [akTop, akRight]
    Caption = '...'
    TabOrder = 0
    OnClick = btnSelectFilesClick
    ExplicitLeft = 518
  end
  object cbSetOutputFolder: TCheckBox
    Left = 200
    Top = 168
    Width = 97
    Height = 17
    Anchors = [akLeft, akBottom]
    Caption = 'Output folder'
    TabOrder = 4
    OnClick = cbSetOutputFolderClick
    ExplicitTop = 167
  end
  object btnOutputFolder: TButton
    Left = 412
    Top = 189
    Width = 25
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = '...'
    TabOrder = 5
    OnClick = btnOutputFolderClick
    ExplicitLeft = 408
    ExplicitTop = 188
  end
end
