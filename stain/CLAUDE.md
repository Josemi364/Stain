# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Stain** is a laundry management game built in **Godot 4.6** (GDScript). Players manually clean garments with mouse input, assign clothes to washing machines, and purchase upgrades. Currency types: `euros`, `ceniza` (ash), and `fragmentos` (fragments). Alien garments are rarer, more valuable, and only processable by quantum machines.

## Running the Game

Open the project in the **Godot 4.6 editor** and press F5, or run:
```
godot --path . res://main.tscn
```
There is no build step or test suite — gameplay verification requires running in the editor.

## Architecture

### Central Controller Pattern

`Main.gd` is the single orchestrator. All subsystems communicate upward through signals; Main processes consequences and calls back down. Subsystems never reference each other directly.

```
Main.gd  ←→  SinkArea.gd       (manual cleaning gameplay)
         ←→  QueuePanel.gd     (FIFO garment queue, 5 slots)
         ←→  MachinesPanel.gd  (automated washing machines)
         ←→  ShopPanel.gd      (permanent upgrades)
         ←→  GarmentData.gd    (Autoload: garment definitions + luck system)
```

### Key Signal Flows

**Manual cleaning loop:**
`queue_panel.siguiente_prenda_lista` → `sink_area.cargar_prenda()` → player scrubs → `sink_area.garment_delivered` → Main rewards player → next garment loaded.

**Machine assignment:**
Player clicks queue slot → `queue_panel.intento_seleccion_lavadora` → Main validates (alien? quantum available?) → `machines_panel.asignar_prenda()` → `queue_panel.confirmar_extraccion()`.

**Machine completion:**
`machines_panel._process(delta)` timer expires → `prenda_procesada(prenda, earned, was_quantum)` → Main applies rewards (quantum machines halve fragment rewards for alien garments).

**Shop purchase:**
`shop_panel.upgrade_solicitado(id, precio)` → Main debits euros → `_aplicar_efecto()` modifies `sink_area.bonus_fuerza`, `sink_area.bonus_radio`, or calls `GarmentData.añadir_suerte()`.

### State Ownership

- **Main.gd**: all player resources (`euros`, `ceniza`, `fragmentos`, `num_prestigios`)
- **SinkArea.gd**: current garment, stain image (256×256 RGBA8 texture), `bonus_fuerza`, `bonus_radio`
- **QueuePanel.gd**: `cola[]` array of pending garments
- **MachinesPanel.gd**: `lavadoras[]` array with per-machine state (garment + elapsed time)
- **GarmentData.gd** (Autoload): read-only garment definitions + mutable `suerte_acumulada`

### GarmentData (Autoload)

Global singleton with two constant arrays: `PRENDAS_NORMALES` (6 types, 2–8€) and `PRENDAS_ALIEN` (4 types, 15–40€ + ash/fragments). Alien spawn probability starts at 1.5%, caps at 25%, increased by shop upgrades via `añadir_suerte(valor)`.

### SinkArea Stain System

Stains are procedurally generated at garment load time. Each stain type (Ketchup, Café, Sangre, Plasma Alien, etc.) is defined by a profile dictionary controlling blob count/size, edge irregularity (multi-frequency sine waves), drip direction/length, splatter, and color variation. Cleaning tracks progress via pixel alpha values; auto-completes at 80% threshold.

### MachinesPanel Machine Types

| Type | Price | Cycle | Accepts Alien | Max |
|------|-------|-------|---------------|-----|
| Basic | 150€ | 30s | No | 3 |
| Industrial | 400€ + 3 ash | 20s | No | 2 |
| Quantum | 1500€ + 15 ash | 15s | Yes | 1 |

## Key Implementation Details

- **Texture generation**: `SinkArea` creates a dynamic `Image` (256×256, FORMAT_RGBA8) for stain tracking; pixel alpha cleared during scrubbing.
- **Frame skipping**: Stain progress measured every `FRAMES_ENTRE_MEDICIONES = 5` frames to avoid per-frame pixel counting.
- **Machine drums**: Each machine card has a static body SVG and a rotating drum SVG; rotation speed scales with machine type.
- **Notifications**: Transient HUD messages use tweens for fade-in/out.
- **Upgrade prerequisites**: Shop upgrade tree enforced in `ShopPanel.gd`; purchased state tracked in a local dictionary.
