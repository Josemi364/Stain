extends Control
##
## AchievementsOverlay.gd — FASE 8
## ============================================================
## Modal a pantalla completa con dos pestañas: Logros y Estadísticas.
## Se construye enteramente por código para evitar editar main.tscn.
##
## API pública:
##   mostrar()  → abre el overlay y refresca contenido
##   ocultar()  → cierra
##
## Main lo instancia y lo añade al HUD.
##

# ============================================================
# CONFIGURACIÓN
# ============================================================
const TAMANO_PANEL: Vector2 = Vector2(840, 560)
const ANCHO_VIEWPORT: int = 1280
const ALTO_VIEWPORT: int = 720

# ============================================================
# REFS INTERNAS
# ============================================================
var _fondo: ColorRect
var _panel: PanelContainer
var _tab_logros_btn: Button
var _tab_stats_btn: Button
var _tab_bestiario_btn: Button
var _contenido: Control
var _vista_logros: ScrollContainer
var _vista_stats: ScrollContainer
var _vista_bestiario: ScrollContainer
var _logros_vbox: VBoxContainer
var _stats_vbox: VBoxContainer
var _bestiario_grid: GridContainer
var _bestiario_progreso_lbl: Label

# Estado de la pestaña actual: 0=logros, 1=stats, 2=bestiario
var _tab_actual: int = 0


func _ready() -> void:
	# Ocupar toda la pantalla. mouse_filter STOP en el fondo bloquea clicks debajo.
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_right = 0.0
	offset_bottom = 0.0
	z_index = 80
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_construir_fondo()
	_construir_panel()


# ============================================================
# CONSTRUCCIÓN UI
# ============================================================
func _construir_fondo() -> void:
	_fondo = ColorRect.new()
	_fondo.color = Color(0, 0, 0, 0.75)
	_fondo.anchor_right = 1.0
	_fondo.anchor_bottom = 1.0
	_fondo.offset_right = 0.0
	_fondo.offset_bottom = 0.0
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
	estilo.border_color = Color("#5A5AAA")
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(10)
	estilo.content_margin_left = 20
	estilo.content_margin_right = 20
	estilo.content_margin_top = 16
	estilo.content_margin_bottom = 16
	_panel.add_theme_stylebox_override("panel", estilo)
	add_child(_panel)

	var raiz_vbox := VBoxContainer.new()
	raiz_vbox.add_theme_constant_override("separation", 14)
	_panel.add_child(raiz_vbox)

	# === Header: título + botón cerrar ===
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	raiz_vbox.add_child(header)

	var titulo := Label.new()
	titulo.text = "📊  PROGRESO"
	titulo.add_theme_font_size_override("font_size", 22)
	titulo.add_theme_color_override("font_color", Color("#A0A0FF"))
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titulo)

	var btn_cerrar := Button.new()
	btn_cerrar.text = "✕"
	btn_cerrar.custom_minimum_size = Vector2(36, 36)
	_estilizar_boton(btn_cerrar, "#3A2A4A", "#FFAAAA")
	btn_cerrar.pressed.connect(ocultar)
	header.add_child(btn_cerrar)

	# === Tabs ===
	var tabs_row := HBoxContainer.new()
	tabs_row.add_theme_constant_override("separation", 4)
	raiz_vbox.add_child(tabs_row)

	_tab_logros_btn = Button.new()
	_tab_logros_btn.text = "Logros"
	_tab_logros_btn.custom_minimum_size = Vector2(140, 32)
	_tab_logros_btn.pressed.connect(_on_tab_logros)
	tabs_row.add_child(_tab_logros_btn)

	_tab_stats_btn = Button.new()
	_tab_stats_btn.text = "Estadísticas"
	_tab_stats_btn.custom_minimum_size = Vector2(140, 32)
	_tab_stats_btn.pressed.connect(_on_tab_stats)
	tabs_row.add_child(_tab_stats_btn)

	_tab_bestiario_btn = Button.new()
	_tab_bestiario_btn.text = "Bestiario"
	_tab_bestiario_btn.custom_minimum_size = Vector2(140, 32)
	_tab_bestiario_btn.pressed.connect(_on_tab_bestiario)
	tabs_row.add_child(_tab_bestiario_btn)

	# === Contenido (vistas alternables) ===
	_contenido = Control.new()
	_contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contenido.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_contenido.custom_minimum_size = Vector2(0, 430)
	raiz_vbox.add_child(_contenido)

	_construir_vista_logros()
	_construir_vista_stats()
	_construir_vista_bestiario()

	_seleccionar_tab_idx(0)


func _construir_vista_logros() -> void:
	_vista_logros = ScrollContainer.new()
	_vista_logros.anchor_right = 1.0
	_vista_logros.anchor_bottom = 1.0
	_vista_logros.offset_right = 0.0
	_vista_logros.offset_bottom = 0.0
	_vista_logros.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_contenido.add_child(_vista_logros)

	_logros_vbox = VBoxContainer.new()
	_logros_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_logros_vbox.add_theme_constant_override("separation", 8)
	_vista_logros.add_child(_logros_vbox)


func _construir_vista_stats() -> void:
	_vista_stats = ScrollContainer.new()
	_vista_stats.anchor_right = 1.0
	_vista_stats.anchor_bottom = 1.0
	_vista_stats.offset_right = 0.0
	_vista_stats.offset_bottom = 0.0
	_vista_stats.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_vista_stats.visible = false
	_contenido.add_child(_vista_stats)

	_stats_vbox = VBoxContainer.new()
	_stats_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_vbox.add_theme_constant_override("separation", 4)
	_vista_stats.add_child(_stats_vbox)


func _construir_vista_bestiario() -> void:
	_vista_bestiario = ScrollContainer.new()
	_vista_bestiario.anchor_right = 1.0
	_vista_bestiario.anchor_bottom = 1.0
	_vista_bestiario.offset_right = 0.0
	_vista_bestiario.offset_bottom = 0.0
	_vista_bestiario.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_vista_bestiario.visible = false
	_contenido.add_child(_vista_bestiario)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vista_bestiario.add_child(vbox)

	_bestiario_progreso_lbl = Label.new()
	_bestiario_progreso_lbl.add_theme_color_override("font_color", Color("#A0A0FF"))
	_bestiario_progreso_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_bestiario_progreso_lbl)

	_bestiario_grid = GridContainer.new()
	_bestiario_grid.columns = 4
	_bestiario_grid.add_theme_constant_override("h_separation", 10)
	_bestiario_grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(_bestiario_grid)


## API pública: refresca la vista del bestiario sin re-abrir el overlay.
## Útil cuando se investiga una nueva prenda con el overlay ya abierto.
func refrescar_bestiario() -> void:
	if _vista_bestiario != null and _vista_bestiario.visible:
		_rellenar_bestiario()


func _rellenar_bestiario() -> void:
	for c in _bestiario_grid.get_children():
		c.queue_free()

	var todas: Array[Dictionary] = GarmentData.get_todas_prendas()
	var investigadas: int = Stats.prendas_investigadas.size()
	var bonus_pct: int = investigadas  # +1% por prenda
	_bestiario_progreso_lbl.text = "Investigadas: %d / %d  ·  Bonus pasivo +%d%% €" % [investigadas, todas.size(), bonus_pct]

	for prenda in todas:
		_crear_card_bestiario(prenda)


func _crear_card_bestiario(prenda: Dictionary) -> void:
	var pid: String = String(prenda.get("id", ""))
	var investigada: bool = pid in Stats.prendas_investigadas
	var es_alien: bool = bool(prenda.get("es_alien", false))

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(180, 100)
	var estilo := StyleBoxFlat.new()
	if investigada:
		estilo.bg_color = Color("#1A1A2E")
		estilo.border_color = Color("#AA40FF") if es_alien else Color("#5A5AAA")
	else:
		estilo.bg_color = Color("#0D0D1A")
		estilo.border_color = Color("#2A2A4A")
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(6)
	estilo.content_margin_left = 8
	estilo.content_margin_right = 8
	estilo.content_margin_top = 6
	estilo.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", estilo)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)

	# Cabecera: color-chip + nombre
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	v.add_child(header)

	var chip := ColorRect.new()
	chip.custom_minimum_size = Vector2(20, 20)
	if investigada:
		chip.color = prenda.get("color_prenda", Color.WHITE)
	else:
		chip.color = Color("#3A3A4A")
	header.add_child(chip)

	var nombre := Label.new()
	if investigada:
		nombre.text = String(prenda.get("nombre", "?"))
		nombre.add_theme_color_override("font_color",
			Color("#E0C0FF") if es_alien else Color("#D0D0F0"))
	else:
		nombre.text = "???"
		nombre.add_theme_color_override("font_color", Color("#555577"))
	nombre.add_theme_font_size_override("font_size", 12)
	nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(nombre)

	# Info: mancha + recompensa
	var info := Label.new()
	if investigada:
		info.text = "Mancha: %s\n+%d€" % [
			String(prenda.get("tipo_mancha", "?")),
			int(prenda.get("recompensa", 0)),
		]
		var frags: int = int(prenda.get("fragmentos_bonus", 0))
		if frags > 0:
			info.text += "  +%d ✧" % frags
		info.add_theme_color_override("font_color", Color("#A0A0CC"))
	else:
		info.text = "Sin investigar"
		info.add_theme_color_override("font_color", Color("#444466"))
	info.add_theme_font_size_override("font_size", 10)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(info)

	_bestiario_grid.add_child(card)


# ============================================================
# REFRESH DE CONTENIDO
# ============================================================
func _rellenar_logros() -> void:
	for c in _logros_vbox.get_children():
		c.queue_free()

	# Header con progreso global
	var progreso: Dictionary = Stats.progreso_logros()
	var header_progreso := Label.new()
	header_progreso.text = "Desbloqueados: %d / %d" % [progreso["desbloqueados"], progreso["total"]]
	header_progreso.add_theme_color_override("font_color", Color("#A0A0FF"))
	header_progreso.add_theme_font_size_override("font_size", 13)
	_logros_vbox.add_child(header_progreso)

	for categoria in Stats.get_categorias():
		var lbl_cat := Label.new()
		lbl_cat.text = categoria.to_upper()
		lbl_cat.add_theme_color_override("font_color", Color("#6060BB"))
		lbl_cat.add_theme_font_size_override("font_size", 12)
		_logros_vbox.add_child(lbl_cat)

		for logro in Stats.get_logros_de_categoria(categoria):
			_crear_card_logro(logro)


func _crear_card_logro(logro: Dictionary) -> void:
	var desbloqueado: bool = logro["id"] in Stats.desbloqueados

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 56)
	var estilo := StyleBoxFlat.new()
	if desbloqueado:
		estilo.bg_color = Color("#1A2A1A")
		estilo.border_color = Color("#40A040")
	else:
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
	icono.text = String(logro.get("icono", "•"))
	icono.add_theme_font_size_override("font_size", 22)
	icono.custom_minimum_size = Vector2(32, 0)
	if not desbloqueado:
		icono.modulate = Color(0.4, 0.4, 0.5)
	hbox.add_child(icono)

	var textos := VBoxContainer.new()
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textos.add_theme_constant_override("separation", 1)
	hbox.add_child(textos)

	var nombre := Label.new()
	nombre.text = String(logro["nombre"])
	nombre.add_theme_font_size_override("font_size", 13)
	nombre.add_theme_color_override("font_color",
		Color("#80FFAA") if desbloqueado else Color("#888899"))
	textos.add_child(nombre)

	var desc := Label.new()
	desc.text = String(logro["descripcion"])
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color",
		Color("#A0CCAA") if desbloqueado else Color("#555577"))
	textos.add_child(desc)

	# Progreso para tipo stat
	if logro["tipo"] == "stat":
		var prog: Dictionary = Stats.get_progreso(logro["id"])
		if not prog.is_empty():
			var actual_int: int = int(min(prog["actual"], prog["umbral"]))
			var prog_lbl := Label.new()
			prog_lbl.text = "%s / %s" % [_formato_num(actual_int), _formato_num(int(prog["umbral"]))]
			prog_lbl.add_theme_font_size_override("font_size", 11)
			prog_lbl.add_theme_color_override("font_color",
				Color("#80FFAA") if desbloqueado else Color("#888899"))
			prog_lbl.custom_minimum_size = Vector2(110, 0)
			prog_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			hbox.add_child(prog_lbl)
	elif desbloqueado:
		var ok_lbl := Label.new()
		ok_lbl.text = "✓"
		ok_lbl.add_theme_font_size_override("font_size", 18)
		ok_lbl.add_theme_color_override("font_color", Color("#80FFAA"))
		hbox.add_child(ok_lbl)

	_logros_vbox.add_child(card)


func _rellenar_stats() -> void:
	for c in _stats_vbox.get_children():
		c.queue_free()

	var bloques: Array = [
		["LIMPIEZA", [
			["Prendas limpiadas a mano", "prendas_total_manual"],
			["Prendas procesadas en lavadora", "prendas_total_lavadora"],
			["Aliens limpiadas a mano", "aliens_total_manual"],
			["Aliens procesadas en lavadora", "aliens_total_lavadora"],
		]],
		["ECONOMÍA", [
			["€ ganados totales", "euros_total_historico"],
			["🜁 obtenida total", "ceniza_total_historico"],
			["✧ obtenidos total", "fragmentos_total_historico"],
			["Mejor run (€)", "max_euros_en_run"],
		]],
		["PROGRESIÓN", [
			["Prestigios realizados", "prestigios_total"],
			["Lavadoras básicas compradas", "lavadoras_basicas_compradas"],
			["Lavadoras industriales compradas", "lavadoras_industriales_compradas"],
			["Lavadoras cuánticas compradas", "lavadoras_cuanticas_compradas"],
			["Upgrades de € comprados", "upgrades_euros_comprados"],
			["Upgrades de 🜁 comprados", "upgrades_ceniza_comprados"],
			["Upgrades de ✧ comprados", "upgrades_fragmentos_comprados"],
		]],
		["EVENTOS", [
			["Eventos vividos", "eventos_completados"],
			["Pedidos VIP completados", "vips_completados"],
		]],
		["TIEMPO", [
			["Tiempo jugado total", "_tiempo_formato"],
		]],
	]

	for bloque in bloques:
		var titulo_b := Label.new()
		titulo_b.text = String(bloque[0])
		titulo_b.add_theme_color_override("font_color", Color("#6060BB"))
		titulo_b.add_theme_font_size_override("font_size", 12)
		_stats_vbox.add_child(titulo_b)

		for fila in bloque[1]:
			_crear_fila_stat(String(fila[0]), String(fila[1]))


func _crear_fila_stat(label_texto: String, stat_id: String) -> void:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)

	var lbl := Label.new()
	lbl.text = label_texto
	lbl.add_theme_color_override("font_color", Color("#A0A0CC"))
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(lbl)

	var valor := Label.new()
	if stat_id == "_tiempo_formato":
		valor.text = _formato_tiempo(Stats.get_stat("tiempo_jugado_seg"))
	else:
		valor.text = _formato_num(int(Stats.get_stat(stat_id)))
	valor.add_theme_color_override("font_color", Color("#FFFFCC"))
	valor.add_theme_font_size_override("font_size", 11)
	valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	valor.custom_minimum_size = Vector2(140, 0)
	fila.add_child(valor)

	_stats_vbox.add_child(fila)


# ============================================================
# TABS
# ============================================================
func _on_tab_logros() -> void:
	_seleccionar_tab_idx(0)


func _on_tab_stats() -> void:
	_seleccionar_tab_idx(1)


func _on_tab_bestiario() -> void:
	_seleccionar_tab_idx(2)


func _seleccionar_tab_idx(idx: int) -> void:
	_tab_actual = idx
	_vista_logros.visible = (idx == 0)
	_vista_stats.visible = (idx == 1)
	_vista_bestiario.visible = (idx == 2)
	_estilizar_tab(_tab_logros_btn, idx == 0)
	_estilizar_tab(_tab_stats_btn, idx == 1)
	_estilizar_tab(_tab_bestiario_btn, idx == 2)
	match idx:
		0: _rellenar_logros()
		1: _rellenar_stats()
		2: _rellenar_bestiario()


# ============================================================
# API PÚBLICA
# ============================================================
func mostrar() -> void:
	visible = true
	_seleccionar_tab_idx(0)
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.2)


func ocultar() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	await tw.finished
	visible = false


# ============================================================
# UTILIDADES
# ============================================================
func _on_fondo_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			ocultar()


func _estilizar_tab(boton: Button, activo: bool) -> void:
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(4)
	if activo:
		s.bg_color = Color("#3A3A6A")
		boton.add_theme_color_override("font_color", Color("#FFFFCC"))
	else:
		s.bg_color = Color("#1A1A2A")
		boton.add_theme_color_override("font_color", Color("#888899"))
	boton.add_theme_stylebox_override("normal", s)
	boton.add_theme_stylebox_override("hover", s)
	boton.add_theme_stylebox_override("pressed", s)
	boton.add_theme_font_size_override("font_size", 12)


func _estilizar_boton(boton: Button, bg_hex: String, fg_hex: String) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(bg_hex)
	s.set_corner_radius_all(4)
	boton.add_theme_stylebox_override("normal", s)
	boton.add_theme_stylebox_override("hover", s)
	boton.add_theme_stylebox_override("pressed", s)
	boton.add_theme_color_override("font_color", Color(fg_hex))
	boton.add_theme_font_size_override("font_size", 14)


func _formato_num(n: int) -> String:
	# Formato 1.234.567 con punto como separador de miles
	var s: String = str(abs(n))
	var partes: PackedStringArray = []
	while s.length() > 3:
		partes.insert(0, s.substr(s.length() - 3, 3))
		s = s.substr(0, s.length() - 3)
	partes.insert(0, s)
	var resultado: String = ".".join(partes)
	if n < 0:
		resultado = "-" + resultado
	return resultado


func _formato_tiempo(seg: float) -> String:
	var s: int = int(seg)
	var h: int = s / 3600
	var m: int = (s % 3600) / 60
	var sg: int = s % 60
	if h > 0:
		return "%dh %02dm %02ds" % [h, m, sg]
	return "%dm %02ds" % [m, sg]
