Engine :: struct {
    screen_width, screen_height : u32;

    is_paused      : bool;
    is_minimized   : bool;
    is_maximized   : bool;
    is_resizing    : bool;

    enable\_4x_msaa : bool;
    quality_4x_msaa : u32;


    hwnd     : Window_Type;
    renderer : Graphics_Device;
}

engine_init    :: (using engine : *Engine) -> bool {
    success := false;

    hwnd = create_window(g_window_width, g_window_height, "Untitled", wanted_msaa=WANTED_MSAA);
    success = hwnd != null;

    success = graphics_device_init(*renderer, hwnd, enable_4x_msaa, *quality_4x_msaa);

    return success;
}

engine_update  :: () {
    renderer_draw(*g_engine.renderer);
}

engine_draw2d  :: () {
}

engine_draw3d  :: () {
}

engine_postupdate :: () {
}
