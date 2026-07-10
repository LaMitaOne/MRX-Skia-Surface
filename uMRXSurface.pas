unit uMRXSurface;

interface

uses
  System.SysUtils, System.Types, System.Classes, System.Math, System.UITypes,
  System.SyncObjs, System.Generics.Collections, System.Generics.Defaults,
  FMX.Types, FMX.Controls, FMX.Skia, System.Skia, uFFmpegPipeline;

type
  TMRXSkiaSurface = class;

  // Defines the visual layering of modules
  TMRXZIndex = (zuiBackground, zuiVideo, zuiOverlay);

  TMRXRedrawReason = (rrNone, rrInternal, rrDragged, rrHotZoom, rrFullscreen);

  { ==========================================================================
    MRX Desktop Objects (Base Class)
    ========================================================================== }
  TMRXDesktopObject = class
  private
    FSurface: TMRXSkiaSurface;
    FPosition: TPointF;
    FSize: TSizeF;
    FRedrawReason: TMRXRedrawReason;
    FVisible: Boolean;
    FIsAnimating: Boolean;
    FCornerRadius: Single;
    FBackgroundAlpha: Byte;
    FActualHotZoom: Single;
    FHotZoomTarget: Single;
    FZIndex: TMRXZIndex; // Determines draw order
  public
    constructor Create(ASurface: TMRXSkiaSurface; const APos: TPointF; const ASize: TSizeF); virtual;
    destructor Destroy; override;

    procedure MarkDirty(AReason: TMRXRedrawReason = rrInternal);
    procedure Draw(const ACanvas: ISkCanvas); virtual; abstract;
    procedure UpdateHotZoom(const DeltaTime: Double);

    function HitTest(const APoint: TPointF): Boolean;

    property Surface: TMRXSkiaSurface read FSurface;
    property Pos: TPointF read FPosition write FPosition;
    property Size: TSizeF read FSize write FSize;
    property RedrawReason: TMRXRedrawReason read FRedrawReason write FRedrawReason;
    property Visible: Boolean read FVisible write FVisible default True;
    property IsAnimating: Boolean read FIsAnimating write FIsAnimating;
    property CornerRadius: Single read FCornerRadius write FCornerRadius;
    property BackgroundAlpha: Byte read FBackgroundAlpha write FBackgroundAlpha;
    property HotZoomTarget: Single read FHotZoomTarget write FHotZoomTarget;
    property ActualHotZoom: Single read FActualHotZoom;
    property ZIndex: TMRXZIndex read FZIndex write FZIndex default zuiBackground;
  end;

  { ==========================================================================
    Standard UI Modules (Background Layer)
    ========================================================================== }
  TMRXAppIcon = class(TMRXDesktopObject)
  public
    constructor Create(ASurface: TMRXSkiaSurface; const APos: TPointF; const ASize: TSizeF); override;
    procedure Draw(const ACanvas: ISkCanvas); override;
  end;

  TMRXCover = class(TMRXDesktopObject)
  public
    constructor Create(ASurface: TMRXSkiaSurface; const APos: TPointF; const ASize: TSizeF); override;
    procedure Draw(const ACanvas: ISkCanvas); override;
  end;

  TMRXInfos = class(TMRXDesktopObject)
  public
    constructor Create(ASurface: TMRXSkiaSurface; const APos: TPointF; const ASize: TSizeF); override;
    procedure Draw(const ACanvas: ISkCanvas); override;
  end;

  { ==========================================================================
    TMRXPlaylist (Can be Background or Overlay via SideBarMode)
    ========================================================================== }
  TMRXPlaylist = class(TMRXDesktopObject)
  private
    FSideBarMode: Boolean;
    procedure SetSideBarMode(const Value: Boolean);
  public
    constructor Create(ASurface: TMRXSkiaSurface; const APos: TPointF; const ASize: TSizeF); override;
    procedure Draw(const ACanvas: ISkCanvas); override;

    property SideBarMode: Boolean read FSideBarMode write SetSideBarMode default False;
  end;

  { ==========================================================================
    TMRXControls (Always Overlay Layer)
    ========================================================================== }
  TMRXControls = class(TMRXDesktopObject)
  public
    constructor Create(ASurface: TMRXSkiaSurface; const APos: TPointF; const ASize: TSizeF); override;
    procedure Draw(const ACanvas: ISkCanvas); override;
  end;

  { ==========================================================================
    TMRXSkiaSurface
    ========================================================================== }
  TMRXSkiaSurface = class(TSkCustomControl)
  private
    FThread: TThread;
    FLock: TCriticalSection;
    FObjectListLock: TCriticalSection;
    FTargetFPS: Integer;
    FThreadActive: Boolean;
    FPaused: Boolean;

    FBackBuffer: ISkImage;
    FThreadSurface: ISkSurface;
    FLastRenderedW: Integer;
    FLastRenderedH: Integer;

    FObjects: TObjectList<TMRXDesktopObject>;

    FActive: Boolean;
    FDesktopColor: TAlphaColor;
    FWallpaper: ISkImage;

    FIsDragging: Boolean;
    FDragObject: TMRXDesktopObject;
    FDragOffset: TPointF;

    procedure SetActive(const Value: Boolean);
    procedure SetTargetFPS(const Value: Integer);
    procedure SetDesktopColor(const Value: TAlphaColor);

    procedure ThreadSafeInvalidate;
    procedure StartThread;
    procedure StopThread;

    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X: Single; Y: Single); override;
    procedure MouseMove(Shift: TShiftState; X: Single; Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X: Single; Y: Single); override;
    procedure DoMouseLeave; override;

    procedure UpdateHoverState(const AX, AY: Single);
    procedure ResetHoverState;
  protected
    procedure Resize; override;
    procedure Draw(const ACanvas: ISkCanvas; const ADest: TRectF; const AOpacity: Single); override;
    procedure UpdateLogic(const DeltaTime: Double); virtual;
    procedure RenderDirtyObjects(const ATime: Double; AW, AH: Integer); virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure AddObject(AObj: TMRXDesktopObject);
    procedure RemoveObject(AObj: TMRXDesktopObject);
    procedure ForceFullRedraw;

    function GetObjectAtPos(const APoint: TPointF): TMRXDesktopObject;

    procedure SetWallpaperFromFile(const AFileName: string);

    property ObjectListLock: TCriticalSection read FObjectListLock;
    property Objects: TObjectList<TMRXDesktopObject> read FObjects;
  published
    property Align default TAlignLayout.Client;
    property HitTest default True;
    property Active: Boolean read FActive write SetActive default False;
    property TargetFPS: Integer read FTargetFPS write SetTargetFPS default 60;
    property DesktopColor: TAlphaColor read FDesktopColor write SetDesktopColor default $FF1A1A1A;
  end;

  { ==========================================================================
    TMRXVideo (Video Layer)
    ========================================================================== }
  TMRXVideo = class(TMRXDesktopObject)
  private
    FActualPosition: TPointF;
    FTargetPosition: TPointF;
    FActualSize: TSizeF;
    FTargetSize: TSizeF;
    FHotZoom: Single;
    FMediaPath: string;
    FIsFullscreen: Boolean;
    FSmallRect: TRectF;

    FPipeline: TFFmpegPipeline;
    FCurrentFrame: ISkImage;
    FIsPlaying: Boolean;
    FVolume: Single;

    procedure SetTargetPosition(const Value: TPointF);
    procedure SetTargetSize(const Value: TSizeF);
    procedure SetHotZoom(Value: Single);
    procedure SetMediaPath(const Value: string);
    procedure SetVolume(const Value: Single);
  public
    constructor Create(ASurface: TMRXSkiaSurface; const APos: TPointF; const ASize: TSizeF); override;
    destructor Destroy; override;
    procedure Draw(const ACanvas: ISkCanvas); override;
    procedure UpdatePhysics(const DeltaTime: Double);
    procedure ToggleFullscreen;

    procedure PlayMediaFile(const APath: string);
    procedure Stop;

    property ActualPosition: TPointF read FActualPosition;
    property TargetPosition: TPointF read FTargetPosition write SetTargetPosition;
    property ActualSize: TSizeF read FActualSize;
    property TargetSize: TSizeF read FTargetSize write SetTargetSize;
    property HotZoom: Single read FHotZoom write SetHotZoom;
    property MediaPath: string read FMediaPath write SetMediaPath;
    property IsFullscreen: Boolean read FIsFullscreen write FIsFullscreen;

    property IsPlaying: Boolean read FIsPlaying;
    property Volume: Single read FVolume write SetVolume;
  end;

implementation

{ ============================================================================= }
{ Custom Z-Index Sorter for rendering order                                           }
{ ============================================================================= }

type
  TMRXObjectSorter = class(TComparer<TMRXDesktopObject>)
  public
    function Compare(const Left, Right: TMRXDesktopObject): Integer; override;
  end;

function TMRXObjectSorter.Compare(const Left, Right: TMRXDesktopObject): Integer;
begin
  // Lower ZIndex gets drawn first (Background -> Video -> Overlay)
  Result := Ord(Left.ZIndex) - Ord(Right.ZIndex);
end;

{==============================================================================
  TMRXDesktopObject
==============================================================================}

constructor TMRXDesktopObject.Create(ASurface: TMRXSkiaSurface; const APos: TPointF; const ASize: TSizeF);
begin
  inherited Create;
  FSurface := ASurface;
  FPosition := APos;
  FSize := ASize;
  FVisible := True;
  FIsAnimating := False;
  FRedrawReason := rrInternal;
  FCornerRadius := 10.0;
  FBackgroundAlpha := 180;
  FActualHotZoom := 1.0;
  FHotZoomTarget := 1.0;
  FZIndex := zuiBackground; // Default to back
end;

destructor TMRXDesktopObject.Destroy;
begin
  if Assigned(FSurface) then
    FSurface.ForceFullRedraw;
  inherited;
end;

procedure TMRXDesktopObject.MarkDirty(AReason: TMRXRedrawReason);
begin
  FRedrawReason := AReason;
end;

procedure TMRXDesktopObject.UpdateHotZoom(const DeltaTime: Double);
var
  Speed: Single;
begin
  // --- ANTI-HOVER LOGIC ---
  if (Self is TMRXVideo) and TMRXVideo(Self).IsFullscreen then
    Exit;
  if (Self is TMRXPlaylist) and TMRXPlaylist(Self).SideBarMode then
    Exit;
  if (Self is TMRXControls) then
    Exit;
  // -----------------------

  if not SameValue(FActualHotZoom, FHotZoomTarget, 0.001) then
  begin
    Speed := 4.0 * DeltaTime;
    FActualHotZoom := FActualHotZoom + (FHotZoomTarget - FActualHotZoom) * Speed;

    if Abs(FActualHotZoom - FHotZoomTarget) < 0.005 then
      FActualHotZoom := FHotZoomTarget;

    MarkDirty(rrHotZoom);
  end;
end;

function TMRXDesktopObject.HitTest(const APoint: TPointF): Boolean;
var
  R: TRectF;
begin
  R := RectF(Pos.X, Pos.Y, Pos.X + Size.Width, Pos.Y + Size.Height);
  Result := R.Contains(APoint);
end;

{==============================================================================
  Background Modules (zuiBackground)
==============================================================================}

constructor TMRXAppIcon.Create(ASurface: TMRXSkiaSurface; const APos: TPointF; const ASize: TSizeF);
begin
  inherited;
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

constructor TMRXCover.Create(ASurface: TMRXSkiaSurface; const APos: TPointF; const ASize: TSizeF);
begin
  inherited;
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

constructor TMRXInfos.Create(ASurface: TMRXSkiaSurface; const APos: TPointF; const ASize: TSizeF);
begin
  inherited;
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

{==============================================================================
  TMRXPlaylist (Dynamic Z-Index based on SideBarMode)
==============================================================================}

constructor TMRXPlaylist.Create(ASurface: TMRXSkiaSurface; const APos: TPointF; const ASize: TSizeF);
begin
  inherited;
end;

procedure TMRXPlaylist.SetSideBarMode(const Value: Boolean);
begin
  if FSideBarMode <> Value then
  begin
    FSideBarMode := Value;
    // Dynamically change layer so it renders above video when true
    if FSideBarMode then
      ZIndex := zuiOverlay
    else
      ZIndex := zuiBackground;

    MarkDirty(rrInternal);
  end;
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

  // Draw shadow if hovered
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

  // Draw background
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
  TMRXControls (Always zuiOverlay)
==============================================================================}

constructor TMRXControls.Create(ASurface: TMRXSkiaSurface; const APos: TPointF; const ASize: TSizeF);
begin
  inherited;
  ZIndex := zuiOverlay; // Force to front always
end;

procedure TMRXControls.Draw(const ACanvas: ISkCanvas);
var
  R: TRectF;
  Paint: ISkPaint;
  RndRect: ISkRoundRect;
begin
  R := RectF(0, 0, Size.Width, Size.Height);
  Paint := TSkPaint.Create;
  Paint.SetARGB(255, $40, $40, $40); // Dark gray for control bar
  Paint.AntiAlias := True;
  Paint.Alpha := 200; // Slightly solid
  RndRect := TSkRoundRect.Create(R, CornerRadius, CornerRadius);
  ACanvas.DrawRoundRect(RndRect, Paint);
  RedrawReason := rrNone;
end;


{==============================================================================
  TMRXSkiaSurface
==============================================================================}

constructor TMRXSkiaSurface.Create(AOwner: TComponent);
begin
  inherited;
  FLock := TCriticalSection.Create;
  FObjectListLock := TCriticalSection.Create;
  FObjects := TObjectList<TMRXDesktopObject>.Create(True);
  FThreadActive := False;
  FPaused := True;
  FActive := False;
  FTargetFPS := 60;
  FDesktopColor := $FF1A1A1A;
  FLastRenderedW := 0;
  FLastRenderedH := 0;
  FIsDragging := False;
  FDragObject := nil;
  FWallpaper := nil;
  Align := TAlignLayout.Client;
  HitTest := True;
end;

destructor TMRXSkiaSurface.Destroy;
begin
  StopThread;
  FObjects.Free;
  FreeAndNil(FObjectListLock);
  FreeAndNil(FLock);
  inherited;
end;

procedure TMRXSkiaSurface.Resize;
begin
  inherited;
  ForceFullRedraw;
end;

procedure TMRXSkiaSurface.AddObject(AObj: TMRXDesktopObject);
begin
  FObjectListLock.Acquire;
  try
    FObjects.Add(AObj);
  finally
    FObjectListLock.Release;
  end;
end;

procedure TMRXSkiaSurface.RemoveObject(AObj: TMRXDesktopObject);
begin
  FObjectListLock.Acquire;
  try
    FObjects.Extract(AObj);
  finally
    FObjectListLock.Release;
  end;
end;

procedure TMRXSkiaSurface.ForceFullRedraw;
var
  i: Integer;
begin
  FObjectListLock.Acquire;
  try
    for i := 0 to FObjects.Count - 1 do
      FObjects[i].RedrawReason := rrInternal;
  finally
    FObjectListLock.Release;
  end;
end;

procedure TMRXSkiaSurface.SetWallpaperFromFile(const AFileName: string);
begin
  if FileExists(AFileName) then
  begin
    FWallpaper := TSkImage.MakeFromEncodedFile(AFileName);
    ForceFullRedraw;
  end;
end;

function TMRXSkiaSurface.GetObjectAtPos(const APoint: TPointF): TMRXDesktopObject;
var
  i: Integer;
begin
  Result := nil;
  FObjectListLock.Acquire;
  try
    // Iterate backwards because top-most visually is at the end of the list
    for i := FObjects.Count - 1 downto 0 do
    begin
      if FObjects[i].Visible and FObjects[i].HitTest(APoint) then
      begin
        Result := FObjects[i];
        Break;
      end;
    end;
  finally
    FObjectListLock.Release;
  end;
end;

// --- HOVER & DRAG LOGIC ---

procedure TMRXSkiaSurface.MouseMove(Shift: TShiftState; X: Single; Y: Single);
begin
  inherited;

  // Dragging has absolute priority
  if FIsDragging then
  begin
    var NewPos: TPointF := TPointF.Create(X - FDragOffset.X, Y - FDragOffset.Y);
    if FDragObject is TMRXVideo then
      TMRXVideo(FDragObject).TargetPosition := NewPos
    else
      FDragObject.Pos := NewPos;

    FDragObject.MarkDirty(rrDragged);
    Exit;
  end;

  // Hover state updates
  if PtInRect(RectF(0, 0, Width, Height), TPointF.Create(X, Y)) then
    UpdateHoverState(X, Y)
  else
    ResetHoverState;
end;

procedure TMRXSkiaSurface.DoMouseLeave;
begin
  inherited;
  if not FIsDragging then
    ResetHoverState;
end;

procedure TMRXSkiaSurface.UpdateHoverState(const AX, AY: Single);
var
  HoveredObj: TMRXDesktopObject;
  P: TPointF;
  i: Integer;
begin
  P := TPointF.Create(AX, AY);
  HoveredObj := GetObjectAtPos(P);

  FObjectListLock.Acquire;
  try
    for i := 0 to FObjects.Count - 1 do
    begin
      if FObjects[i] = HoveredObj then
        FObjects[i].HotZoomTarget := 1.06
      else
        FObjects[i].HotZoomTarget := 1.0;
    end;
  finally
    FObjectListLock.Release;
  end;
end;

procedure TMRXSkiaSurface.ResetHoverState;
var
  i: Integer;
begin
  FObjectListLock.Acquire;
  try
    for i := 0 to FObjects.Count - 1 do
      FObjects[i].HotZoomTarget := 1.0;
  finally
    FObjectListLock.Release;
  end;
end;

procedure TMRXSkiaSurface.MouseDown(Button: TMouseButton; Shift: TShiftState; X: Single; Y: Single);
var
  Pt: TPointF;
begin
  inherited;
  if Button <> TMouseButton.mbLeft then
    Exit;

  Pt := TPointF.Create(X, Y);
  FDragObject := GetObjectAtPos(Pt);

  if Assigned(FDragObject) then
  begin
    FIsDragging := True;
    FDragOffset := TPointF.Create(X - FDragObject.Pos.X, Y - FDragObject.Pos.Y);
  end;
end;

procedure TMRXSkiaSurface.MouseUp(Button: TMouseButton; Shift: TShiftState; X: Single; Y: Single);
begin
  inherited;
  FIsDragging := False;
  FDragObject := nil;
end;

// --- THREADING & RENDERING ---

procedure TMRXSkiaSurface.StartThread;
begin
  if FThreadActive then
    Exit;
  FThreadActive := True;
  FPaused := not FActive;

  FThread := TThread.CreateAnonymousThread(
    procedure
    var
      LastTime, CurrentTime: Cardinal;
      DeltaSec: Double;
      SleepTime: Integer;
      Snapshot: ISkImage;
      W, H: Integer;
    begin
      LastTime := TThread.GetTickCount;
      while not TThread.CheckTerminated do
      begin
        CurrentTime := TThread.GetTickCount;
        DeltaSec := (CurrentTime - LastTime) / 1000.0;
        LastTime := CurrentTime;

        W := Round(Self.Width);
        H := Round(Self.Height);

        if (W > 0) and (H > 0) and ((W <> FLastRenderedW) or (H <> FLastRenderedH)) then
        begin
          FThreadSurface := TSkSurface.MakeRaster(W, H);
          FLastRenderedW := W;
          FLastRenderedH := H;
          if Assigned(FThreadSurface) then
            FThreadSurface.Canvas.Clear(Self.FDesktopColor);
        end;

        if not FPaused then
        begin
          UpdateLogic(DeltaSec);

          if Assigned(FThreadSurface) then
          begin
            RenderDirtyObjects(TThread.GetTickCount / 1000.0, W, H);

            Snapshot := FThreadSurface.MakeImageSnapshot;

            FLock.Acquire;
            try
              FBackBuffer := Snapshot;
            finally
              FLock.Release;
            end;
          end;
        end;

        ThreadSafeInvalidate;

        if FTargetFPS > 0 then
          SleepTime := Round(1000 / FTargetFPS)
        else
          SleepTime := 16;
        Sleep(SleepTime);
      end;
      FThreadActive := False;
    end);

  FThread.FreeOnTerminate := True;
  FThread.Start;
end;

procedure TMRXSkiaSurface.StopThread;
begin
  if not FThreadActive then
    Exit;
  if Assigned(FThread) then
    FThread.Terminate;
  Sleep(100);
end;

procedure TMRXSkiaSurface.ThreadSafeInvalidate;
begin
  if csDestroying in ComponentState then
    Exit;
  TThread.Queue(nil,
    procedure
    begin
      if not (csDestroying in ComponentState) and Assigned(Self) then
        Self.Redraw;
    end);
end;

procedure TMRXSkiaSurface.Draw(const ACanvas: ISkCanvas; const ADest: TRectF; const AOpacity: Single);
var
  ImageToDraw: ISkImage;
  Paint: ISkPaint;
begin
  FLock.Acquire;
  try
    ImageToDraw := FBackBuffer;
  finally
    FLock.Release;
  end;

  if Assigned(ImageToDraw) then
    ACanvas.DrawImage(ImageToDraw, 0, 0, TSkSamplingOptions.Low)
  else
  begin
    Paint := TSkPaint.Create;
    Paint.Style := TSkPaintStyle.Fill;
    Paint.Color := FDesktopColor;
    ACanvas.DrawRect(ADest, Paint);
  end;
end;

procedure TMRXSkiaSurface.UpdateLogic(const DeltaTime: Double);
var
  i: Integer;
begin
  FObjectListLock.Acquire;
  try
    for i := 0 to FObjects.Count - 1 do
    begin
      if FObjects[i].Visible then
      begin
        FObjects[i].UpdateHotZoom(DeltaTime);

        if FObjects[i].IsAnimating then
        begin
          if FObjects[i] is TMRXVideo then
            TMRXVideo(FObjects[i]).UpdatePhysics(DeltaTime);
        end;
      end;
    end;
  finally
    FObjectListLock.Release;
  end;
end;

procedure TMRXSkiaSurface.RenderDirtyObjects(const ATime: Double; AW, AH: Integer);
var
  i: Integer;
  Obj: TMRXDesktopObject;
  NeedsFullRedraw: Boolean;
  ClearPaint: ISkPaint;
  SortedObjects: TList<TMRXDesktopObject>;
begin
  ClearPaint := TSkPaint.Create;
  ClearPaint.Style := TSkPaintStyle.Fill;
  ClearPaint.Color := FDesktopColor;

  NeedsFullRedraw := False;

  FObjectListLock.Acquire;
  try
    for i := 0 to FObjects.Count - 1 do
    begin
      if FObjects[i].Visible and (FObjects[i].RedrawReason <> rrNone) then
      begin
        NeedsFullRedraw := True;
        Break;
      end;
    end;

    if NeedsFullRedraw then
    begin
      // 1. Clear background
      FThreadSurface.Canvas.DrawRect(RectF(0, 0, AW, AH), ClearPaint);

      // 2. Draw wallpaper
      if Assigned(FWallpaper) then
        FThreadSurface.Canvas.DrawImageRect(FWallpaper, RectF(0, 0, AW, AH), TSkSamplingOptions.High);

      // 3. Sort objects by ZIndex to ensure correct layering
      SortedObjects := TList<TMRXDesktopObject>.Create;
      try
        SortedObjects.AddRange(FObjects);
        SortedObjects.Sort(TMRXObjectSorter.Create);

        // 4. Render sorted objects
        for i := 0 to SortedObjects.Count - 1 do
        begin
          Obj := SortedObjects[i];
          if Obj.Visible then
          begin
            FThreadSurface.Canvas.Save;
            FThreadSurface.Canvas.Translate(Obj.Pos.X + (Obj.Size.Width / 2), Obj.Pos.Y + (Obj.Size.Height / 2));
            FThreadSurface.Canvas.Scale(Obj.ActualHotZoom, Obj.ActualHotZoom);
            FThreadSurface.Canvas.Translate(-(Obj.Size.Width / 2), -(Obj.Size.Height / 2));
            try
              Obj.Draw(FThreadSurface.Canvas);
            finally
              FThreadSurface.Canvas.Restore;
            end;
          end;
        end;
      finally
        SortedObjects.Free;
      end;
    end;
  finally
    FObjectListLock.Release;
  end;
end;

procedure TMRXSkiaSurface.SetActive(const Value: Boolean);
begin
  if FActive <> Value then
  begin
    FActive := Value;
    if FActive then
    begin
      if not FThreadActive then
        StartThread
      else
        FPaused := False;
    end
    else
      FPaused := True;
    ThreadSafeInvalidate;
  end;
end;

procedure TMRXSkiaSurface.SetTargetFPS(const Value: Integer);
begin
  if FTargetFPS <> Value then
    FTargetFPS := Value;
end;

procedure TMRXSkiaSurface.SetDesktopColor(const Value: TAlphaColor);
begin
  if FDesktopColor <> Value then
  begin
    FDesktopColor := Value;
    ForceFullRedraw;
  end;
end;

{==============================================================================
  TMRXVideo
==============================================================================}

constructor TMRXVideo.Create(ASurface: TMRXSkiaSurface; const APos: TPointF; const ASize: TSizeF);
begin
  inherited Create(ASurface, APos, ASize);
  FActualPosition := APos;
  FTargetPosition := APos;
  FActualSize := ASize;
  FTargetSize := ASize;
  FHotZoom := 1.0;
  FMediaPath := '';
  FIsFullscreen := False;
  FSmallRect := RectF(APos.X, APos.Y, APos.X + ASize.Width, APos.Y + ASize.Height);

  ZIndex := zuiVideo; // Video is middle layer

  FPipeline := TFFmpegPipeline.Create;
  FIsPlaying := False;
  FVolume := 1.0;
end;

destructor TMRXVideo.Destroy;
begin
  Stop;
  FreeAndNil(FPipeline);
  inherited;
end;

procedure TMRXVideo.SetTargetPosition(const Value: TPointF);
begin
  if FTargetPosition <> Value then
  begin
    FTargetPosition := Value;
    IsAnimating := True;
    MarkDirty(rrDragged);
  end;
end;

procedure TMRXVideo.SetTargetSize(const Value: TSizeF);
begin
  if FTargetSize <> Value then
  begin
    FTargetSize := Value;
    IsAnimating := True;
    MarkDirty(rrFullscreen);
  end;
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
    IsAnimating := True;
    MarkDirty(rrInternal);
  end
  else
  begin
    FIsPlaying := False;
  end;
end;

procedure TMRXVideo.Stop;
begin
  FPipeline.Close;
  FIsPlaying := False;
  FCurrentFrame := nil;
  MarkDirty(rrInternal);
end;

procedure TMRXVideo.ToggleFullscreen;
var
  DesktopW, DesktopH: Single;
begin
  if not Assigned(Surface) then
    Exit;
  DesktopW := Surface.Width;
  DesktopH := Surface.Height;

  if not FIsFullscreen then
  begin
    FIsFullscreen := True;
    FSmallRect := RectF(FActualPosition.X, FActualPosition.Y, FActualPosition.X + FActualSize.Width, FActualPosition.Y + FActualSize.Height);
    TargetPosition := TPointF.Create(0, 0);
    TargetSize := TSizeF.Create(DesktopW, DesktopH);
  end
  else
  begin
    FIsFullscreen := False;
    TargetPosition := TPointF.Create(FSmallRect.Left, FSmallRect.Top);
    TargetSize := TSizeF.Create(FSmallRect.Width, FSmallRect.Height);
  end;
end;

procedure TMRXVideo.UpdatePhysics(const DeltaTime: Double);
var
  Speed, PosEpsilon, SizeEpsilon: Single;
  MaxW, MaxH: Single;
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
      FIsPlaying := False
    else
      MarkDirty(rrInternal);
  end;

  if Assigned(Surface) then
  begin
    MaxW := Surface.Width;
    MaxH := Surface.Height;
  end
  else
  begin
    MaxW := 320;
    MaxH := 240;
  end;

  Speed := 6.0 * DeltaTime;
  PosEpsilon := 0.5;
  SizeEpsilon := 1.0;

  if not SameValue(FActualPosition.X, FTargetPosition.X, PosEpsilon) or not SameValue(FActualPosition.Y, FTargetPosition.Y, PosEpsilon) then
  begin
    FActualPosition.X := FActualPosition.X + (FTargetPosition.X - FActualPosition.X) * Speed;
    FActualPosition.Y := FActualPosition.Y + (FTargetPosition.Y - FActualPosition.Y) * Speed;
  end
  else
  begin
    FActualPosition.X := FTargetPosition.X;
    FActualPosition.Y := FTargetPosition.Y;
  end;

  if not SameValue(FActualSize.Width, FTargetSize.Width, SizeEpsilon) or not SameValue(FActualSize.Height, FTargetSize.Height, SizeEpsilon) then
  begin
    FActualSize.Width := FActualSize.Width + (FTargetSize.Width - FActualSize.Width) * Speed;
    FActualSize.Height := FActualSize.Height + (FTargetSize.Height - FActualSize.Height) * Speed;
  end
  else
  begin
    FActualSize.Width := FTargetSize.Width;
    FActualSize.Height := FTargetSize.Height;
  end;

  if FActualPosition.X < 0 then
    FActualPosition.X := 0;
  if FActualPosition.Y < 0 then
    FActualPosition.Y := 0;
  if FActualSize.Width > MaxW then
    FActualSize.Width := MaxW;
  if FActualSize.Height > MaxH then
    FActualSize.Height := MaxH;

  Pos := FActualPosition;
  Size := FActualSize;

  if SameValue(FActualPosition.X, FTargetPosition.X, PosEpsilon) and SameValue(FActualPosition.Y, FTargetPosition.Y, PosEpsilon) and SameValue(FActualSize.Width, FTargetSize.Width, SizeEpsilon) and SameValue(FActualSize.Height, FTargetSize.Height, SizeEpsilon) and (not FIsPlaying) then
  begin
    IsAnimating := False;
  end;
end;

procedure TMRXVideo.Draw(const ACanvas: ISkCanvas);
var
  Paint: ISkPaint;
  CenterX, CenterY: Single;
  DrawRect: TRectF;
  VideoAspect, TargetAspect: Single;
  W, H: Single;
  RndRect: ISkRoundRect;
  ZoomFactor: Single;
  ShadowFilter: ISkImageFilter;
  LayerPaint: ISkPaint;
  LayerBounds: TRectF;
begin
  CenterX := Size.Width / 2;
  CenterY := Size.Height / 2;
  ZoomFactor := ActualHotZoom;

  RndRect := TSkRoundRect.Create(RectF(0, 0, Size.Width, Size.Height), CornerRadius, CornerRadius);

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
  begin
    ACanvas.ClipRoundRect(RndRect, TSkClipOp.Intersect, True);
  end;

  Paint := TSkPaint.Create;
  Paint.Style := TSkPaintStyle.Fill;
  Paint.SetARGB(255, $00, $00, $00);
  Paint.Alpha := FBackgroundAlpha;
  Paint.AntiAlias := True;

  ACanvas.Save;
  try
    ACanvas.Translate(CenterX, CenterY);
    ACanvas.Scale(FHotZoom, FHotZoom);
    ACanvas.Translate(-CenterX, -CenterY);

    ACanvas.DrawRect(RectF(0, 0, Size.Width, Size.Height), Paint);

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

end.

