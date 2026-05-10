extends Node2D
##
## Main.gd — FASE 4 (revisado v2)
## ============================================================
## - Sink: FIFO automático (consumir_siguiente al inicio y al entregar).
## - Click en cola: intento de asignar prenda a una lavadora libre.
##   Si no hay hueco compatible, la prenda se queda en la cola y avisamos.
##

# ============================================================
# ESTADO DEL JUGADOR
# ============================================================
var euros: float = 0.0
var euros_totales_ganados: float = 0.0
var ceniza: int = 0
var fragmentos: int = 0
var favores: int = 0
var num_prestigios: int = 0

# ============================================================
# SEÑALES GLOBALES
# ============================================================
signal euros_changed(new_val: float)
signal ceniza_changed(new_val: int)
signal fragmentos_changed(new_val: int)
signal favores_changed(new_val: int)

# ============================================================
# REFERENCIAS A NODOS
# ============================================================
@onready var sink_area: Control          = $SinkArea
@onready var queue_panel: HBoxContainer  = $QueuePanel
@onready var shop_panel: Panel           = $ShopPanel
@onready var machines_panel: Panel       = $MachinesPanel
@onready var notif_timer: Timer          = $NotifTimer

@onready var euros_label: Label          = $HUD/CoinsPanel/EurosLabel
@onready var ceniza_label: Label         = $HUD/CoinsPanel/CenizaLabel
@onready var fragmentos_label: Label     = $HUD/CoinsPanel/FragmentosLabel
@onready var notif_label: Label          = $HUD/NotifLabel


# ============================================================
# INICIALIZACIÓN
# ============================================================
func _ready() -> void:
	# SinkArea
	sink_area.garment_delivered.connect(_on_garment_delivered)
	# QueuePanel
	queue_panel.siguiente_prenda_lista.connect(_on_siguiente_prenda_lista)
	queue_panel.intento_seleccion_lavadora.connect(_on_intento_seleccion_lavadora)
	# ShopPanel
	shop_panel.upgrade_solicitado.connect(_on_upgrade_solicitado)
	# MachinesPanel
	machines_panel.lavadora_compra_solicitada.connect(_on_lavadora_compra_solicitada)
	machines_panel.prenda_procesada.connect(_on_prenda_procesada_lavadora)

	# Globales → HUD
	euros_changed.connect(_on_euros_changed)
	ceniza_changed.connect(_on_ceniza_changed)
	fragmentos_changed.connect(_on_fragmentos_changed)

	# Notif timer
	notif_timer.wait_time = 3.0
	notif_timer.one_shot = true
	notif_timer.timeout.connect(_on_notif_timer_timeout)
	notif_label.visible = false

	_update_hud()
	shop_panel.actualizar_euros(euros)
	machines_panel.actualizar_recursos(euros, ceniza)

	# Cargamos la primera prenda al sink (FIFO)
	await get_tree().process_frame
	queue_panel.consumir_siguiente()


# ============================================================
# SINK (FIFO)
# ============================================================
func _on_siguiente_prenda_lista(prenda: Dictionary) -> void:
	sink_area.cargar_prenda(prenda)


func _on_garment_delivered(prenda: Dictionary, earned: float) -> void:
	euros += earned
	euros_totales_ganados += earned
	euros_changed.emit(euros)

	var ceniza_ganada: int = prenda.get("ceniza_bonus", 0)
	if ceniza_ganada > 0:
		ceniza += ceniza_ganada
		ceniza_changed.emit(ceniza)

	var fragmentos_ganados: int = prenda.get("fragmentos_bonus", 0)
	if fragmentos_ganados > 0:
		fragmentos += fragmentos_ganados
		fragmentos_changed.emit(fragmentos)

	var texto_notif := "+%d€" % int(earned)
	if ceniza_ganada > 0:
		texto_notif += "  +%d Ceniza" % ceniza_ganada
	if fragmentos_ganados > 0:
		texto_notif += "  +%d Fragmento" % fragmentos_ganados
	if prenda.get("es_alien", false):
		texto_notif = "ALIEN!  " + texto_notif

	mostrar_notificacion(texto_notif, prenda.get("es_alien", false))

	# Cargar la siguiente prenda al sink
	queue_panel.consumir_siguiente()


# ============================================================
# CLICK EN COLA → ASIGNAR A LAVADORA
# ============================================================
func _on_intento_seleccion_lavadora(idx: int) -> void:
	# Si no hay lavadoras compradas: avisar y salir.
	if not machines_panel.tiene_lavadoras():
		mostrar_notificacion("Compra una lavadora primero", false)
		return

	# Leemos la prenda sin sacarla de la cola
	var prenda: Dictionary = queue_panel.peek_prenda(idx)
	if prenda.is_empty():
		return

	var es_alien: bool = bool(prenda.get("es_alien", false))

	# Si es alien y no tienes ninguna cuántica: avisar y no sacar.
	if es_alien and not machines_panel.tiene_lavadora_alien():
		mostrar_notificacion("Solo la lavadora cuántica acepta alien", true)
		return

	# Intentar asignar
	var asignada: bool = machines_panel.asignar_prenda(prenda)
	if asignada:
		queue_panel.confirmar_extraccion(idx)
		mostrar_notificacion("→ Lavadora", false)
	else:
		mostrar_notificacion("Lavadoras llenas", false)


# ============================================================
# TIENDA — UPGRADES
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
	euros += earned
	euros_totales_ganados += earned
	euros_changed.emit(euros)

	var ceniza_ganada: int = prenda.get("ceniza_bonus", 0)
	var fragmentos_ganados: int = prenda.get("fragmentos_bonus", 0)

	# Cuántica = mitad de fragmentos (incentivo a lavar a mano)
	if era_cuantica and fragmentos_ganados > 0:
		fragmentos_ganados = max(1, int(round(fragmentos_ganados * 0.5)))

	if ceniza_ganada > 0:
		ceniza += ceniza_ganada
		ceniza_changed.emit(ceniza)
	if fragmentos_ganados > 0:
		fragmentos += fragmentos_ganados
		fragmentos_changed.emit(fragmentos)

	var texto := "🌀 +%d€" % int(earned)
	if prenda.get("es_alien", false):
		texto = "🌀 ALIEN  +%d€" % int(earned)
	mostrar_notificacion(texto, prenda.get("es_alien", false))


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


func _on_fragmentos_changed(_val: int) -> void:
	_update_hud()


func _update_hud() -> void:
	euros_label.text = "€ %d" % int(euros)
	ceniza_label.text = "Ceniza: %d" % ceniza
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
