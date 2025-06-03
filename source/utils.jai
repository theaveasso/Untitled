array_normalize :: inline ($T : Type, array : []T, min_range : T, max_range : T) {
    min, max : T = 0;

    for array {
        if it < min min = it;
        if it > max max = it;
    }

    min_max_delta : T;
    if max - min == 0 return; else min_max_delta = max - min; 

    scale := (max_range - min_range) / min_max_delta;
    for array it = (it - min) * scale + min_range;
}