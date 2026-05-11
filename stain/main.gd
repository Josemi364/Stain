extends Node2D
##
## Main.gd — FASE 5 + DEBUG + REBALANCE
## ============================================================
## Orquestador central. Los subsistemas emiten señales hacia aquí;
## Main decide las consecuencias y llama de vuelta hacia abajo.
##
## FASE 5: prestigio, tienda de Ceniza, tabs €/🜁.
## DEBUG:  panel plegable con F1-F5. Desactivar con DEBUG_MODE = false.
## REBALANCE: botón de prestigio condicional (umbral 3000€ totales).
##

# ============================================================
# DEBUG — cambiar a false para build de release
# ============================================================
const DEBUG_MODE: bool = true

# ============================================================
# CONSTANTES DE JUEGO
# ============================================================
# Euros totales ganados necesarios para revelar el botón de prestigio por primera vez
const UMBRAL_PRESTIGIO_PRIMER_USO: int = 3000

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

# ============================================================
# SEÑALES GLOBALES
# ============================================================
signal euros_changed(new_val: float)
signal ceniza_changed(new_val: int)
signal fragmentos_changed(new_val: int)
signal prestige_realizado
signal ceniza_upgrade_aplicado(upgrade_id: String)

# ============================================================
# REFERENCIAS A NODOS
# ============================================================
@onready var sink_area: Control          = $SinkArea
@onready var queue_panel: HBoxContainer  = $QueuePanel
@onready var shop_panel: Panel           = $ShopPanel
@onready var machines_panel: Panel       = $MachinesPanel
@onready var ash_shop_panel: Panel       = $AshShopPanel
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

# Refs del panel de debug (solo se crean si DEBUG_MODE == true)
var _debug_btn_toggle: Button
var _debug_panel_fondo: PanelContainer
var _debug_confirm_panel: Control


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

	# Botón de prestigio y diálogo
	prestige_button.pressed.connect(_on_prestige_button_pressed)
	prestige_dialog.confirmado.connect(_on_prestige_confirmado)
	prestige_dialog.cancelado.connect(_on_prestige_cancelado)

	# Tabs €/🜁
	btn_tab_tienda.pressed.connect(_on_tab_tienda_pressed)
	btn_tab_ceniza.pressed.connect(_on_tab_ceniza_pressed)

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

	# AshShopPanel oculto; ShopPanel visible
	ash_shop_panel.visible = false
	shop_panel.visible = true
	_estilizar_tab(btn_tab_tienda, true)
	_estilizar_tab(btn_tab_ceniza, false)

	_update_hud()
	shop_panel.actualizar_euros(euros)
	machines_panel.actualizar_recursos(euros, ceniza)
	ash_shop_panel.actualizar_ceniza(ceniza)

	if DEBUG_MODE:
		_crear_panel_debug()

	await get_tree().process_frame
	queue_panel.consumir_siguiente()


# ============================================================
# TABS — alternar entre tienda de € y tienda de Ceniza
# ============================================================
func _on_tab_tienda_pressed() -> void:
	shop_panel.visible = true
	ash_shop_panel.visible = false
	_estilizar_tab(btn_tab_tienda, true)
	_estilizar_tab(btn_tab_ceniza, false)


func _on_tab_ceniza_pressed() -> void:
	shop_panel.visible = false
	ash_shop_panel.visible = true
	_estilizar_tab(btn_tab_tienda, false)
	_estilizar_tab(btn_tab_ceniza, true)


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
	var earned_real: float = earned * multiplicador_ganancias
	euros += earned_real
	euros_totales_ganados += earned_real
	euros_changed.emit(euros)

	var ceniza_ganada: int = prenda.get("ceniza_bonus", 0)
	if ceniza_ganada > 0:
		ceniza += ceniza_ganada
		ceniza_changed.emit(ceniza)

	var fragmentos_ganados: int = prenda.get("fragmentos_bonus", 0)
	if fragmentos_ganados > 0:
		fragmentos += fragmentos_ganados
		fragmentos_changed.emit(fragmentos)

	var texto_notif := "+%d€" % int(earned_real)
	if multiplicador_ganancias > 1.001:
		texto_notif += " (×%.2f)" % multiplicador_ganancias
	if ceniza_ganada > 0:
		texto_notif += "  +%d🜁" % ceniza_ganada
	if fragmentos_ganados > 0:
		texto_notif += "  +%d Frag" % fragmentos_ganados
	if prenda.get("es_alien", false):
		texto_notif = "ALIEN!  " + texto_notif

	mostrar_notificacion(texto_notif, prenda.get("es_alien", false))
	_actualizar_estado_prestige_button()
	queue_panel.consumir_siguiente()


# ============================================================
# CLICK EN COLA → ASIGNAR A LAVADORA
# ============================================================
func _on_intento_seleccion_lavadora(idx: int) -> void:
	if not machines_panel.tiene_lavadoras():
		mostrar_notificacion("Compra una lavadora primero", false)
		return

	var prenda: Dictionary = queue_panel.peek_prenda(idx)
	if prenda.is_empty():
		return

	var es_alien: bool = bool(prenda.get("es_alien", false))

	if es_alien and not memoria_prendas_activa and not machines_panel.tiene_lavadora_alien():
		mostrar_notificacion("Solo la lavadora cuántica acepta alien", true)
		return

	var asignada: bool = machines_panel.asignar_prenda(prenda)
	if asignada:
		queue_panel.confirmar_extraccion(idx)
		mostrar_notificacion("→ Lavadora", false)
	else:
		mostrar_notificacion("Lavadoras llenas", false)


# ============================================================
# TIENDA — UPGRADES DE EUROS
# ============================================================
func _on_upgrade_solicitado(upgrade_id: String, precio: int) -> void:
	if euros < precio:
		mostrar_notificacion("No tienes suficiente dinero", false)
		return

	euros -= precio
	euros_changed.emit(euros)

	var datos: Dictionary = shop_panel.get_upgrade(upgrade_id)
	_aplicar_efecto(datos)

	shop_panel.confirmar_compra(upgrade_id)
	mostrar_notificacion("✓ %s comprado" % datos["nombre"], false)


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
		return
	if ceniza < ceniza_req:
		mostrar_notificacion("Te falta Ceniza (necesitas %d)" % ceniza_req, false)
		return

	euros -= precio
	euros_changed.emit(euros)
	if ceniza_req > 0:
		ceniza -= ceniza_req
		ceniza_changed.emit(ceniza)

	machines_panel.confirmar_compra(tipo)
	mostrar_notificacion("✓ Lavadora %s comprada" % tipo, false)


# ============================================================
# LAVADORA TERMINA UN CICLO
# ============================================================
func _on_prenda_procesada_lavadora(prenda: Dictionary, earned: float, era_cuantica: bool) -> void:
	var earned_real: float = earned * multiplicador_ganancias
	euros += earned_real
	euros_totales_ganados += earned_real
	euros_changed.emit(euros)

	var ceniza_ganada: int = prenda.get("ceniza_bonus", 0)
	var fragmentos_ganados: int = prenda.get("fragmentos_bonus", 0)

	if era_cuantica and fragmentos_ganados > 0:
		fragmentos_ganados = max(1, int(round(fragmentos_ganados * 0.5)))

	if ceniza_ganada > 0:
		ceniza += ceniza_ganada
		ceniza_changed.emit(ceniza)
	if fragmentos_ganados > 0:
		fragmentos += fragmentos_ganados
		fragmentos_changed.emit(fragmentos)

	var texto := "🌀 +%d€" % int(earned_real)
	if prenda.get("es_alien", false):
		texto = "🌀 ALIEN  +%d€" % int(earned_real)
	mostrar_notificacion(texto, prenda.get("es_alien", false))
	_actualizar_estado_prestige_button()


# ============================================================
# TIENDA DE CENIZA — UPGRADES PERMANENTES
# ============================================================
func _on_upgrade_ceniza_solicitado(upgrade_id: String, coste: int) -> void:
	if ceniza < coste:
		mostrar_notificacion("Te falta Ceniza (necesitas %d 🜁)" % coste, false)
		return

	ceniza -= coste
	ceniza_changed.emit(ceniza)

	_aplicar_efecto_ceniza(upgrade_id)

	ash_shop_panel.confirmar_compra(upgrade_id)
	ceniza_upgrade_aplicado.emit(upgrade_id)
	mostrar_notificacion("✓ Mejora de Ceniza aplicada", false)


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
			mostrar_notificacion("🜁 Algo arde en el aire. Puedes prestigiar.", false)
		return

	# Ya visible: activo solo si la Ceniza calculada sería ≥ 3
	var preview: int = int(floor(euros_totales_ganados / 1000.0)) + 1
	var activo: bool = preview >= 3
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
	var ceniza_ganada: int = int(floor(euros_totales_ganados / 1000.0)) + 1
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


# ============================================================
# HUD
# ============================================================
func _on_euros_changed(_val: float) -> void:
	_update_hud()
	shop_panel.actualizar_euros(euros)
	machines_panel.actualizar_recursos(euros, ceniza)


func _on_ceniza_changed(_val: int) -> void:
	_update_hud()
	machines_panel.actualizar_recursos(euros, ceniza)
	ash_shop_panel.actualizar_ceniza(ceniza)


func _on_fragmentos_changed(_val: int) -> void:
	_update_hud()


func _update_hud() -> void:
	euros_label.text = "€ %d" % int(euros)
	ceniza_label.text = "🜁 %d" % ceniza
	fragmentos_label.text = "Frag: %d" % fragmentos


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
	if not DEBUG_MODE:
		return
	if event is InputEventKey and (event as InputEventKey).pressed:
		match (event as InputEventKey).keycode:
			KEY_F1: _debug_dar_recursos()
			KEY_F2: _debug_reset_confirmar()
			KEY_F3: _debug_forzar_alien()
			KEY_F4: _debug_completar_ciclos()
			KEY_F5: _debug_limpiar_prenda()


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

	GarmentData.resetear_suerte()
	ash_shop_panel.reset_completo()
	shop_panel.reset_compras()
	machines_panel.reset_lavadoras()
	queue_panel.reset_cola()
	sink_area.reset_sink()

	prestige_button.visible = false

	euros_changed.emit(euros)
	ceniza_changed.emit(ceniza)
	fragmentos_changed.emit(fragmentos)
	_update_hud()
	shop_panel.actualizar_euros(euros)
	machines_panel.actualizar_recursos(euros, ceniza)
	ash_shop_panel.actualizar_ceniza(ceniza)

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
