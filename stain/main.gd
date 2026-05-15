extends Node2D
##
## Main.gd — FASES 5–10
## ============================================================
## Orquestador central. Los subsistemas emiten señales hacia aquí;
## Main decide las consecuencias y llama de vuelta hacia abajo.
##
## FASE 5: prestigio, tienda de Ceniza, tabs €/🜁.
## FASE 6: persistencia JSON (autosave + cierre + manual F6).
## FASE 7: Altar de Fragmentos (tercer panel ✧), prendas alien desbloqueables.
## FASE 8: Stats + logros (AchievementsOverlay, autoload Stats).
## FASE 9: Pulido (AudioManager autoload, partículas, popups, números flotantes).
## FASE 10: Eventos aleatorios (EventsManager autoload, banner UI, VIP).
## DEBUG:  panel plegable con F1-F6. Desactivar con DEBUG_MODE = false.
##

# ============================================================
# DEBUG — cambiar a false para build de release
# ============================================================
const DEBUG_MODE: bool = true

# ============================================================
# CONSTANTES DE JUEGO
# ============================================================
# Euros totales ganados necesarios para revelar el botón de prestigio por primera vez
# Fase 11B: bajado 3000 → 2000 para acortar el primer loop (mejor feedback del meta-loop)
const UMBRAL_PRESTIGIO_PRIMER_USO: int = 2000

# ============================================================
# FASE 6 — PERSISTENCIA
# ============================================================
const SAVE_PATH: String = "user://stain_save.json"
const SAVE_VERSION: int = 1
const AUTOSAVE_INTERVAL: float = 30.0

# ============================================================
# ESTADO DEL JUGADOR — por run (se resetea en prestigio)
# ============================================================
var euros: float = 0.0
var euros_totales_ganados: float = 0.0

# ============================================================
# ESTADO PERMANENTE — nunca se resetea con prestigio
# ============================================================
var ceniza: int = 0
var fragmentos: int = 0
var favores: int = 0
var num_prestigios: int = 0
var prestigio_desbloqueado: bool = false

var multiplicador_ganancias: float = 1.0  # máx 3.0 (+200%)
var memoria_prendas_activa: bool = false
var velocidad_cola_activa: bool = false
var multi_compras_contador: int = 0
var alien_boost_contador: int = 0

# === Fase 10 — Eventos temporales (volátiles, no se persisten) ===
var _ev_mult_recompensa: float = 1.0       # Hora dorada
var _ev_bonus_prob_alien: float = 0.0      # Lluvia alien (suma a GarmentData.bonus_prob_alien)
var _ev_bonus_frag_alien: int = 0          # Susurro del Altar
var _ev_bonus_fuerza: float = 0.0          # Frenesí frotador
var _ev_mult_velocidad_lavadoras: float = 1.0  # Pulso cuántico

# === Fase 7 — Altar de Fragmentos ===
var bonus_frag_alien: int = 0            # +1 fragmento por alien limpiada × n
var bonus_recompensa_alien: float = 0.0  # +10% € por alien × n (0..0.4)
var bonus_ceniza_prestigio: int = 0      # +1 ceniza base en prestigio
var comunion_activa: bool = false        # 20% prob. duplicar fragmentos en limpieza manual de alien

# ============================================================
# SEÑALES GLOBALES
# ============================================================
signal euros_changed(new_val: float)
signal ceniza_changed(new_val: int)
signal fragmentos_changed(new_val: int)
signal prestige_realizado
signal ceniza_upgrade_aplicado(upgrade_id: String)
signal fragmento_upgrade_aplicado(upgrade_id: String)

# ============================================================
# REFERENCIAS A NODOS
# ============================================================
@onready var sink_area: Control          = $SinkArea
@onready var queue_panel: HBoxContainer  = $QueuePanel
@onready var shop_panel: Panel           = $ShopPanel
@onready var machines_panel: Panel       = $MachinesPanel
@onready var ash_shop_panel: Panel       = $AshShopPanel
@onready var fragment_shop_panel: Panel  = $FragmentShopPanel
@onready var notif_timer: Timer          = $NotifTimer

@onready var euros_label: Label          = $HUD/CoinsPanel/EurosLabel
@onready var ceniza_label: Label         = $HUD/CoinsPanel/CenizaLabel
@onready var fragmentos_label: Label     = $HUD/CoinsPanel/FragmentosLabel
@onready var notif_label: Label          = $HUD/NotifLabel

@onready var prestige_button: Button     = $HUD/PrestigeButton
@onready var prestige_overlay: ColorRect = $HUD/PrestigeOverlay
@onready var prestige_dialog: Panel      = $HUD/PrestigeDialog
@onready var narrativo_label: Label      = $HUD/PrestigeOverlay/NarrativoLabel
@onready var btn_tab_tienda: Button      = $HUD/TabTienda
@onready var btn_tab_ceniza: Button      = $HUD/TabCeniza
@onready var btn_tab_fragmentos: Button  = $HUD/TabFragmentos

# Refs del panel de debug (solo se crean si DEBUG_MODE == true)
var _debug_btn_toggle: Button
var _debug_panel_fondo: PanelContainer
var _debug_confirm_panel: Control

# Autosave + indicador HUD
var _autosave_timer: Timer
var _save_indicator: Label

# Fase 8 — Logros
var _achievements_overlay: Control
var _btn_logros: Button

# Fase 9 — cola de popups de logros
var _logro_popup_queue: Array[String] = []
var _logro_popup_activo: bool = false

# Fase 10 — refs del banner de evento
var _event_banner: PanelContainer
var _event_banner_icono: Label
var _event_banner_nombre: Label
var _event_banner_progreso: Label
var _event_banner_barra: ProgressBar

# Fase 11A — Tutorial guiado
var _tutorial: Control
# Umbrales para gating del tutorial. Si cambias precios en balance, ajustar aquí.
const TUTORIAL_UMBRAL_TIENDA: int = 12
const TUTORIAL_UMBRAL_LAVADORA: int = 75

# Fase 11C — Panel de opciones (volumen + futuras settings)
var _opciones_btn: Button
var _opciones_panel: PanelContainer
var _opciones_slider: HSlider

# Fase 12 — Progreso offline
const OFFLINE_MAX_SEG: float = 28800.0       # cap a 8h de tiempo offline contabilizado
const OFFLINE_EFICIENCIA: float = 0.50       # 50% de la ganancia activa
const OFFLINE_AVG_EUROS_POR_CICLO: float = 6.33  # avg de prendas normales (3..10€)
const OFFLINE_MIN_SEG_PARA_POPUP: float = 60.0   # umbral mínimo para mostrar el popup

# Fase 13 — Banner de contratos
var _contract_banner: PanelContainer
var _contract_titulo: Label
var _contract_descripcion: Label
var _contract_barra: ProgressBar
var _contract_btn_aceptar: Button
var _contract_btn_rechazar: Button


# ============================================================
# INICIALIZACIÓN
# ============================================================
func _ready() -> void:
	# SinkArea
	sink_area.garment_delivered.connect(_on_garment_delivered)
	# QueuePanel
	queue_panel.siguiente_prenda_lista.connect(_on_siguiente_prenda_lista)
	queue_panel.intento_seleccion_lavadora.connect(_on_intento_seleccion_lavadora)
	# ShopPanel (euros)
	shop_panel.upgrade_solicitado.connect(_on_upgrade_solicitado)
	# MachinesPanel
	machines_panel.lavadora_compra_solicitada.connect(_on_lavadora_compra_solicitada)
	machines_panel.prenda_procesada.connect(_on_prenda_procesada_lavadora)
	# AshShopPanel (ceniza)
	ash_shop_panel.upgrade_ceniza_solicitado.connect(_on_upgrade_ceniza_solicitado)
	# FragmentShopPanel (fragmentos)
	fragment_shop_panel.upgrade_fragmento_solicitado.connect(_on_upgrade_fragmento_solicitado)

	# Botón de prestigio y diálogo
	prestige_button.pressed.connect(_on_prestige_button_pressed)
	prestige_dialog.confirmado.connect(_on_prestige_confirmado)
	prestige_dialog.cancelado.connect(_on_prestige_cancelado)

	# Tabs €/🜁/✧
	btn_tab_tienda.pressed.connect(_on_tab_tienda_pressed)
	btn_tab_ceniza.pressed.connect(_on_tab_ceniza_pressed)
	btn_tab_fragmentos.pressed.connect(_on_tab_fragmentos_pressed)

	# Señal prestige_realizado → APIs canónicas de cada subsistema
	prestige_realizado.connect(shop_panel.reset_compras)
	prestige_realizado.connect(machines_panel.reset_lavadoras)
	prestige_realizado.connect(queue_panel.reset_cola)
	prestige_realizado.connect(sink_area.reset_sink)
	prestige_realizado.connect(ash_shop_panel.on_prestige_realizado)

	# Señales de moneda → HUD
	euros_changed.connect(_on_euros_changed)
	ceniza_changed.connect(_on_ceniza_changed)
	fragmentos_changed.connect(_on_fragmentos_changed)

	# Notif timer
	notif_timer.wait_time = 3.0
	notif_timer.one_shot = true
	notif_timer.timeout.connect(_on_notif_timer_timeout)
	notif_label.visible = false

	# Botón de prestigio: oculto hasta cruzar el umbral
	prestige_button.visible = false
	prestige_overlay.visible = false
	prestige_dialog.visible = false
	narrativo_label.visible = false
	_estilizar_prestige_button(false)

	# Solo la tienda de € visible al inicio
	ash_shop_panel.visible = false
	fragment_shop_panel.visible = false
	shop_panel.visible = true
	_estilizar_tab(btn_tab_tienda, true)
	_estilizar_tab(btn_tab_ceniza, false)
	_estilizar_tab(btn_tab_fragmentos, false)

	_update_hud()
	shop_panel.actualizar_euros(euros)
	machines_panel.actualizar_recursos(euros, ceniza)
	ash_shop_panel.actualizar_ceniza(ceniza)
	fragment_shop_panel.actualizar_fragmentos(fragmentos)

	if DEBUG_MODE:
		_crear_panel_debug()

	# Indicador de autosave en el HUD (creado siempre, no solo en debug)
	_crear_save_indicator()

	# Fase 8: overlay de logros + botón + suscripción a la señal
	_crear_achievements_overlay()
	_crear_btn_logros()
	Stats.logro_desbloqueado.connect(_on_logro_desbloqueado)

	# Fase 10: eventos
	_crear_event_banner()
	EventsManager.evento_iniciado.connect(_on_evento_iniciado)
	EventsManager.evento_finalizado.connect(_on_evento_finalizado)
	EventsManager.evento_actualizado.connect(_on_evento_actualizado)

	# Fase 11A: tutorial guiado
	_crear_tutorial()

	# Fase 11C: panel de opciones (volumen)
	_crear_panel_opciones()

	# Fase 13: contratos
	_crear_contract_banner()
	ContractsManager.contrato_disponible_aparece.connect(_on_contrato_disponible)
	ContractsManager.contrato_aceptado.connect(_on_contrato_aceptado)
	ContractsManager.contrato_completado.connect(_on_contrato_completado)
	ContractsManager.contrato_actualizado.connect(_on_contrato_actualizado)
	ContractsManager.contrato_disponible_expirado.connect(_on_contrato_expirado)

	# Autosave periódico
	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = AUTOSAVE_INTERVAL
	_autosave_timer.one_shot = false
	_autosave_timer.timeout.connect(_on_autosave_timer_timeout)
	add_child(_autosave_timer)
	_autosave_timer.start()

	# Interceptar el cierre de ventana para guardar antes de salir
	get_tree().auto_accept_quit = false

	await get_tree().process_frame
	# Intentar cargar partida. Si no hay save válido, arranque normal.
	if FileAccess.file_exists(SAVE_PATH) and cargar_partida():
		mostrar_notificacion("Partida cargada", false)
	else:
		queue_panel.consumir_siguiente()
		# Partida nueva: arrancar tutorial desde el principio
		if _tutorial != null:
			_tutorial.iniciar()


# ============================================================
# TABS — alternar entre tienda de €, tienda de Ceniza y Altar
# ============================================================
func _on_tab_tienda_pressed() -> void:
	shop_panel.visible = true
	ash_shop_panel.visible = false
	fragment_shop_panel.visible = false
	_estilizar_tab(btn_tab_tienda, true)
	_estilizar_tab(btn_tab_ceniza, false)
	_estilizar_tab(btn_tab_fragmentos, false)


func _on_tab_ceniza_pressed() -> void:
	shop_panel.visible = false
	ash_shop_panel.visible = true
	fragment_shop_panel.visible = false
	_estilizar_tab(btn_tab_tienda, false)
	_estilizar_tab(btn_tab_ceniza, true)
	_estilizar_tab(btn_tab_fragmentos, false)


func _on_tab_fragmentos_pressed() -> void:
	shop_panel.visible = false
	ash_shop_panel.visible = false
	fragment_shop_panel.visible = true
	_estilizar_tab(btn_tab_tienda, false)
	_estilizar_tab(btn_tab_ceniza, false)
	_estilizar_tab(btn_tab_fragmentos, true)


func _estilizar_tab(boton: Button, activo: bool) -> void:
	var e := StyleBoxFlat.new()
	e.set_corner_radius_all(4)
	if activo:
		e.bg_color = Color("#2A2A5A")
		boton.add_theme_color_override("font_color", Color("#D0D0F0"))
	else:
		e.bg_color = Color("#12122A")
		boton.add_theme_color_override("font_color", Color("#555577"))
	boton.add_theme_stylebox_override("normal", e)
	boton.add_theme_stylebox_override("hover", e)
	boton.add_theme_stylebox_override("pressed", e)


# ============================================================
# SINK (FIFO)
# ============================================================
func _on_siguiente_prenda_lista(prenda: Dictionary) -> void:
	sink_area.cargar_prenda(prenda)


func _on_garment_delivered(prenda: Dictionary, earned: float) -> void:
	var es_alien: bool = bool(prenda.get("es_alien", false))

	# Fase 7: bonus_recompensa_alien aplica antes del multiplicador
	var earned_pre_mult: float = earned
	if es_alien and bonus_recompensa_alien > 0.0:
		earned_pre_mult *= (1.0 + bonus_recompensa_alien)
	# Fase 10: _ev_mult_recompensa (Hora dorada) se aplica como factor extra
	var earned_real: float = earned_pre_mult * multiplicador_ganancias * _ev_mult_recompensa

	euros += earned_real
	euros_totales_ganados += earned_real
	euros_changed.emit(euros)

	var ceniza_ganada: int = prenda.get("ceniza_bonus", 0)
	if ceniza_ganada > 0:
		ceniza += ceniza_ganada
		ceniza_changed.emit(ceniza)

	# Fase 7: bonus_frag_alien y comunion solo en alien limpiadas manualmente
	# Fase 10: _ev_bonus_frag_alien (Susurro del altar) suma adicional
	var fragmentos_ganados: int = prenda.get("fragmentos_bonus", 0)
	if es_alien:
		fragmentos_ganados += bonus_frag_alien + _ev_bonus_frag_alien
		if comunion_activa and randf() < 0.20:
			fragmentos_ganados *= 2
	if fragmentos_ganados > 0:
		fragmentos += fragmentos_ganados
		fragmentos_changed.emit(fragmentos)

	var texto_notif := "+%d€" % int(earned_real)
	if multiplicador_ganancias > 1.001:
		texto_notif += " (×%.2f)" % multiplicador_ganancias
	if ceniza_ganada > 0:
		texto_notif += "  +%d🜁" % ceniza_ganada
	if fragmentos_ganados > 0:
		texto_notif += "  +%d ✧" % fragmentos_ganados
	if es_alien:
		texto_notif = "ALIEN!  " + texto_notif

	mostrar_notificacion(texto_notif, es_alien)
	_actualizar_estado_prestige_button()

	# Fase 9: número flotante + sonido
	var pos_manual: Vector2 = sink_area.global_position + Vector2(sink_area.size.x * 0.5, 30)
	_spawn_floating_number("+%d€" % int(earned_real), Color("#FFD060"), pos_manual, 22)
	AudioManager.play_sfx("alien" if es_alien else "deliver")

	# Fase 10: gate de eventos + tracking VIP
	EventsManager.comprobar_gate(euros_totales_ganados, num_prestigios)
	EventsManager.notificar_prenda_entregada()
	# Fase 13: contratos
	ContractsManager.comprobar_gate(euros_totales_ganados, num_prestigios)
	ContractsManager.notificar_prenda(prenda)

	# Fase 8: stats
	Stats.incrementar("prendas_total_manual")
	if earned_real > 0.0:
		Stats.incrementar("euros_total_historico", earned_real)
	if ceniza_ganada > 0:
		Stats.incrementar("ceniza_total_historico", ceniza_ganada)
	if fragmentos_ganados > 0:
		Stats.incrementar("fragmentos_total_historico", fragmentos_ganados)
	if es_alien:
		Stats.incrementar("aliens_total_manual")
		_check_logros_aliens_combinados()
	Stats.set_max("max_euros_en_run", euros)

	# Fase 11A: tutorial — primera entrega + chequear umbrales
	_notif_tutorial("entrega_completada")
	_chequear_desbloqueos_tutorial()

	queue_panel.consumir_siguiente()


# ============================================================
# CLICK EN COLA → ASIGNAR A LAVADORA
# ============================================================
func _on_intento_seleccion_lavadora(idx: int) -> void:
	if not machines_panel.tiene_lavadoras():
		mostrar_notificacion("Compra una lavadora primero", false)
		AudioManager.play_sfx("denied")
		return

	var prenda: Dictionary = queue_panel.peek_prenda(idx)
	if prenda.is_empty():
		return

	var es_alien: bool = bool(prenda.get("es_alien", false))

	if es_alien and not memoria_prendas_activa and not machines_panel.tiene_lavadora_alien():
		mostrar_notificacion("Solo la lavadora cuántica acepta alien", true)
		AudioManager.play_sfx("denied")
		return

	var asignada: bool = machines_panel.asignar_prenda(prenda)
	if asignada:
		queue_panel.confirmar_extraccion(idx)
		mostrar_notificacion("→ Lavadora", false)
	else:
		mostrar_notificacion("Lavadoras llenas", false)
		AudioManager.play_sfx("denied")


# ============================================================
# TIENDA — UPGRADES DE EUROS
# ============================================================
func _on_upgrade_solicitado(upgrade_id: String, precio: int) -> void:
	if euros < precio:
		mostrar_notificacion("No tienes suficiente dinero", false)
		AudioManager.play_sfx("denied")
		return

	euros -= precio
	euros_changed.emit(euros)

	var datos: Dictionary = shop_panel.get_upgrade(upgrade_id)
	_aplicar_efecto(datos)

	shop_panel.confirmar_compra(upgrade_id)
	mostrar_notificacion("✓ %s comprado" % datos["nombre"], false)
	AudioManager.play_sfx("buy")

	Stats.incrementar("upgrades_euros_comprados")
	_check_logro_polifacetico()
	_notif_tutorial("compra_realizada")


func _aplicar_efecto(datos: Dictionary) -> void:
	var efecto: Dictionary = datos.get("efecto", {})
	var tipo: String = efecto.get("tipo", "")
	var valor: float = efecto.get("valor", 0.0)

	match tipo:
		"fuerza_plus":
			sink_area.bonus_fuerza += valor
		"radio_plus":
			sink_area.bonus_radio += int(valor)
		"suerte":
			GarmentData.añadir_suerte(valor)
		_:
			push_warning("Tipo de efecto desconocido: " + tipo)


# ============================================================
# COMPRA DE LAVADORAS
# ============================================================
func _on_lavadora_compra_solicitada(tipo: String, precio: int, ceniza_req: int) -> void:
	if euros < precio:
		mostrar_notificacion("No tienes suficiente dinero", false)
		AudioManager.play_sfx("denied")
		return
	if ceniza < ceniza_req:
		mostrar_notificacion("Te falta Ceniza (necesitas %d)" % ceniza_req, false)
		AudioManager.play_sfx("denied")
		return

	euros -= precio
	euros_changed.emit(euros)
	if ceniza_req > 0:
		ceniza -= ceniza_req
		ceniza_changed.emit(ceniza)

	machines_panel.confirmar_compra(tipo)
	mostrar_notificacion("✓ Lavadora %s comprada" % tipo, false)
	AudioManager.play_sfx("buy", 0.85)

	match tipo:
		"basica": Stats.incrementar("lavadoras_basicas_compradas")
		"industrial": Stats.incrementar("lavadoras_industriales_compradas")
		"cuantica": Stats.incrementar("lavadoras_cuanticas_compradas")

	_notif_tutorial("lavadora_comprada")


# ============================================================
# LAVADORA TERMINA UN CICLO
# ============================================================
func _on_prenda_procesada_lavadora(prenda: Dictionary, earned: float, era_cuantica: bool) -> void:
	var es_alien: bool = bool(prenda.get("es_alien", false))

	# Fase 7: bonus_recompensa_alien aplica antes del multiplicador
	var earned_pre_mult: float = earned
	if es_alien and bonus_recompensa_alien > 0.0:
		earned_pre_mult *= (1.0 + bonus_recompensa_alien)
	# Fase 10: _ev_mult_recompensa (Hora dorada)
	var earned_real: float = earned_pre_mult * multiplicador_ganancias * _ev_mult_recompensa

	euros += earned_real
	euros_totales_ganados += earned_real
	euros_changed.emit(euros)

	var ceniza_ganada: int = prenda.get("ceniza_bonus", 0)
	var fragmentos_ganados: int = prenda.get("fragmentos_bonus", 0)

	# eco_plasma aplica también a alien procesadas en lavadora (cualquier ruta)
	# Fase 10: Susurro del altar suma +1 frag adicional
	if es_alien:
		fragmentos_ganados += bonus_frag_alien + _ev_bonus_frag_alien
	# Comunión NO aplica aquí: solo limpieza manual

	if era_cuantica and fragmentos_ganados > 0:
		fragmentos_ganados = max(1, int(round(fragmentos_ganados * 0.5)))

	if ceniza_ganada > 0:
		ceniza += ceniza_ganada
		ceniza_changed.emit(ceniza)
	if fragmentos_ganados > 0:
		fragmentos += fragmentos_ganados
		fragmentos_changed.emit(fragmentos)

	var texto := "🌀 +%d€" % int(earned_real)
	if es_alien:
		texto = "🌀 ALIEN  +%d€" % int(earned_real)
	mostrar_notificacion(texto, es_alien)
	_actualizar_estado_prestige_button()

	# Fase 9: número flotante + sonido (sobre el panel de lavadoras)
	var pos_lav: Vector2 = machines_panel.global_position + Vector2(
		machines_panel.size.x * 0.5 + randf_range(-30, 30),
		randf_range(280, 460)
	)
	_spawn_floating_number("+%d€" % int(earned_real), Color("#FFD060"), pos_lav, 18)
	AudioManager.play_sfx("machine_done", randf_range(0.95, 1.05))

	# Fase 10: gate de eventos
	EventsManager.comprobar_gate(euros_totales_ganados, num_prestigios)
	# Fase 13: contratos (las prendas de lavadora también cuentan)
	ContractsManager.comprobar_gate(euros_totales_ganados, num_prestigios)
	ContractsManager.notificar_prenda(prenda)

	# Fase 8: stats
	Stats.incrementar("prendas_total_lavadora")
	if earned_real > 0.0:
		Stats.incrementar("euros_total_historico", earned_real)
	if ceniza_ganada > 0:
		Stats.incrementar("ceniza_total_historico", ceniza_ganada)
	if fragmentos_ganados > 0:
		Stats.incrementar("fragmentos_total_historico", fragmentos_ganados)
	if es_alien:
		Stats.incrementar("aliens_total_lavadora")
		_check_logros_aliens_combinados()
	Stats.set_max("max_euros_en_run", euros)


# ============================================================
# TIENDA DE CENIZA — UPGRADES PERMANENTES
# ============================================================
func _on_upgrade_ceniza_solicitado(upgrade_id: String, coste: int) -> void:
	if ceniza < coste:
		mostrar_notificacion("Te falta Ceniza (necesitas %d 🜁)" % coste, false)
		AudioManager.play_sfx("denied")
		return

	ceniza -= coste
	ceniza_changed.emit(ceniza)

	_aplicar_efecto_ceniza(upgrade_id)

	ash_shop_panel.confirmar_compra(upgrade_id)
	ceniza_upgrade_aplicado.emit(upgrade_id)
	mostrar_notificacion("✓ Mejora de Ceniza aplicada", false)
	AudioManager.play_sfx("buy", 1.15)

	Stats.incrementar("upgrades_ceniza_comprados")
	_check_logro_polifacetico()


func _aplicar_efecto_ceniza(upgrade_id: String) -> void:
	match upgrade_id:
		"multi_ganancias":
			multi_compras_contador += 1
			multiplicador_ganancias = min(1.0 + multi_compras_contador * 0.05, 3.0)
		"alien_boost":
			alien_boost_contador += 1
			GarmentData.añadir_suerte_ceniza(0.05)
		"velocidad_cola":
			velocidad_cola_activa = true
		"memoria_prendas":
			memoria_prendas_activa = true
			machines_panel.activar_memoria_prendas()
		_:
			push_warning("Upgrade de Ceniza desconocido: " + upgrade_id)


# ============================================================
# ALTAR DE FRAGMENTOS — UPGRADES PERMANENTES (Fase 7)
# ============================================================
func _on_upgrade_fragmento_solicitado(upgrade_id: String, coste: int) -> void:
	if fragmentos < coste:
		mostrar_notificacion("Te faltan fragmentos (necesitas %d ✧)" % coste, false)
		AudioManager.play_sfx("denied")
		return

	fragmentos -= coste
	fragmentos_changed.emit(fragmentos)

	_aplicar_efecto_fragmento(upgrade_id)

	fragment_shop_panel.confirmar_compra(upgrade_id)
	fragmento_upgrade_aplicado.emit(upgrade_id)
	mostrar_notificacion("✦ %s aplicado" % fragment_shop_panel.get_upgrade(upgrade_id).get("nombre", upgrade_id), false)
	AudioManager.play_sfx("buy", 0.7)  # pitch grave: "altar"

	Stats.incrementar("upgrades_fragmentos_comprados")
	_check_logro_polifacetico()
	# Susurrador: ambas prendas alien del altar desbloqueadas
	if GarmentData.prendas_desbloqueadas.size() >= 2:
		Stats.notificar_evento("susurrador")


func _aplicar_efecto_fragmento(upgrade_id: String) -> void:
	# Fase 14: si la mejora tiene texto de lore, mostrarlo en popup narrativo
	var datos: Dictionary = fragment_shop_panel.get_upgrade(upgrade_id)
	var lore: String = String(datos.get("lore", ""))
	if not lore.is_empty():
		_mostrar_lore_altar(lore)

	match upgrade_id:
		"eco_plasma":
			bonus_frag_alien += 1
		"murmullo_vacio":
			bonus_recompensa_alien = min(bonus_recompensa_alien + 0.10, 0.40)
		"compas_observador":
			GarmentData.bonus_prob_alien += 0.02
		"compresor_temporal":
			machines_panel.aplicar_bonus_velocidad_cuantica(0.20)
		"sudario_mensajero":
			GarmentData.desbloquear_prenda("sudario_mensajero")
		"resonancia_ancestral":
			bonus_ceniza_prestigio += 1
		"velo_inicio":
			GarmentData.desbloquear_prenda("velo_inicio")
		"comunion":
			comunion_activa = true
		_:
			push_warning("Upgrade de Fragmento desconocido: " + upgrade_id)


# ============================================================
# PRESTIGIO — BOTÓN CONDICIONAL
# ============================================================

## Comprueba si hay que revelar o actualizar el estado del botón de prestigio.
## Llamar cada vez que euros_totales_ganados cambia.
func _actualizar_estado_prestige_button() -> void:
	if not prestigio_desbloqueado:
		if euros_totales_ganados >= UMBRAL_PRESTIGIO_PRIMER_USO:
			prestigio_desbloqueado = true
			prestige_button.visible = true
			_estilizar_prestige_button(true)
			var preview: int = int(floor(euros_totales_ganados / 1000.0)) + 1 + bonus_ceniza_prestigio
			prestige_button.text = "PRESTIGIO  +%d 🜁" % preview
			mostrar_notificacion("🜁 Algo arde en el aire. Puedes prestigiar.", false)
			_notif_tutorial("prestigio_visible")
		return

	# Ya visible: activo solo si la Ceniza calculada sería ≥ 3
	# Fase 11C: incluimos la preview de ceniza en el propio texto del botón
	var preview: int = int(floor(euros_totales_ganados / 1000.0)) + 1 + bonus_ceniza_prestigio
	var activo: bool = preview >= 3
	prestige_button.text = "PRESTIGIO  +%d 🜁" % preview
	prestige_button.disabled = not activo
	_estilizar_prestige_button(activo)


func _estilizar_prestige_button(activo: bool) -> void:
	var en := StyleBoxFlat.new()
	en.set_corner_radius_all(6)
	var pr := StyleBoxFlat.new()
	pr.set_corner_radius_all(6)
	if activo:
		en.bg_color = Color("#FF4040")
		pr.bg_color = Color("#CC2020")
	else:
		en.bg_color = Color("#552020")
		pr.bg_color = Color("#331010")
	prestige_button.add_theme_stylebox_override("normal", en)
	prestige_button.add_theme_stylebox_override("hover", en)
	prestige_button.add_theme_stylebox_override("pressed", pr)
	prestige_button.add_theme_stylebox_override("disabled", en)
	prestige_button.add_theme_font_size_override("font_size", 13)


func _on_prestige_button_pressed() -> void:
	var ceniza_preview: int = int(floor(euros_totales_ganados / 1000.0)) + 1
	prestige_dialog.mostrar(ceniza_preview, num_prestigios)


func _on_prestige_cancelado() -> void:
	prestige_dialog.visible = false


func _on_prestige_confirmado() -> void:
	var texto: String = prestige_dialog.texto_seleccionado
	prestige_dialog.visible = false
	await _animar_prestigio(texto)
	_ejecutar_prestigio()
	await get_tree().process_frame
	queue_panel.consumir_siguiente()


func _animar_prestigio(texto: String) -> void:
	narrativo_label.text = texto
	narrativo_label.modulate.a = 0.0
	narrativo_label.visible = false
	prestige_overlay.modulate.a = 0.0
	prestige_overlay.visible = true

	AudioManager.play_sfx("prestige")

	var tw_in := create_tween()
	tw_in.tween_property(prestige_overlay, "modulate:a", 1.0, 0.5)
	await tw_in.finished

	narrativo_label.visible = true
	var tw_txt := create_tween()
	tw_txt.tween_property(narrativo_label, "modulate:a", 1.0, 0.4)
	await tw_txt.finished

	await get_tree().create_timer(2.2).timeout

	var tw_out := create_tween()
	tw_out.tween_property(prestige_overlay, "modulate:a", 0.0, 0.5)
	await tw_out.finished
	prestige_overlay.visible = false
	narrativo_label.visible = false


func _ejecutar_prestigio() -> void:
	# Fase 7: +1 ceniza base por compra de "Resonancia ancestral"
	var ceniza_ganada: int = int(floor(euros_totales_ganados / 1000.0)) + 1 + bonus_ceniza_prestigio
	num_prestigios += 1

	euros = 0.0
	euros_totales_ganados = 0.0
	ceniza += ceniza_ganada

	GarmentData.resetear_suerte_euros()
	prestige_realizado.emit()

	if memoria_prendas_activa:
		machines_panel.activar_memoria_prendas()

	euros_changed.emit(euros)
	ceniza_changed.emit(ceniza)
	_update_hud()
	_actualizar_estado_prestige_button()

	mostrar_notificacion("+%d 🜁 Ceniza  (Prestigio #%d)" % [ceniza_ganada, num_prestigios], false)

	# Fase 8: stats
	Stats.incrementar("prestigios_total")
	# Fase 10: el primer prestigio abre el gate de eventos
	EventsManager.comprobar_gate(euros_totales_ganados, num_prestigios)
	# Fase 11A: tutorial — cierra el paso "prestigio"
	_notif_tutorial("prestigio_hecho")

	# Snapshot inmediato del estado post-prestigio
	guardar_partida()


# ============================================================
# HUD
# ============================================================
func _on_euros_changed(_val: float) -> void:
	_update_hud()
	shop_panel.actualizar_euros(euros)
	machines_panel.actualizar_recursos(euros, ceniza)
	_chequear_desbloqueos_tutorial()


func _on_ceniza_changed(_val: int) -> void:
	_update_hud()
	machines_panel.actualizar_recursos(euros, ceniza)
	ash_shop_panel.actualizar_ceniza(ceniza)


func _on_fragmentos_changed(_val: int) -> void:
	_update_hud()
	fragment_shop_panel.actualizar_fragmentos(fragmentos)


func _update_hud() -> void:
	euros_label.text = "€ %d" % int(euros)
	ceniza_label.text = "🜁 %d" % ceniza
	fragmentos_label.text = "✧ %d" % fragmentos


# ============================================================
# NOTIFICACIONES
# ============================================================
func mostrar_notificacion(texto: String, es_alien: bool = false) -> void:
	notif_label.text = texto
	notif_label.visible = true
	if es_alien:
		notif_label.add_theme_color_override("font_color", Color("#AA40FF"))
	else:
		notif_label.add_theme_color_override("font_color", Color("#FFAA00"))

	var tween := create_tween()
	notif_label.modulate.a = 0.0
	tween.tween_property(notif_label, "modulate:a", 1.0, 0.3)
	notif_timer.stop()
	notif_timer.start()


func _on_notif_timer_timeout() -> void:
	var tween := create_tween()
	tween.tween_property(notif_label, "modulate:a", 0.0, 0.5)
	await tween.finished
	notif_label.visible = false


# ============================================================
# DEBUG — ATAJOS DE TECLADO (solo activos si DEBUG_MODE == true)
# ============================================================
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not (event as InputEventKey).pressed:
		return
	var key_event := event as InputEventKey
	# Atajos de jugador (siempre activos)
	match key_event.keycode:
		KEY_SPACE:
			if sink_area.intentar_entregar():
				get_viewport().set_input_as_handled()
			return
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			var slot: int = key_event.keycode - KEY_1
			_on_intento_seleccion_lavadora(slot)
			get_viewport().set_input_as_handled()
			return
	# Atajos de debug (solo en DEBUG_MODE)
	if not DEBUG_MODE:
		return
	match key_event.keycode:
		KEY_F1: _debug_dar_recursos()
		KEY_F2: _debug_reset_confirmar()
		KEY_F3: _debug_forzar_alien()
		KEY_F4: _debug_completar_ciclos()
		KEY_F5: _debug_limpiar_prenda()
		KEY_F6: _debug_guardar()
		KEY_F7: _debug_forzar_evento()
		KEY_F8: _debug_forzar_contrato()


# ============================================================
# DEBUG — PANEL VISUAL
# ============================================================
func _crear_panel_debug() -> void:
	var raiz := Control.new()
	raiz.position = Vector2(5, 5)
	raiz.z_index = 100
	$HUD.add_child(raiz)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	raiz.add_child(vbox)

	# Botón toggle (siempre visible en debug)
	_debug_btn_toggle = Button.new()
	_debug_btn_toggle.text = "🛠 DEBUG ▶"
	_debug_btn_toggle.custom_minimum_size = Vector2(150, 32)
	_estilizar_debug_boton(_debug_btn_toggle, "#AA2020", "#FFAAAA")
	_debug_btn_toggle.pressed.connect(_on_debug_toggle)
	vbox.add_child(_debug_btn_toggle)

	# Panel expandible con los 5 botones (colapsado por defecto)
	_debug_panel_fondo = PanelContainer.new()
	_debug_panel_fondo.visible = false
	var estilo_fondo := StyleBoxFlat.new()
	estilo_fondo.bg_color = Color("#1A0000")
	estilo_fondo.border_color = Color("#FF6060")
	estilo_fondo.set_border_width_all(1)
	estilo_fondo.set_corner_radius_all(4)
	estilo_fondo.content_margin_left = 5
	estilo_fondo.content_margin_right = 5
	estilo_fondo.content_margin_top = 5
	estilo_fondo.content_margin_bottom = 5
	_debug_panel_fondo.add_theme_stylebox_override("panel", estilo_fondo)
	vbox.add_child(_debug_panel_fondo)

	var contenido := VBoxContainer.new()
	contenido.add_theme_constant_override("separation", 3)
	_debug_panel_fondo.add_child(contenido)

	var acciones: Array = [
		["Dar recursos      (F1)", _debug_dar_recursos],
		["Reset total       (F2)", _debug_reset_confirmar],
		["Forzar alien      (F3)", _debug_forzar_alien],
		["Completar ciclos  (F4)", _debug_completar_ciclos],
		["Limpiar prenda    (F5)", _debug_limpiar_prenda],
		["Guardar ahora     (F6)", _debug_guardar],
		["Forzar evento     (F7)", _debug_forzar_evento],
		["Forzar contrato   (F8)", _debug_forzar_contrato],
	]
	for a in acciones:
		var btn := Button.new()
		btn.text = a[0]
		btn.custom_minimum_size = Vector2(185, 26)
		_estilizar_debug_boton(btn, "#3A0000", "#FF8080")
		btn.pressed.connect(a[1])
		contenido.add_child(btn)

	_crear_debug_confirm_panel()


func _crear_debug_confirm_panel() -> void:
	_debug_confirm_panel = Control.new()
	_debug_confirm_panel.visible = false
	_debug_confirm_panel.z_index = 200
	$HUD.add_child(_debug_confirm_panel)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 110)
	panel.position = Vector2(490, 305)

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("#1A0000")
	estilo.border_color = Color("#FF4040")
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(8)
	estilo.content_margin_left = 16
	estilo.content_margin_right = 16
	estilo.content_margin_top = 12
	estilo.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", estilo)
	_debug_confirm_panel.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "¿RESET TOTAL?\n(euros, ceniza, todo)"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color("#FF8080"))
	lbl.add_theme_font_size_override("font_size", 14)
	vbox.add_child(lbl)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 15)
	vbox.add_child(hbox)

	var btn_si := Button.new()
	btn_si.text = "Sí, borrar todo"
	btn_si.custom_minimum_size = Vector2(130, 34)
	_estilizar_debug_boton(btn_si, "#AA2020", "#FFAAAA")
	btn_si.pressed.connect(_debug_ejecutar_reset)
	hbox.add_child(btn_si)

	var btn_no := Button.new()
	btn_no.text = "Cancelar"
	btn_no.custom_minimum_size = Vector2(90, 34)
	_estilizar_debug_boton(btn_no, "#2A2A4A", "#AAAACC")
	btn_no.pressed.connect(func(): _debug_confirm_panel.visible = false)
	hbox.add_child(btn_no)


func _on_debug_toggle() -> void:
	_debug_panel_fondo.visible = not _debug_panel_fondo.visible
	_debug_btn_toggle.text = "🛠 DEBUG %s" % ("▼" if _debug_panel_fondo.visible else "▶")


func _estilizar_debug_boton(btn: Button, bg: String, fg: String) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = Color(bg)
	n.set_corner_radius_all(4)
	var h := StyleBoxFlat.new()
	h.bg_color = Color(bg).lightened(0.15)
	h.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", n)
	btn.add_theme_color_override("font_color", Color(fg))
	btn.add_theme_color_override("font_disabled_color", Color(fg).darkened(0.4))
	btn.add_theme_font_size_override("font_size", 11)


# ============================================================
# DEBUG — ACCIONES
# ============================================================
func _debug_dar_recursos() -> void:
	euros += 10000.0
	euros_totales_ganados += 10000.0
	ceniza += 5
	fragmentos += 3
	euros_changed.emit(euros)
	ceniza_changed.emit(ceniza)
	fragmentos_changed.emit(fragmentos)
	_update_hud()
	_actualizar_estado_prestige_button()
	EventsManager.comprobar_gate(euros_totales_ganados, num_prestigios)
	mostrar_notificacion("[DEBUG] +10k€  +5🜁  +3frag", false)


func _debug_reset_confirmar() -> void:
	if _debug_confirm_panel != null:
		_debug_confirm_panel.visible = true


func _debug_ejecutar_reset() -> void:
	if _debug_confirm_panel != null:
		_debug_confirm_panel.visible = false

	# Resetear TODA la partida: estado por-run y estado permanente
	euros = 0.0
	euros_totales_ganados = 0.0
	ceniza = 0
	fragmentos = 0
	favores = 0
	num_prestigios = 0
	prestigio_desbloqueado = false
	multiplicador_ganancias = 1.0
	multi_compras_contador = 0
	alien_boost_contador = 0
	memoria_prendas_activa = false
	velocidad_cola_activa = false
	# Fase 7
	bonus_frag_alien = 0
	bonus_recompensa_alien = 0.0
	bonus_ceniza_prestigio = 0
	comunion_activa = false

	GarmentData.resetear_suerte()
	GarmentData.bonus_prob_alien = 0.0
	GarmentData.prendas_desbloqueadas.clear()
	ash_shop_panel.reset_completo()
	fragment_shop_panel.reset_completo()
	shop_panel.reset_compras()
	machines_panel.bonus_reduccion_ciclo_cuantica = 0.0
	machines_panel.mult_velocidad_evento = 1.0
	machines_panel.reset_lavadoras()
	queue_panel.reset_cola()
	sink_area.reset_sink()
	sink_area.bonus_fuerza_evento = 0.0
	Stats.reset_completo()
	EventsManager.reset_completo()
	ContractsManager.reset_completo()
	if _tutorial != null:
		_tutorial.reset_completo()
		_tutorial.iniciar()
	# Fase 10 — limpiar variables temporales
	_ev_mult_recompensa = 1.0
	_ev_bonus_prob_alien = 0.0
	_ev_bonus_frag_alien = 0
	_ev_bonus_fuerza = 0.0
	_ev_mult_velocidad_lavadoras = 1.0

	prestige_button.visible = false

	# Borra también el save: si no, al reabrir el juego volvería el estado anterior
	borrar_save()

	euros_changed.emit(euros)
	ceniza_changed.emit(ceniza)
	fragmentos_changed.emit(fragmentos)
	_update_hud()
	shop_panel.actualizar_euros(euros)
	machines_panel.actualizar_recursos(euros, ceniza)
	ash_shop_panel.actualizar_ceniza(ceniza)
	fragment_shop_panel.actualizar_fragmentos(fragmentos)

	await get_tree().process_frame
	queue_panel.consumir_siguiente()
	mostrar_notificacion("[DEBUG] Reset total ejecutado", false)


func _debug_forzar_alien() -> void:
	GarmentData.forzar_siguiente_alien()
	mostrar_notificacion("[DEBUG] Próxima prenda: ALIEN", false)


func _debug_completar_ciclos() -> void:
	machines_panel.completar_todos_los_ciclos()
	mostrar_notificacion("[DEBUG] Ciclos de lavadoras completados", false)


func _debug_limpiar_prenda() -> void:
	sink_area.limpiar_instantaneo()
	mostrar_notificacion("[DEBUG] Prenda limpia al instante", false)


func _debug_guardar() -> void:
	if guardar_partida():
		mostrar_notificacion("[DEBUG] Partida guardada", false)
	else:
		mostrar_notificacion("[DEBUG] Error guardando", false)


## [Debug F7] Dispara un evento aleatorio inmediatamente, saltando cooldown y gate.
func _debug_forzar_evento() -> void:
	EventsManager.habilitado = true
	if not EventsManager.evento_activo.is_empty():
		mostrar_notificacion("[DEBUG] Ya hay un evento activo", false)
		return
	EventsManager.cooldown_restante = 0.0
	EventsManager._disparar_evento()
	mostrar_notificacion("[DEBUG] Evento forzado", false)


## [Debug F8] Ofrece un contrato aleatorio inmediatamente (skip gate + cooldown).
func _debug_forzar_contrato() -> void:
	ContractsManager.habilitado = true
	if not ContractsManager.contrato_activo.is_empty() or not ContractsManager.contrato_disponible.is_empty():
		mostrar_notificacion("[DEBUG] Ya hay un contrato activo/disponible", false)
		return
	ContractsManager.cooldown_restante = 0.0
	ContractsManager._ofrecer_contrato()
	mostrar_notificacion("[DEBUG] Contrato forzado", false)


# ============================================================
# FASE 6 — PERSISTENCIA
# ============================================================
##
## Esquema del save (versión 1, extendido en Fase 7):
##   {
##     "version": <int>,
##     "main": { euros, euros_totales_ganados, ceniza, fragmentos, favores,
##               num_prestigios, prestigio_desbloqueado, multiplicador_ganancias,
##               memoria_prendas_activa, velocidad_cola_activa,
##               multi_compras_contador, alien_boost_contador,
##               bonus_frag_alien, bonus_recompensa_alien,
##               bonus_ceniza_prestigio, comunion_activa },
##     "garment_data": GarmentData.serializar(),  # incluye prendas_desbloqueadas
##     "shop_panel":   shop_panel.serializar(),
##     "ash_shop_panel": ash_shop_panel.serializar(),
##     "fragment_shop_panel": fragment_shop_panel.serializar(),
##     "machines_panel": machines_panel.serializar(),  # incluye bonus_reduccion_ciclo_cuantica
##     "queue_panel":  queue_panel.serializar(),
##     "sink_area":    sink_area.serializar(),
##     "stats":        Stats.serializar(),           # contadores + desbloqueados (Fase 8)
##   }
##
## Las prendas se serializan como IDs (no como Dictionary): los Color de las
## prendas no son JSON-serializables, y GarmentData.get_prenda_por_id() las
## reconstruye sin ambigüedad. La textura de manchas no se persiste: la prenda
## en curso se recarga fresca al cargar partida.
##
## Saves de Fase 6 (sin sección "fragment_shop_panel") cargan correctamente:
## los `data.get(..., default)` rellenan los campos faltantes con valores neutros.

func guardar_partida() -> bool:
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"main": {
			"euros": euros,
			"euros_totales_ganados": euros_totales_ganados,
			"ceniza": ceniza,
			"fragmentos": fragmentos,
			"favores": favores,
			"num_prestigios": num_prestigios,
			"prestigio_desbloqueado": prestigio_desbloqueado,
			"multiplicador_ganancias": multiplicador_ganancias,
			"memoria_prendas_activa": memoria_prendas_activa,
			"velocidad_cola_activa": velocidad_cola_activa,
			"multi_compras_contador": multi_compras_contador,
			"alien_boost_contador": alien_boost_contador,
			# Fase 7 — efectos del altar
			"bonus_frag_alien": bonus_frag_alien,
			"bonus_recompensa_alien": bonus_recompensa_alien,
			"bonus_ceniza_prestigio": bonus_ceniza_prestigio,
			"comunion_activa": comunion_activa,
		},
		"garment_data": GarmentData.serializar(),
		"shop_panel": shop_panel.serializar(),
		"ash_shop_panel": ash_shop_panel.serializar(),
		"fragment_shop_panel": fragment_shop_panel.serializar(),
		"machines_panel": machines_panel.serializar(),
		"queue_panel": queue_panel.serializar(),
		"sink_area": sink_area.serializar(),
		"stats": Stats.serializar(),
		"tutorial": _tutorial.serializar() if _tutorial != null else {},
		"opciones": {
			"volumen_db": AudioManager.get_volumen_db(),
		},
		"timestamp_guardado": Time.get_unix_time_from_system(),
	}

	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("No se pudo abrir %s para escritura (err=%d)" % [SAVE_PATH, FileAccess.get_open_error()])
		return false
	f.store_string(JSON.stringify(payload, "  "))
	f.close()
	_flash_save_indicator()
	return true


## Lee el save y aplica el estado a todos los subsistemas.
## Devuelve true si la carga fue válida (y por tanto el sink puede tener prenda).
func cargar_partida() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var contenido: String = f.get_as_text()
	f.close()

	var parsed: Variant = JSON.parse_string(contenido)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save corrupto: no es un Dictionary")
		return false

	var data: Dictionary = parsed
	var version: int = int(data.get("version", 0))
	if version != SAVE_VERSION:
		push_warning("Save de versión %d, esperaba %d — ignorando" % [version, SAVE_VERSION])
		return false

	# 1. Estado de Main
	var m: Dictionary = data.get("main", {})
	euros = float(m.get("euros", 0.0))
	euros_totales_ganados = float(m.get("euros_totales_ganados", 0.0))
	ceniza = int(m.get("ceniza", 0))
	fragmentos = int(m.get("fragmentos", 0))
	favores = int(m.get("favores", 0))
	num_prestigios = int(m.get("num_prestigios", 0))
	prestigio_desbloqueado = bool(m.get("prestigio_desbloqueado", false))
	multiplicador_ganancias = float(m.get("multiplicador_ganancias", 1.0))
	memoria_prendas_activa = bool(m.get("memoria_prendas_activa", false))
	velocidad_cola_activa = bool(m.get("velocidad_cola_activa", false))
	multi_compras_contador = int(m.get("multi_compras_contador", 0))
	alien_boost_contador = int(m.get("alien_boost_contador", 0))
	# Fase 7
	bonus_frag_alien = int(m.get("bonus_frag_alien", 0))
	bonus_recompensa_alien = float(m.get("bonus_recompensa_alien", 0.0))
	bonus_ceniza_prestigio = int(m.get("bonus_ceniza_prestigio", 0))
	comunion_activa = bool(m.get("comunion_activa", false))

	# 2. Subsistemas
	GarmentData.cargar_estado(data.get("garment_data", {}))
	shop_panel.cargar_estado(data.get("shop_panel", {}))
	ash_shop_panel.cargar_estado(data.get("ash_shop_panel", {}))
	fragment_shop_panel.cargar_estado(data.get("fragment_shop_panel", {}))
	machines_panel.cargar_estado(data.get("machines_panel", {}))
	queue_panel.cargar_estado(data.get("queue_panel", {}))
	var sink_tenia_prenda: bool = sink_area.cargar_estado(data.get("sink_area", {}))
	Stats.cargar_estado(data.get("stats", {}))
	if _tutorial != null:
		_tutorial.cargar_estado(data.get("tutorial", {}))

	# Fase 11C: opciones
	var opciones: Dictionary = data.get("opciones", {})
	if opciones.has("volumen_db"):
		AudioManager.set_volumen_db(float(opciones["volumen_db"]))
		if _opciones_slider != null:
			_opciones_slider.value = AudioManager.get_volumen_db()

	# 3. Estado derivado: si memoria_prendas_activa, propagarlo al panel de lavadoras
	# (cargar_estado ya lo restauró desde su propia sección, pero por si la mejora se
	# compró antes de tener lavadoras esto deja todo coherente)
	if memoria_prendas_activa:
		machines_panel.activar_memoria_prendas()

	# 4. Botón de prestigio + HUD
	prestige_button.visible = prestigio_desbloqueado
	_estilizar_prestige_button(prestigio_desbloqueado)
	_actualizar_estado_prestige_button()

	euros_changed.emit(euros)
	ceniza_changed.emit(ceniza)
	fragmentos_changed.emit(fragmentos)
	_update_hud()
	shop_panel.actualizar_euros(euros)
	machines_panel.actualizar_recursos(euros, ceniza)
	ash_shop_panel.actualizar_ceniza(ceniza)
	fragment_shop_panel.actualizar_fragmentos(fragmentos)

	# 5. Si el sink no tenía prenda en el save, arrancamos el ciclo normal
	if not sink_tenia_prenda:
		queue_panel.consumir_siguiente()

	# 6. Fase 12: ganancias offline (si había timestamp y hay lavadoras)
	var ts_guardado: float = float(data.get("timestamp_guardado", 0.0))
	if ts_guardado > 0.0:
		_aplicar_progreso_offline(ts_guardado)

	return true


## Borra el archivo de save del disco. Idempotente.
func borrar_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# ============================================================
# AUTOSAVE
# ============================================================
func _on_autosave_timer_timeout() -> void:
	guardar_partida()


## Indicador 💾 en el HUD que parpadea cuando se autoguarda.
func _crear_save_indicator() -> void:
	_save_indicator = Label.new()
	_save_indicator.text = "💾"
	_save_indicator.add_theme_font_size_override("font_size", 14)
	_save_indicator.add_theme_color_override("font_color", Color("#40FF80"))
	# Anclado a la esquina superior derecha del HUD
	_save_indicator.anchor_left = 1.0
	_save_indicator.anchor_top = 0.0
	_save_indicator.anchor_right = 1.0
	_save_indicator.anchor_bottom = 0.0
	_save_indicator.offset_left = -32
	_save_indicator.offset_top = 6
	_save_indicator.offset_right = -8
	_save_indicator.offset_bottom = 28
	_save_indicator.modulate.a = 0.0
	$HUD.add_child(_save_indicator)


func _flash_save_indicator() -> void:
	if _save_indicator == null:
		return
	var tw := create_tween()
	tw.tween_property(_save_indicator, "modulate:a", 1.0, 0.2)
	tw.tween_interval(0.8)
	tw.tween_property(_save_indicator, "modulate:a", 0.0, 0.4)


# ============================================================
# CIERRE DE VENTANA — guardado final
# ============================================================
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		guardar_partida()
		get_tree().quit()


# ============================================================
# FASE 8 — LOGROS COMBINADOS
# ============================================================
func _check_logros_aliens_combinados() -> void:
	var total: float = Stats.get_stat("aliens_total_manual") + Stats.get_stat("aliens_total_lavadora")
	if total >= 10:
		Stats.notificar_evento("cazador_alien_10")
	if total >= 50:
		Stats.notificar_evento("coleccionista_alien_50")


func _check_logro_polifacetico() -> void:
	if Stats.get_stat("upgrades_euros_comprados") >= 1 \
			and Stats.get_stat("upgrades_ceniza_comprados") >= 1 \
			and Stats.get_stat("upgrades_fragmentos_comprados") >= 1:
		Stats.notificar_evento("polifacetico")


# ============================================================
# FASE 8 — OVERLAY DE LOGROS + BOTÓN + NOTIFICACIÓN
# ============================================================
func _crear_achievements_overlay() -> void:
	var script: GDScript = load("res://achievements_overlay.gd")
	_achievements_overlay = script.new()
	$HUD.add_child(_achievements_overlay)


func _crear_btn_logros() -> void:
	_btn_logros = Button.new()
	_btn_logros.text = "📊"
	_btn_logros.tooltip_text = "Logros y estadísticas"
	# Esquina inferior derecha, lejos de tabs, PrestigeButton y CoinsPanel.
	_btn_logros.anchor_left = 1.0
	_btn_logros.anchor_top = 1.0
	_btn_logros.anchor_right = 1.0
	_btn_logros.anchor_bottom = 1.0
	_btn_logros.offset_left = -64
	_btn_logros.offset_top = -54
	_btn_logros.offset_right = -16
	_btn_logros.offset_bottom = -16
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#2A2A4A")
	s.set_corner_radius_all(4)
	_btn_logros.add_theme_stylebox_override("normal", s)
	_btn_logros.add_theme_stylebox_override("hover", s)
	_btn_logros.add_theme_stylebox_override("pressed", s)
	_btn_logros.add_theme_font_size_override("font_size", 14)
	_btn_logros.add_theme_color_override("font_color", Color("#FFFFCC"))
	_btn_logros.pressed.connect(_on_btn_logros_pressed)
	$HUD.add_child(_btn_logros)


func _on_btn_logros_pressed() -> void:
	if _achievements_overlay != null:
		_achievements_overlay.mostrar()


# ============================================================
# FASE 9 — FEEDBACK VISUAL
# ============================================================
## Spawn de Label flotante que sube y se desvanece.
func _spawn_floating_number(texto: String, color: Color, pos: Vector2, size_px: int = 20) -> void:
	var lbl := Label.new()
	lbl.text = texto
	lbl.add_theme_font_size_override("font_size", size_px)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.position = pos + Vector2(randf_range(-12, 12), 0)
	lbl.z_index = 90
	$HUD.add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 70, 0.9)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.9).set_delay(0.25)
	await tw.finished
	lbl.queue_free()


func _on_logro_desbloqueado(logro_id: String) -> void:
	AudioManager.play_sfx("achievement")
	_logro_popup_queue.append(logro_id)
	if not _logro_popup_activo:
		_procesar_siguiente_popup()


func _procesar_siguiente_popup() -> void:
	if _logro_popup_queue.is_empty():
		_logro_popup_activo = false
		return
	_logro_popup_activo = true
	var logro_id: String = _logro_popup_queue.pop_front()
	await _mostrar_achievement_popup(logro_id)
	_procesar_siguiente_popup()


## Popup deslizante: entra por la derecha, hold, sale por la derecha.
func _mostrar_achievement_popup(logro_id: String) -> void:
	var l: Dictionary = Stats.get_logro(logro_id)
	if l.is_empty():
		return

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 64)
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#1A1A30")
	s.border_color = Color("#FFD060")
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", s)
	panel.z_index = 95

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	var icono := Label.new()
	icono.text = String(l.get("icono", "🏆"))
	icono.add_theme_font_size_override("font_size", 32)
	icono.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(icono)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)

	var titulo := Label.new()
	titulo.text = "🏆 LOGRO: " + String(l["nombre"])
	titulo.add_theme_color_override("font_color", Color("#FFD060"))
	titulo.add_theme_font_size_override("font_size", 13)
	vbox.add_child(titulo)

	var desc := Label.new()
	desc.text = String(l["descripcion"])
	desc.add_theme_color_override("font_color", Color("#A0A0CC"))
	desc.add_theme_font_size_override("font_size", 10)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc)

	# Anclado a la esquina superior derecha, debajo del PrestigeButton/tabs
	const ANCHO_VP: int = 1280
	const TARGET_Y: int = 110
	panel.position = Vector2(ANCHO_VP + 20, TARGET_Y)
	$HUD.add_child(panel)

	var pos_target_x: float = ANCHO_VP - 320.0
	var tw := create_tween()
	tw.tween_property(panel, "position:x", pos_target_x, 0.35) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(2.4)
	tw.tween_property(panel, "position:x", float(ANCHO_VP + 20), 0.25).set_ease(Tween.EASE_IN)
	await tw.finished
	panel.queue_free()


# ============================================================
# FASE 10 — EVENTOS ALEATORIOS
# ============================================================
func _crear_event_banner() -> void:
	_event_banner = PanelContainer.new()
	_event_banner.modulate.a = 0.0  # invisible mediante alpha, no `visible`
	_event_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_event_banner.z_index = 70
	# Anclado al centro-superior del HUD, debajo del NotifLabel
	_event_banner.anchor_left = 0.5
	_event_banner.anchor_top = 0.0
	_event_banner.anchor_right = 0.5
	_event_banner.anchor_bottom = 0.0
	_event_banner.offset_left = -200
	_event_banner.offset_top = 95
	_event_banner.offset_right = 200
	_event_banner.offset_bottom = 158
	$HUD.add_child(_event_banner)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	_event_banner.add_child(hbox)

	_event_banner_icono = Label.new()
	_event_banner_icono.add_theme_font_size_override("font_size", 30)
	_event_banner_icono.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(_event_banner_icono)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)

	_event_banner_nombre = Label.new()
	_event_banner_nombre.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_event_banner_nombre)

	_event_banner_progreso = Label.new()
	_event_banner_progreso.add_theme_font_size_override("font_size", 11)
	_event_banner_progreso.add_theme_color_override("font_color", Color("#A0A0CC"))
	vbox.add_child(_event_banner_progreso)

	_event_banner_barra = ProgressBar.new()
	_event_banner_barra.custom_minimum_size = Vector2(0, 6)
	_event_banner_barra.show_percentage = false
	_event_banner_barra.value = 100.0
	vbox.add_child(_event_banner_barra)


func _on_evento_iniciado(id: String) -> void:
	var ev: Dictionary = EventsManager.get_evento(id)
	if ev.is_empty():
		return

	# Aplicar modificador
	match id:
		"lluvia_alien":
			_ev_bonus_prob_alien = 0.10
			GarmentData.bonus_prob_alien += _ev_bonus_prob_alien
		"hora_dorada":
			_ev_mult_recompensa = 2.0
		"susurro_altar":
			_ev_bonus_frag_alien = 1
		"frenesi_frotador":
			_ev_bonus_fuerza = 0.12
			sink_area.bonus_fuerza_evento = _ev_bonus_fuerza
		"pulso_cuantico":
			_ev_mult_velocidad_lavadoras = 1.5
			machines_panel.mult_velocidad_evento = _ev_mult_velocidad_lavadoras
		"pedido_vip":
			pass  # tracking en EventsManager
		_:
			push_warning("Evento desconocido: " + id)

	# Banner visible + estilizado con el color del evento
	var col := Color(String(ev["color"]))
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#1A1A2A")
	s.border_color = col
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	_event_banner.add_theme_stylebox_override("panel", s)
	_event_banner_icono.text = String(ev["icono"])
	_event_banner_nombre.text = String(ev["nombre"])
	_event_banner_nombre.add_theme_color_override("font_color", col)
	_event_banner_progreso.text = String(ev["descripcion"])

	var barra_estilo := StyleBoxFlat.new()
	barra_estilo.bg_color = col
	barra_estilo.set_corner_radius_all(2)
	_event_banner_barra.add_theme_stylebox_override("fill", barra_estilo)
	_event_banner_barra.value = 100.0
	var tw := create_tween()
	tw.tween_property(_event_banner, "modulate:a", 1.0, 0.3)

	AudioManager.play_sfx("achievement", 0.85)
	mostrar_notificacion("⚡ " + String(ev["nombre"]) + " activo", false)


func _on_evento_finalizado(id: String, exito: bool) -> void:
	# Revertir modificador
	match id:
		"lluvia_alien":
			GarmentData.bonus_prob_alien -= _ev_bonus_prob_alien
			_ev_bonus_prob_alien = 0.0
		"hora_dorada":
			_ev_mult_recompensa = 1.0
		"susurro_altar":
			_ev_bonus_frag_alien = 0
		"frenesi_frotador":
			sink_area.bonus_fuerza_evento = 0.0
			_ev_bonus_fuerza = 0.0
		"pulso_cuantico":
			machines_panel.mult_velocidad_evento = 1.0
			_ev_mult_velocidad_lavadoras = 1.0
		"pedido_vip":
			if exito:
				var ev: Dictionary = EventsManager.get_evento(id)
				var rec_eu: int = int(ev.get("vip_recompensa_euros", 0))
				var rec_fr: int = int(ev.get("vip_recompensa_fragmentos", 0))
				euros += rec_eu
				euros_totales_ganados += rec_eu
				euros_changed.emit(euros)
				if rec_fr > 0:
					fragmentos += rec_fr
					fragmentos_changed.emit(fragmentos)
				mostrar_notificacion("🎩 VIP satisfecho: +%d€  +%d ✧" % [rec_eu, rec_fr], false)
				Stats.incrementar("vips_completados")
				Stats.notificar_evento("cliente_fiel")
				if Stats.get_stat("vips_completados") >= 5:
					Stats.notificar_evento("vip_frecuente")
				AudioManager.play_sfx("achievement", 1.2)

	# Fade-out del banner (sin await; si llega otro evento se reusa el mismo banner)
	if _event_banner != null:
		var tw := create_tween()
		tw.tween_property(_event_banner, "modulate:a", 0.0, 0.4)

	# Stats: cualquier evento finalizado (con o sin éxito) cuenta como vivido
	Stats.incrementar("eventos_completados")
	Stats.notificar_evento("primera_ronda")
	if Stats.get_stat("eventos_completados") >= 10:
		Stats.notificar_evento("habitual")


func _on_evento_actualizado(_id: String, restante: float, datos: Dictionary) -> void:
	if _event_banner == null:
		return
	var ev: Dictionary = EventsManager.get_evento(_id)
	if ev.is_empty():
		return
	var duracion: float = float(ev.get("duracion", 1.0))
	_event_banner_barra.value = clamp(restante / duracion, 0.0, 1.0) * 100.0

	if ev.get("tipo", "") == "vip":
		var prog: int = int(datos.get("progreso", 0))
		var obj: int = int(datos.get("objetivo", 0))
		_event_banner_progreso.text = "%d / %d prendas · %.1fs" % [prog, obj, restante]
	else:
		_event_banner_progreso.text = "%s · %.1fs" % [String(ev["descripcion"]), restante]


# ============================================================
# FASE 14 — NARRATIVA DEL ALTAR
# ============================================================
## Popup fullscreen con texto narrativo. Aparece al comprar mejoras del altar.
## Click o 5s para cerrar. No bloqueante: el juego sigue corriendo detrás.
func _mostrar_lore_altar(texto: String) -> void:
	var fondo := ColorRect.new()
	fondo.color = Color(0.05, 0.0, 0.10, 0.0)
	fondo.anchor_right = 1.0
	fondo.anchor_bottom = 1.0
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	fondo.z_index = 220
	$HUD.add_child(fondo)

	var label := Label.new()
	label.text = texto
	label.add_theme_color_override("font_color", Color("#E0C0FF"))
	label.add_theme_font_size_override("font_size", 26)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.anchor_left = 0.1
	label.anchor_top = 0.35
	label.anchor_right = 0.9
	label.anchor_bottom = 0.65
	label.modulate.a = 0.0
	fondo.add_child(label)

	# Click en el fondo cierra antes
	var cerrado: Array[bool] = [false]
	fondo.gui_input.connect(func(ev):
		if cerrado[0]:
			return
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			cerrado[0] = true
			_cerrar_lore_altar(fondo)
	)

	# Sonido sutil
	AudioManager.play_sfx("alien", 0.6)

	# Animación de entrada
	var tw_in := create_tween().set_parallel()
	tw_in.tween_property(fondo, "color:a", 0.7, 0.5)
	tw_in.tween_property(label, "modulate:a", 1.0, 0.5)
	await tw_in.finished

	# Hold 5 segundos o hasta click
	var t: float = 0.0
	while t < 5.0 and not cerrado[0]:
		await get_tree().process_frame
		t += get_process_delta_time()

	if not cerrado[0]:
		cerrado[0] = true
		_cerrar_lore_altar(fondo)


func _cerrar_lore_altar(fondo: ColorRect) -> void:
	if fondo == null or not is_instance_valid(fondo):
		return
	var tw_out := create_tween().set_parallel()
	tw_out.tween_property(fondo, "color:a", 0.0, 0.4)
	if fondo.get_child_count() > 0:
		var lbl: Node = fondo.get_child(0)
		if lbl is CanvasItem:
			tw_out.tween_property(lbl, "modulate:a", 0.0, 0.4)
	await tw_out.finished
	if is_instance_valid(fondo):
		fondo.queue_free()


# ============================================================
# FASE 13 — CONTRATOS (UI + HANDLERS)
# ============================================================
func _crear_contract_banner() -> void:
	_contract_banner = PanelContainer.new()
	_contract_banner.visible = false
	_contract_banner.custom_minimum_size = Vector2(420, 0)
	# Posicionado debajo del banner de eventos (Fase 10)
	_contract_banner.anchor_left = 0.5
	_contract_banner.anchor_top = 0.0
	_contract_banner.anchor_right = 0.5
	_contract_banner.anchor_bottom = 0.0
	_contract_banner.offset_left = -210
	_contract_banner.offset_top = 168
	_contract_banner.offset_right = 210
	_contract_banner.offset_bottom = 268
	_contract_banner.z_index = 60

	var pe := StyleBoxFlat.new()
	pe.bg_color = Color("#0F1A22")
	pe.border_color = Color("#40D0FF")
	pe.set_border_width_all(2)
	pe.set_corner_radius_all(8)
	pe.content_margin_left = 14
	pe.content_margin_right = 14
	pe.content_margin_top = 10
	pe.content_margin_bottom = 10
	_contract_banner.add_theme_stylebox_override("panel", pe)
	$HUD.add_child(_contract_banner)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_contract_banner.add_child(vbox)

	_contract_titulo = Label.new()
	_contract_titulo.add_theme_color_override("font_color", Color("#40D0FF"))
	_contract_titulo.add_theme_font_size_override("font_size", 15)
	vbox.add_child(_contract_titulo)

	_contract_descripcion = Label.new()
	_contract_descripcion.add_theme_color_override("font_color", Color("#CCDDEE"))
	_contract_descripcion.add_theme_font_size_override("font_size", 12)
	_contract_descripcion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_contract_descripcion.custom_minimum_size = Vector2(390, 0)
	vbox.add_child(_contract_descripcion)

	_contract_barra = ProgressBar.new()
	_contract_barra.custom_minimum_size = Vector2(0, 8)
	_contract_barra.show_percentage = false
	var bb := StyleBoxFlat.new()
	bb.bg_color = Color("#15263A")
	bb.set_corner_radius_all(2)
	var bf := StyleBoxFlat.new()
	bf.bg_color = Color("#40D0FF")
	bf.set_corner_radius_all(2)
	_contract_barra.add_theme_stylebox_override("background", bb)
	_contract_barra.add_theme_stylebox_override("fill", bf)
	vbox.add_child(_contract_barra)

	# HBox con los botones (solo visible en estado DISPONIBLE)
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_END
	hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(hbox)

	_contract_btn_rechazar = Button.new()
	_contract_btn_rechazar.text = "Rechazar"
	_contract_btn_rechazar.custom_minimum_size = Vector2(100, 28)
	var br := StyleBoxFlat.new()
	br.bg_color = Color("#2A2A3A")
	br.set_corner_radius_all(4)
	_contract_btn_rechazar.add_theme_stylebox_override("normal", br)
	_contract_btn_rechazar.add_theme_stylebox_override("hover", br)
	_contract_btn_rechazar.add_theme_stylebox_override("pressed", br)
	_contract_btn_rechazar.add_theme_color_override("font_color", Color("#AAAACC"))
	_contract_btn_rechazar.add_theme_font_size_override("font_size", 12)
	_contract_btn_rechazar.pressed.connect(func(): ContractsManager.rechazar())
	hbox.add_child(_contract_btn_rechazar)

	_contract_btn_aceptar = Button.new()
	_contract_btn_aceptar.text = "Aceptar"
	_contract_btn_aceptar.custom_minimum_size = Vector2(100, 28)
	var ba := StyleBoxFlat.new()
	ba.bg_color = Color("#185A7A")
	ba.set_corner_radius_all(4)
	_contract_btn_aceptar.add_theme_stylebox_override("normal", ba)
	_contract_btn_aceptar.add_theme_stylebox_override("hover", ba)
	_contract_btn_aceptar.add_theme_stylebox_override("pressed", ba)
	_contract_btn_aceptar.add_theme_color_override("font_color", Color("#E0F4FF"))
	_contract_btn_aceptar.add_theme_font_size_override("font_size", 12)
	_contract_btn_aceptar.pressed.connect(func(): ContractsManager.aceptar())
	hbox.add_child(_contract_btn_aceptar)


func _on_contrato_disponible(contrato: Dictionary) -> void:
	_contract_banner.visible = true
	_contract_banner.modulate.a = 1.0
	_contract_titulo.text = "%s  %s" % [String(contrato.get("icono", "📋")), String(contrato.get("nombre", ""))]
	var rec_e: int = int(contrato.get("reward_euros", 0))
	var rec_f: int = int(contrato.get("reward_fragmentos", 0))
	var rec_c: int = int(contrato.get("reward_ceniza", 0))
	var rec_partes: Array[String] = []
	if rec_e > 0: rec_partes.append("+%d€" % rec_e)
	if rec_f > 0: rec_partes.append("+%d ✧" % rec_f)
	if rec_c > 0: rec_partes.append("+%d 🜁" % rec_c)
	_contract_descripcion.text = "%s  →  %s" % [String(contrato.get("descripcion", "")), ", ".join(rec_partes)]
	_contract_barra.value = 0.0
	_contract_btn_aceptar.visible = true
	_contract_btn_rechazar.visible = true
	AudioManager.play_sfx("achievement", 0.7)


func _on_contrato_aceptado(contrato: Dictionary) -> void:
	_contract_btn_aceptar.visible = false
	_contract_btn_rechazar.visible = false
	_contract_titulo.text = "%s  %s" % [String(contrato.get("icono", "📋")), String(contrato.get("nombre", ""))]
	var obj: int = int(contrato.get("objetivo", 0))
	_contract_descripcion.text = "Progreso: 0 / %d  ·  %.0fs" % [obj, float(contrato.get("duracion", 0.0))]
	_contract_barra.value = 0.0
	AudioManager.play_sfx("buy")


func _on_contrato_actualizado(restante: float, progreso_actual: int) -> void:
	var c: Dictionary = ContractsManager.contrato_activo
	if c.is_empty() or _contract_banner == null:
		return
	var obj: int = int(c.get("objetivo", 0))
	_contract_descripcion.text = "Progreso: %d / %d  ·  %.1fs" % [progreso_actual, obj, restante]
	_contract_barra.value = (float(progreso_actual) / float(max(obj, 1))) * 100.0


func _on_contrato_completado(contrato: Dictionary, exito: bool) -> void:
	if exito:
		var rec_e: int = int(contrato.get("reward_euros", 0))
		var rec_f: int = int(contrato.get("reward_fragmentos", 0))
		var rec_c: int = int(contrato.get("reward_ceniza", 0))
		if rec_e > 0:
			euros += float(rec_e)
			euros_totales_ganados += float(rec_e)
			euros_changed.emit(euros)
		if rec_f > 0:
			fragmentos += rec_f
			fragmentos_changed.emit(fragmentos)
		if rec_c > 0:
			ceniza += rec_c
			ceniza_changed.emit(ceniza)
		Stats.incrementar("contratos_completados")
		Stats.notificar_evento("primer_contrato")
		if Stats.get_stat("contratos_completados") >= 10:
			Stats.notificar_evento("contratista_habitual")
		mostrar_notificacion("✓ Contrato completado: +%d€ +%d ✧" % [rec_e, rec_f], false)
		AudioManager.play_sfx("achievement", 1.1)
	else:
		mostrar_notificacion("Contrato fallido", false)
	# Fade-out del banner
	var tw := create_tween()
	tw.tween_property(_contract_banner, "modulate:a", 0.0, 0.4)
	await tw.finished
	_contract_banner.visible = false


func _on_contrato_expirado(_c: Dictionary) -> void:
	# Se ofrecía un contrato pero el jugador no lo aceptó a tiempo
	var tw := create_tween()
	tw.tween_property(_contract_banner, "modulate:a", 0.0, 0.4)
	await tw.finished
	_contract_banner.visible = false


# ============================================================
# FASE 12 — PROGRESO OFFLINE
# ============================================================
## Calcula y aplica las ganancias acumuladas mientras el juego estuvo cerrado.
## Se llama al final de cargar_partida() con el timestamp del último save.
func _aplicar_progreso_offline(ts_guardado: float) -> void:
	var ahora: float = Time.get_unix_time_from_system()
	var delta: float = ahora - ts_guardado
	# Evitar valores negativos (cambio horario, viaje a otra zona) y caps
	if delta < OFFLINE_MIN_SEG_PARA_POPUP:
		return
	var delta_efectivo: float = clamp(delta, 0.0, OFFLINE_MAX_SEG)

	var ciclos: int = machines_panel.contar_ciclos_offline(delta_efectivo)
	if ciclos <= 0:
		return

	var ganancia_base: float = float(ciclos) * OFFLINE_AVG_EUROS_POR_CICLO
	var ganancia_real: float = ganancia_base * multiplicador_ganancias * OFFLINE_EFICIENCIA
	var ganancia_int: int = int(round(ganancia_real))
	if ganancia_int <= 0:
		return

	euros += float(ganancia_int)
	euros_totales_ganados += float(ganancia_int)
	euros_changed.emit(euros)
	Stats.incrementar("euros_total_historico", float(ganancia_int))
	Stats.incrementar("prendas_total_lavadora", float(ciclos))
	Stats.set_max("max_euros_en_run", euros)
	_actualizar_estado_prestige_button()

	_mostrar_popup_offline(delta, ciclos, ganancia_int)


## Formatea segundos como "Xh Ym" o "Ym" o "Zs".
func _formatear_duracion(segundos: float) -> String:
	var s: int = int(segundos)
	if s >= 3600:
		var h: int = s / 3600
		var m: int = (s % 3600) / 60
		return "%dh %dm" % [h, m]
	elif s >= 60:
		var m: int = s / 60
		return "%dm" % m
	else:
		return "%ds" % s


## Popup centrado con resumen de ganancias offline. Auto-cierre al pulsar.
func _mostrar_popup_offline(delta: float, ciclos: int, ganancia: int) -> void:
	var capped: bool = delta > OFFLINE_MAX_SEG
	var texto_tiempo: String = _formatear_duracion(min(delta, OFFLINE_MAX_SEG))
	var nota_cap: String = "  (limitado a 8h)" if capped else ""

	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.55)
	fondo.anchor_right = 1.0
	fondo.anchor_bottom = 1.0
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	fondo.z_index = 200
	$HUD.add_child(fondo)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -210
	panel.offset_top = -100
	panel.offset_right = 210
	panel.offset_bottom = 100
	var pe := StyleBoxFlat.new()
	pe.bg_color = Color("#1A1A2E")
	pe.border_color = Color("#FFD060")
	pe.set_border_width_all(2)
	pe.set_corner_radius_all(10)
	pe.content_margin_left = 22
	pe.content_margin_right = 22
	pe.content_margin_top = 18
	pe.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", pe)
	fondo.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var titulo := Label.new()
	titulo.text = "🌙 Has vuelto"
	titulo.add_theme_color_override("font_color", Color("#FFD060"))
	titulo.add_theme_font_size_override("font_size", 20)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(titulo)

	var detalle := Label.new()
	detalle.text = "Estuviste fuera %s%s.\nTus lavadoras procesaron %d prendas." % [texto_tiempo, nota_cap, ciclos]
	detalle.add_theme_color_override("font_color", Color("#E0E0F0"))
	detalle.add_theme_font_size_override("font_size", 13)
	detalle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detalle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(detalle)

	var ganancia_label := Label.new()
	ganancia_label.text = "+%d€" % ganancia
	ganancia_label.add_theme_color_override("font_color", Color("#40FF80"))
	ganancia_label.add_theme_font_size_override("font_size", 28)
	ganancia_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(ganancia_label)

	var btn := Button.new()
	btn.text = "Continuar"
	btn.custom_minimum_size = Vector2(0, 36)
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color("#403318")
	bs.border_color = Color("#FFD060")
	bs.set_border_width_all(1)
	bs.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", bs)
	btn.add_theme_stylebox_override("hover", bs)
	btn.add_theme_stylebox_override("pressed", bs)
	btn.add_theme_color_override("font_color", Color("#FFE898"))
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(func(): fondo.queue_free())
	vbox.add_child(btn)

	# Sonido de bienvenida
	AudioManager.play_sfx("achievement", 0.9)


# ============================================================
# FASE 11C — PANEL DE OPCIONES (VOLUMEN)
# ============================================================
func _crear_panel_opciones() -> void:
	# Botón ⚙️ encima del btn_logros (ambos en esquina inferior derecha)
	_opciones_btn = Button.new()
	_opciones_btn.text = "⚙"
	_opciones_btn.tooltip_text = "Opciones"
	_opciones_btn.anchor_left = 1.0
	_opciones_btn.anchor_top = 1.0
	_opciones_btn.anchor_right = 1.0
	_opciones_btn.anchor_bottom = 1.0
	_opciones_btn.offset_left = -64
	_opciones_btn.offset_top = -100
	_opciones_btn.offset_right = -16
	_opciones_btn.offset_bottom = -62
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#2A2A4A")
	s.set_corner_radius_all(4)
	_opciones_btn.add_theme_stylebox_override("normal", s)
	_opciones_btn.add_theme_stylebox_override("hover", s)
	_opciones_btn.add_theme_stylebox_override("pressed", s)
	_opciones_btn.add_theme_font_size_override("font_size", 16)
	_opciones_btn.add_theme_color_override("font_color", Color("#CCCCFF"))
	_opciones_btn.pressed.connect(_on_opciones_btn_pressed)
	$HUD.add_child(_opciones_btn)

	# Panel popup
	_opciones_panel = PanelContainer.new()
	_opciones_panel.visible = false
	_opciones_panel.custom_minimum_size = Vector2(280, 0)
	_opciones_panel.anchor_left = 1.0
	_opciones_panel.anchor_top = 1.0
	_opciones_panel.anchor_right = 1.0
	_opciones_panel.anchor_bottom = 1.0
	_opciones_panel.offset_left = -300
	_opciones_panel.offset_top = -210
	_opciones_panel.offset_right = -16
	_opciones_panel.offset_bottom = -110
	_opciones_panel.z_index = 80
	var pe := StyleBoxFlat.new()
	pe.bg_color = Color("#1A1A2E")
	pe.border_color = Color("#5A5A8A")
	pe.set_border_width_all(2)
	pe.set_corner_radius_all(8)
	pe.content_margin_left = 16
	pe.content_margin_right = 16
	pe.content_margin_top = 12
	pe.content_margin_bottom = 12
	_opciones_panel.add_theme_stylebox_override("panel", pe)
	$HUD.add_child(_opciones_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_opciones_panel.add_child(vbox)

	var titulo := Label.new()
	titulo.text = "Opciones"
	titulo.add_theme_color_override("font_color", Color("#CCCCFF"))
	titulo.add_theme_font_size_override("font_size", 16)
	vbox.add_child(titulo)

	var hbox_vol := HBoxContainer.new()
	hbox_vol.add_theme_constant_override("separation", 10)
	vbox.add_child(hbox_vol)

	var vol_label := Label.new()
	vol_label.text = "Volumen"
	vol_label.add_theme_color_override("font_color", Color("#AAAACC"))
	vol_label.add_theme_font_size_override("font_size", 12)
	vol_label.custom_minimum_size = Vector2(70, 0)
	hbox_vol.add_child(vol_label)

	_opciones_slider = HSlider.new()
	_opciones_slider.min_value = -40.0
	_opciones_slider.max_value = 6.0
	_opciones_slider.step = 1.0
	_opciones_slider.value = AudioManager.get_volumen_db()
	_opciones_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_opciones_slider.value_changed.connect(_on_opciones_volumen_cambiado)
	hbox_vol.add_child(_opciones_slider)

	var btn_mute := Button.new()
	btn_mute.text = "🔇"
	btn_mute.custom_minimum_size = Vector2(36, 28)
	btn_mute.tooltip_text = "Silenciar"
	btn_mute.pressed.connect(func(): _opciones_slider.value = -40.0)
	hbox_vol.add_child(btn_mute)

	# Atajos hint
	var atajos := Label.new()
	atajos.text = "Atajos:\n  ESPACIO — entregar prenda\n  1-5 — asignar slot a lavadora"
	atajos.add_theme_color_override("font_color", Color("#888899"))
	atajos.add_theme_font_size_override("font_size", 11)
	vbox.add_child(atajos)

	# Botón reiniciar tutorial
	var btn_tut := Button.new()
	btn_tut.text = "Reiniciar tutorial"
	btn_tut.custom_minimum_size = Vector2(0, 28)
	var bts := StyleBoxFlat.new()
	bts.bg_color = Color("#2A2A4A")
	bts.set_corner_radius_all(4)
	btn_tut.add_theme_stylebox_override("normal", bts)
	btn_tut.add_theme_stylebox_override("hover", bts)
	btn_tut.add_theme_stylebox_override("pressed", bts)
	btn_tut.add_theme_color_override("font_color", Color("#CCCCFF"))
	btn_tut.add_theme_font_size_override("font_size", 12)
	btn_tut.pressed.connect(_on_btn_reiniciar_tutorial)
	vbox.add_child(btn_tut)


func _on_btn_reiniciar_tutorial() -> void:
	if _tutorial == null:
		return
	_tutorial.reset_completo()
	_tutorial.iniciar()
	_opciones_panel.visible = false
	mostrar_notificacion("Tutorial reiniciado", false)


func _on_opciones_btn_pressed() -> void:
	_opciones_panel.visible = not _opciones_panel.visible


func _on_opciones_volumen_cambiado(valor: float) -> void:
	AudioManager.set_volumen_db(valor)


# ============================================================
# FASE 11A — TUTORIAL GUIADO
# ============================================================
func _crear_tutorial() -> void:
	var script: GDScript = load("res://tutorial_manager.gd")
	_tutorial = script.new()
	$HUD.add_child(_tutorial)
	_tutorial.tutorial_completado.connect(func(): Stats.notificar_evento("aprendiz_aplicado"))
	_tutorial.tutorial_saltado.connect(func(): Stats.notificar_evento("sin_entrenamiento"))


## Wrapper seguro para notificar al tutorial (evita comprobar null en cada call site).
## Tras cada cierre, re-evalúa los desbloqueos por si el siguiente paso ya tiene
## su precondición cumplida (p.ej. avanzar a "tienda" cuando ya hay 12€+).
func _notif_tutorial(evento: String) -> void:
	if _tutorial == null:
		return
	_tutorial.notificar(evento)
	_chequear_desbloqueos_tutorial()


## Comprueba umbrales económicos para desbloquear pasos del tutorial que esperan
## a que el jugador pueda actuar (ej. paso "tienda" requiere euros >= 12).
func _chequear_desbloqueos_tutorial() -> void:
	if _tutorial == null:
		return
	if euros >= TUTORIAL_UMBRAL_TIENDA:
		_tutorial.notificar("tienda_disponible")
	if euros >= TUTORIAL_UMBRAL_LAVADORA:
		_tutorial.notificar("lavadora_disponible")
