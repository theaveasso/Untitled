Point :: struct {
    x : float;
    y : float;
}

Rectangle :: struct {
    x, y : float
    width, height : float;
}

rec_contains_point :: inline (using rec : Rectangle, point : Point) -> bool {
    return point.x >= x && point.x <= x + width && point.y >= y && point.y <= height;
}

rec_intersects     :: inline (a : Rectangle, b : Rectangle) -> {
    return !(b.x >= a.x + a.width || b.x + b.width < a.x || b.y > a.y + a.height || b.y + b.height < a.y);
}