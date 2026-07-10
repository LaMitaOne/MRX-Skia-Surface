# MRX-Skia-Surface
An experimental module rendering engine for Delphi (FMX), powered by Skia4Delphi and FFmpeg.  
   
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/LaMitaOne/MRX-Skia-Surface)   
   

Instead of using standard FMX controls, this provides a generic TMRXDesktopObject base class. The surface manages these objects in a background thread, handling Z-Index layering, hit-testing, and smooth Lerp animations.
Current State

(Prototype - Work in Progress, playing around :D)

Right now, this is an active testing ground. The core threading, the Z-Index logic, and the basic compositing (with dynamic drop shadows and alpha-blending) work. Video playback is integrated to test how heavy, continuously updating modules behave alongside transparent UI widgets.

So far working:

     Start video playback (click on black module)
     Video dblclick animated zoom to fullscreen and back
     Dragging of modules
     Mouseover HotZoom
     Shadows   
     Z-Order layering
       
<img width="1183" height="748" alt="Unbenannt" src="https://github.com/user-attachments/assets/a356c461-2a2b-4545-b1c5-ec4c49980bb0" />
    
requirements

     Delphi (RAD Studio)
     Skia4Delphi
     FFmpeg DLLs v8.1 or newer (libavcodec, libavformat, libswscale, libavutil)
   
project and zipped sample exe included (but you need to get the dlls self, they are way too big :P)   

   https://www.gyan.dev/ffmpeg/builds/    
   
ffmpeg units from:   
   https://github.com/Laex/Delphi-FFMPEG
