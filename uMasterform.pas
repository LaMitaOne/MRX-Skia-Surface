unit uMasterform;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, uMRXSurface;

type
  TFMaster = class(TForm)
    OpenDialog1: TOpenDialog;
    procedure FormCreate(Sender: TObject);
  private
    MRXDesktop: TMRXSkiaSurface;
    ControlsModul: TMRXControls;
    VideoModul: TMRXVideo;
    PlaylistModul: TMRXPlaylist;
    AppIconModul: TMRXAppIcon;
    CoverModul: TMRXCover;
    InfosModul: TMRXInfos;

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
  MRXDesktop := TMRXSkiaSurface.Create(Self);
  MRXDesktop.Parent := Self;
  MRXDesktop.Align := TAlignLayout.Client;
  MRXDesktop.DesktopColor := $FF1A1A1A;

  MRXDesktop.SetWallpaperFromFile('back.jpg');

  MRXDesktop.Active := True;

  MRXDesktop.OnClick := DesktopClick;
  MRXDesktop.OnDblClick := DesktopDblClick;

  VideoModul := TMRXVideo.Create(MRXDesktop, TPointF.Create(100, 80), TSizeF.Create(640, 360));
  MRXDesktop.AddObject(VideoModul);

  PlaylistModul := TMRXPlaylist.Create(MRXDesktop, TPointF.Create(50, 500), TSizeF.Create(300, 200));
  MRXDesktop.AddObject(PlaylistModul);

  AppIconModul := TMRXAppIcon.Create(MRXDesktop, TPointF.Create(800, 50), TSizeF.Create(100, 100));
  MRXDesktop.AddObject(AppIconModul);

  CoverModul := TMRXCover.Create(MRXDesktop, TPointF.Create(400, 500), TSizeF.Create(200, 200));
  MRXDesktop.AddObject(CoverModul);

  InfosModul := TMRXInfos.Create(MRXDesktop, TPointF.Create(800, 200), TSizeF.Create(250, 150));
  MRXDesktop.AddObject(InfosModul);

  ControlsModul := TMRXControls.Create(MRXDesktop, TPointF.Create(200, 450), TSizeF.Create(400, 50));
  MRXDesktop.AddObject(ControlsModul);
end;

procedure TFMaster.DesktopClick(Sender: TObject);
var
  ClickedObj: TMRXDesktopObject;
  P: TPointF;
begin
  P := MRXDesktop.ScreenToLocal(Screen.MousePos);
  ClickedObj := MRXDesktop.GetObjectAtPos(P);

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

  if (ClickedObj <> nil) and (ClickedObj is TMRXVideo) then
    TMRXVideo(ClickedObj).ToggleFullscreen;
end;

end.

