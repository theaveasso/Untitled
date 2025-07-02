
CPU_Timer :: struct {
    current:    float = 0.016667;
    DT_MAX:     float = 0.15;   

    last : float64;
}

cpu_timer_init :: (using cpu_timer: *CPU_Timer) {
    last = seconds_since_init();
}

cpu_timer_tick :: () {

    using g_cputimer;
    now := seconds_since_init();
    delta : float64 = now - last;
    current = cast(float) delta;

    if current > DT_MAX current = DT_MAX;

    last = now;
}