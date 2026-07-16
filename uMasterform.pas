unit uMasterform;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, uMRXSurface,
  uMRXModules, uSkiaAliveHighlighter;

type
  TFMaster = class(TForm)
    OpenDialog1: TOpenDialog;
    Timer1: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
  private
    MRXDesktop: TMRXSkiaSurface;

    ControlsModul: TMRXControls;
    VideoModul: TMRXVideo;
    PlaylistModul: TMRXPlaylist;
    AppIconModul: TMRXAppIcon;
    CoverModul: TMRXCover;
    InfosModul: TMRXInfos;
    TopInfoModul: TMRXTopInfoModule;
    FHighlighterModule: TMRXAliveHighlighterModule;
    procedure DesktopClick(Sender: TObject);
    procedure DesktopDblClick(Sender: TObject);
  public
  end;

var
  FMaster: TFMaster;

implementation

{$R *.fmx}

procedure TFMaster.FormCreate(Sender: TObject);
begin
  // Initialize the primary rendering surface and background logic
  MRXDesktop := TMRXSkiaSurface.Create(Self);
  MRXDesktop.Parent := Self;
  MRXDesktop.Align := TAlignLayout.Client;
  MRXDesktop.DesktopColor := $FF1A1A1A;
  MRXDesktop.SetWallpaperFromFile('back.jpg');
  MRXDesktop.Active := True;
  MRXDesktop.OnClick := DesktopClick;
  MRXDesktop.OnDblClick := DesktopDblClick;

  // Instantiate the top overlay layer first so it can accept module registrations
  TopInfoModul := TMRXTopInfoModule.Create(MRXDesktop, TPointF.Create(0, 0), TSizeF.Create(ClientWidth, ClientHeight));
  MRXDesktop.AddObject(TopInfoModul);

  // Create desktop modules and register them with the intro sequence handler
  VideoModul := TMRXVideo.Create(MRXDesktop, TPointF.Create(100, 80), TSizeF.Create(640, 360));
  VideoModul.AllowFullscreen := True;
  MRXDesktop.AddObject(VideoModul);
  TopInfoModul.RegisterModuleForEntry(VideoModul);

  PlaylistModul := TMRXPlaylist.Create(MRXDesktop, TPointF.Create(50, 500), TSizeF.Create(300, 200));
  MRXDesktop.AddObject(PlaylistModul);
  TopInfoModul.RegisterModuleForEntry(PlaylistModul);

  AppIconModul := TMRXAppIcon.Create(MRXDesktop, TPointF.Create(800, 50), TSizeF.Create(100, 100));
  MRXDesktop.AddObject(AppIconModul);
  TopInfoModul.RegisterModuleForEntry(AppIconModul);

  CoverModul := TMRXCover.Create(MRXDesktop, TPointF.Create(400, 500), TSizeF.Create(200, 200));
  CoverModul.AllowFullscreen := True;
  MRXDesktop.AddObject(CoverModul);
  TopInfoModul.RegisterModuleForEntry(CoverModul);

  InfosModul := TMRXInfos.Create(MRXDesktop, TPointF.Create(800, 200), TSizeF.Create(250, 150));
  InfosModul.AllowFullscreen := True;
  MRXDesktop.AddObject(InfosModul);
  TopInfoModul.RegisterModuleForEntry(InfosModul);

  ControlsModul := TMRXControls.Create(MRXDesktop, TPointF.Create(700, 650), TSizeF.Create(400, 50));
  MRXDesktop.AddObject(ControlsModul);
  TopInfoModul.RegisterModuleForEntry(ControlsModul);

  FHighlighterModule := TMRXAliveHighlighterModule.Create(MRXDesktop, TPointF.Create(0, 0), TSizeF.Create(0, 0));
  MRXDesktop.AddObject(FHighlighterModule);
  FHighlighterModule.Highlighter.Style := asSnake; // asEnergyBeam oder asFirefly
  FHighlighterModule.Highlighter.Color := TAlphaColors.Cyan;
  FHighlighterModule.Highlighter.AllowMoodSwings := True; // Soll er den Mauscursor jagen?
end;

procedure TFMaster.DesktopClick(Sender: TObject);
var
  ClickedObj: TMRXDesktopObject;
  P: TPointF;
begin
  P := MRXDesktop.ScreenToLocal(Screen.MousePos);
  ClickedObj := MRXDesktop.GetObjectAtPos(P);

  // Prompt for a media file if the video module is clicked while idle
  if (ClickedObj <> nil) and (ClickedObj is TMRXVideo) then
  begin
    if not TMRXVideo(ClickedObj).IsPlaying then
      if Opendialog1.execute then
        TMRXVideo(ClickedObj).PlayMediaFile(Opendialog1.Filename);
  end;
end;

procedure TFMaster.DesktopDblClick(Sender: TObject);
var
  ClickedObj: TMRXDesktopObject;
  P: TPointF;
begin
  P := MRXDesktop.ScreenToLocal(Screen.MousePos);
  ClickedObj := MRXDesktop.GetObjectAtPos(P);

  // Toggle fullscreen state on any valid double-clicked module
  if (ClickedObj <> nil) then
    ClickedObj.ToggleFullscreen;
end;

procedure TFMaster.FormShow(Sender: TObject);
begin
  // Execute the intro sequence after the form has finished sizing itself
  TopInfoModul.StartIntro;
  //Timer1.Enabled := True;  //alive highlighter test- gest stuck atm often
end;

procedure TFMaster.Timer1Timer(Sender: TObject);
var
  TargetRect: TRectF;
begin
  Timer1.Enabled := False;
  if not Assigned(FHighlighterModule) then
    Exit;

  TargetRect := TRectF.Create(InfosModul.Pos.X, InfosModul.Pos.Y, InfosModul.Pos.X + InfosModul.Size.Width, InfosModul.Pos.Y + InfosModul.Size.Height);

  FHighlighterModule.Highlighter.SendToRect(TargetRect);
end;

end.

