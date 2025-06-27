#if OS == .WINDOWS {
    #load "windows/windows_d3d11.jai";

    #library,system,link_always "dwmapi";
    #library,system,link_always "user32";
    #library,system,link_always "shell32";
}