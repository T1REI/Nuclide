<div align="center">

# ⚛️ Nuclide

### A new optimized experience.

**Fast, open and reliable client modules for Roblox — built with [Rayfield](https://docs.sirius.menu/rayfield).**

---

[![Version](https://img.shields.io/badge/Version-0.0.1-8b5cf6?style=for-the-badge&logo=atom&logoColor=white)](https://github.com/NuclideModules/Nuclide)
[![ESP Module](https://img.shields.io/badge/ESP_Module-v0.0.1-22c55e?style=for-the-badge)](#-modules)
[![Open Source](https://img.shields.io/badge/Open_Source-100%25-0ea5e9?style=for-the-badge)](#-open-source)
[![No Obfuscation](https://img.shields.io/badge/No_Obfuscation-True-ef4444?style=for-the-badge)](#-open-source)
[![No Key System](https://img.shields.io/badge/No_Key_System-True-f59e0b?style=for-the-badge)](#-open-source)
[![License](https://img.shields.io/badge/License-MIT-facc15?style=for-the-badge)](#-license)

---

### 🚀 Quick links

[![GET STARTED](https://img.shields.io/badge/GET_STARTED-18181b?style=for-the-badge)](#-installation)
[![COPY main.lua](https://img.shields.io/badge/COPY_main.lua-2f81f7?style=for-the-badge)](https://raw.githubusercontent.com/NuclideModules/Nuclide/main/main.lua)
[![COPY nucesp.lua](https://img.shields.io/badge/COPY_nucesp.lua-2f81f7?style=for-the-badge)](https://raw.githubusercontent.com/NuclideModules/Nuclide/main/nucesp.lua)
[![RAYFIELD DOCS](https://img.shields.io/badge/RAYFIELD_DOCS-1b2a41?style=for-the-badge)](https://docs.sirius.menu/rayfield)

</div>

---

## 📖 About

Nuclide is a collection of open-source client modules for Roblox. The whole project is built around one idea:

> **A new optimized experience.**

Every module is written in modern Luau with OOP design and published fully open — no obfuscation, no hidden code, no keys. What you see on GitHub is exactly what runs.

---

## ✨ Features

- 🧠 **OOP architecture** — clean classes, no spaghetti globals
- 🧱 **Modular design** — each feature ships as its own independent module
- 🖥️ **Modern UI** — powered by [Rayfield](https://docs.sirius.menu/rayfield)
- 📂 **Config saving** — settings persist between sessions
- 🕊️ **100% open source** — every line is public, readable and auditable

---

## 🧩 Modules

| Module | Version | Description | Status |
| :--- | :--- | :--- | :--- |
| 🎯 **NuclideESP** | `0.0.1` | Player ESP module — skeleton release, rendering API coming in `v0.1.0` | 🚧 In development |
| 🗂️ **UI Shell** | `0.0.1` | Rayfield window with the `About` tab | ✅ Stable |

More modules are on the way — see the [Roadmap](#-roadmap).

---

## 📦 Installation

> **Requires a Luau executor** (Synapse X, Fluxus, Wave, Solara, Xeno, etc.).

### Option A — One-liner (recommended for executors)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/NuclideModules/Nuclide/main/main.lua"))()
loadstring(game:HttpGet("https://raw.githubusercontent.com/NuclideModules/Nuclide/main/nucesp.lua"))()
```

### Option B — Studio / full project

1. Insert `main.lua` as a **LocalScript** into `Workspace`.
2. Insert `nucesp.lua` as a **LocalScript** into `Workspace`.
3. Play — the Rayfield window opens with the **About** tab, and the ESP module loads.

> 📌 `main.lua` loads the Rayfield UI library from `https://sirius.menu/rayfield`.

---

## 🎮 Usage

`nucesp.lua` is currently a **skeleton release** — the module class and global instance are in place, the rendering API is coming in `v0.1.0`.

The module instance is exposed globally for future control:

```lua
local ESP = getgenv().NuclideESP

print(ESP.Version) -- 0.0.1

ESP:Start()        -- mark the module as running
ESP:Stop()         -- mark the module as stopped
```

---

## 🛣️ Roadmap

- [x] NuclideESP skeleton (`v0.0.1`)
- [x] Rayfield UI shell with `About` tab
- [ ] ESP rendering (box, health bar, name, distance)
- [ ] ESP control tab (toggles, colors, distance slider)
- [ ] Aim Assist module
- [ ] Tracer & chams module
- [ ] Config presets (save / load)
- [ ] Full test coverage with Luau unit tests

---

## 🕊️ Open Source

Nuclide is and will always be **free and open source**:

- 🔓 No key system
- 🔍 No obfuscation
- 👀 No hidden code — nothing is locked away
- 🤝 Fork it, read it, learn from it, contribute to it

We believe the best software is the software you can actually read.

---

## 🤝 Credits

- [Rayfield](https://docs.sirius.menu/rayfield) — the UI library that powers the Nuclide interface

---

## 📄 License

Distributed under the **MIT License**. Use it, modify it, ship it — just keep the license notice.

---

<div align="center">

**Made with ❤️ by the Nuclide team.**

[![Star](https://img.shields.io/github/stars/NuclideModules/Nuclide?style=social&label=Star)](https://github.com/NuclideModules/Nuclide)
[![Fork](https://img.shields.io/github/forks/NuclideModules/Nuclide?style=social&label=Fork)](https://github.com/NuclideModules/Nuclide/fork)

</div>
