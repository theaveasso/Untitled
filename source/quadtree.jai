Quadtree :: struct {
    node : Bucket_Array(Quadtree_Node, 1024);
    root: *Quadtree_Node;
    dirty := true;
}

Quadtree_Node :: struct {
    size  : Vector2;
    bound : Rectf;

    parent : *Quadtree_Node;
    children : [..]*Quadtree_Node;

    locator : Bucket_Locator;
}