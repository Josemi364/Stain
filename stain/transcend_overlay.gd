extends Control
##
## TranscendOverlay.gd — FASE 18
## ============================================================
## Modal con la "Sala de Esencia". Las mejoras se compran con Esencia ✺
## (moneda meta) y persisten incluso a través de trascendencias.
##
## API pública:
##   mostrar(esencia, comprados)
##   ocultar()
##   refrescar(esencia, comprados)
##
## Señales:
##   esencia_solicitada(id, coste) → Main valida y aplica
##

signal esencia_solicitada(id: String, coste: int)

# ============================================================
# CONFIGURACIÓN
# ============================================================
const TAMANO_PANEL: Vector2 = Vector2(540, 540)
const ANCHO_VIEWPORT: int = 1280
const ALTO_VIEWPORT: int = 720

const MEJORAS: Array[Dictionary] = [
	{
		"id": "aliento_eterno",
		"nombre": "Aliento eterno",
		"descripcion": "Empiezas cada run con +100 €.",
		"coste": 2,
		"icono": "🌬",
		"color": "#80FFAA",
	},
	{
		"id": "eco_ascendido",
		"nombre": "Eco ascendido",
		"descripcion": "+5% € en todo. Permanente entre trascendencias.",
		"coste": 4,
		"icono": "💎",
		"color": "#FFD060",
	},
	{
		"id": "cuna_abierta",
		"nombre": "Cuna abierta",
		"descripcion": "+1 al máximo de lavadoras básicas (3 → 4).",
		"coste": 7,
		"icono": "📦",
		"color": "#40A0FF",
	},
	{
		"id": "memoria_eterna",
		"nombre": "Memoria eterna",
		"descripcion": "La Ceniza 🜁 se conserva al trascender.",
		"coste": 12,
		"icono": "🜁",
		"color": "#FF8080",
	},
	{
		"id": "lavandero",
		"nombre": "El Lavandero",
		"descripcion": "El multiplicador máximo sube de 3.0× a 5.0×.",
		"coste": 20,
		"icono": "👑",
		"color": "#E0C0FF",
	},
]

# ============================================================
# REFS
# ============================================================
var _fondo: ColorRect
var _panel: PanelContainer
var _esencia_label: Label
var _grid: VBoxContainer

var esencia_actual: int = 0
var comprados: Array[String] = []


# ============================================================
# INICIALIZACIÓN
# ============================================================
func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	z_index = 80
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_construir_fondo()
	_construir_panel()


func _construir_fondo() -> void:
	_fondo = ColorRect.new()
	_fondo.color = Color(0, 0, 0, 0.78)
	_fondo.anchor_right = 1.0
	_fondo.anchor_bottom = 1.0
	_fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	_fondo.gui_input.connect(_on_fondo_input)
	add_child(_fondo)


func _construir_panel() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = TAMANO_PANEL
	_panel.position = Vector2(
		(ANCHO_VIEWPORT - TAMANO_PANEL.x) / 2.0,
		(ALTO_VIEWPORT - TAMANO_PANEL.y) / 2.0
	)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("#0E0E1E")
	estilo.border_color = Color("#FFD060")
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(10)
	estilo.content_margin_left = 22
	estilo.content_margin_right = 22
	estilo.content_margin_top = 18
	estilo.content_margin_bottom = 18
	_panel.add_theme_stylebox_override("panel", estilo)
	add_child(_panel)

	var raiz := VBoxContainer.new()
	raiz.add_theme_constant_override("separation", 14)
	_panel.add_child(raiz)

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	raiz.add_child(header)

	var titulo := Label.new()
	titulo.text = "✺  SALA DE ESENCIA"
	titulo.add_theme_font_size_override("font_size", 22)
	titulo.add_theme_color_override("font_color", Color("#FFD060"))
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titulo)

	_esencia_label = Label.new()
	_esencia_label.add_theme_font_size_override("font_size", 18)
	_esencia_label.add_theme_color_override("font_color", Color("#FFD060"))
	header.add_child(_esencia_label)

	var btn_cerrar := Button.new()
	btn_cerrar.text = "✕"
	btn_cerrar.custom_minimum_size = Vector2(36, 36)
	var es := StyleBoxFlat.new()
	es.bg_color = Color("#3A2A4A")
	es.set_corner_radius_all(4)
	btn_cerrar.add_theme_stylebox_override("normal", es)
	btn_cerrar.add_theme_stylebox_override("hover", es)
	btn_cerrar.add_theme_stylebox_override("pressed", es)
	btn_cerrar.add_theme_color_override("font_color", Color("#FFAAAA"))
	btn_cerrar.add_theme_font_size_override("font_size", 14)
	btn_cerrar.pressed.connect(ocultar)
	header.add_child(btn_cerrar)

	# Subtítulo / explicación
	var subtitulo := Label.new()
	subtitulo.text = "Reliquias permanentes que sobreviven a TODO. Ni la trascendencia las borra."
	subtitulo.add_theme_color_override("font_color", Color("#888899"))
	subtitulo.add_theme_font_size_override("font_size", 11)
	subtitulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	raiz.add_child(subtitulo)

	# Lista de mejoras
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	raiz.add_child(scroll)

	_grid = VBoxContainer.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("separation", 8)
	scroll.add_child(_grid)


# ============================================================
# RENDER
# ============================================================
func _rellenar() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_esencia_label.text = "✺ %d" % esencia_actual
	for m in MEJORAS:
		_crear_card(m)


func _crear_card(mejora: Dictionary) -> void:
	var mid: String = String(mejora["id"])
	var comprado: bool = mid in comprados
	var coste: int = int(mejora["coste"])
	var puede_pagar: bool = esencia_actual >= coste

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 80)
	var estilo := StyleBoxFlat.new()
	if comprado:
		estilo.bg_color = Color("#2A2A1A")
		estilo.border_color = Color("#FFD060")
	else:
		estilo.bg_color = Color("#0D0D1A")
		estilo.border_color = Color(String(mejora["color"]))
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(6)
	estilo.content_margin_left = 12
	estilo.content_margin_right = 12
	estilo.content_margin_top = 8
	estilo.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", estilo)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	var icono := Label.new()
	icono.text = String(mejora["icono"])
	icono.add_theme_font_size_override("font_size", 32)
	icono.custom_minimum_size = Vector2(48, 0)
	if not comprado:
		icono.modulate = Color(0.7, 0.7, 0.85)
	hbox.add_child(icono)

	var textos := VBoxContainer.new()
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textos.add_theme_constant_override("separation", 2)
	hbox.add_child(textos)

	var nombre := Label.new()
	nombre.text = String(mejora["nombre"])
	nombre.add_theme_font_size_override("font_size", 14)
	nombre.add_theme_color_override("font_color",
		Color("#FFD060") if comprado else Color(String(mejora["color"])))
	textos.add_child(nombre)

	var desc := Label.new()
	desc.text = String(mejora["descripcion"])
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color("#A0A0CC"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	textos.add_child(desc)

	var boton := Button.new()
	boton.custom_minimum_size = Vector2(110, 40)
	boton.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bs := StyleBoxFlat.new()
	bs.set_corner_radius_all(4)
	if comprado:
		boton.text = "✓"
		bs.bg_color = Color("#A0801A")
		boton.add_theme_color_override("font_color", Color("#0D0D1A"))
		boton.disabled = true
	elif not puede_pagar:
		boton.text = "%d ✺" % coste
		bs.bg_color = Color("#1A1A2A")
		boton.add_theme_color_override("font_color", Color("#555577"))
		boton.disabled = true
	else:
		boton.text = "%d ✺" % coste
		bs.bg_color = Color(String(mejora["color"])).darkened(0.5)
		boton.add_theme_color_override("font_color", Color("#FFFFFF"))
		boton.pressed.connect(func(): esencia_solicitada.emit(mid, coste))
	boton.add_theme_stylebox_override("normal", bs)
	boton.add_theme_stylebox_override("hover", bs)
	boton.add_theme_stylebox_override("pressed", bs)
	boton.add_theme_stylebox_override("disabled", bs)
	boton.add_theme_font_size_override("font_size", 14)
	hbox.add_child(boton)

	_grid.add_child(card)


# ============================================================
# API PÚBLICA
# ============================================================
func mostrar(esencia: int, lista_compradas: Array[String]) -> void:
	esencia_actual = esencia
	comprados = lista_compradas.duplicate()
	visible = true
	_rellenar()
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.2)


func ocultar() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	await tw.finished
	visible = false


func refrescar(esencia: int, lista_compradas: Array[String]) -> void:
	esencia_actual = esencia
	comprados = lista_compradas.duplicate()
	if visible:
		_rellenar()


# ============================================================
# UTILIDADES
# ============================================================
func _on_fondo_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			ocultar()
