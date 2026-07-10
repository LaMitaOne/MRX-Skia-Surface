program MRXskiasurface;

uses
  System.StartUpCopy,
  FMX.Forms,
  FMX.Skia,
  uMasterform in 'uMasterform.pas' {FMaster},
  uMRXSurface in 'uMRXSurface.pas',
  uFFmpegPipeline in 'uFFmpegPipeline.pas';

{$R *.res}

begin
  GlobalUseSkia := True;
  Application.Initialize;
  Application.CreateForm(TFMaster, FMaster);
  Application.Run;
end.
