# MRX-Skia-Surface
An experimental module rendering engine for Delphi (FMX), powered by Skia4Delphi and FFmpeg.  
   
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/LaMitaOne/MRX-Skia-Surface)   
   

Instead of using standard FMX controls, this provides a generic TMRXDesktopObject base class. The surface manages these objects in a background thread, handling Z-Index layering, hit-testing, and smooth Lerp animations.
Current State

(Prototype - Work in Progress, playing around :D)

Right now, this is an active testing ground. The core threading, the Z-Index logic, and the basic compositing (with dynamic drop shadows and alpha-blending) work. Video playback is integrated to test how heavy, continuously updating modules behave alongside transparent UI widgets.  
   
<img width="1183" height="748" alt="Unbenannt" src="https://github.com/user-attachments/assets/a356c461-2a2b-4545-b1c5-ec4c49980bb0" />
   

So far working:

     Start video playback (click on black module)
     Video dblclick animated zoom to fullscreen and back
     Dragging of modules
     Mouseover HotZoom
     Shadows   
     Z-Order layering
       

 ----Latest Changes   
   v 0.2   
    - Replaced static Enum Z-Indexing with dynamic Integer Z-Ordering.    
    - Moved Modules in single unit.   
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
    
    
requirements

     Delphi (RAD Studio)
     Skia4Delphi
     FFmpeg DLLs v8.1 or newer (libavcodec, libavformat, libswscale, libavutil)
   
project and zipped sample exe included (but you need to get the dlls self, they are way too big :P)   

   https://www.gyan.dev/ffmpeg/builds/    
 - take those: ffmpeg-release-full-shared
   
ffmpeg units from:   
   https://github.com/Laex/Delphi-FFMPEG
