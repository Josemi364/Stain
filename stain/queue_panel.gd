extends HBoxContainer
##
## QueuePanel.gd — FASE 4 (revisado v2)
## ============================================================
## El SINK consume SIEMPRE en orden FIFO mediante consumir_siguiente().
## Los CLICKS del jugador en los slots emiten una señal aparte para
## intentar asignar esa prenda a una lavadora.
##
## Flujo del click:
##   click → intento_seleccion_lavadora(idx)
##   → Main pregunta peek_prenda(idx)
##   → Main intenta machines_panel.asignar_prenda(prenda)
##   → si OK: Main llama confirmar_extraccion(idx) → la quita y rellena
##   → si KO: notifica al jugador y la prenda se queda en la cola
##

signal siguiente_prenda_lista(prenda: Dictionary)
signal intento_seleccion_lavadora(idx: int)

# ============================================================
# CONFIGURACIÓN
# ============================================================
const MAX_COLA: int = 5
const SLOT_SIZE: Vector2 = Vector2(80, 100)
const SLOT_SEPARACION: int = 10

# ============================================================
# ESTADO INTERNO
# ============================================================
var cola: Array[Dictionary] = []
var slots: Array[PanelContainer] = []
var slot_iconos: Array[ColorRect] = []
var slot_labels: Array[Label] = []


# ============================================================
# INICIALIZACIÓN
# ============================================================
func _ready() -> void:
	add_theme_constant_override("separation", SLOT_SEPARACION)

	for i in MAX_COLA:
		_crear_slot(i)

	cola = GarmentData.get_cola_inicial(MAX_COLA)
	_refrescar_visual()


# ============================================================
# API PÚBLICA — para el SINK (FIFO)
# ============================================================

## Saca la primera prenda de la cola y la envía al sink.
## La llama Main al inicio y cuando el jugador entrega.
func consumir_siguiente() -> void:
	if cola.is_empty():
		push_warning("QueuePanel: cola vacía.")
		return
	var prenda: Dictionary = cola.pop_front()
	cola.append(GarmentData.get_prenda_aleatoria())
	_refrescar_visual()
	siguiente_prenda_lista.emit(prenda)


# ============================================================
# API PÚBLICA — para LAVADORAS (selección manual)
# ============================================================

## Lee la prenda en un índice sin sacarla de la cola.
func peek_prenda(idx: int) -> Dictionary:
	if idx < 0 or idx >= cola.size():
		return {}
	return cola[idx]


## Saca la prenda en un índice y rellena con una nueva al final.
## La llama Main cuando ha podido asignarla a una lavadora.
func confirmar_extraccion(idx: int) -> void:
	if idx < 0 or idx >= cola.size():
		return
	cola.remove_at(idx)
	cola.append(GarmentData.get_prenda_aleatoria())
	_refrescar_visual()


## Devuelve cuántas prendas hay en la cola.
func get_cantidad() -> int:
	return cola.size()


## Útil si en el futuro queremos lavadoras con búsqueda automática.
func extraer_prenda_compatible(acepta_alien: bool) -> Dictionary:
	for i in cola.size():
		var p: Dictionary = cola[i]
		var es_alien: bool = bool(p.get("es_alien", false))
		if es_alien and not acepta_alien:
			continue
		cola.remove_at(i)
		cola.append(GarmentData.get_prenda_aleatoria())
		_refrescar_visual()
		return p
	return {}


# ============================================================
# CREACIÓN DE SLOTS
# ============================================================
func _crear_slot(idx: int) -> void:
	var contenedor := PanelContainer.new()
	contenedor.custom_minimum_size = SLOT_SIZE
	contenedor.mouse_filter = Control.MOUSE_FILTER_STOP

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("#12122A")
	estilo.border_color = Color("#2A2A4A")
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(6)
	contenedor.add_theme_stylebox_override("panel", estilo)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenedor.add_child(vbox)

	var icono := ColorRect.new()
	icono.custom_minimum_size = Vector2(50, 55)
	icono.color = Color("#2A2A4A")
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icono)

	var nombre_label := Label.new()
	nombre_label.text = "..."
	nombre_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nombre_label.add_theme_font_size_override("font_size", 9)
	nombre_label.add_theme_color_override("font_color", Color("#8888BB"))
	nombre_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	nombre_label.custom_minimum_size = Vector2(76, 0)
	nombre_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(nombre_label)

	contenedor.gui_input.connect(_on_slot_input.bind(idx))

	add_child(contenedor)
	slots.append(contenedor)
	slot_iconos.append(icono)
	slot_labels.append(nombre_label)


## Click izquierdo en un slot → emitimos intento_seleccion_lavadora.
## La cola NO se modifica aquí; Main decide si la prenda se va o no.
func _on_slot_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if idx < cola.size():
				intento_seleccion_lavadora.emit(idx)


# ============================================================
# VISUAL
# ============================================================
func _refrescar_visual() -> void:
	for i in MAX_COLA:
		var icono: ColorRect = slot_iconos[i]
		var label: Label = slot_labels[i]
		var slot: PanelContainer = slots[i]

		if i < cola.size():
			var prenda: Dictionary = cola[i]
			icono.color = prenda.get("color_prenda", Color("#2A2A4A"))
			icono.modulate.a = 1.0

			var nombre: String = prenda.get("nombre", "?")
			label.text = nombre.split(" ")[0]

			var es_alien: bool = prenda.get("es_alien", false)
			var estilo := StyleBoxFlat.new()
			estilo.bg_color = Color("#12122A")
			estilo.set_corner_radius_all(6)
			if es_alien:
				estilo.border_color = Color("#AA40FF")
				estilo.set_border_width_all(3)
			else:
				estilo.border_color = Color("#2A2A4A")
				estilo.set_border_width_all(2)
			slot.add_theme_stylebox_override("panel", estilo)
		else:
			icono.color = Color("#1A1A2A")
			icono.modulate.a = 1.0
			label.text = ""


func _process(_delta: float) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	for i in min(cola.size(), MAX_COLA):
		if cola[i].get("es_alien", false):
			var pulse: float = 0.7 + 0.3 * sin(t * 3.0 + i)
			slot_iconos[i].modulate.a = pulse
