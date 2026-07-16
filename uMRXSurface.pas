{*******************************************************************************
  uMRXSurface
********************************************************************************
  A high-performance, offscreen-rendered desktop environment for Delphi FMX.
  Built natively on Skia4Delphi.

  Core Architecture:
  - Custom double-buffered render loop running on a dedicated background thread.
  - Dynamic Z-Ordering system allowing runtime layer elevation (e.g., Fullscreen).
  - Centralized physics pipeline managing smooth position/size interpolations.

  Key Features:
  - Completely decoupled from the standard FMX layout engine to prevent flicker.
  - Thread-safe object management and backbuffer swapping.
  - Automated hover-state tracking with HotZoom physics.
  - Built-in smooth rotation and alpha interpolation physics.
*******************************************************************************}

{                                                                              }
{------------------------------------------------------------------------------}
{ by Lara Miriam Tamy Reschke                                                  }
{                                                                              }
{ larate@gmx.net                                                               }
{ https://lamita.jimdosite.com                                                 }
{                                                                              }
{------------------------------------------------------------------------------}

{
 ----Latest Changes
   v 0.3
    - Added feature toggle properties: AllowFullscreen, AllowDrag, AllowRotation,
      AllowTransparent, AllowSidebarmode.
    - Added TargetAlpha and Rotation properties with built-in smooth physics.
    - Base class ApplyDrag and ToggleFullscreen now respect their Allow-flags.
    - RenderDirtyObjects applies Rotation matrix and uses TargetAlpha globally.
    - Added mouse position passthrough for overlay modules (e.g., AliveHighlighter).
    - Added uSkiaAliveHighlighter integration (beasty gets stuck atm, but bascially working)

   v 0.2
    - Replaced static Enum Z-Indexing with dynamic Integer Z-Ordering.
    - Added logic to elevate modules to Z_ORDER_FULLSCREEN dynamically.
    - Implemented precise Z-Order aware HitTesting for mouse interactions.
    - Switched dragging from eased TargetPosition to direct 1:1 Pos tracking.
    - Added FForcePhysicsUpdate flag to keep state loops alive (Video frames).
    - Refined entry animation physics for smoother edge-slide-in transitions.
    - Added TMRXTopInfoModule to handle cinematic black-curtain intro sequence.
    - Modules now start hidden (Visible := False) and are triggered by TopInfo.
    - Implemented TMRXEntryStyle (esFromEdge) to auto-detect closest screen edge.
    - TMRXControls locked out of Fullscreen transitions but kept above Video layer.
    - TMRXPlaylist disables dragging and HotZoom when in SideBarMode.
    - Stripped redundant physics code from TMRXVideo, now fully driven by base class.
}

unit uMRXSurface;

interface

uses
  System.SysUtils, System.Types, System.Classes, System.Math, System.UITypes,
  System.SyncObjs, System.Generics.Collections, System.Generics.Defaults,
  FMX.Types, FMX.Controls, FMX.Skia, FMX.Platform.Win, System.Skia;

const
  // Dynamic Z-Ordering constants to dictate render hierarchy at runtime.
  // Modules can change their ZOrder dynamically (e.g., jumping to FULLSCREEN when maximized).
  Z_ORDER_BACKGROUND = 10;
  Z_ORDER_VIDEO = 20;
  Z_ORDER_CONTROLS = 51; // Renders above video, but below fullscreen modules
  Z_ORDER_FULLSCREEN = 50; // Any module transitioning to fullscreen claims this layer
  Z_ORDER_SIDEBAR = 80; // Reserved for panels locked to screen edges
  Z_ORDER_TOPINFO = 100; // Ultimate top layer for intro overlays

type
  TMRXSkiaSurface = class;

  TMRXRedrawReason = (rrNone, rrInternal, rrDragged, rrHotZoom, rrFullscreen);

  TMRXEntryStyle = (esNone, esFromLeft, esFromRight, esFromTop, esFromBottom, esFromEdge);

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

    // New Feature Toggles
    FAllowFullscreen: Boolean;
    FAllowDrag: Boolean;
    FAllowRotation: Boolean;
    FAllowTransparent: Boolean;
    FAllowSidebarmode: Boolean;
  protected
    FBackgroundAlpha: Byte;
    FActualHotZoom: Single;
    FHotZoomTarget: Single;
    FZOrder: Integer;

    // Individual module backbuffer to cache internal state (like video frames or text)
    FRenderCache: ISkImage;

    // Flag to keep the physics loop running even when stationary (used by video playback)
    FForcePhysicsUpdate: Boolean;

    // Entry animation state
    FEntryStyle: TMRXEntryStyle;
    FEntryProgress: Single;
    FIsEntering: Boolean;
    FStartOffset: TPointF;

    // Smooth motion and fullscreen state
    FIsFullscreen: Boolean;
    FSmallRect: TRectF;
    FTargetPosition: TPointF;
    FActualPosition: TPointF;
    FTargetSize: TSizeF;
    FActualSize: TSizeF;

    // New Physics State for Rotation and Alpha
    FTargetAlpha: Single;
    FActualAlpha: Single;
    FTargetRotation: Single; // In degrees
    FActualRotation: Single; // In degrees

    procedure SetTargetPosition(const Value: TPointF);
    procedure SetTargetSize(const Value: TSizeF);

    // Evaluates target position to determine the optimal off-screen starting point
    procedure CalculateStartOffset;
  public
    constructor Create(ASurface: TMRXSkiaSurface; const APos: TPointF; const ASize: TSizeF); virtual;
    destructor Destroy; override;

    procedure MarkDirty(AReason: TMRXRedrawReason = rrInternal);
    procedure Draw(const ACanvas: ISkCanvas); virtual; abstract;

    // Core animation loop methods called by the render thread
    procedure UpdateHotZoom(const DeltaTime: Double); virtual;
    procedure UpdatePhysics(const DeltaTime: Double); virtual;
    procedure ApplyDrag(const ANewPos: TPointF); virtual;

    // Hook for overlay modules to receive raw mouse coordinates
    procedure UpdateMousePosition(const AMousePos: TPointF); virtual;

    // Modules override this to define where they sit when maximized
    function GetFullscreenZOrder: Integer; virtual;

    // Triggers the slide-in animation from outside the screen bounds
    procedure InitEntryAnimation(AStyle: TMRXEntryStyle); virtual;

    // Toggles between normal bounds and desktop-sized fullscreen
    procedure ToggleFullscreen; virtual;

    // Simple rectangular hit test for mouse interactions
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
    property ZOrder: Integer read FZOrder write FZOrder default Z_ORDER_BACKGROUND;

    property TargetPosition: TPointF read FTargetPosition write SetTargetPosition;
    property ActualPosition: TPointF read FActualPosition;
    property TargetSize: TSizeF read FTargetSize write SetTargetSize;
    property ActualSize: TSizeF read FActualSize;
    property IsFullscreen: Boolean read FIsFullscreen;

    // New Feature Toggle Properties
    property AllowFullscreen: Boolean read FAllowFullscreen write FAllowFullscreen default True;
    property AllowDrag: Boolean read FAllowDrag write FAllowDrag default True;
    property AllowRotation: Boolean read FAllowRotation write FAllowRotation default True;
    property AllowTransparent: Boolean read FAllowTransparent write FAllowTransparent default True;
    property AllowSidebarmode: Boolean read FAllowSidebarmode write FAllowSidebarmode default True;

    // New Animated Properties
    property TargetAlpha: Single read FTargetAlpha write FTargetAlpha;
    property ActualAlpha: Single read FActualAlpha;
    property Rotation: Single read FTargetRotation write FTargetRotation; // Target in degrees
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

    // Double buffering via Skia offscreen surface
    FBackBuffer: ISkImage;
    FThreadSurface: ISkSurface;
    FGRContext: IGrDirectContext;
    FLastRenderedW: Integer;
    FLastRenderedH: Integer;

    FObjects: TObjectList<TMRXDesktopObject>;

    FActive: Boolean;
    FDesktopColor: TAlphaColor;
    FWallpaper: ISkImage;

    // Mouse drag interaction state
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

    // Returns the top-most visible object at a given coordinate
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

implementation

type
  // Custom sorter to arrange the render queue based on dynamic ZOrder values
  TMRXObjectSorter = class(TComparer<TMRXDesktopObject>)
  public
    function Compare(const Left, Right: TMRXDesktopObject): Integer; override;
  end;

function TMRXObjectSorter.Compare(const Left, Right: TMRXDesktopObject): Integer;
begin
  // Lower ZOrder values are drawn first, higher values draw on top
  Result := Left.FZOrder - Right.FZOrder;
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

  // Initialize smooth motion targets to the creation position
  FActualPosition := APos;
  FTargetPosition := APos;
  FActualSize := ASize;
  FTargetSize := ASize;

  FVisible := True;
  FIsAnimating := False;
  FRedrawReason := rrInternal;
  FCornerRadius := 10.0;
  FBackgroundAlpha := 180;
  FActualHotZoom := 1.0;
  FHotZoomTarget := 1.0;
  FZOrder := Z_ORDER_BACKGROUND;

  // Initialize entry animation to a completed state
  FEntryStyle := esNone;
  FEntryProgress := 1.0;
  FIsEntering := False;
  FStartOffset := TPointF.Create(0, 0);

  // Store initial bounds to restore from fullscreen later
  FIsFullscreen := False;
  FSmallRect := RectF(APos.X, APos.Y, APos.X + ASize.Width, APos.Y + ASize.Height);

  // Initialize new feature toggles (all allowed by default)
  FAllowFullscreen := True;
  FAllowDrag := True;
  FAllowRotation := True;
  FAllowTransparent := True;
  FAllowSidebarmode := True;

  // Initialize new physics states
  FTargetAlpha := 1.0; // Fully opaque by default
  FActualAlpha := 1.0;
  FTargetRotation := 0.0; // No rotation by default
  FActualRotation := 0.0;
end;

destructor TMRXDesktopObject.Destroy;
begin
  // Ensure the desktop redraws the area where this object was located
  if Assigned(FSurface) then
    FSurface.ForceFullRedraw;
  inherited;
end;

procedure TMRXDesktopObject.MarkDirty(AReason: TMRXRedrawReason);
begin
  FRedrawReason := AReason;
end;

function TMRXDesktopObject.GetFullscreenZOrder: Integer;
begin
  // By default, standard modules claim the dedicated fullscreen layer
  Result := Z_ORDER_FULLSCREEN;
end;

procedure TMRXDesktopObject.SetTargetPosition(const Value: TPointF);
begin
  if FTargetPosition <> Value then
  begin
    FTargetPosition := Value;
    IsAnimating := True;
    MarkDirty(rrDragged);
  end;
end;

procedure TMRXDesktopObject.SetTargetSize(const Value: TSizeF);
begin
  if FTargetSize <> Value then
  begin
    FTargetSize := Value;
    IsAnimating := True;
    MarkDirty(rrFullscreen);
  end;
end;

procedure TMRXDesktopObject.CalculateStartOffset;
var
  DesktopW, DesktopH: Single;
begin
  if not Assigned(Surface) then
    Exit;
  DesktopW := Surface.Width;
  DesktopH := Surface.Height;

  if FEntryStyle = esFromEdge then
  begin
    // Automatically determine the closest edge based on the final target coordinates
    if FTargetPosition.X > (DesktopW / 2) then
      FStartOffset.X := DesktopW
    else if FTargetPosition.X < (DesktopW / 2) then
      FStartOffset.X := -Size.Width;

    if FTargetPosition.Y > (DesktopH / 2) then
      FStartOffset.Y := DesktopH
    else if FTargetPosition.Y < (DesktopH / 2) then
      FStartOffset.Y := -Size.Height;
  end
  else
  begin
    // Apply explicit directional offsets
    case FEntryStyle of
      esFromLeft:
        FStartOffset := TPointF.Create(-Size.Width, 0);
      esFromRight:
        FStartOffset := TPointF.Create(DesktopW, 0);
      esFromTop:
        FStartOffset := TPointF.Create(0, -Size.Height);
      esFromBottom:
        FStartOffset := TPointF.Create(0, DesktopH);
    end;
  end;
end;

procedure TMRXDesktopObject.InitEntryAnimation(AStyle: TMRXEntryStyle);
begin
  FEntryStyle := AStyle;
  if FEntryStyle = esNone then
    Exit;

  FEntryProgress := 0.0;
  FIsEntering := True;
  IsAnimating := True;

  CalculateStartOffset;
  MarkDirty(rrInternal);
end;

procedure TMRXDesktopObject.ToggleFullscreen;
var
  DesktopW, DesktopH: Single;
begin
  // Respect the feature toggle
  if not FAllowFullscreen then
    Exit;

  if not Assigned(Surface) then
    Exit;
  DesktopW := Surface.Width;
  DesktopH := Surface.Height;

  if not FIsFullscreen then
  begin
    FIsFullscreen := True;
    FSmallRect := RectF(FActualPosition.X, FActualPosition.Y, FActualPosition.X + FActualSize.Width, FActualPosition.Y + FActualSize.Height);

    // Force it to strictly one layer BELOW controls/sidebars, but above EVERYTHING else
    if FZOrder < Z_ORDER_FULLSCREEN then
      FZOrder := Z_ORDER_FULLSCREEN - 1;

    TargetPosition := TPointF.Create(0, 0);
    TargetSize := TSizeF.Create(DesktopW, DesktopH);
  end
  else
  begin
    FIsFullscreen := False;

    if not IsAnimating then
      FZOrder := Z_ORDER_BACKGROUND;

    TargetPosition := TPointF.Create(FSmallRect.Left, FSmallRect.Top);
    TargetSize := TSizeF.Create(FSmallRect.Width, FSmallRect.Height);
  end;
end;

procedure TMRXDesktopObject.UpdateHotZoom(const DeltaTime: Double);
var
  Speed: Single;
begin
  // Disable hover scaling while in fullscreen mode
  if FIsFullscreen then
    Exit;

  if not SameValue(FActualHotZoom, FHotZoomTarget, 0.001) then
  begin
    Speed := 4.0 * DeltaTime;
    FActualHotZoom := FActualHotZoom + (FHotZoomTarget - FActualHotZoom) * Speed;
    if Abs(FActualHotZoom - FHotZoomTarget) < 0.005 then
      FActualHotZoom := FHotZoomTarget;
    MarkDirty(rrHotZoom);
  end;
end;

procedure TMRXDesktopObject.UpdatePhysics(const DeltaTime: Double);
var
  Speed, PosEpsilon, SizeEpsilon, MaxW, MaxH: Single;
  CurrentOffset: TPointF;
  PosReached, SizeReached: Boolean;
begin
  // Phase 1: Evaluate slide-in entry animation
  if FIsEntering then
  begin
    Speed := 0.8 * DeltaTime;
    FEntryProgress := FEntryProgress + Speed;

    if FEntryProgress >= 1.0 then
    begin
      FEntryProgress := 1.0;
      FIsEntering := False;
    end;

    // Calculate interpolated offset from the starting edge
    CurrentOffset.X := FStartOffset.X * (1.0 - FEntryProgress);
    CurrentOffset.Y := FStartOffset.Y * (1.0 - FEntryProgress);

    FActualPosition.X := FTargetPosition.X + CurrentOffset.X;
    FActualPosition.Y := FTargetPosition.Y + CurrentOffset.Y;
    FActualSize := FTargetSize;

    Pos := FActualPosition;
    Size := FActualSize;
    MarkDirty(rrInternal);

    if FIsEntering then
      Exit;
  end;

  // Phase 2: Standard position and size interpolation (easing)
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

  PosReached := SameValue(FActualPosition.X, FTargetPosition.X, PosEpsilon) and SameValue(FActualPosition.Y, FTargetPosition.Y, PosEpsilon);
  SizeReached := SameValue(FActualSize.Width, FTargetSize.Width, SizeEpsilon) and SameValue(FActualSize.Height, FTargetSize.Height, SizeEpsilon);

  if not PosReached then
  begin
    FActualPosition.X := FActualPosition.X + (FTargetPosition.X - FActualPosition.X) * Speed;
    FActualPosition.Y := FActualPosition.Y + (FTargetPosition.Y - FActualPosition.Y) * Speed;
  end
  else
  begin
    FActualPosition.X := FTargetPosition.X;
    FActualPosition.Y := FTargetPosition.Y;
  end;

  if not SizeReached then
  begin
    FActualSize.Width := FActualSize.Width + (FTargetSize.Width - FActualSize.Width) * Speed;
    FActualSize.Height := FActualSize.Height + (FTargetSize.Height - FActualSize.Height) * Speed;
  end
  else
  begin
    FActualSize.Width := FTargetSize.Width;
    FActualSize.Height := FTargetSize.Height;
  end;

  // Clamp coordinates to prevent rendering outside desktop bounds
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

  // Phase 3: Smooth Alpha Interpolation
  if FAllowTransparent then
  begin
    if not SameValue(FActualAlpha, FTargetAlpha, 0.01) then
    begin
      FActualAlpha := FActualAlpha + (FTargetAlpha - FActualAlpha) * (5.0 * DeltaTime);
      if Abs(FActualAlpha - FTargetAlpha) < 0.01 then
        FActualAlpha := FTargetAlpha;
      MarkDirty(rrInternal);
    end;
  end
  else
    FActualAlpha := 1.0; // Force opaque if transparency is not allowed

  // Phase 4: Smooth Rotation Interpolation
  if FAllowRotation then
  begin
    if not SameValue(FActualRotation, FTargetRotation, 0.1) then
    begin
      FActualRotation := FActualRotation + (FTargetRotation - FActualRotation) * (5.0 * DeltaTime);
      if Abs(FActualRotation - FTargetRotation) < 0.1 then
        FActualRotation := FTargetRotation;
      MarkDirty(rrInternal);
    end;
  end
  else
    FActualRotation := 0.0; // Force no rotation if not allowed

  // Conclude animation state unless a derived class requires continuous updates
  if PosReached and SizeReached and not FForcePhysicsUpdate and SameValue(FActualAlpha, FTargetAlpha, 0.01) and SameValue(FActualRotation, FTargetRotation, 0.1) then
    IsAnimating := False
  else
    MarkDirty(rrDragged);
end;

procedure TMRXDesktopObject.ApplyDrag(const ANewPos: TPointF);
begin
  // Respect the feature toggle
  if not FAllowDrag then
    Exit;

  // Prevent dragging while expanded to fullscreen
  if FIsFullscreen then
    Exit;

  // Prevent dragging during active position/size transitions to avoid jittering
  if IsAnimating then
    Exit;

  TargetPosition := ANewPos;
  MarkDirty(rrDragged);
end;

procedure TMRXDesktopObject.UpdateMousePosition(const AMousePos: TPointF);
begin
  // Virtual hook for derived classes (e.g., passing coordinates to TAliveHighlighter)
end;

function TMRXDesktopObject.HitTest(const APoint: TPointF): Boolean;
var
  R: TRectF;
begin
  R := RectF(Pos.X, Pos.Y, Pos.X + Size.Width, Pos.Y + Size.Height);
  Result := R.Contains(APoint);
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
  // Force a complete repaint when the control dimensions change
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
  SortedObjects: TList<TMRXDesktopObject>;
begin
  Result := nil;
  FObjectListLock.Acquire;
  try
    // Create a temporary list sorted by Z-Order to respect visual layering
    SortedObjects := TList<TMRXDesktopObject>.Create;
    try
      SortedObjects.AddRange(FObjects);
      SortedObjects.Sort(TMRXObjectSorter.Create);

      // Iterate from highest Z-Order down to lowest
      for i := SortedObjects.Count - 1 downto 0 do
      begin
        if SortedObjects[i].Visible and SortedObjects[i].HitTest(APoint) then
        begin
          Result := SortedObjects[i];
          Break;
        end;
      end;
    finally
      SortedObjects.Free;
    end;
  finally
    FObjectListLock.Release;
  end;
end;

procedure TMRXSkiaSurface.MouseMove(Shift: TShiftState; X: Single; Y: Single);
begin
  inherited;

  if FIsDragging then
  begin
    var NewPos: TPointF := TPointF.Create(X - FDragOffset.X, Y - FDragOffset.Y);

    // Direct position assignment for instant, lag-free mouse tracking
    FDragObject.Pos := NewPos;
    FDragObject.TargetPosition := NewPos; // Keep target in sync to prevent easing snap-back when released
    FDragObject.MarkDirty(rrDragged);
    Exit;
  end;

  // Manage hover effects when not dragging
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
      // Trigger slight scale-up on the hovered module, reset others
      if FObjects[i] = HoveredObj then
        FObjects[i].HotZoomTarget := 1.06
      else
        FObjects[i].HotZoomTarget := 1.0;

      // Pass absolute mouse position to modules that need it (e.g. AliveHighlighter)
      FObjects[i].UpdateMousePosition(P);
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
    // Store offset so the module doesn't snap its center to the cursor
    FDragOffset := TPointF.Create(X - FDragObject.Pos.X, Y - FDragObject.Pos.Y);
  end;
end;

procedure TMRXSkiaSurface.MouseUp(Button: TMouseButton; Shift: TShiftState; X: Single; Y: Single);
begin
  inherited;
  FIsDragging := False;
  FDragObject := nil;
end;

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
      SurfaceInfo: TSkImageInfo;
    begin
      LastTime := TThread.GetTickCount;

      // 1. Try to initialize the GPU context (OpenGL) strictly inside this thread.
      // If the user's graphics driver fails, this returns nil safely.
      try
        FGRContext := TGrDirectContext.MakeGL;
      except
        FGRContext := nil;
      end;

      while not TThread.CheckTerminated do
      begin
        CurrentTime := TThread.GetTickCount;
        DeltaSec := (CurrentTime - LastTime) / 1000.0;
        LastTime := CurrentTime;

        W := Round(Self.Width);
        H := Round(Self.Height);

        if (W > 0) and (H > 0) and ((W <> FLastRenderedW) or (H <> FLastRenderedH)) then
        begin
          SurfaceInfo := TSkImageInfo.Create(W, H, TSkColorType.RGBA8888, TSkAlphaType.Premul);

          // 2. Create the surface using the GPU context if we got one, otherwise pure CPU
          if Assigned(FGRContext) then
            FThreadSurface := TSkSurface.MakeRenderTarget(FGRContext, True, SurfaceInfo)
          else
            FThreadSurface := TSkSurface.MakeRaster(SurfaceInfo);

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

      // 3. Cleanup GPU resources safely when the thread closes
      FThreadSurface := nil;
      FGRContext := nil; // Destroys the OpenGL context
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
  begin
    // Using High quality sampling here forces GPU acceleration for the final draw call
    ACanvas.DrawImage(ImageToDraw, 0, 0, TSkSamplingOptions.High)
  end
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

        // Continue processing physics if moving, or if it has continuous internal updates
        if FObjects[i].IsAnimating or FObjects[i].FForcePhysicsUpdate then
          FObjects[i].UpdatePhysics(DeltaTime);
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
  NeedsRedraw: Boolean;
  ClearPaint: ISkPaint;
  SortedObjects: TList<TMRXDesktopObject>;
  CenterX, CenterY: Single;
  RadRotation: Single;
begin
  NeedsRedraw := False;
  FObjectListLock.Acquire;
  try
    for i := 0 to FObjects.Count - 1 do
      if FObjects[i].Visible and (FObjects[i].RedrawReason <> rrNone) then
      begin
        NeedsRedraw := True;
        Break;
      end;

    if NeedsRedraw then
    begin
      ClearPaint := TSkPaint.Create;
      ClearPaint.Style := TSkPaintStyle.Fill;
      ClearPaint.Color := FDesktopColor;

      // 1. Always clear and draw wallpaper (Safe and clean)
      FThreadSurface.Canvas.DrawRect(RectF(0, 0, AW, AH), ClearPaint);
      if Assigned(FWallpaper) then
        FThreadSurface.Canvas.DrawImageRect(FWallpaper, RectF(0, 0, AW, AH), TSkSamplingOptions.High);

      // 2. Draw all visible modules
      SortedObjects := TList<TMRXDesktopObject>.Create;
      try
        SortedObjects.AddRange(FObjects);
        SortedObjects.Sort(TMRXObjectSorter.Create);

        for i := 0 to SortedObjects.Count - 1 do
        begin
          Obj := SortedObjects[i];
          if Obj.Visible then
          begin
            FThreadSurface.Canvas.Save;

            // Calculate center for translate and rotate
            CenterX := Obj.ActualPosition.X + (Obj.Size.Width / 2);
            CenterY := Obj.ActualPosition.Y + (Obj.Size.Height / 2);

            // 1. Move origin to center of the module
            FThreadSurface.Canvas.Translate(CenterX, CenterY);

            // 2. Apply smooth rotation (convert degrees to radians)
            if Obj.AllowRotation and not SameValue(Obj.FActualRotation, 0, 0.1) then
            begin
              RadRotation := DegToRad(Obj.FActualRotation);
              FThreadSurface.Canvas.Rotate(RadRotation, 0, 0);
            end;

            // 3. Apply hover scale
            FThreadSurface.Canvas.Scale(Obj.ActualHotZoom, Obj.ActualHotZoom);

            // 4. Move origin back to top-left corner for standard module drawing
            FThreadSurface.Canvas.Translate(-(Obj.Size.Width / 2), -(Obj.Size.Height / 2));

            try
              // If the module has a pre-rendered cache (like Video), blit it directly
              if Assigned(Obj.FRenderCache) then
                FThreadSurface.Canvas.DrawImage(Obj.FRenderCache, 0, 0, TSkSamplingOptions.Low)
              else
                // Otherwise, fall back to standard live drawing
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

end.

