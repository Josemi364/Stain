extends Control
##
## CodexOverlay.gd — FASE 21
## ============================================================
## Modal con dos pestañas:
##   - Glosario: definiciones fijas de términos del juego (15 entradas)
##   - Diario:  registro cronológico de hitos personales con timestamps
##              reales. Las entradas las añade Main vía notif_hito().
##
## API pública:
##   mostrar(diario_entradas)
##   ocultar()
##   refrescar(diario_entradas)
##

# ============================================================
# CONFIGURACIÓN
# ============================================================
const TAMANO_PANEL: Vector2 = Vector2(720, 560)
const ANCHO_VIEWPORT: int = 1280
const ALTO_VIEWPORT: int = 720

# Glosario fijo. Cualquier término nuevo: añadir aquí.
const GLOSARIO: Array[Dictionary] = [
	{"icono": "€",  "nombre": "Euros",         "texto": "Moneda principal de la run. Se gana limpiando prendas y se gasta en la Tienda. Se resetea al prestigiar."},
	{"icono": "🜁", "nombre": "Ceniza",        "texto": "Moneda permanente del prestigio. Se gasta en la Tienda de Ceniza para mejoras de eficiencia."},
	{"icono": "✧", "nombre": "Fragmentos",    "texto": "Moneda alien. Cae al limpiar prendas alien. Se gasta en el Altar para mejoras narrativas."},
	{"icono": "✦", "nombre": "Favores",       "texto": "Moneda social. +1 al completar contrato o VIP. Se gasta en la Cantina de Aliados."},
	{"icono": "✺", "nombre": "Esencia",       "texto": "Moneda meta-permanente de la Trascendencia. Mejoras que sobreviven a TODO."},
	{"icono": "🔥", "nombre": "Prestigio",     "texto": "Reset de la run a cambio de Ceniza. Aparece a partir de 2000€ totales ganados."},
	{"icono": "✺", "nombre": "Trascendencia", "texto": "Reset profundo tras 5 prestigios. Ganas Esencia. Se conservan logros, bestiario, opciones y mejoras de esencia."},
	{"icono": "🛸", "nombre": "Custodio",      "texto": "Prenda alien especial. Aparece automáticamente cada 15 alien limpiadas. Solo manual. Da las 3 monedas."},
	{"icono": "✋", "nombre": "Bendición",     "texto": "Modificador aleatorio elegido tras cada prestigio. Una sola activa por run."},
	{"icono": "🤝", "nombre": "Aliado",        "texto": "Personaje permanente comprado con Favores. Efecto pasivo que NO resetea con prestigio."},
	{"icono": "🌀", "nombre": "Lavadora cuántica", "texto": "La única que acepta prendas alien por defecto. Su ciclo se reduce con la mejora 'Compresor temporal' del Altar."},
	{"icono": "📿", "nombre": "Altar de Fragmentos", "texto": "Tercera tienda. Mejoras pagadas con ✧, todas permanentes. Cada compra revela un fragmento de lore."},
	{"icono": "👽", "nombre": "Suerte alien",  "texto": "Probabilidad de que una prenda generada sea alien. Sube con mejoras y eventos."},
	{"icono": "⚡", "nombre": "Eventos aleatorios", "texto": "Modificadores temporales que aparecen periódicamente. Susto del altar, hora dorada, lluvia alien..."},
	{"icono": "📋", "nombre": "Contratos",     "texto": "Pedidos opcionales con objetivo + plazo + recompensa. Aceptar o rechazar antes de que expiren."},
	{"icono": "🧽", "nombre": "Habilidades",   "texto": "Capacidades activables con cooldown. Se desbloquean al progresar. Atajos: Q, W, E."},
]


# ============================================================
# REFS
# ============================================================
var _fondo: ColorRect
var _panel: PanelContainer
var _tab_glosario_btn: Button
var _tab_diario_btn: Button
var _contenido: Control
var _vista_glosario: ScrollContainer
var _vista_diario: ScrollContainer
var _glosario_vbox: VBoxContainer
var _diario_vbox: VBoxContainer

var diario_entradas: Array = []  # [{id, ts, icono, texto}]


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
	estilo.bg_color = Color("#12122A")
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
	raiz.add_theme_constant_override("separation", 14)
	_panel.add_child(raiz)

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	raiz.add_child(header)

	var titulo := Label.new()
	titulo.text = "📖  CODEX DEL LAVANDERO"
	titulo.add_theme_font_size_override("font_size", 22)
	titulo.add_theme_color_override("font_color", Color("#E0C0FF"))
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titulo)

	var btn_cerrar := Button.new()
	btn_cerrar.text = "✕"
	btn_cerrar.custom_minimum_size = Vector2(36, 36)
	var ec := StyleBoxFlat.new()
	ec.bg_color = Color("#3A2A4A")
	ec.set_corner_radius_all(4)
	btn_cerrar.add_theme_stylebox_override("normal", ec)
	btn_cerrar.add_theme_stylebox_override("hover", ec)
	btn_cerrar.add_theme_stylebox_override("pressed", ec)
	btn_cerrar.add_theme_color_override("font_color", Color("#FFAAAA"))
	btn_cerrar.add_theme_font_size_override("font_size", 14)
	btn_cerrar.pressed.connect(ocultar)
	header.add_child(btn_cerrar)

	# Tabs
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	raiz.add_child(tabs)

	_tab_glosario_btn = Button.new()
	_tab_glosario_btn.text = "Glosario"
	_tab_glosario_btn.custom_minimum_size = Vector2(140, 32)
	_tab_glosario_btn.pressed.connect(func(): _seleccionar_tab(0))
	tabs.add_child(_tab_glosario_btn)

	_tab_diario_btn = Button.new()
	_tab_diario_btn.text = "Diario"
	_tab_diario_btn.custom_minimum_size = Vector2(140, 32)
	_tab_diario_btn.pressed.connect(func(): _seleccionar_tab(1))
	tabs.add_child(_tab_diario_btn)

	# Contenido
	_contenido = Control.new()
	_contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contenido.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_contenido.custom_minimum_size = Vector2(0, 420)
	raiz.add_child(_contenido)

	_construir_vista_glosario()
	_construir_vista_diario()
	_seleccionar_tab(0)


func _construir_vista_glosario() -> void:
	_vista_glosario = ScrollContainer.new()
	_vista_glosario.anchor_right = 1.0
	_vista_glosario.anchor_bottom = 1.0
	_vista_glosario.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_contenido.add_child(_vista_glosario)

	_glosario_vbox = VBoxContainer.new()
	_glosario_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_glosario_vbox.add_theme_constant_override("separation", 6)
	_vista_glosario.add_child(_glosario_vbox)


func _construir_vista_diario() -> void:
	_vista_diario = ScrollContainer.new()
	_vista_diario.anchor_right = 1.0
	_vista_diario.anchor_bottom = 1.0
	_vista_diario.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_vista_diario.visible = false
	_contenido.add_child(_vista_diario)

	_diario_vbox = VBoxContainer.new()
	_diario_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_diario_vbox.add_theme_constant_override("separation", 6)
	_vista_diario.add_child(_diario_vbox)


# ============================================================
# RENDER
# ============================================================
func _rellenar_glosario() -> void:
	for c in _glosario_vbox.get_children():
		c.queue_free()
	for term in GLOSARIO:
		_crear_card_termino(term)


func _crear_card_termino(term: Dictionary) -> void:
	var card := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("#0D0D1A")
	estilo.border_color = Color("#2A2A4A")
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(6)
	estilo.content_margin_left = 10
	estilo.content_margin_right = 10
	estilo.content_margin_top = 6
	estilo.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", estilo)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)

	var icono := Label.new()
	icono.text = String(term["icono"])
	icono.add_theme_font_size_override("font_size", 22)
	icono.custom_minimum_size = Vector2(36, 0)
	hbox.add_child(icono)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	hbox.add_child(v)

	var nombre := Label.new()
	nombre.text = String(term["nombre"])
	nombre.add_theme_font_size_override("font_size", 13)
	nombre.add_theme_color_override("font_color", Color("#D0D0F0"))
	v.add_child(nombre)

	var texto := Label.new()
	texto.text = String(term["texto"])
	texto.add_theme_font_size_override("font_size", 11)
	texto.add_theme_color_override("font_color", Color("#9090AA"))
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(texto)

	_glosario_vbox.add_child(card)


func _rellenar_diario() -> void:
	for c in _diario_vbox.get_children():
		c.queue_free()

	if diario_entradas.is_empty():
		var vacio := Label.new()
		vacio.text = "Aún no has registrado ningún hito.\nSigue jugando y volverás aquí a leer tu historia."
		vacio.add_theme_color_override("font_color", Color("#888899"))
		vacio.add_theme_font_size_override("font_size", 12)
		vacio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_diario_vbox.add_child(vacio)
		return

	# Ordenar por timestamp asc (las más antiguas arriba)
	var ordenadas: Array = diario_entradas.duplicate()
	ordenadas.sort_custom(func(a, b): return float(a.get("ts", 0.0)) < float(b.get("ts", 0.0)))

	for entry in ordenadas:
		_crear_card_diario(entry)


func _crear_card_diario(entry: Dictionary) -> void:
	var card := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("#1A1A2E")
	estilo.border_color = Color("#5A4A8A")
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(6)
	estilo.content_margin_left = 10
	estilo.content_margin_right = 10
	estilo.content_margin_top = 6
	estilo.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", estilo)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)

	var icono := Label.new()
	icono.text = String(entry.get("icono", "•"))
	icono.add_theme_font_size_override("font_size", 22)
	icono.custom_minimum_size = Vector2(36, 0)
	hbox.add_child(icono)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	hbox.add_child(v)

	var fecha := Label.new()
	fecha.text = _formatear_fecha(float(entry.get("ts", 0.0)))
	fecha.add_theme_font_size_override("font_size", 10)
	fecha.add_theme_color_override("font_color", Color("#888899"))
	v.add_child(fecha)

	var texto := Label.new()
	texto.text = String(entry.get("texto", ""))
	texto.add_theme_font_size_override("font_size", 12)
	texto.add_theme_color_override("font_color", Color("#E0E0F0"))
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(texto)

	_diario_vbox.add_child(card)


# ============================================================
# TABS
# ============================================================
func _seleccionar_tab(idx: int) -> void:
	_vista_glosario.visible = (idx == 0)
	_vista_diario.visible = (idx == 1)
	_estilizar_tab(_tab_glosario_btn, idx == 0)
	_estilizar_tab(_tab_diario_btn, idx == 1)
	match idx:
		0: _rellenar_glosario()
		1: _rellenar_diario()


func _estilizar_tab(boton: Button, activo: bool) -> void:
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(4)
	if activo:
		s.bg_color = Color("#3A2A4A")
		boton.add_theme_color_override("font_color", Color("#E0C0FF"))
	else:
		s.bg_color = Color("#1A1A2A")
		boton.add_theme_color_override("font_color", Color("#888899"))
	boton.add_theme_stylebox_override("normal", s)
	boton.add_theme_stylebox_override("hover", s)
	boton.add_theme_stylebox_override("pressed", s)
	boton.add_theme_font_size_override("font_size", 12)


# ============================================================
# API PÚBLICA
# ============================================================
func mostrar(entradas: Array) -> void:
	diario_entradas = entradas.duplicate(true)
	visible = true
	_seleccionar_tab(0)
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.2)


func ocultar() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	await tw.finished
	visible = false


func refrescar(entradas: Array) -> void:
	diario_entradas = entradas.duplicate(true)
	if visible and _vista_diario.visible:
		_rellenar_diario()


# ============================================================
# UTILIDADES
# ============================================================
func _on_fondo_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			ocultar()


func _formatear_fecha(ts: float) -> String:
	if ts <= 0.0:
		return "—"
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(int(ts))
	return "%04d-%02d-%02d  %02d:%02d" % [
		int(dt["year"]), int(dt["month"]), int(dt["day"]),
		int(dt["hour"]), int(dt["minute"]),
	]
