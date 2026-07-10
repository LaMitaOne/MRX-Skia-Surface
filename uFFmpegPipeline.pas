unit uFFmpegPipeline;

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.Skia, ffmpeg_types,
  libavcodec, libavformat, libavutil, libswscale;

type
  TFFmpegPipeline = class
  private
    FFormatCtx: PAVFormatContext;
    FCodecCtx: PAVCodecContext;
    FVideoStreamIdx: Integer;
    FSwsCtx: PSwsContext;
    FFrame: PAVFrame;
    FFrameBGRA: PAVFrame;
    FPacket: PAVPacket;
    FIsOpen: Boolean;
    FLock: TCriticalSection;

    // Target resolution for FFmpeg to scale to (usually matches the control size)
    FOutWidth: Integer;
    FOutHeight: Integer;
    FLastPTS: Int64;
    FCachedSkImage: ISkImage;

    procedure Cleanup;
  public
    constructor Create;
    destructor Destroy; override;

    // IMPORTANT: Requires the target dimensions for downscaling during decoding
    function LoadMedia(const AFileName: string; AWidth: Integer = 640; AHeight: Integer = 360): Boolean;
    function GrabNextFrame: ISkImage;
    procedure SeekToFrame(AFrameIndex: Integer);
    procedure ResizeTarget(AWidth, AHeight: Integer);
    procedure Close;

    property IsOpen: Boolean read FIsOpen;
    property Width: Integer read FOutWidth;
    property Height: Integer read FOutHeight;
  end;

implementation

{ TFFmpegPipeline }

constructor TFFmpegPipeline.Create;
begin
  inherited;
  FLock := TCriticalSection.Create;
  FFormatCtx := nil;
  FCodecCtx := nil;
  FVideoStreamIdx := -1;
  FSwsCtx := nil;
  FFrame := nil;
  FFrameBGRA := nil;
  FPacket := nil;
  FIsOpen := False;
  FLastPTS := -1;
  FOutWidth := 640;
  FOutHeight := 360;
end;

destructor TFFmpegPipeline.Destroy;
begin
  Close;
  FreeAndNil(FLock);
  inherited;
end;

procedure TFFmpegPipeline.Cleanup;
begin
  if Assigned(FSwsCtx) then
  begin
    sws_freeContext(FSwsCtx);
    FSwsCtx := nil;
  end;
  if Assigned(FFrameBGRA) then
  begin
    // NOTE: Because av_frame_get_buffer is used, av_frame_free handles the buffer deallocation.
    // Calling av_freep(@FFrameBGRA.data[0]) here would cause an Access Violation.
    av_frame_free(FFrameBGRA);
    FFrameBGRA := nil;
  end;
  if Assigned(FFrame) then
  begin
    av_frame_free(FFrame);
    FFrame := nil;
  end;
  if Assigned(FPacket) then
  begin
    av_packet_free(FPacket);
    FPacket := nil;
  end;
  if Assigned(FCodecCtx) then
  begin
    avcodec_free_context(FCodecCtx);
    FCodecCtx := nil;
  end;
  if Assigned(FFormatCtx) then
  begin
    avformat_close_input(FFormatCtx);
    FFormatCtx := nil;
  end;

  FIsOpen := False;
  FLastPTS := -1;
  FCachedSkImage := nil;
end;

procedure TFFmpegPipeline.Close;
begin
  FLock.Enter;
  try
    Cleanup;
  finally
    FLock.Leave;
  end;
end;

function TFFmpegPipeline.LoadMedia(const AFileName: string; AWidth: Integer; AHeight: Integer): Boolean;
var
  Ret: Integer;
  Codec: PAVCodec;
  St: PAVStream;
begin
  Result := False;
  Close;

  FOutWidth := AWidth;
  FOutHeight := AHeight;

  FLock.Enter;
  try
    FFormatCtx := avformat_alloc_context();
    if not Assigned(FFormatCtx) then
      Exit;

    Ret := avformat_open_input(FFormatCtx, PAnsiChar(AnsiString(AFileName)), nil, nil);
    if Ret < 0 then
      Exit;

    Ret := avformat_find_stream_info(FFormatCtx, nil);
    if Ret < 0 then
      Exit;

    Ret := av_find_best_stream(FFormatCtx, AVMEDIA_TYPE_VIDEO, -1, -1, Codec, 0);
    if Ret < 0 then
      Exit;

    FVideoStreamIdx := Ret;
    St := FFormatCtx.streams[FVideoStreamIdx];

    Codec := avcodec_find_decoder(St.codecpar.codec_id);
    if not Assigned(Codec) then
      Exit;

    FCodecCtx := avcodec_alloc_context3(Codec);
    if not Assigned(FCodecCtx) then
      Exit;

    avcodec_parameters_to_context(FCodecCtx, St.codecpar);

    Ret := avcodec_open2(FCodecCtx, Codec, nil);
    if Ret < 0 then
      Exit;

    FFrame := av_frame_alloc();
    FFrameBGRA := av_frame_alloc();

    // Allocate memory exactly for the target resolution
    FFrameBGRA.width := FOutWidth;
    FFrameBGRA.height := FOutHeight;
    FFrameBGRA.format := Integer(AV_PIX_FMT_BGRA);
    Ret := av_frame_get_buffer(FFrameBGRA, 0);
    if Ret < 0 then
      Exit;

    // OPTIMIZATION: FFmpeg scales the source video (e.g., 1080p) directly down to the target size.
    // This native C scaling is extremely fast and significantly reduces CPU load during rendering.
    FSwsCtx := sws_getContext(FCodecCtx.width, FCodecCtx.height, FCodecCtx.pix_fmt, FOutWidth, FOutHeight, AV_PIX_FMT_BGRA, SWS_BICUBIC, nil, nil, nil);

    FPacket := av_packet_alloc();

    FIsOpen := True;
    Result := True;
  finally
    FLock.Leave;
  end;
end;

function TFFmpegPipeline.GrabNextFrame: ISkImage;
var
  Ret: Integer;
  Info: TSkImageInfo;
begin
  Result := nil;
  if not FIsOpen then
    Exit;

  FLock.Enter;
  try
    while av_read_frame(FFormatCtx, FPacket) >= 0 do
    begin
      try
        if FPacket.stream_index <> FVideoStreamIdx then
          Continue;

        Ret := avcodec_send_packet(FCodecCtx, FPacket);
        if Ret < 0 then
          Break;

        while True do
        begin
          Ret := avcodec_receive_frame(FCodecCtx, FFrame);
          if Ret = AVERROR_EAGAIN then
            Break;
          if Ret = AVERROR_EOF then
            Break;
          if Ret < 0 then
            Break;

          // PTS deduplication: Only process and scale the frame if it's a new timestamp
          if FFrame.pts <> FLastPTS then
          begin
            FLastPTS := FFrame.pts;

            // Scale the frame directly into the pre-allocated target buffer
            sws_scale(FSwsCtx, @FFrame.data, @FFrame.linesize, 0, FCodecCtx.height, @FFrameBGRA.data, @FFrameBGRA.linesize);

            // Create a Skia image wrapping the FFmpeg buffer.
            // NOTE: We use FFrameBGRA.linesize[0] (the actual stride calculated by FFmpeg),
            // not just FOutWidth * 4, to ensure pixel-perfect alignment.
            Info := TSkImageInfo.Create(FOutWidth, FOutHeight, TSkColorType.BGRA8888, TSkAlphaType.Premul);
            FCachedSkImage := TSkImage.MakeFromRaster(Info, FFrameBGRA.data[0], FFrameBGRA.linesize[0], nil);
          end;

          Result := FCachedSkImage;
          av_frame_unref(FFrame);
          Break;
        end;
      finally
        av_packet_unref(FPacket);
      end;

      if Assigned(Result) then
        Break;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TFFmpegPipeline.SeekToFrame(AFrameIndex: Integer);
begin
  if not FIsOpen then
    Exit;
  FLock.Enter;
  try
    // Reset cache and PTS to force fetching a fresh frame after seeking
    FLastPTS := -1;
    FCachedSkImage := nil;
    av_seek_frame(FFormatCtx, FVideoStreamIdx, AFrameIndex, AVSEEK_FLAG_FRAME or AVSEEK_FLAG_BACKWARD);
    avcodec_flush_buffers(FCodecCtx);
  finally
    FLock.Leave;
  end;
end;

procedure TFFmpegPipeline.ResizeTarget(AWidth, AHeight: Integer);
begin

  if not FIsOpen then
    Exit;
  if (FOutWidth = AWidth) and (FOutHeight = AHeight) then
    Exit; // No resize needed

  FLock.Enter;
  try
    // 1. Free old scaling context and target frame buffer
    if Assigned(FSwsCtx) then
    begin
      sws_freeContext(FSwsCtx);
      FSwsCtx := nil;
    end;
    if Assigned(FFrameBGRA) then
    begin
      av_frame_free(FFrameBGRA);
      FFrameBGRA := nil;
    end;

    // 2. Apply new dimensions
    FOutWidth := AWidth;
    FOutHeight := AHeight;

    // 3. Allocate new buffer with the updated size
    FFrameBGRA := av_frame_alloc();
    FFrameBGRA.width := FOutWidth;
    FFrameBGRA.height := FOutHeight;
    FFrameBGRA.format := Integer(AV_PIX_FMT_BGRA);
    av_frame_get_buffer(FFrameBGRA, 0);

    // 4. Recreate the scaling context for the new resolution
    FSwsCtx := sws_getContext(FCodecCtx.width, FCodecCtx.height, FCodecCtx.pix_fmt, FOutWidth, FOutHeight, AV_PIX_FMT_BGRA, SWS_BICUBIC, nil, nil, nil);

    // 5. Clear cache so the next frame renders in the new size
    FLastPTS := -1;
    FCachedSkImage := nil;
  finally
    FLock.Leave;
  end;
end;

end.

