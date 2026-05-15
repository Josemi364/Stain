extends Control
##
## AlliesOverlay.gd — FASE 17
## ============================================================
## Modal con la "Cantina de Aliados". Cada aliado se compra una sola vez
## con favores y aplica un efecto pasivo permanente (no resetea con
## prestigio).
##
## Construido programáticamente, instanciado por Main como hijo del HUD.
##
## API pública:
##   mostrar()
##   ocultar()
##   refrescar()  → re-renderiza tras compra exitosa
##
## Señales:
##   aliado_solicitado(id, coste) → Main valida favores y aplica
##

signal aliado_solicitado(id: String, coste: int)

# ============================================================
# CONFIGURACIÓN
# ============================================================
const TAMANO_PANEL: Vector2 = Vector2(520, 520)
const ANCHO_VIEWPORT: int = 1280
const ALTO_VIEWPORT: int = 720

# Lista canónica de aliados. La fuente de verdad la mantiene Main, pero
# duplicamos aquí los campos UI para evitar dependencia inversa.
const ALIADOS: Array[Dictionary] = [
	{
		"id": "aprendiz_veloz",
		"nombre": "Aprendiz veloz",
		"descripcion": "Te ayuda a frotar más fuerte. +0.10 fuerza de borrado base.",
		"coste": 3,
		"icono": "✋",
		"color": "#FFAA40",
	},
	{
		"id": "tendero",
		"nombre": "Tendero del barrio",
		"descripcion": "Te aconseja al cobrar. +5% € en todo (apila).",
		"coste": 5,
		"icono": "💰",
		"color": "#FFD060",
	},
	{
		"id": "mensajero",
		"nombre": "Mensajero callejero",
		"descripcion": "Trae prendas raras del extranjero. +2% prob. alien.",
		"coste": 8,
		"icono": "📨",
		"color": "#AA40FF",
	},
	{
		"id": "relojero",
		"nombre": "Relojero excéntrico",
		"descripcion": "Sincroniza tus máquinas. −5% ciclo en TODAS las lavadoras.",
		"coste": 10,
		"icono": "⏱",
		"color": "#40A0FF",
	},
	{
		"id": "custodio",
		"nombre": "Custodio de la ceniza",
		"descripcion": "Reza por ti al renacer. +2 🜁 al prestigiar (apila).",
		"coste": 15,
		"icono": "🜁",
		"color": "#FF8080",
	},
]

# ============================================================
# REFS
# ============================================================
var _fondo: ColorRect
var _panel: PanelContainer
var _favores_label: Label
var _grid: VBoxContainer

# Estado heredado desde Main (refresco)
var favores_actuales: int = 0
var aliados_comprados: Array[String] = []


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
	_fondo.color = Color(0, 0, 0, 0.75)
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
	estilo.bg_color = Color("#181826")
	estilo.border_color = Color("#AA80FF")
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(10)
	estilo.content_margin_left = 20
	estilo.content_margin_right = 20
	estilo.content_margin_top = 16
	estilo.content_margin_bottom = 16
	_panel.add_theme_stylebox_override("panel", estilo)
	add_child(_panel)

	var raiz := VBoxContainer.new()
	raiz.add_theme_constant_override("separation", 12)
	_panel.add_child(raiz)

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	raiz.add_child(header)

	var titulo := Label.new()
	titulo.text = "🤝  CANTINA DE ALIADOS"
	titulo.add_theme_font_size_override("font_size", 20)
	titulo.add_theme_color_override("font_color", Color("#E0C0FF"))
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titulo)

	_favores_label = Label.new()
	_favores_label.add_theme_font_size_override("font_size", 16)
	_favores_label.add_theme_color_override("font_color", Color("#FFD060"))
	header.add_child(_favores_label)

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

	# Grid de aliados (un VBox con cards)
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
	_favores_label.text = "✦ %d Favores" % favores_actuales
	for ali in ALIADOS:
		_crear_card(ali)


func _crear_card(ali: Dictionary) -> void:
	var aid: String = String(ali["id"])
	var comprado: bool = aid in aliados_comprados
	var coste: int = int(ali["coste"])
	var puede_pagar: bool = favores_actuales >= coste

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 80)
	var estilo := StyleBoxFlat.new()
	if comprado:
		estilo.bg_color = Color("#1A2A1A")
		estilo.border_color = Color("#40A040")
	else:
		estilo.bg_color = Color("#0D0D1A")
		estilo.border_color = Color(String(ali["color"]))
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
	icono.text = String(ali["icono"])
	icono.add_theme_font_size_override("font_size", 30)
	icono.custom_minimum_size = Vector2(44, 0)
	if not comprado:
		icono.modulate = Color(0.7, 0.7, 0.85)
	hbox.add_child(icono)

	var textos := VBoxContainer.new()
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textos.add_theme_constant_override("separation", 2)
	hbox.add_child(textos)

	var nombre := Label.new()
	nombre.text = String(ali["nombre"])
	nombre.add_theme_font_size_override("font_size", 14)
	nombre.add_theme_color_override("font_color",
		Color("#80FFAA") if comprado else Color(String(ali["color"])))
	textos.add_child(nombre)

	var desc := Label.new()
	desc.text = String(ali["descripcion"])
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color",
		Color("#A0CCAA") if comprado else Color("#A0A0CC"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	textos.add_child(desc)

	var boton := Button.new()
	boton.custom_minimum_size = Vector2(110, 40)
	boton.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bs := StyleBoxFlat.new()
	bs.set_corner_radius_all(4)
	if comprado:
		boton.text = "✓"
		bs.bg_color = Color("#40A040")
		boton.add_theme_color_override("font_color", Color("#0D0D1A"))
		boton.disabled = true
	elif not puede_pagar:
		boton.text = "%d ✦" % coste
		bs.bg_color = Color("#1A1A2A")
		boton.add_theme_color_override("font_color", Color("#555577"))
		boton.disabled = true
	else:
		boton.text = "%d ✦" % coste
		bs.bg_color = Color(String(ali["color"])).darkened(0.5)
		boton.add_theme_color_override("font_color", Color("#FFFFFF"))
		boton.pressed.connect(func(): aliado_solicitado.emit(aid, coste))
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
func mostrar(favores: int, comprados: Array[String]) -> void:
	favores_actuales = favores
	aliados_comprados = comprados.duplicate()
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


func refrescar(favores: int, comprados: Array[String]) -> void:
	favores_actuales = favores
	aliados_comprados = comprados.duplicate()
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
