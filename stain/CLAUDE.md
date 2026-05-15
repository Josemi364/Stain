# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Stain** is a laundry management incremental game built in **Godot 4.6** (GDScript). Players manually clean garments with mouse input, assign clothes to washing machines, and purchase upgrades. Currency types: `euros` (per-run), `ceniza` (permanent, from prestige, spent at the ash shop), and `fragmentos` ✧ (permanent, from alien garments, spent at the Altar de Fragmentos for narrative-themed permanent perks). Alien garments are rarer jackpots that give high euros + fragments but **no ceniza** — ceniza comes exclusively from prestiging.

The game persists state to `user://stain_save.json` (autosave every 30 s + on close + on prestige). See "Persistence (Fase 6)" below for the schema.

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
Main.gd  ←→  SinkArea.gd               (manual cleaning gameplay)
         ←→  QueuePanel.gd             (FIFO garment queue, 5 slots)
         ←→  MachinesPanel.gd          (automated washing machines)
         ←→  ShopPanel.gd              (euro upgrades, resets on prestige)
         ←→  AshShopPanel.gd           (ceniza upgrades, permanent)
         ←→  FragmentShopPanel.gd      (fragment "altar" upgrades, permanent)
         ←→  AchievementsOverlay.gd    (logros + stats modal, Fase 8)
         ←→  PrestigeDialog.gd         (prestige confirmation modal)
         ←→  GarmentData.gd            (Autoload: garments + luck + unlock pool)
         ←→  Stats.gd                  (Autoload: stats + achievements, Fase 8)
         ←→  AudioManager.gd           (Autoload: procedural SFX, Fase 9)
         ←→  EventsManager.gd          (Autoload: eventos temporales, Fase 10)
         ←→  TutorialManager.gd        (hijo de HUD: tutorial guiado, Fase 11A)
         ←→  ContractsManager.gd       (Autoload: contratos opcionales, Fase 13)
         ←→  AlliesOverlay.gd          (hijo de HUD: cantina aliados, Fase 17)
         ←→  TranscendOverlay.gd       (hijo de HUD: sala de esencia, Fase 18)
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

**Fragment shop purchase:**
`fragment_shop_panel.upgrade_fragmento_solicitado(id, coste)` → Main debits fragmentos → `_aplicar_efecto_fragmento()` → may mutate `GarmentData.bonus_prob_alien`, `GarmentData.prendas_desbloqueadas`, `machines_panel.bonus_reduccion_ciclo_cuantica`, or flags on Main (`bonus_frag_alien`, `bonus_recompensa_alien`, `bonus_ceniza_prestigio`, `comunion_activa`).

**Prestige flow:**
PrestigeButton (visible after `UMBRAL_PRESTIGIO_PRIMER_USO = 3000€`) → `prestige_dialog.mostrar()` → player confirms → `_animar_prestigio()` → `_ejecutar_prestigio()` → `prestige_realizado.emit()` → all panels reset via their canonical APIs → new run starts.

### State Ownership

- **Main.gd**: all player resources; permanent state (`multiplicador_ganancias`, `memoria_prendas_activa`, `num_prestigios`, `prestigio_desbloqueado`); Fase 7 flags (`bonus_frag_alien`, `bonus_recompensa_alien`, `bonus_ceniza_prestigio`, `comunion_activa`)
- **SinkArea.gd**: current garment, stain image (256×256 RGBA8), `bonus_fuerza`, `bonus_radio`
- **QueuePanel.gd**: `cola[]` array of pending garments
- **MachinesPanel.gd**: `lavadoras[]` array, `memoria_prendas` flag, `bonus_reduccion_ciclo_cuantica`
- **AshShopPanel.gd**: `compras_contador` dict — permanent, never resets
- **FragmentShopPanel.gd**: `compras_contador` dict — permanent, never resets
- **GarmentData.gd** (Autoload): garment data, `suerte_euros` (resets on prestige), `suerte_ceniza` (permanent), `bonus_prob_alien` (Fase 7, permanent), `prendas_desbloqueadas` (Fase 7, permanent), `_forzar_siguiente_alien` debug flag

### Prestige System

- `UMBRAL_PRESTIGIO_PRIMER_USO = 2000` (Fase 11B, antes 3000) — euros_totales_ganados needed to reveal the button
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
| FragmentShopPanel | (no se resetea en prestigio) | `reset_completo()` |
| Stats (Autoload) | (no se resetea en prestigio) | `reset_completo()` |
| EventsManager (Autoload) | (no se resetea en prestigio) | `reset_completo()` |

### Altar de Fragmentos (Fase 7)

`FragmentShopPanel.gd` es la tercera tienda, pagada con ✧ (fragmentos). Estado **permanente** — nunca se resetea en prestigio. Tab dedicada (`TabFragmentos`) junto a `TabTienda` y `TabCeniza`, solo una visible a la vez.

Las 8 mejoras y sus efectos:

| ID | Coste | Max | Efecto |
|---|---|---|---|
| `eco_plasma` | 3✧ | 3 | +1 fragmento por prenda alien (limpieza manual y máquina) |
| `murmullo_vacio` | 5✧ | 4 | +10% € en prendas alien (acumulable a +40%, antes de multiplicador) |
| `compas_observador` | 10✧ | 1 | +2% probabilidad base de prendas alien |
| `compresor_temporal` | 12✧ | 1 | Lavadora cuántica: -20% tiempo de ciclo (retroactivo) |
| `sudario_mensajero` | 15✧ | 1 | Desbloquea prenda alien (100€, +4✧) |
| `resonancia_ancestral` | 20✧ | 1 | Prestigio: +1 ceniza base adicional |
| `velo_inicio` | 30✧ | 1 | Desbloquea prenda alien legendaria (150€, +5✧) |
| `comunion` | 40✧ | 1 | 20% prob. duplicar fragmentos en limpieza manual de alien |

**Coste de implementación**: los efectos se almacenan como state directo en `Main`/`GarmentData`/`MachinesPanel`. El `compras_contador` del panel es solo para UI (✓ y disabled); los efectos se persisten por separado en sus owners. Al cargar partida, los efectos se restauran sin "replay" de compras.

### Trascendencia / Meta-prestigio (Fase 18)

Sistema de "soft reset" que va por encima del prestigio. Tras `TRASCENDENCIA_UMBRAL_PRESTIGIOS = 5` prestigios, aparece el botón "TRASCENDER ✺" en la esquina superior central. Al confirmar via diálogo modal, se ejecuta `_ejecutar_trascendencia()`:

- Resetea: euros, ceniza (a menos que esté `memoria_eterna`), num_prestigios, todo el ash shop, todo el altar, máquinas, sink, queue, suerte, bendiciones, aliados, GarmentData.prendas_desbloqueadas
- Conserva: `esencia`, `num_trascendencias`, `fragmentos`, `Stats` completo (contadores históricos, logros, bestiario), `tutorial`, `opciones`, `cap_multiplicador`, `_esc_mult_euros`, `esencia_compras`
- Recompensa: `esencia += max(1, floor(num_prestigios / 2))`
- Reaplica al final las mejoras de Esencia que afectan estado fresco (`aliento_eterno`, `cuna_abierta`)

Modal `transcend_overlay.gd` (botón ✺ en HUD inferior derecha, encima de 🤝) muestra 5 mejoras pagables con Esencia:

| ID | Coste ✺ | Efecto |
|---|---|---|
| `aliento_eterno` | 2 | `euros = 100` al iniciar cada run (post-prestigio y post-trascendencia) |
| `eco_ascendido` | 4 | `_esc_mult_euros = 1.05` apila con todos los demás multiplicadores de € |
| `cuna_abierta` | 7 | `machines_panel.bonus_max_basica = 1` (cap básica 3 → 4) |
| `memoria_eterna` | 12 | Conserva ceniza al trascender (consultado en `_ejecutar_trascendencia`) |
| `lavandero` | 20 | `cap_multiplicador = 5.0` (sube el techo del multi de 3.0 a 5.0) |

`machines_panel` extendido con `bonus_max_basica` (Fase 18) — verificación en `_refrescar_botones` y en `cargar_estado`. Persistido en `save.machines_panel`.

UI nueva en HUD:
- Label `✺ N` en CoinsPanel (visible solo si `esencia > 0` o `num_trascendencias > 0`)
- Botón "TRASCENDER  +N ✺" arriba-centro (offset_left 905), oculto hasta cumplir gate
- Botón ✺ inferior derecha (encima de 🤝)
- Diálogo de confirmación modal antes de trascender

4 logros nuevos: `primera_trascendencia` (Prestigio), `trascendido_5` (Prestigio, 5 trascendencias), `primera_esencia` (Hitos), `ascendido` (Hitos, las 5 mejoras).

### Sistema de Aliados / Favores (Fase 17)

Aprovecha la variable `favores` (ya declarada en Main desde fase 6 pero sin uso). +1 favor automático al completar:
- Un contrato (`_on_contrato_completado(true)`)
- Un evento VIP exitoso (`_on_evento_finalizado` rama `vip_objetivo` cumplido)

Label de favores añadido al `CoinsPanel` (HBoxContainer) en `_crear_favores_label()`. Botón 🤝 en esquina inferior derecha (encima de ⚙) abre el modal `allies_overlay.gd`.

5 aliados (compras únicas, permanentes, no resetean en prestigio):

| ID | Coste | Efecto |
|---|---|---|
| `aprendiz_veloz` | 3 ✦ | `sink_area.bonus_fuerza += 0.10` |
| `tendero` | 5 ✦ | `_ali_mult_euros = 1.05` (factor en handlers de €) |
| `mensajero` | 8 ✦ | `GarmentData.añadir_suerte_ceniza(0.02)` |
| `relojero` | 10 ✦ | `machines_panel.aplicar_bonus_velocidad_aliados(0.05)` |
| `custodio` | 15 ✦ | `bonus_ceniza_prestigio += 2` |

`machines_panel.bonus_reduccion_aliados` apila multiplicativo con `bonus_reduccion_global` (Fase 15) y `bonus_reduccion_ciclo_cuantica` (Fase 7). Refactor: `_recalcular_ciclos_lavadoras()` helper común para ambos setters de velocidad.

`_ali_mult_euros` se aplica como factor en ambos handlers de € apilando con `multiplicador_ganancias × _ev_mult_recompensa × _bend_mult_euros × _bestiario_mult`.

Persistencia en `save.main.aliados_comprados`, `_ali_mult_euros`, `_ali_red_velocidad`. `machines_panel` persiste `bonus_reduccion_aliados`. Al cargar, no se re-aplican efectos (los que están en estado, ya están guardados). `aliados_comprados` se filtra contra `ALIADO_IDS` para descartar IDs obsoletos.

2 logros nuevos en Hitos: `primer_aliado`, `circulo_completo` (los 5).

`_debug_dar_recursos` (F1) ahora también da +5 favores.

### Bestiario de prendas (Fase 16)

Cada vez que el jugador limpia una prenda (manual o lavadora), `Stats.investigar_prenda(id)` la añade al set `prendas_investigadas` si era nueva y emite `prenda_investigada(id, total)`. Main escucha y:
- Actualiza `_bestiario_mult = 1.0 + total × BESTIARIO_BONUS_POR_PRENDA` (1% por prenda, max 12% con las 12 conocidas)
- Muestra notificación "📖 Nueva prenda investigada (N)"
- Comprueba logros `bestiario_normales` (6 normales) y `bestiario_completo` (12)
- Refresca la pestaña del bestiario si está abierta (`refrescar_bestiario()`)

`_bestiario_mult` se aplica como factor en ambos handlers de € (manual y lavadora), apilando con `multiplicador_ganancias`, `_ev_mult_recompensa` y `_bend_mult_euros`.

UI: nueva pestaña en `achievements_overlay` (`refrescar_bestiario()` API pública), grid de 4 columnas con 12 cards. Prendas no investigadas se muestran como "???" con bordes apagados. Las alien tienen borde púrpura, normales azul.

`GarmentData.get_todas_prendas()` devuelve las 12 (6 normales + 4 alien base + 2 alien desbloqueables del altar). Los logros `bestiario_completo` exige desbloquear y limpiar las 2 del altar.

Persistencia en `save.stats.prendas_investigadas`. Al cargar y al F2 reset se llama `_recalcular_bestiario_mult()` para sincronizar el multiplicador con el nuevo estado de Stats.

### Bendiciones del Lavado (Fase 15)

Tras cada prestigio, el jugador elige 1 de 3 bendiciones aleatorias del pool `BENDICIONES` (6 totales). Cada bendición es un modificador pequeño activo durante toda la run; al siguiente prestigio se reemplaza por una nueva elección.

| ID | Icono | Efecto |
|---|---|---|
| `manos_rapidas` | ✋ | +0.10 fuerza de borrado base (sumada a `sink_area.bonus_fuerza`) |
| `bolsillos_profundos` | 💰 | `_bend_mult_euros = 1.08` (factor en handlers de €) |
| `ojos_alienados` | 👁 | +0.015 a `GarmentData.bonus_prob_alien` |
| `tiempo_lento` | ⏳ | `machines_panel.bonus_reduccion_global = 0.10` (apila multiplicativo con cuántica) |
| `salto_inicial` | 🚀 | `euros = 75.0` al elegir (one-shot) |
| `eco_compasivo` | ✧ | +1 fragmento por alien (chequeado en handlers via `bendicion_activa`) |

Flujo en `_on_prestige_confirmado`:
1. `_animar_prestigio(texto)` (3-4s)
2. `_ejecutar_prestigio()` — reset incluye limpiar bendición previa y guardado intermedio (por si cierran durante la elección)
3. `_mostrar_seleccion_bendicion()` — modal awaitable con 3 cards; bloquea hasta que el jugador elige
4. `_aplicar_bendicion(id)` aplica el efecto sobre el estado fresco
5. `guardar_partida()` final con la bendición activa
6. Continuar consumiendo cola

Persistido en `save.main.bendicion_activa`, `_bend_mult_euros`, `_bend_red_velocidad`. `machines_panel` persiste también `bonus_reduccion_global`. Todos se restauran al cargar sin re-aplicar la bendición (los efectos ya están reflejados en el estado).

El botón ⚙ de opciones muestra como tooltip la bendición activa: "Bendición: ✋ Manos rápidas".

### Narrativa del Altar (Fase 14)

Cada upgrade del altar tiene un campo `lore: String` (multilínea) en `UPGRADES_FRAGMENTO` (`fragment_shop_panel.gd`). Al comprarlo, `Main._aplicar_efecto_fragmento` llama a `_mostrar_lore_altar(texto)` ANTES de aplicar el efecto.

El popup es un `ColorRect` fullscreen semi-transparente (negro púrpura, alpha 0.7) con un Label centrado en color `#E0C0FF`, font 26. Fade in 0.5s + hold 5s + fade out 0.4s. Click en el fondo cierra antes (`gui_input` + `mouse_filter = STOP`). Usa `AudioManager.play_sfx("alien", 0.6)` para ambientación.

8 fragmentos de lore (uno por upgrade del altar) cuentan progresivamente la transformación del lavandero ante las prendas alien. Diseño de horror cósmico ligero — el último (`comunion`) cierra el arco: "Has dejado de ser un lavandero. Ahora eres el Lavandero."

NO se persiste qué textos se han visto — están atados a las compras (que sí se persisten en `compras_contador` del fragment shop). Si el jugador resetea solo el save (no las compras), no volverá a verlos.

### Contratos / clientes (Fase 13)

`ContractsManager.gd` (Autoload) ofrece contratos opcionales — el jugador acepta o rechaza, completa el objetivo en plazo, y recibe recompensa fija. **No** modifica modificadores globales (a diferencia de los eventos). Compatible con eventos activos al mismo tiempo.

Estados (transiciones internas via `_process`):
- **IDLE** → cooldown corriendo (`COOLDOWN_BASE_SEG ± COOLDOWN_VARIANZA_SEG`)
- **DISPONIBLE** → contrato ofrecido, ventana de `TIEMPO_OFERTA_SEG` (25s) para decidir
- **ACTIVO** → aceptado, cuenta atrás del plazo

5 contratos definidos (`CONTRATOS`):

| ID | Objetivo | Tipo | Plazo | Reward |
|---|---|---|---|---|
| `lavanderia_rapida` | 8 prendas | any | 90s | 80€ + 1✧ |
| `lote_completo` | 20 prendas | any | 240s | 250€ + 2✧ |
| `cazador_alien` | 3 alien | alien | 180s | 200€ + 5✧ |
| `marathon` | 50 prendas | any | 600s | 700€ + 5✧ + 2🜁 |
| `exprés` | 5 prendas | any | 30s | 60€ + 1✧ |

Gating: igual que eventos (>= 200€ totales o >= 1 prestigio).

Main conecta 5 señales (`contrato_disponible_aparece`, `contrato_aceptado`, `contrato_completado`, `contrato_actualizado`, `contrato_disponible_expirado`) y llama a `ContractsManager.notificar_prenda(prenda)` desde `_on_garment_delivered` y `_on_prenda_procesada_lavadora` (cuentan ambas vías).

Banner UI programático (`_crear_contract_banner`) bajo el banner de eventos (Fase 10), centrado-arriba en y=168-268. Estado DISPONIBLE muestra botones Aceptar/Rechazar; ACTIVO muestra barra de progreso.

Logros nuevos en categoría Eventos: `primer_contrato`, `contratista_habitual` (10).

Stat nuevo: `contratos_completados`.

**No persiste** (igual que eventos): cooldown limpio al cargar partida.

### Progreso offline (Fase 12)

`Main` persiste `timestamp_guardado: int` (unix epoch) en cada `guardar_partida()`. En `cargar_partida()`, tras restaurar todo, llama a `_aplicar_progreso_offline(ts)`:

1. Calcula `delta = ahora - ts`. Si < `OFFLINE_MIN_SEG_PARA_POPUP` (60s), no hace nada.
2. Limita a `OFFLINE_MAX_SEG` (8h) — evita exploit de cambiar reloj del sistema.
3. Pregunta a `machines_panel.contar_ciclos_offline(delta)` cuántos ciclos habrían completado las lavadoras activas en ese tiempo (suma `floor(delta / ciclo_seg)` por lavadora).
4. Recompensa = `ciclos × OFFLINE_AVG_EUROS_POR_CICLO (6.33) × multiplicador_ganancias × OFFLINE_EFICIENCIA (0.5)`.
5. Aplica €, suma a `prendas_total_lavadora` y `euros_total_historico`, dispara popup centrado.

El popup es modal (ColorRect oscurecido + PanelContainer con resumen). Se cierra con "Continuar". No persiste reward — se aplica directamente al cargar.

Limitaciones aceptadas: solo simula recompensa promedio de prendas normales (no alien, no fragmentos). Los ciclos parciales (lavadora a medio ciclo en el momento del save) se ignoran por simplicidad.

### Atajos de teclado y opciones (Fase 11C)

`Main._input()` maneja los atajos del jugador (siempre activos, no requieren `DEBUG_MODE`):

| Tecla | Acción |
|---|---|
| ESPACIO | Entrega la prenda actual si está limpia (`sink_area.intentar_entregar()`) |
| 1–5 | Asigna el slot N de la cola a una lavadora libre (equivalente a clic en el slot) |

`AudioManager` expone `set_volumen_db(db)` y `get_volumen_db()` (rango -80..6 dB). El panel de opciones (botón ⚙ en la esquina inferior derecha, encima del 📊) tiene un slider de volumen y muestra los atajos disponibles. El volumen se persiste en `save.opciones.volumen_db`.

Logros nuevos en categoría Hitos: `aprendiz_aplicado` (completar tutorial) y `sin_entrenamiento` (saltarlo). Se notifican via `tutorial.tutorial_completado` y `tutorial.tutorial_saltado`.

El botón de prestigio muestra ahora su preview de ceniza dinámicamente: `"PRESTIGIO  +N 🜁"` donde N incluye `bonus_ceniza_prestigio` (mejora del Altar).

### Tutorial guiado (Fase 11A)

`tutorial_manager.gd` se instancia desde `Main._crear_tutorial()` como hijo del HUD (no es Autoload — necesita acceso a las refs de Main). Sistema de 6 pasos secuenciales con dos eventos por paso: **desbloqueo** (lo abre) + **cierre** (lo avanza).

| # | Paso | Desbloqueo | Cierre | Target |
|---|---|---|---|---|
| 0 | bienvenida | (inmediato) | botón Entendido | SinkArea |
| 1 | primera_entrega | (inmediato) | `entrega_completada` | SinkArea |
| 2 | cola | (inmediato) | botón Entendido | QueuePanel |
| 3 | tienda | `tienda_disponible` (euros≥12) | `compra_realizada` | ShopPanel |
| 4 | lavadora | `lavadora_disponible` (euros≥75) | `lavadora_comprada` | MachinesPanel |
| 5 | prestigio | `prestigio_visible` | `prestigio_hecho` | PrestigeButton |

Main llama a `_notif_tutorial(evento)` desde los handlers (`_on_garment_delivered`, `_on_upgrade_solicitado`, `_on_lavadora_compra_solicitada`, `_actualizar_estado_prestige_button`, `_ejecutar_prestigio`). `_chequear_desbloqueos_tutorial()` se llama en `_on_euros_changed` para los gates económicos.

Estado persistido (`tutorial.paso_actual: int`, -1 = completado/saltado). Saves anteriores a Fase 11 (sin sección `tutorial`) se interpretan como completados — el tutorial no molesta a partidas existentes. Para verlo de nuevo, F2 (debug reset) borra el save y lo reactiva.

UI: anillo amarillo pulsante (`_draw_ring()`) alrededor del target + panel auto-posicionado en el espacio libre (derecha/izquierda/arriba/abajo del target según `max_espacio`). Botón "Saltar tutorial" en la esquina inferior izquierda.

Constantes en Main para el gating de los pasos 3 y 4: `TUTORIAL_UMBRAL_TIENDA = 12`, `TUTORIAL_UMBRAL_LAVADORA = 75`. Si cambias precios en balance, ajusta también estos.

### Eventos aleatorios (Fase 10)

`EventsManager.gd` (Autoload) dispara eventos temporales que modifican el juego durante una duración fija. Un único evento activo a la vez; cooldown variable entre eventos (90 ± 30 s tras primer evento; 60 s antes del primero).

**Gating**: el sistema permanece dormido hasta que `euros_total_ganado >= 500` o `num_prestigios >= 1` (lo que ocurra antes). Main llama `EventsManager.comprobar_gate(...)` en cada income event y tras prestigio.

Los **6 eventos** definidos:

| ID | Duración | Efecto |
|---|---|---|
| `lluvia_alien` | 30 s | `GarmentData.bonus_prob_alien += 0.10` |
| `hora_dorada` | 20 s | `_ev_mult_recompensa = 2.0` (× sobre todo el resto) |
| `pedido_vip` | 45 s | Limpia 6 prendas manualmente → +500€ + 2 ✧ |
| `susurro_altar` | 25 s | `_ev_bonus_frag_alien = 1` (suma en cada alien) |
| `frenesi_frotador` | 20 s | `sink_area.bonus_fuerza_evento = 0.12` |
| `pulso_cuantico` | 40 s | `machines_panel.mult_velocidad_evento = 1.5` |

Señales:
- `evento_iniciado(id)` → Main aplica modificador y muestra banner
- `evento_finalizado(id, exito)` → revierte y oculta banner; si VIP con `exito=true`, da reward
- `evento_actualizado(id, restante, datos)` → tick para refrescar barra de tiempo + contador VIP

**Banner UI**: `PanelContainer` programático anclado al centro-superior del HUD, con icono, nombre, descripción/progreso y barra de tiempo. Color del borde según el evento.

**No persiste**: los modificadores y cooldowns son volátiles. Si el jugador cierra durante un evento, al recargar empieza con cooldown limpio. Las variables temporales en Main (`_ev_*`) y los flags en SinkArea/MachinesPanel se reinician naturalmente al instanciar (defaults).

4 logros nuevos en categoría "Eventos": `primera_ronda`, `cliente_fiel`, `habitual` (10 eventos), `vip_frecuente` (5 VIPs).

### Pulido visual + audio (Fase 9)

**Audio**: `AudioManager.gd` (Autoload) sintetiza todos los SFX procedualmente al arranque — sin assets externos. Genera `AudioStreamWAV` 16-bit mono a 22050 Hz para 8 sonidos (`scrub`, `deliver`, `buy`, `alien`, `machine_done`, `achievement`, `prestige`, `denied`) mediante helpers: `_generar_tono`, `_generar_tono_vibrato`, `_generar_arpegio`, `_generar_acorde`, `_generar_ruido`. Reproducción via pool circular de 8 `AudioStreamPlayer` para permitir solapamiento.

API: `AudioManager.play_sfx(id: String, pitch: float = 1.0)`. Para reemplazar por audio real más adelante, basta sustituir el dict `_streams` por `load("res://assets/audio/...ogg")`.

**Feedback visual**:
- `SinkArea` — `CPUParticles2D` de burbujas blancas que ascienden mientras `frotando == true`. SFX `scrub` con cooldown 80 ms y pitch aleatorizado.
- `Main._spawn_floating_number(texto, color, pos, size)` — Label que sube 70 px y se desvanece en 0.9 s. Llamado en `_on_garment_delivered` (sobre sink) y `_on_prenda_procesada_lavadora` (sobre machines_panel con jitter).
- `MachinesPanel._flash_card(card)` — tween de `modulate` de 1.7× → blanco en 0.45 s al completar ciclo.
- `ShopPanel/AshShopPanel/FragmentShopPanel._flash_compra(upgrade_id)` — mismo efecto al confirmar compra.
- `Main._mostrar_achievement_popup(logro_id)` — popup deslizante (PanelContainer 300×64) que entra por la derecha con `TRANS_BACK`, hold 2.4 s, sale por la derecha. Cola gestionada por `_logro_popup_queue` + `_logro_popup_activo` para múltiples logros simultáneos.

### Logros y estadísticas (Fase 8)

`Stats.gd` (Autoload) centraliza contadores permanentes y logros. Cualquier subsistema puede llamar a `Stats.incrementar(stat_id, n)`, `Stats.set_max(stat_id, valor)` o `Stats.notificar_evento(logro_id)`. Stats emite `logro_desbloqueado(id)`; Main escucha y muestra una notificación destacada en dorado.

Los logros son de dos tipos:
- **tipo "stat"**: se desbloquea automáticamente cuando `contadores[stat] >= umbral`
- **tipo "evento"**: lo dispara Main vía `Stats.notificar_evento(id)` (combinaciones, hitos complejos)

Stats vivos (todos `float` para evitar overflow en contadores grandes):
- Limpieza: `prendas_total_manual`, `prendas_total_lavadora`, `aliens_total_manual`, `aliens_total_lavadora`
- Economía: `euros_total_historico`, `ceniza_total_historico`, `fragmentos_total_historico`, `max_euros_en_run`
- Progresión: `prestigios_total`, `lavadoras_basicas/industriales/cuanticas_compradas`, `upgrades_euros/ceniza/fragmentos_comprados`
- Tiempo: `tiempo_jugado_seg` (auto-incrementa en `_process(delta)` de Stats)

`AchievementsOverlay.gd` se construye 100% por código y se instancia desde `Main._crear_achievements_overlay()`. Tiene dos pestañas (Logros / Estadísticas). Se abre con el botón 📊 en la esquina inferior derecha del HUD.

Los logros con condición compuesta están en `Main`:
- `_check_logros_aliens_combinados()` — `aliens_total_manual + aliens_total_lavadora >= {10, 50}`
- `_check_logro_polifacetico()` — al menos 1 upgrade de cada tienda
- Susurrador — disparado tras compra del altar si `prendas_desbloqueadas.size() >= 2`

### Persistence (Fase 6)

`Main.gd` orchestrates save/load. Path: `user://stain_save.json` (JSON, debuggable). Version: `SAVE_VERSION = 1`. Autosave interval: 30 s. Saves also fire on `NOTIFICATION_WM_CLOSE_REQUEST` (window close) and after `_ejecutar_prestigio()`.

Each panel exposes `serializar() -> Dictionary` and `cargar_estado(data: Dictionary)`. SinkArea's `cargar_estado` returns `bool` to tell Main whether to call `queue_panel.consumir_siguiente()` (false = sink was empty, needs a new garment).

**Garments are serialized by ID, not by Dictionary** — `Color` is not JSON-serializable, and `GarmentData.get_prenda_por_id()` rebuilds the full dict deterministically. **Stain pixel state is NOT persisted**: any garment in progress is recharged with fresh stains on load. This is a deliberate trade-off: ~256 KB of pixel data vs. one re-clean of the current garment.

Save schema (top level):
```
{
  "version": 1,
  "main": { euros, euros_totales_ganados, ceniza, fragmentos, favores,
            num_prestigios, prestigio_desbloqueado, multiplicador_ganancias,
            memoria_prendas_activa, velocidad_cola_activa,
            multi_compras_contador, alien_boost_contador,
            bonus_frag_alien, bonus_recompensa_alien, bonus_ceniza_prestigio,
            comunion_activa,
            bendicion_activa, _bend_mult_euros, _bend_red_velocidad,    # Fase 15
            aliados_comprados, _ali_mult_euros, _ali_red_velocidad,     # Fase 17
            esencia, num_trascendencias, trascendencia_desbloqueada,
            esencia_compras, _esc_mult_euros, cap_multiplicador },      # Fase 18
  "garment_data":   { suerte_euros, suerte_ceniza },
  "shop_panel":     { upgrades_comprados: [String] },
  "ash_shop_panel": { compras_contador: {String → int} },
  "machines_panel": { memoria_prendas, lavadoras: [{tipo, tiempo, prenda_id}] },
  "queue_panel":    { cola_ids: [String] },
  "sink_area":      { bonus_fuerza, bonus_radio, prenda_actual_id },
  "tutorial":       { paso_actual: int },                 # Fase 11A
  "opciones":       { volumen_db: float },                # Fase 11C
  "timestamp_guardado": float                             # Fase 12 (unix epoch)
}
```

API in Main: `guardar_partida() -> bool`, `cargar_partida() -> bool`, `borrar_save()`. F2 (reset total) also calls `borrar_save()`.

### GarmentData (Autoload)

- `PRENDAS_NORMALES` (6 types, 3–10€ avg 6.33€)
- `PRENDAS_ALIEN` (4 types, 30–80€, `ceniza_bonus=0`, `fragmentos_bonus=2–3`)
- `PRENDAS_ALIEN_DESBLOQUEABLES` (Fase 7, 2 types: 100€/+4✧ y 150€/+5✧). Solo entran al pool tras comprar la mejora correspondiente en el Altar.
- Luck split: `suerte_euros` (from € shop, resets on prestige) + `suerte_ceniza` (from ash shop, permanent) + `bonus_prob_alien` (Fase 7, from altar, permanent)
- `get_prendas_alien_activas()` devuelve el pool actual (base + desbloqueadas). `get_prenda_aleatoria()` lo usa para el sampleo.
- Debug: `forzar_siguiente_alien()` forces the next generated garment to be alien (one-shot)

### MachinesPanel Machine Types

| Type | Price | Ceniza | Cycle | Accepts Alien | Max |
|------|-------|--------|-------|---------------|-----|
| Basic | 75€ (Fase 11B, antes 100€) | 0 | 20s | No (unless memoria_prendas) | 3 |
| Industrial | 350€ | 3🜁 | 15s | No (unless memoria_prendas) | 2 |
| Quantum | 1200€ | 12🜁 | 12s | Yes | 1 |

### Debug Panel (`DEBUG_MODE = true` in main.gd)

Plegable en la esquina superior izquierda del HUD. Cambiar a `false` para builds de release — ni el panel ni los atajos de teclado se registran.

| Atajo | Acción |
|---|---|
| F1 | +10.000€, +5🜁, +3 fragmentos |
| F2 | Reset total (con confirmación modal). También borra el save. |
| F3 | Forzar siguiente prenda como alien |
| F4 | Completar ciclos de todas las lavadoras activas |
| F5 | Limpiar prenda actual al 100% (activa el botón de entregar) |
| F6 | Guardar partida ahora |
| F7 | Forzar un evento aleatorio (salta cooldown + gate) |
| F8 | Ofrecer un contrato (salta cooldown + gate) |

## Key Implementation Details

- **Texture generation**: `SinkArea` creates a dynamic `Image` (256×256, FORMAT_RGBA8) for stain tracking; pixel alpha cleared during scrubbing.
- **Frame skipping**: Stain progress measured every `FRAMES_ENTRE_MEDICIONES = 5` frames.
- **Machine drums**: Each machine card has a static body SVG and a rotating drum SVG.
- **Earnings multiplier**: `multiplicador_ganancias` (permanent) applied in both `_on_garment_delivered` and `_on_prenda_procesada_lavadora` before accumulating `euros_totales_ganados`.
- **Prestige button reveal**: `_actualizar_estado_prestige_button()` called on every income event; first call past 3000€ total makes the button appear with a notification.
