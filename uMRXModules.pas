{*******************************************************************************
  uMRXModules
********************************************************************************
  Visual module library for the MRX Desktop Environment.
  Built natively on Skia4Delphi.

  Core Architecture:
  - Base-class driven design where modules inherit physics, dragging, and rendering.
  - Polymorphic overrides to disable specific features per module (e.g., no HotZoom
    on Controls, no Fullscreen on Playlists).

*******************************************************************************}

{                                                                              }
{------------------------------------------------------------------------------}
{ by Lara Miriam Tamy Reschke                                                  }
{                                                                              }
{ larate@gmx.net                                                               }
{ https://lamita.jimdosite.com                                                 }
{                                                                              }
{------------------------------------------------------------------------------}


unit uMRXModules;

interface

uses
  System.SysUtils, System.Types, System.Classes, System.Math, System.UITypes,
  FMX.Types, FMX.Controls, FMX.Graphics, FMX.Platform, FMX.Skia, System.Skia,
  System.Generics.Collections, uMRXSurface, uFFmpegPipeline;

type
  { ==========================================================================
    TMRXAppIcon
    ========================================================================== }
  TMRXAppIcon = class(TMRXDesktopObject)
  public
    constructor Create(ASurface: TMRXSkiaSurface; const APos: TPointF; const ASize: TSizeF); override;
    procedure Draw(const ACanvas: ISkCanvas); override;
    procedure ApplyDrag(const ANewPos: TPointF); override;
  end;

  { ==========================================================================
    TMRXCover
    ========================================================================== }
  TMRXCover = class(TMRXDesktopObject)
  public
    constructor Create(ASurface: TMRXSkiaSurface; const APos: TPointF; const ASize: TSizeF); override;
    procedure Draw(const ACanvas: ISkCanvas); override;
    procedure ApplyDrag(const ANewPos: TPointF); override;
  end;

  { ==========================================================================
    TMRXInfos
    ========================================================================== }
  TMRXInfos = class(TMRXDesktopObject)
  public
    constructor Create(ASurface: TMRXSkiaSurface; const APos: TPointF; const ASize: TSizeF); override;
    procedure Draw(const ACanvas: ISkCanvas); override;
    procedure ApplyDrag(const ANewPos: TPointF); override;
  end;

  { ==========================================================================
    TMRXPlaylist
    ========================================================================== }
  TMRXPlaylist = class(TMRXDesktopObject)
  private
    FSideBarMode: Boolean;
    procedure SetSideBarMode(const Value: Boolean);
  public
    constructor Create(ASurface: TMRXSkiaSurface; const APos: TPointF; const ASize: TSizeF); override;
    procedure Draw(const ACanvas: ISkCanvas); override;
    procedure UpdateHotZoom(const DeltaTime: Double); override;
    procedure ApplyDrag(const ANewPos: TPointF); override;

    property SideBarMode: Boolean read FSideBarMode write SetSideBarMode default False;
  end;

  { ==========================================================================
    TMRXControls
    ========================================================================== }
  TMRXControls = class(TMRXDesktopObject)
  public
    constructor Create(ASurface: TMRXSkiaSurface; const APos: TPointF; const ASize: TSizeF); override;
    procedure Draw(const ACanvas: ISkCanvas); override;
    procedure UpdateHotZoom(const DeltaTime: Double); override;
    procedure ApplyDrag(const ANewPos: TPointF); override;
    procedure ToggleFullscreen; override;
  end;

  { ==========================================================================
    TMRXVideo
    ========================================================================== }
  TMRXVideo = class(TMRXDesktopObject)
  private
    FHotZoom: Single;
    FMediaPath: string;
    FPipeline: TFFmpegPipeline;
    FCurrentFrame: ISkImage;
    FIsPlaying: Boolean;
    FVolume: Single;

    procedure SetHotZoom(Value: Single);
    procedure SetMediaPath(const Value: string);
    procedure SetVolume(const Value: Single);
  public
    constructor Create(ASurface: TMRXSkiaSurface; const APos: TPointF; const ASize: TSizeF); override;
    destructor Destroy; override;
    procedure Draw(const ACanvas: ISkCanvas); override;
    procedure UpdatePhysics(const DeltaTime: Double); override;
    procedure ApplyDrag(const ANewPos: TPointF); override;
    procedure PlayMediaFile(const APath: string);
    procedure Stop;

    property HotZoom: Single read FHotZoom write SetHotZoom;
    property MediaPath: string read FMediaPath write SetMediaPath;
    property IsPlaying: Boolean read FIsPlaying;
    property Volume: Single read FVolume write SetVolume;
  end;

  { ==========================================================================
    TMRXTopInfoModule
    ========================================================================== }
  TMRXTopInfoModule = class(TMRXDesktopObject)
  private
    FCurtainAlpha: Single;
    FIsIntroActive: Boolean;
    FEntriesTriggered: Boolean;
    FModulesToReveal: TList<TMRXDesktopObject>;
  public
    constructor Create(ASurface: TMRXSkiaSurface; const APos: TPointF; const ASize: TSizeF); override;
    destructor Destroy; override;
    procedure Draw(const ACanvas: ISkCanvas); override;
    procedure UpdateHotZoom(const DeltaTime: Double); override;
    procedure UpdatePhysics(const DeltaTime: Double); override;
    procedure ApplyDrag(const ANewPos: TPointF); override;

    // Queue modules to be animated in once the curtain opens
    procedure RegisterModuleForEntry(AModule: TMRXDesktopObject);
    procedure StartIntro;
    property IsIntroActive: Boolean read FIsIntroActive;
  end;

implementation

{==============================================================================
  TMRXAppIcon
==============================================================================}

constructor TMRXAppIcon.Create(ASurface: TMRXSkiaSurface; const APos: TPointF; const ASize: TSizeF);
begin
  inherited;
  // Hidden initially until the intro sequence reveals it
  Visible := False;
end;

procedure TMRXAppIcon.Draw(const ACanvas: ISkCanvas);
var
  R: TRectF;
  Paint: ISkPaint;
  RndRect: ISkRoundRect;
begin
  R := RectF(0, 0, Size.Width, Size.Height);
  Paint := TSkPaint.Create;
  Paint.SetARGB(255, $35, $35, $00);
  Paint.AntiAlias := True;
  Paint.Alpha := FBackgroundAlpha;
  RndRect := TSkRoundRect.Create(R, CornerRadius, CornerRadius);
  ACanvas.DrawRoundRect(RndRect, Paint);
  RedrawReason := rrNone;
end;

procedure TMRXAppIcon.ApplyDrag(const ANewPos: TPointF);
begin
  inherited;
end;

{==============================================================================
  TMRXCover
==============================================================================}
constructor TMRXCover.Create(ASurface: TMRXSkiaSurface; const APos: TPointF; const ASize: TSizeF);
begin
  inherited;
  Visible := False;
end;

procedure TMRXCover.Draw(const ACanvas: ISkCanvas);
var
  R: TRectF;
  Paint: ISkPaint;
  RndRect: ISkRoundRect;
begin
  R := RectF(0, 0, Size.Width, Size.Height);
  Paint := TSkPaint.Create;
  Paint.SetARGB(255, $00, $25, $35);
  Paint.Alpha := FBackgroundAlpha;
  Paint.AntiAlias := True;
  RndRect := TSkRoundRect.Create(R, CornerRadius, CornerRadius);
  ACanvas.DrawRoundRect(RndRect, Paint);
  RedrawReason := rrNone;
end;

procedure TMRXCover.ApplyDrag(const ANewPos: TPointF);
begin
  inherited;
end;

{==============================================================================
  TMRXInfos
==============================================================================}
constructor TMRXInfos.Create(ASurface: TMRXSkiaSurface; const APos: TPointF; const ASize: TSizeF);
begin
  inherited;
  Visible := False;
end;

procedure TMRXInfos.Draw(const ACanvas: ISkCanvas);
var
  R: TRectF;
  Paint: ISkPaint;
  RndRect: ISkRoundRect;
begin
  R := RectF(0, 0, Size.Width, Size.Height);
  Paint := TSkPaint.Create;
  Paint.SetARGB(255, $1A, $00, $25);
  Paint.Alpha := FBackgroundAlpha;
  Paint.AntiAlias := True;
  RndRect := TSkRoundRect.Create(R, CornerRadius, CornerRadius);
  ACanvas.DrawRoundRect(RndRect, Paint);
  RedrawReason := rrNone;
end;

procedure TMRXInfos.ApplyDrag(const ANewPos: TPointF);
begin
  inherited;
end;

{==============================================================================
  TMRXPlaylist
==============================================================================}
constructor TMRXPlaylist.Create(ASurface: TMRXSkiaSurface; const APos: TPointF; const ASize: TSizeF);
begin
  inherited;
  Visible := False;
end;

procedure TMRXPlaylist.SetSideBarMode(const Value: Boolean);
begin
  if FSideBarMode <> Value then
  begin
    FSideBarMode := Value;
    // Elevate above fullscreen elements when docked, drop to background when floating
    if FSideBarMode then
      FZOrder := Z_ORDER_SIDEBAR
    else
      FZOrder := Z_ORDER_BACKGROUND;

    MarkDirty(rrInternal);
  end;
end;

procedure TMRXPlaylist.UpdateHotZoom(const DeltaTime: Double);
begin
  // Disable hover scaling when docked to the edge
  if FSideBarMode then
    Exit;
  inherited;
end;

procedure TMRXPlaylist.ApplyDrag(const ANewPos: TPointF);
begin
  // Only allow repositioning when floating freely
  if not FSideBarMode then
    inherited;
end;

procedure TMRXPlaylist.Draw(const ACanvas: ISkCanvas);
var
  R: TRectF;
  Paint: ISkPaint;
  RndRect: ISkRoundRect;
  ShadowFilter: ISkImageFilter;
  LayerPaint: ISkPaint;
  LayerBounds: TRectF;
  ZoomFactor: Single;
begin
  ZoomFactor := ActualHotZoom;
  R := RectF(0, 0, Size.Width, Size.Height);

  // Render a soft drop shadow behind the module when hovered
  if ZoomFactor > 1.01 then
  begin
    LayerPaint := TSkPaint.Create;
    LayerPaint.Color := TAlphaColors.White;
    LayerPaint.Alpha := 255;
    LayerBounds := R;
    LayerBounds.Inflate(50, 50);
    ACanvas.SaveLayer(LayerBounds, LayerPaint);
    ShadowFilter := TSkImageFilter.MakeDropShadow(0, (ZoomFactor - 1.0) * 50, (ZoomFactor - 1.0) * 40, (ZoomFactor - 1.0) * 40, TAlphaColors.Black, nil);
    Paint := TSkPaint.Create;
    Paint.ImageFilter := ShadowFilter;
    Paint.Style := TSkPaintStyle.Fill;
    Paint.Color := TAlphaColors.Black;
    Paint.AntiAlias := True;
    RndRect := TSkRoundRect.Create(R, CornerRadius, CornerRadius);
    ACanvas.DrawRoundRect(RndRect, Paint);
    ACanvas.ClipRoundRect(RndRect, TSkClipOp.Intersect, True);
  end;

  // Draw the main background panel
  Paint := TSkPaint.Create;
  Paint.SetARGB(255, $25, $25, $25);
  Paint.Alpha := FBackgroundAlpha;
  Paint.AntiAlias := True;
  RndRect := TSkRoundRect.Create(R, CornerRadius, CornerRadius);
  ACanvas.DrawRoundRect(RndRect, Paint);

  if ZoomFactor > 1.01 then
    ACanvas.Restore;
  RedrawReason := rrNone;
end;

{==============================================================================
  TMRXControls
==============================================================================}
constructor TMRXControls.Create(ASurface: TMRXSkiaSurface; const APos: TPointF; const ASize: TSizeF);
begin
  inherited;
  FZOrder := Z_ORDER_CONTROLS;
  Visible := False;
end;

procedure TMRXControls.UpdateHotZoom(const DeltaTime: Double);
begin
  // Interface controls remain strictly static under the cursor
  Exit;
end;

procedure TMRXControls.ApplyDrag(const ANewPos: TPointF);
begin
  inherited;
end;

procedure TMRXControls.ToggleFullscreen;
begin
  // Interface controls are locked to their layout dimensions
end;

procedure TMRXControls.Draw(const ACanvas: ISkCanvas);
var
  R: TRectF;
  Paint: ISkPaint;
  RndRect: ISkRoundRect;
begin
  R := RectF(0, 0, Size.Width, Size.Height);
  Paint := TSkPaint.Create;
  Paint.SetARGB(255, $40, $40, $40);
  Paint.AntiAlias := True;
  Paint.Alpha := 200;
  RndRect := TSkRoundRect.Create(R, CornerRadius, CornerRadius);
  ACanvas.DrawRoundRect(RndRect, Paint);
  RedrawReason := rrNone;
end;

{==============================================================================
  TMRXVideo
==============================================================================}
constructor TMRXVideo.Create(ASurface: TMRXSkiaSurface; const APos: TPointF; const ASize: TSizeF);
begin
  inherited Create(ASurface, APos, ASize);
  FZOrder := Z_ORDER_VIDEO;
  FHotZoom := 1.0;
  FMediaPath := '';
  FPipeline := TFFmpegPipeline.Create;
  FIsPlaying := False;
  FVolume := 1.0;
  FForcePhysicsUpdate := False;
  Visible := False;
end;

destructor TMRXVideo.Destroy;
begin
  Stop;
  FreeAndNil(FPipeline);
  inherited;
end;

procedure TMRXVideo.ApplyDrag(const ANewPos: TPointF);
begin
  inherited;
end;

procedure TMRXVideo.SetHotZoom(Value: Single);
begin
  if Value < 0.1 then
    Value := 0.1;
  if not SameValue(FHotZoom, Value, 0.0001) then
  begin
    FHotZoom := Value;
    IsAnimating := True;
    MarkDirty(rrHotZoom);
  end;
end;

procedure TMRXVideo.SetMediaPath(const Value: string);
begin
  if FMediaPath <> Value then
  begin
    FMediaPath := Value;
    if FIsPlaying then
      Stop;
  end;
end;

procedure TMRXVideo.SetVolume(const Value: Single);
begin
  FVolume := EnsureRange(Value, 0.0, 1.0);
end;

procedure TMRXVideo.PlayMediaFile(const APath: string);
begin
  FMediaPath := APath;
  if FPipeline.LoadMedia(APath) then
  begin
    FIsPlaying := True;
    // Signal the base class to keep calling UpdatePhysics even when stationary
    FForcePhysicsUpdate := True;
    IsAnimating := True;
    MarkDirty(rrInternal);
  end
  else
    FIsPlaying := False;
end;

procedure TMRXVideo.Stop;
begin
  FPipeline.Close;
  FIsPlaying := False;
  FForcePhysicsUpdate := False;
  FCurrentFrame := nil;
  MarkDirty(rrInternal);
end;

procedure TMRXVideo.UpdatePhysics(const DeltaTime: Double);
var
  NewW, NewH: Integer;
begin
  if FIsPlaying then
  begin
    NewW := Round(Size.Width);
    NewH := Round(Size.Height);

    if (FPipeline.Width <> NewW) or (FPipeline.Height <> NewH) then
      FPipeline.ResizeTarget(NewW, NewH);

    FCurrentFrame := FPipeline.GrabNextFrame();
    if not Assigned(FCurrentFrame) then
    begin
      FIsPlaying := False;
      FForcePhysicsUpdate := False;
    end
    else
    begin
      FRenderCache := FCurrentFrame;
      MarkDirty(rrInternal);
    end;
  end;

  inherited;
end;

procedure TMRXVideo.Draw(const ACanvas: ISkCanvas);
var
  Paint: ISkPaint;
  CenterX, CenterY, ZoomFactor, VideoAspect, TargetAspect, W, H: Single;
  DrawRect: TRectF;
  RndRect: ISkRoundRect;
  ShadowFilter: ISkImageFilter;
  LayerPaint: ISkPaint;
  LayerBounds: TRectF;
begin
  CenterX := Size.Width / 2;
  CenterY := Size.Height / 2;
  ZoomFactor := ActualHotZoom;

  RndRect := TSkRoundRect.Create(RectF(0, 0, Size.Width, Size.Height), CornerRadius, CornerRadius);

  // Apply shadow effect when hovered and scaled up
  if ZoomFactor > 1.01 then
  begin
    LayerPaint := TSkPaint.Create;
    LayerPaint.Color := TAlphaColors.White;
    LayerPaint.Alpha := 255;
    LayerBounds := RectF(0, 0, Size.Width, Size.Height);
    LayerBounds.Inflate(60, 60);
    ACanvas.SaveLayer(LayerBounds, LayerPaint);
    ShadowFilter := TSkImageFilter.MakeDropShadow(0, (ZoomFactor - 1.0) * 60, (ZoomFactor - 1.0) * 50, (ZoomFactor - 1.0) * 50, TAlphaColors.Black, nil);
    Paint := TSkPaint.Create;
    Paint.ImageFilter := ShadowFilter;
    Paint.Style := TSkPaintStyle.Fill;
    Paint.Color := TAlphaColors.Black;
    Paint.AntiAlias := True;
    ACanvas.DrawRoundRect(RndRect, Paint);
    ACanvas.ClipRoundRect(RndRect, TSkClipOp.Intersect, True);
  end
  else
    ACanvas.ClipRoundRect(RndRect, TSkClipOp.Intersect, True);

  // Draw black backdrop behind the video
  Paint := TSkPaint.Create;
  Paint.Style := TSkPaintStyle.Fill;
  Paint.SetARGB(255, $00, $00, $00);
  Paint.Alpha := FBackgroundAlpha;
  Paint.AntiAlias := True;

  ACanvas.Save;
  try
    // Apply internal video scaling matrix
    ACanvas.Translate(CenterX, CenterY);
    ACanvas.Scale(FHotZoom, FHotZoom);
    ACanvas.Translate(-CenterX, -CenterY);
    ACanvas.DrawRect(RectF(0, 0, Size.Width, Size.Height), Paint);

    // Maintain aspect ratio and draw the decoded frame
    if Assigned(FCurrentFrame) and (FCurrentFrame.Width > 0) and (FCurrentFrame.Height > 0) then
    begin
      Paint.SetARGB(255, 255, 255, 255);
      Paint.Alpha := 240;
      VideoAspect := FCurrentFrame.Width / FCurrentFrame.Height;
      TargetAspect := Size.Width / Size.Height;

      if TargetAspect > VideoAspect then
      begin
        H := Size.Height;
        W := H * VideoAspect;
      end
      else
      begin
        W := Size.Width;
        H := W / VideoAspect;
      end;

      DrawRect := TRectF.Create((Size.Width - W) / 2, (Size.Height - H) / 2, (Size.Width + W) / 2, (Size.Height + H) / 2);

      // Use nearest-neighbor scaling if the frame is smaller than the view to preserve sharp pixels
      if (W > FCurrentFrame.Width) or (H > FCurrentFrame.Height) then
        ACanvas.DrawImageRect(FCurrentFrame, DrawRect, TSkSamplingOptions.Create(TSkFilterMode.Nearest, TSkMipmapMode.None), Paint)
      else
        ACanvas.DrawImageRect(FCurrentFrame, DrawRect, TSkSamplingOptions.Low, Paint);
    end;
  finally
    ACanvas.Restore;
  end;

  if ZoomFactor > 1.01 then
    ACanvas.Restore;
  RedrawReason := rrNone;
end;

{==============================================================================
  TMRXTopInfoModule
==============================================================================}
constructor TMRXTopInfoModule.Create(ASurface: TMRXSkiaSurface; const APos: TPointF; const ASize: TSizeF);
begin
  inherited;
  FZOrder := Z_ORDER_TOPINFO;

  // Start opaque to hide the desktop while modules load in the background
  FCurtainAlpha := 1.0;
  FIsIntroActive := False;
  FEntriesTriggered := False;
  Visible := True;
  FModulesToReveal := TList<TMRXDesktopObject>.Create;
end;

destructor TMRXTopInfoModule.Destroy;
begin
  FModulesToReveal.Free;
  inherited;
end;

procedure TMRXTopInfoModule.RegisterModuleForEntry(AModule: TMRXDesktopObject);
begin
  if Assigned(AModule) then
    FModulesToReveal.Add(AModule);
end;

procedure TMRXTopInfoModule.StartIntro;
begin
  FCurtainAlpha := 1.0;
  FIsIntroActive := True;
  FEntriesTriggered := False;
  IsAnimating := True;
  Visible := True;
  MarkDirty(rrInternal);
end;

procedure TMRXTopInfoModule.UpdateHotZoom(const DeltaTime: Double);
begin
  // Top layer UI ignores hover effects
  Exit;
end;

procedure TMRXTopInfoModule.UpdatePhysics(const DeltaTime: Double);
var
  i: Integer;
begin
  if not FIsIntroActive then
    Exit;

  // Trigger phase: As soon as the curtain begins to fade, wake up the queued modules
  if (not FEntriesTriggered) and (FCurtainAlpha < 0.99) then
  begin
    FEntriesTriggered := True;
    for i := 0 to FModulesToReveal.Count - 1 do
    begin
      FModulesToReveal[i].Visible := True;
      FModulesToReveal[i].InitEntryAnimation(esFromEdge);
    end;
  end;

  // Gradually dissolve the black overlay
  FCurtainAlpha := FCurtainAlpha - (DeltaTime * 0.4);

  if FCurtainAlpha <= 0 then
  begin
    FCurtainAlpha := 0;
    FIsIntroActive := False;
    IsAnimating := False;
    // Remove from render cycle and disable hit testing so it doesn't block interactions
    Visible := False;
  end;

  MarkDirty(rrInternal);
end;

procedure TMRXTopInfoModule.ApplyDrag(const ANewPos: TPointF);
begin
  // The top overlay layer is anchored to the screen and cannot be dragged
end;

procedure TMRXTopInfoModule.Draw(const ACanvas: ISkCanvas);
var
  R: TRectF;
  Paint: ISkPaint;
begin
  if FCurtainAlpha > 0 then
  begin
    R := RectF(0, 0, Size.Width, Size.Height);
    Paint := TSkPaint.Create;
    Paint.Style := TSkPaintStyle.Fill;
    Paint.Color := TAlphaColors.Black;
    Paint.Alpha := Round(FCurtainAlpha * 255);
    ACanvas.DrawRect(R, Paint);
  end;
  RedrawReason := rrNone;
end;

end.

