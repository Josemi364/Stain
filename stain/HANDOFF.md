# HANDOFF — Estado del proyecto Stain

Documento de traspaso para retomar el trabajo en otra sesión. Última actualización: 2026-05-16.

## Resumen rápido

**Stain** es un incremental game de lavandería en **Godot 4.6.2** (GDScript). Repo: `https://github.com/Josemi364/Stain`. Branch principal: `main`. No hay test suite — verificación = boot headless o ejecutar en editor.

- **20 fases completas** (Fase 20 terminada, pendiente de commit + push)
- Toda la documentación viva del proyecto está en `CLAUDE.md` (extensa, con secciones por fase)
- Memoria persistente del agente en `C:\Users\Josemi\.claude\projects\C--Users-Josemi-OneDrive...\memory\`

---

## Modo de trabajo acordado

El usuario me dio modo **autónomo** explícito (sale de casa) — no preguntar entre fases, encadenar trabajo y mostrar resumen al final. Guardado en `feedback_autonomous_mode.md` del memory dir.

Flujo estándar por fase:
1. Diseñar y proponer brevemente (1-2 frases con el plan)
2. Implementar
3. `godot --headless --quit-after 60` para validar parseo
4. Documentar en CLAUDE.md
5. Marcar tarea completada
6. **Esperar a que el usuario diga "commit and push"** — no se commitea automáticamente

Godot CLI en: `C:\Users\Josemi\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe`.

Comando de validación:
```powershell
& $godot --headless --path . --quit-after 60 2>&1 | Select-String -Pattern "(ERROR|Parse|Compile|Failed|WARNING)" | Select-Object -First 30
```

---

## Fases completadas (1–19)

| Fase | Tema | Commit |
|---|---|---|
| 1–4 | Gameplay base (sink, queue, machines, shop €) | (pre-existing) |
| 5 | Prestigio + ash shop + tabs €/🜁 | `b4ad623` |
| 6 | Persistencia JSON (autosave + cierre + prestigio) | en `b4ad623` |
| 7 | Altar de Fragmentos (3ª tienda, ✧) | en `b4ad623` |
| 8 | Logros + estadísticas (Stats autoload + overlay) | en `b4ad623` |
| 9 | Pulido visual + audio procedural (AudioManager autoload) | en `b4ad623` |
| 10 | Eventos aleatorios temporales (EventsManager autoload) | en `b4ad623` |
| 11A | Tutorial guiado (6 pasos, anillo pulsante) | `fe5a42e` |
| 11B | Balance pass (lavadora básica 100€→75€, prestigio 3000€→2000€) | `fe5a42e` |
| 11C | UX: atajos (ESPACIO, 1-5), panel opciones (⚙), preview ceniza | `fe5a42e` |
| 12 | Progreso offline (cap 8h, 50% eficiencia, popup "Has vuelto") | `a10164a` |
| 13 | Contratos / clientes (ContractsManager autoload, 5 contratos) | `a10164a` |
| 14 | Narrativa del Altar (lore al comprar mejoras del altar) | `a10164a` |
| 15 | Bendiciones del Lavado (3 de 6 opciones al prestigiar) | `fb77c58` |
| 16 | Bestiario de prendas (13 entradas, +1% € por investigada) | `6885c23` |
| 17 | Sistema de Aliados (favores ✦, allies_overlay, 5 aliados) | `c8b76c2` |
| 18 | Trascendencia / Meta-prestigio (Esencia ✺, 5 mejoras) | `223cb6d` |
| 19 | El Custodio (encuentro cada 15 alien, +200€ +5✧ +1🜁) | `8939eb3` |

**Monedas activas** (5): € (per-run), 🜁 ceniza (permanente, prestigio), ✧ fragmentos (permanente, alien), ✦ favores (permanente, contratos/VIP), ✺ esencia (meta-permanente, trascendencia).

**Autoloads en `project.godot:17-23`**: GarmentData, Stats, AudioManager, EventsManager, ContractsManager. Si añades otro, registrarlo aquí o todo rompe con "Identifier not declared".

**Overlays modal (no autoload, hijos de HUD)**: AchievementsOverlay, AlliesOverlay, TranscendOverlay, TutorialManager.

---

## Fase 20 EN PROGRESO — Habilidades activas

**Diseño acordado**:
- 3 habilidades activables con cooldown propio (Q/W/E + click en barra UI)
- **Pulso de Esponja** (Q): limpia 50% del sink actual. CD 60s. Desbloquea al 1er prestigio.
- **Hora del Tendero** (W): +100% € durante 15s. CD 120s. Desbloquea al 3er prestigio.
- **Ojo Abierto** (E): siguiente prenda forzada como alien. CD 90s. Desbloquea tras 1ª trascendencia.

**Lo que YA está hecho** (commit pendiente, no pusheado):

1. **`sink_area.gd`**: nuevo método público `limpiar_porcentaje(pct: float)` — borra píxeles de mancha proporcionalmente y dispara `_actualizar_progreso()`.

2. **`main.gd` — constantes y vars añadidas**:
   - `HABILIDADES: Array[Dictionary]` con las 3 (id, nombre, descripcion, icono, color, cooldown, atajo, desbloqueo)
   - `habilidades_desbloqueadas: Array[String]`
   - `_hab_cooldowns: Dictionary` (no persistido)
   - `_hab_hora_tendero_seg: float`, `HORA_TENDERO_DURACION`, `HORA_TENDERO_MULT = 2.0`
   - Refs UI: `_hab_bar: HBoxContainer`, `_hab_cards: Dictionary`

3. **Aplicación del mult**: en los 2 handlers de € se aplica `hab_mult = HORA_TENDERO_MULT if _hab_hora_tendero_seg > 0.0 else 1.0` como factor extra apilado con todos los demás.

4. **Llamada en `_ready`**: `_crear_hab_bar()` + `_refrescar_hab_bar()` — pero estas funciones **NO existen aún** (Godot dará error si se intenta arrancar).

**Lo que FALTA hacer en Fase 20**:

1. **Implementar `_crear_hab_bar()`**: HBoxContainer programático en esquina inferior centro (debajo del SinkArea, encima del QueuePanel — y=560-624 aprox). 3 cards 64×64 con icono + cooldown radial.

2. **Implementar `_refrescar_hab_bar()`**: muestra/oculta cada card según `habilidades_desbloqueadas`. Refresca cooldowns.

3. **Implementar `_process(delta)` en main.gd** (no existe aún):
   - Decrementar `_hab_cooldowns[id]` hasta 0
   - Decrementar `_hab_hora_tendero_seg` y refrescar UI
   - Redibujar cooldown radial cada frame mientras activo

4. **Cooldown radial**: usar `Control._draw()` con `draw_arc()` apuntando al porcentaje restante. O un `ColorRect` overlay con `material` shader. Más simple: solo Label con segundos restantes.

5. **Hooks de input para Q/W/E**: extender `_input(event)` (ya existe el de SPACE y 1-5). Mapear KEY_Q → `pulso_esponja`, KEY_W → `hora_tendero`, KEY_E → `ojo_abierto`.

6. **Función `_activar_habilidad(id)`**:
   - Si no desbloqueada → notif "no desbloqueada"
   - Si en cooldown → notif "espera Xs"
   - Si OK:
     - `pulso_esponja` → `sink_area.limpiar_porcentaje(0.5)`
     - `hora_tendero` → `_hab_hora_tendero_seg = HORA_TENDERO_DURACION`
     - `ojo_abierto` → `GarmentData.forzar_siguiente_alien()`
   - Stats.incrementar("habilidades_usadas")
   - Disparar `primer_pulso` si es pulso, comprobar `maestro_habilidades` (las 3 usadas)
   - Set cooldown a su max

7. **Hook de desbloqueo en `_ejecutar_prestigio`**:
   - Si `num_prestigios == 1` → desbloquear "pulso_esponja" + notif "🧽 Nueva habilidad: Pulso de Esponja (Q)"
   - Si `num_prestigios == 3` → desbloquear "hora_tendero"

8. **Hook de desbloqueo en `_ejecutar_trascendencia`**:
   - Si `num_trascendencias == 1` → desbloquear "ojo_abierto"

9. **Persistencia**: añadir `habilidades_desbloqueadas` a `save.main`. Cooldowns reinician al cargar (intencional).

10. **Reset F2**: limpiar `habilidades_desbloqueadas`, `_hab_cooldowns`, `_hab_hora_tendero_seg`.

11. **Stats nuevo**: `habilidades_usadas` en STAT_IDS.

12. **Logros nuevos** (Hitos):
    - `primer_pulso`: usa pulso_esponja (evento)
    - `maestro_habilidades`: usa las 3 habilidades en una sesión (evento)

13. **Documentar en CLAUDE.md** (sección "Habilidades activas (Fase 20)") + actualizar schema del save.

14. **Boot validation** + commit + push (esperar a que el usuario lo pida).

**Posición sugerida para la barra UI**: esquina inferior centro. Coordenadas aproximadas:
- anchor_left/right = 0.5, anchor_bottom = 1.0
- offset_left = -110, offset_right = 110 (220px ancho)
- offset_top = -80, offset_bottom = -16 (encima del QueuePanel)

---

## Próximas fases sugeridas (ideas)

Lista priorizada por impacto / dificultad:

### Alto impacto, scope medio
- **Fase 21: Diario del Lavandero** — Codex narrativo con dos pestañas (Glosario de términos + Diario cronológico de hitos personales). Conecta con Fase 14 (narrativa). ~250 LOC.
- **Fase 22: Mejoras visuales del sink** — particles de jabón mejoradas, slowmo al entregar Custodio, screen shake al primer alien. ~200 LOC.
- **Fase 23: Sistema "Día/Noche"** — visual cycle cada 5 min real. Cambia fondo + ligero tinte. Prendas alien más probables de noche. ~200 LOC.

### Alto impacto, scope grande
- **Fase 24: Mini-juegos extra** — planchado/secado tras limpiar (drag&drop opcional para multiplicador extra). Refactor de sink necesario. ~500+ LOC.
- **Fase 25: Skins / cosméticos** — desbloqueables por logros. Paletas alternativas para sink, lavadoras, queue. Sin balance impact. Requiere algunos assets nuevos.

### Pulido / técnico
- **Fase 26: Refactor de main.gd** — main.gd tiene ~2700 líneas. Extraer "managers" a archivos propios: `prestige_manager.gd`, `transcend_manager.gd`, `hud_manager.gd`. NO modificar comportamiento; solo mover funciones.
- **Fase 27: Localización i18n** — extraer strings a `translations/es.csv` + `en.csv`. Cambiar a `tr("KEY")` en código.
- **Fase 28: Stats avanzados con gráficas** — snapshots cada 5 min de €, 🜁, ✧; pestaña nueva en achievements_overlay con line charts custom-drawn.

### Específicas del lore
- **Fase 29: Frutos del Altar** — al limpiar un Custodio, 25% prob de soltar un "Fruto" (reliquia única, una vez por save). 5 frutos coleccionables con efectos pasivos micro.
- **Fase 30: Final secreto** — al cumplir condiciones (5 trascendencias + bestiario completo + las 5 mejoras esencia + todas las bendiciones vistas), desbloquear un ending narrativo especial. Texto fullscreen con animación.

---

## Notas técnicas importantes

### Convenciones del proyecto
- **GDScript en español** (variables, funciones públicas). Inglés permitido en helpers/internals.
- **No tocar `main.tscn`** — añadir UI programáticamente en `_crear_*` y `add_child($HUD)`.
- **Sistemas nuevos** suelen ser: (a) autoload si necesitan _process global y singleton, o (b) Control hijo del HUD si son UI.
- **Comentarios mínimos** — solo donde la lógica es no obvia. La documentación profunda va en CLAUDE.md.
- **Persistencia**: cada subsistema con estado expone `serializar() -> Dictionary` + `cargar_estado(data: Dictionary)`. Main orquesta.

### Multiplicadores de € apilados
Actualmente en `_on_garment_delivered` y `_on_prenda_procesada_lavadora`:
```
earned * multiplicador_ganancias * _ev_mult_recompensa * _bend_mult_euros
       * _bestiario_mult * _ali_mult_euros * _esc_mult_euros * hab_mult
```
Si añades una fuente nueva de multiplicador, encadénala aquí también.

### Reductores de ciclo de lavadora
En `machines_panel._recalcular_ciclos_lavadoras()` (helper Fase 17):
- `bonus_reduccion_ciclo_cuantica` (Fase 7, solo cuántica)
- `bonus_reduccion_global` (Fase 15 bendición tiempo_lento)
- `bonus_reduccion_aliados` (Fase 17 aliado relojero)
- `mult_velocidad_evento` (Fase 10 evento pulso_cuantico, NO aquí — se aplica en delta)

### Atajos de teclado actuales
- `ESPACIO` — entregar prenda
- `1-5` — asignar slot a lavadora
- `Q/W/E` — habilidades (planeado Fase 20)
- `F1-F8` — debug (si DEBUG_MODE=true)

### Botones flotantes (esquina inferior derecha)
De arriba abajo: ✺ (esencia), 🤝 (aliados), ⚙ (opciones), 📊 (logros).
Si añades otro, asignar `offset_top` libre evitando solapamiento.

### Tareas en TaskCreate
Cada fase es 1 tarea. Marcar `in_progress` al empezar y `completed` al terminar. No batch — completar inmediatamente.

---

## Si retomas el trabajo

1. Lee `CLAUDE.md` completo primero — es la fuente de verdad técnica.
2. Lee este HANDOFF.md.
3. Continúa Fase 20 desde "Lo que FALTA hacer" — no es difícil pero hay que cerrar muchos puntos.
4. Si el usuario quiere saltar Fase 20, ofrece las opciones de la lista "Próximas fases sugeridas".
5. Recuerda: **NO commitear sin que el usuario lo pida explícitamente**. Excepto si está en modo autónomo confirmado.
