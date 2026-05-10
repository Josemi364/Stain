extends Panel
##
## MachinesPanel.gd — FASE 4 + ASSETS PRO
## ============================================================
## Lavadoras visualizadas con cuerpo SVG + tambor SVG rotando
## superpuesto. El jugador clica prendas en la cola para asignarlas.
##

signal lavadora_compra_solicitada(tipo: String, precio: int, ceniza: int)
signal prenda_procesada(prenda: Dictionary, earned: float, era_cuantica: bool)


# ============================================================
# CONFIGURACIÓN DE TIPOS — añadidos paths de assets y centros
# ============================================================
const TIPOS_LAVADORA: Dictionary = {
	"basica": {
		"nombre": "Lavadora básica",
		"descripcion": "Procesa prendas normales. Lenta.",
		"precio": 150,
		"ceniza": 0,
		"ciclo_seg": 30.0,
		"acepta_alien": false,
		"max_unidades": 3,
		"color": Color("#4080CC"),
		"cuerpo_path": "res://assets/lavadoras/basica_cuerpo.svg",
		"tambor_path": "res://assets/lavadoras/basica_tambor.svg",
		# Coords donde colocar el tambor relativas al cuerpo (cuerpo es 128x128)
		"tambor_offset": Vector2(64, 72),
		"velocidad_giro": 4.0,
	},
	"industrial": {
		"nombre": "Lavadora industrial",
		"descripcion": "Más rápida. Solo prendas normales.",
		"precio": 400,
		"ceniza": 3,
		"ciclo_seg": 20.0,
		"acepta_alien": false,
		"max_unidades": 2,
		"color": Color("#FF6020"),
		"cuerpo_path": "res://assets/lavadoras/industrial_cuerpo.svg",
		"tambor_path": "res://assets/lavadoras/industrial_tambor.svg",
		"tambor_offset": Vector2(64, 74),
		"velocidad_giro": 6.0,
	},
	"cuantica": {
		"nombre": "Lavadora cuántica",
		"descripcion": "Procesa cualquier prenda, incluso alien.",
		"precio": 1500,
		"ceniza": 15,
		"ciclo_seg": 15.0,
		"acepta_alien": true,
		"max_unidades": 1,
		"color": Color("#AA40FF"),
		"cuerpo_path": "res://assets/lavadoras/cuantica_cuerpo.svg",
		"tambor_path": "res://assets/lavadoras/cuantica_tambor.svg",
		"tambor_offset": Vector2(64, 74),
		"velocidad_giro": 8.0,
	},
}


# ============================================================
# ESTADO
# ============================================================
var lavadoras: Array[Dictionary] = []
var euros_actuales: float = 0.0
var ceniza_actual: int = 0
var contador_por_tipo: Dictionary = {"basica": 0, "industrial": 0, "cuantica": 0}

var titulo_label: Label
var lista_compra: VBoxContainer
var lista_activas: VBoxContainer
var botones_compra: Dictionary = {}


func _ready() -> void:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("#12122A")
	estilo.border_color = Color("#2A2A4A")
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", estilo)

	_construir_estructura()
	_construir_botones_compra()
	_refrescar_botones()


func _construir_estructura() -> void:
	titulo_label = Label.new()
	titulo_label.text = "LAVADORAS"
	titulo_label.position = Vector2(15, 10)
	titulo_label.size = Vector2(320, 30)
	titulo_label.add_theme_font_size_override("font_size", 22)
	titulo_label.add_theme_color_override("font_color", Color("#6060FF"))
	titulo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(titulo_label)

	lista_compra = VBoxContainer.new()
	lista_compra.position = Vector2(10, 50)
	lista_compra.size = Vector2(330, 200)
	lista_compra.add_theme_constant_override("separation", 6)
	add_child(lista_compra)

	var separator := HSeparator.new()
	separator.position = Vector2(15, 240)
	separator.size = Vector2(320, 2)
	add_child(separator)

	var label_activas := Label.new()
	label_activas.text = "ACTIVAS"
	label_activas.position = Vector2(15, 250)
	label_activas.size = Vector2(320, 22)
	label_activas.add_theme_font_size_override("font_size", 14)
	label_activas.add_theme_color_override("font_color", Color("#8888BB"))
	label_activas.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label_activas)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10, 280)
	scroll.size = Vector2(330, 215)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	lista_activas = VBoxContainer.new()
	lista_activas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista_activas.add_theme_constant_override("separation", 8)
	scroll.add_child(lista_activas)


func _construir_botones_compra() -> void:
	for tipo in TIPOS_LAVADORA.keys():
		var datos: Dictionary = TIPOS_LAVADORA[tipo]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 56)

		var estilo := StyleBoxFlat.new()
		estilo.bg_color = Color("#0D0D1A")
		estilo.border_color = datos["color"]
		estilo.set_border_width_all(1)
		estilo.set_corner_radius_all(6)
		estilo.content_margin_left = 8
		estilo.content_margin_right = 8
		estilo.content_margin_top = 4
		estilo.content_margin_bottom = 4
		card.add_theme_stylebox_override("panel", estilo)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		card.add_child(hbox)

		# Mini icono usando el SVG del cuerpo
		var icono := TextureRect.new()
		icono.custom_minimum_size = Vector2(40, 40)
		icono.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icono.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var path: String = datos["cuerpo_path"]
		if ResourceLoader.exists(path):
			icono.texture = load(path)
		hbox.add_child(icono)

		var vbox := VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 1)
		hbox.add_child(vbox)

		var nombre := Label.new()
		nombre.text = datos["nombre"]
		nombre.add_theme_color_override("font_color", Color("#D0D0F0"))
		nombre.add_theme_font_size_override("font_size", 12)
		vbox.add_child(nombre)

		var desc := Label.new()
		desc.text = datos["descripcion"]
		desc.add_theme_color_override("font_color", Color("#8888BB"))
		desc.add_theme_font_size_override("font_size", 9)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(desc)

		var boton := Button.new()
		boton.custom_minimum_size = Vector2(75, 40)
		boton.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		boton.pressed.connect(_on_boton_compra.bind(tipo))
		hbox.add_child(boton)

		lista_compra.add_child(card)
		botones_compra[tipo] = boton


# ============================================================
# API PÚBLICA
# ============================================================
func actualizar_recursos(euros: float, ceniza: int) -> void:
	euros_actuales = euros
	ceniza_actual = ceniza
	_refrescar_botones()


func confirmar_compra(tipo: String) -> void:
	if not contador_por_tipo.has(tipo):
		return
	contador_por_tipo[tipo] += 1
	_crear_lavadora_activa(tipo)
	_refrescar_botones()


func asignar_prenda(prenda: Dictionary) -> bool:
	if prenda.is_empty():
		return false
	var es_alien: bool = bool(prenda.get("es_alien", false))
	for i in lavadoras.size():
		var lav: Dictionary = lavadoras[i]
		if not lav["prenda_actual"].is_empty():
			continue
		if es_alien and not lav["acepta_alien"]:
			continue
		lav["prenda_actual"] = prenda
		lav["tiempo"] = 0.0
		return true
	return false


func tiene_lavadoras() -> bool:
	return not lavadoras.is_empty()


func tiene_lavadora_alien() -> bool:
	for lav in lavadoras:
		if lav["acepta_alien"]:
			return true
	return false


# ============================================================
# CICLO DE PROCESAMIENTO
# ============================================================
func _process(delta: float) -> void:
	for i in lavadoras.size():
		var lav: Dictionary = lavadoras[i]

		if lav["prenda_actual"].is_empty():
			lav["label_estado"].text = "Esperando asignación..."
			continue

		lav["tiempo"] += delta
		var pct: float = clamp(lav["tiempo"] / lav["ciclo_seg"], 0.0, 1.0)
		lav["barra"].value = pct * 100.0

		var nombre_corto: String = String(lav["prenda_actual"].get("nombre", "?")).split(" ")[0]
		lav["label_estado"].text = "Lavando: %s" % nombre_corto

		# Hacer girar el sprite del tambor
		lav["tambor"].rotation += delta * lav["velocidad_giro"]

		if lav["tiempo"] >= lav["ciclo_seg"]:
			var prenda: Dictionary = lav["prenda_actual"]
			var recompensa: float = float(prenda.get("recompensa", 0.0))
			var es_cuantica: bool = (lav["tipo"] == "cuantica")
			prenda_procesada.emit(prenda, recompensa, es_cuantica)
			lav["prenda_actual"] = {}
			lav["tiempo"] = 0.0
			lav["barra"].value = 0.0


# ============================================================
# CARDS DE LAVADORAS ACTIVAS — con sprite SVG + tambor rotando
# ============================================================
func _crear_lavadora_activa(tipo: String) -> void:
	var datos: Dictionary = TIPOS_LAVADORA[tipo]

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 100)

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("#0D0D1A")
	estilo.border_color = datos["color"]
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(6)
	estilo.content_margin_left = 8
	estilo.content_margin_right = 8
	estilo.content_margin_top = 6
	estilo.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", estilo)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	# === CONTENEDOR DE LA LAVADORA (cuerpo + tambor superpuesto) ===
	# Usamos un Control con tamaño fijo. Dentro:
	#   - TextureRect con el cuerpo SVG (estático).
	#   - Sprite2D del tambor centrado en tambor_offset, rota su propiedad rotation.
	var vista_lavadora := Control.new()
	vista_lavadora.custom_minimum_size = Vector2(85, 85)
	vista_lavadora.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(vista_lavadora)

	# Cuerpo
	var cuerpo := TextureRect.new()
	cuerpo.custom_minimum_size = Vector2(85, 85)
	cuerpo.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	cuerpo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(datos["cuerpo_path"]):
		cuerpo.texture = load(datos["cuerpo_path"])
	cuerpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vista_lavadora.add_child(cuerpo)

	# Tambor — Sprite2D para poder rotar fácil
	var tambor := Sprite2D.new()
	if ResourceLoader.exists(datos["tambor_path"]):
		tambor.texture = load(datos["tambor_path"])
	# El cuerpo SVG es 128x128 originalmente, pero lo dibujamos a 85x85.
	# El offset del tambor está en coords del SVG (0-128), así que escalamos.
	var escala: float = 85.0 / 128.0
	var offset_svg: Vector2 = datos["tambor_offset"]
	tambor.position = offset_svg * escala
	# El tambor SVG es de 80x80 (160x160 viewport con coord 0,0 al centro),
	# así que se renderiza a tamaño nativo. Si es muy grande, escalamos.
	tambor.scale = Vector2(escala * 0.85, escala * 0.85)
	vista_lavadora.add_child(tambor)

	# === INFO LATERAL ===
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(vbox)

	var nombre_label := Label.new()
	nombre_label.text = datos["nombre"]
	nombre_label.add_theme_color_override("font_color", Color("#D0D0F0"))
	nombre_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(nombre_label)

	var label_estado := Label.new()
	label_estado.text = "Esperando asignación..."
	label_estado.add_theme_color_override("font_color", Color("#8888BB"))
	label_estado.add_theme_font_size_override("font_size", 10)
	vbox.add_child(label_estado)

	var barra := ProgressBar.new()
	barra.custom_minimum_size = Vector2(0, 10)
	barra.value = 0.0
	barra.show_percentage = false
	# Color de la barra acorde al tipo
	var barra_estilo := StyleBoxFlat.new()
	barra_estilo.bg_color = datos["color"]
	barra_estilo.set_corner_radius_all(2)
	barra.add_theme_stylebox_override("fill", barra_estilo)
	vbox.add_child(barra)

	lista_activas.add_child(card)

	lavadoras.append({
		"tipo": tipo,
		"ciclo_seg": float(datos["ciclo_seg"]),
		"acepta_alien": bool(datos["acepta_alien"]),
		"velocidad_giro": float(datos["velocidad_giro"]),
		"tiempo": 0.0,
		"prenda_actual": {},
		"card": card,
		"tambor": tambor,
		"barra": barra,
		"label_estado": label_estado,
	})


# ============================================================
# REFRESCO DE BOTONES (sin cambios respecto a v2)
# ============================================================
func _refrescar_botones() -> void:
	for tipo in TIPOS_LAVADORA.keys():
		var datos: Dictionary = TIPOS_LAVADORA[tipo]
		var boton: Button = botones_compra[tipo]
		var contador: int = contador_por_tipo[tipo]
		var max_unidades: int = int(datos["max_unidades"])
		var precio: int = int(datos["precio"])
		var ceniza_req: int = int(datos["ceniza"])

		if contador >= max_unidades:
			boton.text = "MÁX\n%d/%d" % [contador, max_unidades]
			boton.disabled = true
			_estilizar_boton(boton, true)
			continue

		var puede_pagar: bool = euros_actuales >= precio and ceniza_actual >= ceniza_req
		var texto: String = "%d€" % precio
		if ceniza_req > 0:
			texto += "\n+%d🜁" % ceniza_req
		if max_unidades > 1:
			texto += "\n(%d/%d)" % [contador, max_unidades]

		boton.text = texto
		boton.disabled = not puede_pagar
		_estilizar_boton(boton, false)


func _estilizar_boton(boton: Button, alcanzo_max: bool) -> void:
	var estilo_normal := StyleBoxFlat.new()
	var estilo_disabled := StyleBoxFlat.new()
	for s in [estilo_normal, estilo_disabled]:
		s.set_corner_radius_all(4)

	if alcanzo_max:
		estilo_normal.bg_color = Color("#2A4A2A")
		estilo_disabled.bg_color = Color("#2A4A2A")
		boton.add_theme_color_override("font_color", Color("#80C080"))
		boton.add_theme_color_override("font_disabled_color", Color("#80C080"))
	else:
		estilo_normal.bg_color = Color("#3A3A6A")
		estilo_disabled.bg_color = Color("#1A1A2A")
		boton.add_theme_color_override("font_color", Color("#FFAA00"))
		boton.add_theme_color_override("font_disabled_color", Color("#555577"))

	boton.add_theme_stylebox_override("normal", estilo_normal)
	boton.add_theme_stylebox_override("hover", estilo_normal)
	boton.add_theme_stylebox_override("pressed", estilo_normal)
	boton.add_theme_stylebox_override("disabled", estilo_disabled)
	boton.add_theme_font_size_override("font_size", 10)


func _on_boton_compra(tipo: String) -> void:
	var datos: Dictionary = TIPOS_LAVADORA[tipo]
	lavadora_compra_solicitada.emit(
		tipo,
		int(datos["precio"]),
		int(datos["ceniza"])
	)
