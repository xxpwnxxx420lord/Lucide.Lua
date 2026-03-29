# 🔷 Lucide.Lua

<div align="center">

![Lua](https://img.shields.io/badge/Lua-2C2D72?style=for-the-badge&logo=lua&logoColor=white)
![Roblox](https://img.shields.io/badge/Roblox-000000?style=for-the-badge&logo=roblox&logoColor=white)
![License: MIT](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Icons](https://img.shields.io/badge/Icons-1694%2B-orange?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-Active-brightgreen?style=for-the-badge)

**A pure-Lua port of the entire [Lucide](https://lucide.dev) icon library for Roblox — with zero dependencies, runtime SVG rasterization, full color + size control, and built-in disk caching.**

[Usage](#-usage) · [API](#-api-reference) · [Examples](#-examples) · [Contributing](#-contributing)

</div>

---

## 📚 Table of Contents

- [Introduction](#-introduction)
- [Key Features](#-key-features)
- [How It Works](#-how-it-works)
- [Project Structure](#-project-structure)
- [Installation](#-installation)
- [Usage](#-usage)
- [API Reference](#-api-reference)
- [Examples](#-examples)
- [Icon Naming](#-icon-naming)
- [Contributing](#-contributing)
- [Authors](#-authors)
- [License](#-license)

---

## 🌟 Introduction

**Lucide.Lua** (also stylized as *Lucide.luaU*) eliminates the icon integration nightmare that every Roblox developer knows too well — no more manually exporting SVGs to PNGs, no more hunting down white variants of icons, no more re-uploading assets every time a color needs to change.

This library ships **1,694+ icons** from the Lucide icon set directly into your Roblox scripts. Under the hood, it implements a complete SVG-to-PNG rasterizer written entirely in Luau — including Bézier curve sampling, arc interpolation, stroke rendering, and valid PNG encoding with CRC32 and Adler32 checksums — all without a single external dependency.

The result: request any icon at any size, in any hex color, with any stroke width, and receive a fully rendered PNG asset ready to drop into an `ImageLabel`.

> **Target Environment:** Roblox exploit/executor context (requires `game:HttpGet`, `makefolder`, `writefile`, `isfile`, `getcustomasset`)

---

## ✨ Key Features

- 🎨 **Full color control** — pass any hex color (`#ff6b6b`, `#00f0ff`, `#ffffff`) at call time
- 📐 **Arbitrary sizing** — render icons at any pixel size, not just preset dimensions
- ✏️ **Stroke width control** — adjust line weight per icon independently
- ⚡ **Disk caching** — rendered PNGs are cached to `lucide_cache/` so repeated calls cost nothing
- 🔁 **Alias support** — use `arrow-right` or `arrow_right` interchangeably
- 📦 **1,694+ icons** — the full Lucide set, chunked across 9 loader files
- 🛠️ **Zero dependencies** — the entire PNG pipeline is implemented in pure Luau
- 🌐 **Remote loading** — fetches and executes chunks lazily from GitHub at runtime

---

## ⚙️ How It Works

Lucide.Lua is built on three layers that work together seamlessly:

```
┌─────────────────────────────────────────────────┐
│                  lucide.lua                      │
│         Entry point & public API (:geticon)      │
└────────────────────┬────────────────────────────┘
                     │ loads remotely
         ┌───────────┴───────────┐
         ▼                       ▼
  icons/chunk_01.lua       Converter.lua
  icons/chunk_02.lua    ┌──────────────────────┐
       ...              │  SVG Node Parser      │
  icons/chunk_09.lua    │  Path Rasterizer      │
                        │  Bézier Sampler       │
  (1,694+ icon defs     │  Stroke Renderer      │
   as Lua SVG trees)    │  PNG Encoder          │
                        │  CRC32 + Adler32      │
                        └──────────────────────┘
                                 │
                                 ▼
                        lucide_cache/*.png
                     (keyed by name+size+sw+color)
```

**Step by step:**

1. `lucide.lua` is loaded via `HttpGet` in your executor script
2. On first load, it fetches `Converter.lua` and all 9 icon chunk files from GitHub
3. Icon chunks are merged into a single flat lookup table (`IconData`) with hyphen and underscore aliases
4. When you call `:geticon(name, opts)`, it checks the disk cache first
5. On a cache miss, it passes the SVG node tree through `Converter.toPNG()` which rasterizes SVG paths into an RGBA pixel buffer, then encodes it as a valid PNG binary
6. The PNG is written to disk via `writefile`, then served back via `getcustomasset`

---

## 📁 Project Structure

```
Lucide.Lua/
├── lucide.lua          # Main module — entry point, icon loader, :geticon() API
├── Converter.lua       # Pure-Lua SVG-to-PNG rasterizer (385 lines, zero deps)
├── example.lua         # Minimal usage example (ScreenGui + ImageLabel)
├── Readme.md           # Original readme
└── icons/
    ├── chunk_01.lua    # Icon definitions 1/9  (~58 KB)
    ├── chunk_02.lua    # Icon definitions 2/9  (~66 KB)
    ├── chunk_03.lua    # Icon definitions 3/9  (~61 KB)
    ├── chunk_04.lua    # Icon definitions 4/9  (~68 KB)
    ├── chunk_05.lua    # Icon definitions 5/9  (~63 KB)
    ├── chunk_06.lua    # Icon definitions 6/9  (~64 KB)
    ├── chunk_07.lua    # Icon definitions 7/9  (~65 KB)
    ├── chunk_08.lua    # Icon definitions 8/9  (~63 KB)
    └── chunk_09.lua    # Icon definitions 9/9  (~31 KB)
```

### Key Files

| File | Purpose |
|---|---|
| `lucide.lua` | Public API. Fetches all remote modules, merges icon data, exposes `:geticon()` |
| `Converter.lua` | The rasterizer. Implements CRC32, Adler32, PNG encoding, SVG path parsing, cubic/quadratic Bézier sampling, elliptical arc interpolation, and polyline stroke rendering |
| `icons/chunk_*.lua` | Lua tables mapping icon names to arrays of SVG node descriptors (`tag`, `attrs`) |
| `example.lua` | Bootstraps a `ScreenGui` with a centered `ImageLabel` to demonstrate the library |

---

## 🚀 Installation

No package manager needed. Load directly in your executor:

```lua
local lucide = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/xxpwnxxx420lord/Lucide.Lua/refs/heads/main/lucide.lua",
    true
))()
```

That single line fetches and initializes the entire library — all 9 icon chunks and the converter — automatically. Icons render on first use and are cached to `lucide_cache/` in your executor's working directory.

<Callout type="info">
  **Requirements:** Your executor must support `game:HttpGet`, `makefolder`, `writefile`, `isfile`, and `getcustomasset`. Most modern Roblox executors support these.
</Callout>

<Callout type="warning">
  **First Load:** The initial load fetches ~540 KB of icon data across 9 HTTP requests. Subsequent loads benefit from Lua's module cache. Individual icon renders are cached to disk and never re-processed.
</Callout>

---

## 💡 Usage

### Basic

```lua
local lucide = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/xxpwnxxx420lord/Lucide.Lua/refs/heads/main/lucide.lua",
    true
))()

-- Get an icon as a custom asset path
local icon = lucide:geticon("arrow-right", {
    size = 48,
    color = "#ffffff",
    stroke_width = 1.5,
})

-- Use it anywhere an ImageLabel accepts an asset
myImageLabel.Image = icon
```

### Display in a ScreenGui

```lua
local lucide = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/xxpwnxxx420lord/Lucide.Lua/refs/heads/main/lucide.lua",
    true
))()

local icon = lucide:geticon("arrow-right", {
    size = 48,
    color = "#ffffff",
    stroke_width = 1.5,
})

local screenGui = Instance.new("ScreenGui")
screenGui.ResetOnSpawn = false
screenGui.Parent = game.CoreGui

local imageLabel = Instance.new("ImageLabel")
imageLabel.Image = icon
imageLabel.Size = UDim2.new(0, 48, 0, 48)
imageLabel.Position = UDim2.new(0.5, -24, 0.5, -24)
imageLabel.BackgroundTransparency = 1
imageLabel.ScaleType = Enum.ScaleType.Fit
imageLabel.Parent = screenGui
```

### Multiple Icons, Multiple Colors

```lua
local icons = {
    { name = "check",     color = "#4ade80", size = 32 },
    { name = "x",         color = "#f87171", size = 32 },
    { name = "star",      color = "#facc15", size = 32 },
    { name = "heart",     color = "#fb7185", size = 32 },
    { name = "settings",  color = "#94a3b8", size = 32 },
}

for _, def in ipairs(icons) do
    local asset = lucide:geticon(def.name, {
        size = def.size,
        color = def.color,
        stroke_width = 2,
    })
    -- assign to your UI elements...
end
```

---

## 📖 API Reference

### `lucide:geticon(name, opts?)`

Renders and returns a `getcustomasset` path for the requested icon.

**Parameters**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `name` | `string` | ✅ | Icon name (e.g. `"arrow-right"`, `"settings"`, `"heart"`) |
| `opts` | `table` | ❌ | Options table (see below) |

**Options (`opts`)**

| Key | Type | Default | Description |
|---|---|---|---|
| `size` | `number` | `64` | Output PNG dimensions in pixels (square) |
| `color` | `string` | `"#ffffff"` | Hex color string for icon strokes |
| `stroke_width` | `number` | `2` | Stroke line weight in SVG units |

**Returns:** `string` — a `getcustomasset(...)` path usable as an `ImageLabel.Image` value.

**Errors:** Throws `[lucide] icon not found: <name>` if the icon name doesn't exist in the dataset.

**Example**

```lua
-- Minimal call — uses all defaults (64px, white, stroke 2)
local icon = lucide:geticon("star")

-- Fully specified
local icon = lucide:geticon("shield-check", {
    size         = 128,
    color        = "#6ee7b7",
    stroke_width = 1.5,
})
```

### Cache Behavior

Rendered icons are cached at:
```
lucide_cache/<name>_s<size>_sw<stroke_width>_c<color>.png
```

The same icon at the same size/color/stroke is **never re-rasterized** across sessions — the cached PNG is served directly via `getcustomasset`.

---

## 🖼️ Examples

### Icon Naming

Lucide.Lua accepts both **hyphenated** and **underscore** variants of every icon name:

```lua
lucide:geticon("arrow-right")   -- ✅ hyphenated (canonical Lucide name)
lucide:geticon("arrow_right")   -- ✅ underscore alias (auto-generated)
```

Both resolve to the same underlying icon data.

### Sizing Guide

| `size` | Best for |
|---|---|
| `16–24` | Inline text icons, small indicators |
| `32–48` | Toolbar buttons, list item icons |
| `64` | Default — cards, feature icons |
| `96–128` | Hero sections, large UI panels |

### Color Tips

Any valid hex color works, including shorthand:

```lua
lucide:geticon("zap", { color = "#fff" })       -- shorthand white
lucide:geticon("zap", { color = "#ffffff" })     -- full white
lucide:geticon("zap", { color = "#f97316" })     -- orange
lucide:geticon("zap", { color = "#818cf8" })     -- indigo
```

<Callout type="tip">
  **Stroke Width Tip:** Values between `1.5` and `2` match the reference Lucide aesthetic. Go below `1` for ultra-thin decorative icons, or above `2.5` for bold/chunky UI styles.
</Callout>

---

## 🏗️ Converter Internals

`Converter.lua` is the heart of the library — a self-contained SVG rasterization pipeline:

| Component | Implementation |
|---|---|
| PNG encoding | Raw RGBA pixel buffer → IDAT/IHDR/IEND chunks |
| Checksum | CRC32 (polynomial `0xEDB88320`) + Adler32 |
| SVG paths | Full `d` attribute parser: M, L, H, V, C, S, Q, T, A, Z commands |
| Curves | Cubic & quadratic Bézier adaptive sampling |
| Arcs | Elliptical arc via center parameterization (SVG spec §B.2.4) |
| Stroke | Distance-to-segment antialiased polyline rasterizer |
| Color | Hex3 / Hex6 parser with `currentColor` fallback |

This means icons render identically to their browser counterparts — no pre-baked sprites, no lossy re-encoding.

---

## 🤝 Contributing

Contributions are welcome! Here's how to get involved:

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/my-improvement`
3. **Commit** your changes: `git commit -m "feat: add xyz"`
4. **Push** to your fork: `git push origin feature/my-improvement`
5. **Open a Pull Request** against `main`

**Good contribution ideas:**
- Adding missing Lucide icons from newer upstream releases
- Performance improvements to the rasterizer
- Additional color format support (RGB, HSL)
- `ImageButton` helper utilities
- Preload/batch fetch helpers

---

## 👥 Authors

- **[@Syntaxical](https://github.com/xxpwnxxx420lord)** — Original developer, SVG rasterizer, Roblox integration
- **[@lucide-icons](https://github.com/lucide-icons)** — Icon source (SVG definitions)

> If you use Lucide.Lua in a project that gains traction, reach out at **triocantgetme@gmail.com** — the author would love to hear about it.

---

## 📄 License

[MIT](https://choosealicense.com/licenses/mit/) © Syntaxical

Permission is hereby granted, free of charge, to any person obtaining a copy of this software, to deal in the software without restriction — including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies — subject to the above copyright notice appearing in all copies.

---

<div align="center">

Made with 💖 and a lot of Bézier math

⭐ Star this repo if it saved you time

Will add Lucide LAB Icons later

</div>
