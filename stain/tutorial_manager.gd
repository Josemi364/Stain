extends Control
##
## TutorialManager.gd — FASE 11A
## ============================================================
## Tutorial guiado de 6 pasos para los primeros minutos de juego.
## Se instancia como hijo del HUD desde Main._ready().
##
## Cada paso tiene:
##   - desbloqueo: evento que tiene que ocurrir para poder mostrar el paso
##                 ("" = se muestra al instante al alcanzarlo)
##   - cierre: evento que cierra el paso y avanza al siguiente
##             ("auto" = el panel tiene un botón "Entendido" que cierra)
##   - target: nombre del nodo a destacar con el anillo pulsante (path
##             relativo al HUD o a Main)
##
## Main llama a `notificar(evento)` en momentos clave; el TutorialManager
## decide si avanza, si muestra el panel pendiente, o si lo ignora.
##
## Estado persistido (en el save):
##   - paso_actual: int  (0..N o -1 = completado/saltado)
##

signal tutorial_completado  # se completaron todos los pasos legítimamente
signal tutorial_saltado     # el usuario pulsó "Saltar tutorial"

# ============================================================
# CONFIGURACIÓN
# ============================================================
const PASO_INICIAL: int = 0
const PASO_COMPLETADO: int = -1

var pasos: Array[Dictionary] = [
	{
		"id": "bienvenida",
		"titulo": "¡Bienvenido a Stain!",
		"texto": "Tu lavandería abre sus puertas.\nFrota las manchas con el ratón sobre la prenda para limpiarlas.",
		"target": "SinkArea",
		"desbloqueo": "",
		"cierre": "auto",
	},
	{
		"id": "primera_entrega",
		"titulo": "Entrega la prenda",
		"texto": "Cuando una prenda esté limpia del todo, aparecerá un botón para entregarla y cobrar.",
		"target": "SinkArea",
		"desbloqueo": "",
		"cierre": "entrega_completada",
	},
	{
		"id": "cola",
		"titulo": "Cola de prendas",
		"texto": "Las prendas que vienen aparecen aquí.\nMás adelante podrás enviarlas a las lavadoras haciendo clic en su slot.",
		"target": "QueuePanel",
		"desbloqueo": "",
		"cierre": "auto",
	},
	{
		"id": "tienda",
		"titulo": "Mejora tus herramientas",
		"texto": "Ya puedes comprar tu primer Detergente (12€).\nAumentará la fuerza con que limpias.",
		"target": "ShopPanel",
		"desbloqueo": "tienda_disponible",
		"cierre": "compra_realizada",
	},
	{
		"id": "lavadora",
		"titulo": "Automatiza el trabajo",
		"texto": "Compra tu primera lavadora.\nLimpiará prendas mientras tú frotas otras.",
		"target": "MachinesPanel",
		"desbloqueo": "lavadora_disponible",
		"cierre": "lavadora_comprada",
	},
	{
		"id": "prestigio",
		"titulo": "El Ritual de la Ceniza",
		"texto": "Has acumulado bastante. Pulsa Prestigiar para reiniciar la run a cambio de Ceniza permanente (🜁).",
		"target": "PrestigeButton",
		"desbloqueo": "prestigio_visible",
		"cierre": "prestigio_hecho",
	},
]

# ============================================================
# ESTADO
# ============================================================
var paso_actual: int = PASO_INICIAL
var _activo: bool = false  # tutorial corriendo (no completado)
var _panel_visible: bool = false  # paso actualmente mostrado al usuario

# Refs UI
var _panel: PanelContainer
var _titulo_label: Label
var _texto_label: Label
var _btn_entendido: Button
var _btn_saltar: Button
var _highlight_ring: Control

# Tween del anillo
var _ring_tween: Tween
var _target_node: Control = null
var _ring_phase: float = 0.0


# ============================================================
# INICIALIZACIÓN
# ============================================================
func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 90

	_construir_anillo()
	_construir_panel()
	_construir_btn_saltar()
	_ocultar_todo()


func _construir_anillo() -> void:
	_highlight_ring = Control.new()
	_highlight_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight_ring.anchor_right = 1.0
	_highlight_ring.anchor_bottom = 1.0
	_highlight_ring.z_index = 1
	_highlight_ring.draw.connect(_draw_ring)
	add_child(_highlight_ring)


func _construir_panel() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(360, 0)
	_panel.z_index = 5
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("#1A1A2E")
	estilo.border_color = Color("#FFD060")
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(8)
	estilo.content_margin_left = 16
	estilo.content_margin_right = 16
	estilo.content_margin_top = 12
	estilo.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", estilo)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)

	_titulo_label = Label.new()
	_titulo_label.add_theme_font_size_override("font_size", 16)
	_titulo_label.add_theme_color_override("font_color", Color("#FFD060"))
	vbox.add_child(_titulo_label)

	_texto_label = Label.new()
	_texto_label.add_theme_font_size_override("font_size", 13)
	_texto_label.add_theme_color_override("font_color", Color("#E0E0F0"))
	_texto_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto_label.custom_minimum_size = Vector2(328, 0)
	vbox.add_child(_texto_label)

	_btn_entendido = Button.new()
	_btn_entendido.text = "Entendido"
	_btn_entendido.custom_minimum_size = Vector2(110, 30)
	var b_estilo := StyleBoxFlat.new()
	b_estilo.bg_color = Color("#403318")
	b_estilo.border_color = Color("#FFD060")
	b_estilo.set_border_width_all(1)
	b_estilo.set_corner_radius_all(4)
	_btn_entendido.add_theme_stylebox_override("normal", b_estilo)
	_btn_entendido.add_theme_stylebox_override("hover", b_estilo)
	_btn_entendido.add_theme_stylebox_override("pressed", b_estilo)
	_btn_entendido.add_theme_color_override("font_color", Color("#FFE898"))
	_btn_entendido.pressed.connect(_on_btn_entendido_pressed)
	vbox.add_child(_btn_entendido)


func _construir_btn_saltar() -> void:
	_btn_saltar = Button.new()
	_btn_saltar.text = "Saltar tutorial ✕"
	_btn_saltar.custom_minimum_size = Vector2(140, 26)
	# Esquina inferior izquierda, lejos del HUD principal
	_btn_saltar.anchor_left = 0.0
	_btn_saltar.anchor_top = 1.0
	_btn_saltar.anchor_right = 0.0
	_btn_saltar.anchor_bottom = 1.0
	_btn_saltar.offset_left = 10
	_btn_saltar.offset_top = -40
	_btn_saltar.offset_right = 150
	_btn_saltar.offset_bottom = -14
	_btn_saltar.z_index = 6
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#2A2A3A")
	s.border_color = Color("#888899")
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	_btn_saltar.add_theme_stylebox_override("normal", s)
	_btn_saltar.add_theme_stylebox_override("hover", s)
	_btn_saltar.add_theme_stylebox_override("pressed", s)
	_btn_saltar.add_theme_color_override("font_color", Color("#BBBBCC"))
	_btn_saltar.add_theme_font_size_override("font_size", 11)
	_btn_saltar.pressed.connect(saltar)
	add_child(_btn_saltar)


func _ocultar_todo() -> void:
	_panel.visible = false
	_btn_entendido.visible = false
	_btn_saltar.visible = false
	_panel_visible = false
	if _highlight_ring != null:
		_highlight_ring.visible = false


# ============================================================
# API PÚBLICA
# ============================================================

## Arranca el tutorial. Solo si no se completó/saltó antes.
func iniciar() -> void:
	if paso_actual == PASO_COMPLETADO:
		return
	_activo = true
	_btn_saltar.visible = true
	_intentar_mostrar_paso_actual()


## Salta todo el tutorial. Permanente.
func saltar() -> void:
	paso_actual = PASO_COMPLETADO
	_activo = false
	_ocultar_todo()
	tutorial_saltado.emit()


## Notifica un evento desde Main.
## Si el evento desbloquea el paso actual: muestra el panel.
## Si el evento cierra el paso actual: avanza al siguiente.
func notificar(evento: String) -> void:
	if not _activo or paso_actual == PASO_COMPLETADO:
		return
	if paso_actual >= pasos.size():
		return
	var paso: Dictionary = pasos[paso_actual]
	var desbloqueo: String = paso.get("desbloqueo", "")
	var cierre: String = paso.get("cierre", "auto")

	# Desbloqueo: mostrar el paso si estaba esperando
	if not _panel_visible and not desbloqueo.is_empty() and evento == desbloqueo:
		_mostrar_paso(paso_actual)
		return

	# Cierre: avanzar al siguiente paso
	if _panel_visible and evento == cierre:
		_avanzar()


## Reset (debug F2). Vuelve al paso 0.
func reset_completo() -> void:
	paso_actual = PASO_INICIAL
	_activo = false
	_ocultar_todo()


# ============================================================
# PERSISTENCIA
# ============================================================
func serializar() -> Dictionary:
	return {"paso_actual": paso_actual}


func cargar_estado(data: Dictionary) -> void:
	# Save de versiones anteriores a Fase 11 (sin sección tutorial): se asume
	# que la partida ya está avanzada y no debe forzar el tutorial. Para verlo,
	# el usuario puede borrar el save (F2 en debug).
	if data.is_empty():
		paso_actual = PASO_COMPLETADO
		_activo = false
		_ocultar_todo()
		return
	paso_actual = int(data.get("paso_actual", PASO_COMPLETADO))
	if paso_actual != PASO_COMPLETADO:
		_activo = true
		_btn_saltar.visible = true
		_intentar_mostrar_paso_actual()


# ============================================================
# LÓGICA DE PASOS
# ============================================================
func _avanzar() -> void:
	paso_actual += 1
	if paso_actual >= pasos.size():
		paso_actual = PASO_COMPLETADO
		_activo = false
		_ocultar_todo()
		tutorial_completado.emit()
		return
	_intentar_mostrar_paso_actual()


## Si el paso actual no requiere desbloqueo, lo muestra.
## Si requiere desbloqueo, oculta el panel y espera la notificación.
func _intentar_mostrar_paso_actual() -> void:
	if paso_actual < 0 or paso_actual >= pasos.size():
		_ocultar_todo()
		return
	var paso: Dictionary = pasos[paso_actual]
	var desbloqueo: String = paso.get("desbloqueo", "")
	if desbloqueo.is_empty():
		_mostrar_paso(paso_actual)
	else:
		# Esperar al evento de desbloqueo: ocultar panel y anillo, dejar saltar visible
		_panel.visible = false
		_btn_entendido.visible = false
		_panel_visible = false
		if _highlight_ring != null:
			_highlight_ring.visible = false
		_btn_saltar.visible = true


func _mostrar_paso(idx: int) -> void:
	if idx < 0 or idx >= pasos.size():
		return
	var paso: Dictionary = pasos[idx]
	_titulo_label.text = paso["titulo"]
	_texto_label.text = paso["texto"]
	_btn_entendido.visible = (paso.get("cierre", "auto") == "auto")
	_panel.visible = true
	_btn_saltar.visible = true
	_highlight_ring.visible = true
	_panel_visible = true

	var target_path: String = paso.get("target", "")
	_target_node = _resolver_target(target_path)
	_iniciar_pulso_anillo()
	_highlight_ring.queue_redraw()
	_posicionar_panel()


func _resolver_target(path: String) -> Control:
	if path.is_empty():
		return null
	var hud := get_parent()
	if hud != null:
		var n: Node = hud.get_node_or_null(path)
		if n is Control:
			return n
		var main := hud.get_parent()
		if main != null:
			n = main.get_node_or_null(path)
			if n is Control:
				return n
	return null


func _posicionar_panel() -> void:
	# Esperamos un frame para que el panel calcule su tamaño tras setear textos
	await get_tree().process_frame
	if not _panel_visible:
		return

	var p_size: Vector2 = _panel.size
	var screen_size: Vector2 = size

	if _target_node == null or not _target_node.is_inside_tree():
		_panel.position = (screen_size - p_size) * 0.5
		return

	var t_rect: Rect2 = _target_node.get_global_rect()
	var espacio_derecha: float = screen_size.x - (t_rect.position.x + t_rect.size.x)
	var espacio_izquierda: float = t_rect.position.x
	var espacio_arriba: float = t_rect.position.y
	var espacio_abajo: float = screen_size.y - (t_rect.position.y + t_rect.size.y)
	var max_espacio: float = max(espacio_derecha, max(espacio_izquierda, max(espacio_arriba, espacio_abajo)))

	var pos: Vector2
	if max_espacio == espacio_derecha and espacio_derecha >= p_size.x + 20:
		pos = Vector2(t_rect.position.x + t_rect.size.x + 16, t_rect.position.y + t_rect.size.y * 0.5 - p_size.y * 0.5)
	elif max_espacio == espacio_izquierda and espacio_izquierda >= p_size.x + 20:
		pos = Vector2(t_rect.position.x - p_size.x - 16, t_rect.position.y + t_rect.size.y * 0.5 - p_size.y * 0.5)
	elif max_espacio == espacio_abajo:
		pos = Vector2(t_rect.position.x + t_rect.size.x * 0.5 - p_size.x * 0.5, t_rect.position.y + t_rect.size.y + 16)
	else:
		pos = Vector2(t_rect.position.x + t_rect.size.x * 0.5 - p_size.x * 0.5, t_rect.position.y - p_size.y - 16)

	pos.x = clamp(pos.x, 10, screen_size.x - p_size.x - 10)
	pos.y = clamp(pos.y, 70, screen_size.y - p_size.y - 10)
	_panel.position = pos


func _iniciar_pulso_anillo() -> void:
	if _ring_tween != null and _ring_tween.is_valid():
		_ring_tween.kill()
	_ring_phase = 0.0
	_ring_tween = create_tween()
	_ring_tween.set_loops()
	_ring_tween.tween_method(_set_ring_phase, 0.0, TAU, 1.6)


func _set_ring_phase(f: float) -> void:
	_ring_phase = f
	if _highlight_ring != null and _highlight_ring.visible:
		_highlight_ring.queue_redraw()


func _draw_ring() -> void:
	if _target_node == null or not _target_node.is_inside_tree():
		return
	var rect: Rect2 = _target_node.get_global_rect()
	var center: Vector2 = rect.position + rect.size * 0.5 - global_position
	var radio_base: float = max(rect.size.x, rect.size.y) * 0.5 + 18.0
	var pulso: float = sin(_ring_phase) * 0.5 + 0.5
	var radio: float = radio_base + pulso * 8.0
	var alpha: float = 0.45 + pulso * 0.45
	_highlight_ring.draw_arc(center, radio, 0.0, TAU, 64, Color(1.0, 0.85, 0.30, alpha), 4.0, true)
	_highlight_ring.draw_arc(center, radio - 3.0, 0.0, TAU, 64, Color(1.0, 0.95, 0.50, alpha * 0.5), 2.0, true)


# ============================================================
# CALLBACKS
# ============================================================
func _on_btn_entendido_pressed() -> void:
	_avanzar()


func _process(_delta: float) -> void:
	if _panel_visible and _highlight_ring != null:
		_highlight_ring.queue_redraw()
