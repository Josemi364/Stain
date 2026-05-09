extends HBoxContainer
##
## QueuePanel.gd — FASE 2
## ============================================================
## Cola visual de las próximas prendas en espera.
## Los slots se crean por código y guardamos referencias directas
## a los iconos y labels en arrays paralelos (más fiable que get_node).
##

signal siguiente_prenda_lista(prenda: Dictionary)

# ============================================================
# CONFIGURACIÓN
# ============================================================
const MAX_COLA: int = 5
const SLOT_SIZE: Vector2 = Vector2(80, 100)
const SLOT_SEPARACION: int = 10
#aaa
# ============================================================
# ESTADO INTERNO
# ============================================================
var cola: Array[Dictionary] = []
var slots: Array[PanelContainer] = []      # Contenedores externos
var slot_iconos: Array[ColorRect] = []     # Referencia directa al icono de cada slot
var slot_labels: Array[Label] = []         # Referencia directa al label de cada slot


# ============================================================
# INICIALIZACIÓN
# ============================================================
func _ready() -> void:
	add_theme_constant_override("separation", SLOT_SEPARACION)

	# Creamos los slots visuales
	for i in MAX_COLA:
		_crear_slot()

	# Llenamos la cola inicial con prendas aleatorias
	cola = GarmentData.get_cola_inicial(MAX_COLA)
	_refrescar_visual()


# ============================================================
# API PÚBLICA
# ============================================================

## Saca la primera prenda y la envía al SinkArea, rellena la cola.
func consumir_siguiente() -> void:
	if cola.is_empty():
		push_warning("QueuePanel: cola vacía.")
		return

	var prenda: Dictionary = cola.pop_front()
	cola.append(GarmentData.get_prenda_aleatoria())
	_refrescar_visual()
	siguiente_prenda_lista.emit(prenda)


func get_cantidad() -> int:
	return cola.size()


# ============================================================
# VISUAL — SLOTS
# ============================================================

## Crea un slot visual y guarda referencias al icono y label.
func _crear_slot() -> void:
	# Contenedor externo
	var contenedor := PanelContainer.new()
	contenedor.custom_minimum_size = SLOT_SIZE

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("#12122A")
	estilo.border_color = Color("#2A2A4A")
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(6)
	contenedor.add_theme_stylebox_override("panel", estilo)

	# VBox interior
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	contenedor.add_child(vbox)

	# Icono (ColorRect)
	var icono := ColorRect.new()
	icono.custom_minimum_size = Vector2(50, 55)
	icono.color = Color("#2A2A4A")
	vbox.add_child(icono)

	# Label con el nombre corto
	var nombre_label := Label.new()
	nombre_label.text = "..."
	nombre_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nombre_label.add_theme_font_size_override("font_size", 9)
	nombre_label.add_theme_color_override("font_color", Color("#8888BB"))
	nombre_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	nombre_label.custom_minimum_size = Vector2(76, 0)
	vbox.add_child(nombre_label)

	# Añadimos el slot al árbol de escena
	add_child(contenedor)

	# Guardamos referencias directas en arrays paralelos
	slots.append(contenedor)
	slot_iconos.append(icono)
	slot_labels.append(nombre_label)


## Actualiza el visual de todos los slots según el contenido de la cola.
func _refrescar_visual() -> void:
	for i in MAX_COLA:
		var icono: ColorRect = slot_iconos[i]
		var label: Label = slot_labels[i]
		var slot: PanelContainer = slots[i]

		if i < cola.size():
			var prenda: Dictionary = cola[i]
			icono.color = prenda.get("color_prenda", Color("#2A2A4A"))
			icono.modulate.a = 1.0  # Reset modulate por si quedó del pulso

			var nombre: String = prenda.get("nombre", "?")
			label.text = nombre.split(" ")[0]

			# Borde violeta si es alienígena
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
			# Slot vacío
			icono.color = Color("#1A1A2A")
			icono.modulate.a = 1.0
			label.text = ""


## Pulso suave en el icono de las prendas alienígenas.
func _process(_delta: float) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	for i in min(cola.size(), MAX_COLA):
		if cola[i].get("es_alien", false):
			var pulse: float = 0.7 + 0.3 * sin(t * 3.0 + i)
			slot_iconos[i].modulate.a = pulse
