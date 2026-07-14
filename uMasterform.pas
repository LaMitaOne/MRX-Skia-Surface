unit uMasterform;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, uMRXSurface,
  uMRXModules;

type
  TFMaster = class(TForm)
    OpenDialog1: TOpenDialog;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    MRXDesktop: TMRXSkiaSurface;

    ControlsModul: TMRXControls;
    VideoModul: TMRXVideo;
    PlaylistModul: TMRXPlaylist;
    AppIconModul: TMRXAppIcon;
    CoverModul: TMRXCover;
    InfosModul: TMRXInfos;
    TopInfoModul: TMRXTopInfoModule;
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
  MRXDesktop.AddObject(VideoModul);
  TopInfoModul.RegisterModuleForEntry(VideoModul);

  PlaylistModul := TMRXPlaylist.Create(MRXDesktop, TPointF.Create(50, 500), TSizeF.Create(300, 200));
  MRXDesktop.AddObject(PlaylistModul);
  TopInfoModul.RegisterModuleForEntry(PlaylistModul);

  AppIconModul := TMRXAppIcon.Create(MRXDesktop, TPointF.Create(800, 50), TSizeF.Create(100, 100));
  MRXDesktop.AddObject(AppIconModul);
  TopInfoModul.RegisterModuleForEntry(AppIconModul);

  CoverModul := TMRXCover.Create(MRXDesktop, TPointF.Create(400, 500), TSizeF.Create(200, 200));
  MRXDesktop.AddObject(CoverModul);
  TopInfoModul.RegisterModuleForEntry(CoverModul);

  InfosModul := TMRXInfos.Create(MRXDesktop, TPointF.Create(800, 200), TSizeF.Create(250, 150));
  MRXDesktop.AddObject(InfosModul);
  TopInfoModul.RegisterModuleForEntry(InfosModul);

  ControlsModul := TMRXControls.Create(MRXDesktop, TPointF.Create(700, 650), TSizeF.Create(400, 50));
  MRXDesktop.AddObject(ControlsModul);
  TopInfoModul.RegisterModuleForEntry(ControlsModul);
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
end;

end.

