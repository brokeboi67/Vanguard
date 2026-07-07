# 🛡️ Vanguard Runtime Instrumentation & Debugging Suite (Vanguard RIDS)

Vanguard RIDS is an advanced, modular instrumentation toolkit and spatial diagnostics framework designed for Roblox Lua runtime environments. Developed for researchers and developers, Vanguard provides tools to analyze rendering engines, simulate high-frequency user inputs, inspect 3D character rigs, audit environmental lighting, and implement client-side accessibility features in real-time.

---

## 🔬 Core Capabilities

### 📐 Spatial Diagnostics & Rig Analysis (formerly ESP)
- **Spatial Boundaries:** Generates dynamic 2D bounding boxes and viewport alignments to visualize bounding calculations.
- **Skeletal Rig Visualization:** Renders interactive skeletal joints overlaying R6 and R15 rigs for debugging character animations.
- **Line-of-Sight (LoS) Raycasting:** Runs real-time raycasting audits between the camera viewport and character parts to identify occlusion properties.
- **Off-Screen Tracking:** Renders directional markers along screen edges to debug camera frustum culling.

### 🎮 Input Simulation & Assistive Control Models (formerly Aimbot)
- **Target Tracking Simulation:** Simulated client camera adjustments using mathematical curves, customizable field-of-view (FOV) thresholds, and interpolation smoothing.
- **Automated Input Dispatcher:** Fires automated inputs based on dynamic target visibility to stress-test weapon activation structures and network replication.
- **Custom Input Bindings:** Maps custom triggers (mouse/keyboard events) to script actions.

### 🎨 Render & Lighting Instrumentation (formerly World)
- **Lighting Profiles:** Overrides global lighting properties, enabling custom color correction, saturation, outdoor ambient tinting, and shadows.
- **Atmospheric Filters:** Toggles and calibrates fog boundaries and atmosphere densities.
- **Post-Processing Overlays:** Enables real-time adjustments of Bloom, Blur, and Sun Rays.

### 🎵 Dynamic Media Streaming
- **External Stream Integration:** Dynamically fetches and plays audio assets from cloud APIs (Audius, Archive.org) and local disk folders to test audial processing interfaces.
- **Widget Interface:** Built-in UI widget to monitor media buffer speeds and track metadata.

### 🛡️ Sandboxing & Thread Isolation
- **Secure GUI Instantiation:** Leverages robust sandbox wrappers (`gethui`, `cloneref`, `syn.protect_gui`) to evaluate interface isolation against detection algorithms.
- **Weak Reference Protection:** Utilizes weak-keyed tables (`__mode = "k"`) to prevent reference leaks and prevent script memory tracking.

---

## 🚀 Execution & Setup

To initialize Vanguard RIDS in your research sandbox environment, execute the main entry bootstrapper:

```lua
local repo = "https://raw.githubusercontent.com/ihatelgbt2-art/Test/main/"
loadstring(game:HttpGet(repo .. "Main.lua"))()
```

---

## 📂 Codebase Reference

| Module | Purpose |
|---|---|
| [Main.lua](file:///c:/Users/Admin/Documents/Vanguard/Main.lua) | Entry-point bootstrapper that fetches and dynamically executes modular components. |
| [Core.lua](file:///c:/Users/Admin/Documents/Vanguard/Core.lua) | Coordinates lifecycle management, duplicate prevention, and garbage collection hook procedures. |
| [Settings.lua](file:///c:/Users/Admin/Documents/Vanguard/Settings.lua) | Core configurations registry specifying simulation and visualization metrics. |
| [Config.lua](file:///c:/Users/Admin/Documents/Vanguard/Config.lua) | Implements client-side serialization and deserialization of settings. |
| [I18n.lua](file:///c:/Users/Admin/Documents/Vanguard/I18n.lua) | Dynamic internationalization and localized string resource map. |
| [Util.lua](file:///c:/Users/Admin/Documents/Vanguard/Util.lua) | High-performance helper algorithms (raycasts, parts resolution, and virtual mouse events). |
| [AntiBypass.lua](file:///c:/Users/Admin/Documents/Vanguard/AntiBypass.lua) | Evaluates GUI concealment metrics against host process detection loops. |
| [ESP.lua](file:///c:/Users/Admin/Documents/Vanguard/ESP.lua) | Drawing framework to render skeletal structures and boundary visualizations. |
| [Aim.lua](file:///c:/Users/Admin/Documents/Vanguard/Aim.lua) | Handles automated tracking logic, input curves, and viewport-to-world conversion metrics. |

---

## ⚠️ Disclaimer

This repository is maintained for educational and diagnostic analysis purposes. It is designed to assist developers in understanding runtime memory inspection, rendering processes, and input automation. Please ensure compliance with the target environment's Terms of Service when executing diagnostics scripts.
