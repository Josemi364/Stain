# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Stain** is a laundry management incremental game built in **Godot 4.6** (GDScript). Players manually clean garments with mouse input, assign clothes to washing machines, and purchase upgrades. Currency types: `euros` (per-run), `ceniza` (permanent, from prestige), and `fragmentos` (narrative, permanent). Alien garments are rarer jackpots that give high euros + fragments but **no ceniza** — ceniza comes exclusively from prestiging.

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
Main.gd  ←→  SinkArea.gd        (manual cleaning gameplay)
         ←→  QueuePanel.gd      (FIFO garment queue, 5 slots)
         ←→  MachinesPanel.gd   (automated washing machines)
         ←→  ShopPanel.gd       (euro upgrades, resets on prestige)
         ←→  AshShopPanel.gd    (ceniza upgrades, permanent)
         ←→  PrestigeDialog.gd  (prestige confirmation modal)
         ←→  GarmentData.gd     (Autoload: garment definitions + luck system)
```

### Key Signal Flows

**Manual cleaning loop:**
`queue_panel.siguiente_prenda_lista` → `sink_area.cargar_prenda()` → player scrubs → `sink_area.garment_delivered` → Main rewards player → `_actualizar_estado_prestige_button()` → next garment loaded.

**Machine assignment:**
Player clicks queue slot → `queue_panel.intento_seleccion_lavadora` → Main validates (alien? `memoria_prendas_activa`? quantum available?) → `machines_panel.asignar_prenda()` → `queue_panel.confirmar_extraccion()`.

**Machine completion:**
`machines_panel._process(delta)` timer expires → `prenda_procesada(prenda, earned, was_quantum)` → Main applies rewards × `multiplicador_ganancias`.

**Euro shop purchase:**
`shop_panel.upgrade_solicitado(id, precio)` → Main debits euros → `_aplicar_efecto()`.

**Ceniza shop purchase:**
`ash_shop_panel.upgrade_ceniza_solicitado(id, coste)` → Main debits ceniza → `_aplicar_efecto_ceniza()`.

**Prestige flow:**
PrestigeButton (visible after `UMBRAL_PRESTIGIO_PRIMER_USO = 3000€`) → `prestige_dialog.mostrar()` → player confirms → `_animar_prestigio()` → `_ejecutar_prestigio()` → `prestige_realizado.emit()` → all panels reset via their canonical APIs → new run starts.

### State Ownership

- **Main.gd**: all player resources; permanent state (`multiplicador_ganancias`, `memoria_prendas_activa`, `num_prestigios`, `prestigio_desbloqueado`)
- **SinkArea.gd**: current garment, stain image (256×256 RGBA8), `bonus_fuerza`, `bonus_radio`
- **QueuePanel.gd**: `cola[]` array of pending garments
- **MachinesPanel.gd**: `lavadoras[]` array, `memoria_prendas` flag
- **AshShopPanel.gd**: `compras_contador` dict — permanent, never resets
- **GarmentData.gd** (Autoload): garment data, `suerte_euros` (resets on prestige), `suerte_ceniza` (permanent), `_forzar_siguiente_alien` debug flag

### Prestige System

- `UMBRAL_PRESTIGIO_PRIMER_USO = 3000` — euros_totales_ganados needed to reveal the button
- Ceniza formula: `floor(euros_totales_ganados / 1000) + 1`
- Button disabled (dark) if calculated ceniza < 3; active (red) otherwise
- Resets: euros, all euro upgrades, all machines, queue, sink bonuses, `suerte_euros`
- Preserved: ceniza, fragmentos, `suerte_ceniza`, ash shop purchases, multiplier

### Panel Reset APIs (canonical names)

Each panel exposes a public reset method. `reset_para_prestigio()` exists as a compatibility alias but delegates to the canonical method. Main also calls these directly from the debug F2 full reset.

| Panel | Canonical method | Additional debug method |
|---|---|---|
| ShopPanel | `reset_compras()` | — |
| MachinesPanel | `reset_lavadoras()` | `completar_todos_los_ciclos()` |
| QueuePanel | `reset_cola()` | — |
| SinkArea | `reset_sink()` | `limpiar_instantaneo()` |
| AshShopPanel | `on_prestige_realizado()` | `reset_completo()` |

### GarmentData (Autoload)

- `PRENDAS_NORMALES` (6 types, 3–10€ avg 6.33€)
- `PRENDAS_ALIEN` (4 types, 30–80€, `ceniza_bonus=0`, `fragmentos_bonus=2–3`)
- Luck split: `suerte_euros` (from € shop, resets on prestige) + `suerte_ceniza` (from ash shop, permanent)
- Debug: `forzar_siguiente_alien()` forces the next generated garment to be alien (one-shot)

### MachinesPanel Machine Types

| Type | Price | Ceniza | Cycle | Accepts Alien | Max |
|------|-------|--------|-------|---------------|-----|
| Basic | 100€ | 0 | 20s | No (unless memoria_prendas) | 3 |
| Industrial | 350€ | 3🜁 | 15s | No (unless memoria_prendas) | 2 |
| Quantum | 1200€ | 12🜁 | 12s | Yes | 1 |

### Debug Panel (`DEBUG_MODE = true` in main.gd)

Plegable en la esquina superior izquierda del HUD. Cambiar a `false` para builds de release — ni el panel ni los atajos de teclado se registran.

| Atajo | Acción |
|---|---|
| F1 | +10.000€, +5🜁, +3 fragmentos |
| F2 | Reset total (con confirmación modal) |
| F3 | Forzar siguiente prenda como alien |
| F4 | Completar ciclos de todas las lavadoras activas |
| F5 | Limpiar prenda actual al 100% (activa el botón de entregar) |

## Key Implementation Details

- **Texture generation**: `SinkArea` creates a dynamic `Image` (256×256, FORMAT_RGBA8) for stain tracking; pixel alpha cleared during scrubbing.
- **Frame skipping**: Stain progress measured every `FRAMES_ENTRE_MEDICIONES = 5` frames.
- **Machine drums**: Each machine card has a static body SVG and a rotating drum SVG.
- **Earnings multiplier**: `multiplicador_ganancias` (permanent) applied in both `_on_garment_delivered` and `_on_prenda_procesada_lavadora` before accumulating `euros_totales_ganados`.
- **Prestige button reveal**: `_actualizar_estado_prestige_button()` called on every income event; first call past 3000€ total makes the button appear with a notification.
