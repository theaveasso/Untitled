#if OS == .WINDOWS {
    #load "bindings/windows/windows.jai";
} else {
    #assert false "this OS is not currently supported by llhttp. You must generate bindings for it. Check the README for information.";
}
