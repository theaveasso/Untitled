# Untitled

🚧 This is a learning-focused renderer under construction — built with love and low-level code.

Yet another renderer engine without title. This built from the ground up using **DirectX 11** and **JAI** — focused on lighting, performance, and GPU-driven workflows. This project serves as a personal exploration of engine architecture, graphics programming, and system-level design without relying on third-party game engines.


## ✨ Features

- 🧵 **glTF Model Viewer**
  - Loads static glTF/glb files (geometry data)
  - Custom vertex layout and GPU upload pipeline
- 💡 **Forward Lighting Pass**
  - Directional light with Blinn-Phong highlights
  - Hemispheric ambient light (simple ambient approximation)
  - Per-material lighting logic in HLSL
- 🧰 **2D Sprite Batching**
  - Dynamic batching system using indexed quads
  - Ideal for UI overlays or debug rendering
- 🎨 **Material System**
  - GPU-side `StructuredBuffer<Material>` with ID-based lookup
  - Per-object constant buffer contains material index and transform
- ⚙️ **DirectX 11 Backend**
  - Manually managed device, states, buffers, and draw calls
  - Shader-driven rendering with clean buffer separation

## 🚧 Work in Progress

This project is **not yet real-time or optimized**. It's a renderer under active development, intended to test core features and rendering workflows.

Current focus areas:
- Building a simple scene/instance system
- Improving GPU material lookup and buffer management
- Adding debug overlays and shader hot-reloading (planned)

## 💼 About the Developer

I'm an aspiring graphics programmer focused on understanding the low-level foundations of rendering engines. This project reflects my hands-on approach to learning modern GPU pipelines, lighting models, and rendering techniques from scratch.

## 🔧 Tech Stack

- **Language**: Jai
- **Graphics API**: DirectX 11
- **Shader Language**: HLSL
- **Rendering**: Forward pass with lighting
- **Model Format**: glTF 2.0 (geometry/material only)

## 📌 Goals

- Build a functional forward rendering/ deferred rendering pipeline
- Showcase lighting and structured GPU material design
- Prepare a foundation for real-time rendering in the future

---

## 🛠️ How to Build

### ✅ Requirements
- Jai compiler (private beta)
- Windows OS with **DirectX 11.1**
- GPU supporting **Direct3D Feature Level 11_0** or higher
- Terminal or shell that supports running `jai` commands

### 🧱 Build Instructions

1. **Install the Jai compiler**
   - This project requires the Jai language compiler, which is currently in closed early access.

2. **Open a terminal** in the project directory

3. **Generate Bindings for ImGui**
   - This project uses **Dear ImGui** as the UI layer. You'll need to generate static bindings before building the engine.
   - Navigate to the ImGui vendor folder:
     ```sh
     cd vendor/imgui
     ```
   - Run the following Jai commands:
     ```sh
     jai generate.jai -- -compile
     jai generate.jai -- -backend_d3d11
     ```
   - This will generate the necessary static library and backend-specific bindings for DirectX 11.

4. **Compile the project**
   ```sh
   jai first.jai
   ```
