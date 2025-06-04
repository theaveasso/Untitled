# Untitled

Yet another Voxel engine without title.

## Phase 0: Groundwork
- [x] Setup OpenGL context.
- [x] Setup Camera movement and controls.
- [x] Add basic input system (WASD, mouse)
- [x] Basic rendering (quad, cube, terrain[WIP])

## Phase 1: Core Voxel Structure
🎯 Goal: Create your dynamic voxel representation
- [ ] Design `Voxel` structure
- [ ] Implement `Chunk` system

## Phase 2: Meshing
🎯 Goal: Render visible voxels efficiently
- [ ] Implement greedy meshing / surface nets / Marching Cubes (for smooth surfaces)
- [ ] Cull hidden voxels (faces between filled neighbors)
- [x] Upload vertex data to OpenGL buffers (VBOs, VAOs)
- [ ] Support dynamic remeshing when voxel data changes

## Phase 3: Rendering
🎯 Goal: Make it look decent and fast
- [ ] Write voxel fragment + vertex shaders
- [ ] Add per-voxel lighting (basic Lambert or Blinn-Phong)
- Add support for:
    - [ ] Normal mapping (optional)
    - [ ] Ambient Occlusion (precomputed or SSAO)
    - [ ] Transparency (for water, glass)
- [ ] Use frustum culling to skip off-screen chunks

## Phase 4: Interactivity
🎯 Goal: World changes in real-time
- [ ] Raycast picking (select voxel under cursor)
- [ ] Add / remove / modify voxels at runtime
- [ ] Dynamic chunk remeshing on edit

## Phase 5: Optimization
🎯 Goal: Make it scalable
- [ ] Multithread chunk meshing and generation
- [ ] Implement LOD system (more coarse far away)
- [ ] Use spatial partitioning for updates (e.g., octree)
- [ ] Implement chunk streaming (load/unload based on camera pos)

## Phase 6: World Generation (optional)
🎯 Goal: Generate interesting terrain or structures
- [ ] Perlin / Simplex noise terrain generator
- [ ] Cave generation (e.g., 3D noise or cellular automata)
- [ ] Place trees/structures procedurally

## Phase 7: Polishing & Extras
🎯 Goal: Make it feel like a game engine
- [ ] Basic UI (debug info, FPS counter)
- [ ] Post-processing (FXAA, bloom, etc.)
- [ ] Save/load voxel world (binary or compressed formats)
- [ ] Physics / collision (AABB or voxel-aware)

