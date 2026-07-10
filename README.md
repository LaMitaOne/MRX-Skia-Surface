# MRX-Skia-Surface
An experimental module rendering engine for Delphi (FMX), powered by Skia4Delphi and FFmpeg. 

Instead of using standard FMX controls, this provides a generic TMRXDesktopObject base class. The surface manages these objects in a background thread, handling Z-Index layering, hit-testing, and smooth Lerp animations.    
    
Current State (Prototype - Work in Progress, playing around :D)   
Right now, this is an active testing ground. The core threading, the Z-Index logic, and the basic compositing (with dynamic drop shadows and alpha-blending) work. Video playback is integrated to test how heavy, continuously updating modules behave alongside transparent UI widgets. 
  
So far working:  
    
  -start video playback (click on black module)   
  -video dblclick animated zoom to fullscreen and back    
  -dragging of modules   
  -mouseover hotzoom  
  -z-order   
    
<img width="1183" height="748" alt="Unbenannt" src="https://github.com/user-attachments/assets/a356c461-2a2b-4545-b1c5-ec4c49980bb0" />

requirements

     Delphi (RAD Studio)
     Skia4Delphi
     FFmpeg DLLs v8.1 or newer (libavcodec, libavformat, libswscale, libavutil)
