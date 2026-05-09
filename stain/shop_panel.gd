extends Panel
##
## ShopPanel.gd — FASE 3
## ============================================================
## Tienda de mejoras. Muestra una lista de upgrades comprables.
##
## Estructura de nodos necesaria:
##   ShopPanel (Panel) ← este script
##   ├── Titulo (Label)
##   └── ScrollContainer (ScrollContainer)
##       └── ItemsContainer (VBoxContainer)
##
## Las cards de cada upgrade se generan por código.
##
## Señales:
##   upgrade_solicitado(upgrade_id: String, precio: int)
##     → Main escucha y decide si puede pagarse
##

signal upgrade_solicitado(upgrade_id: String, precio: int)

# ============================================================
# DATOS DE UPGRADES
# ============================================================
const UPGRADES: Array[Dictionary] = [
	{
		"id": "detergente_basico",
		"nombre": "Detergente",
		"descripcion": "Aumenta la fuerza de borrado (+0.10).",
		"precio": 12,
		"requiere": "",
		"efecto": {"tipo": "fuerza_plus", "valor": 0.10},
		"icono_color": Color("#40A0FF"),
	},
	{
		"id": "cepillo",
		"nombre": "Cepillo",
		"descripcion": "Aumenta el radio del cursor (+6 px).",
		"precio": 25,
		"requiere": "",
		"efecto": {"tipo": "radio_plus", "valor": 6},
		"icono_color": Color("#FFAA40"),
	},
	{
		"id": "vista_aguda_1",
		"nombre": "Vista aguda I",
		"descripcion": "+1.5% probabilidad prendas alien.",
		"precio": 40,
		"requiere": "",
		"efecto": {"tipo": "suerte", "valor": 0.015},
		"icono_color": Color("#AA40FF"),
	},
	{
		"id": "detergente_industrial",
		"nombre": "Detergente industrial",
		"descripcion": "Más fuerza de borrado (+0.15).",
		"precio": 60,
		"requiere": "detergente_basico",
		"efecto": {"tipo": "fuerza_plus", "valor": 0.15},
		"icono_color": Color("#4080FF"),
	},
	{
		"id": "cepillo_pro",
		"nombre": "Cepillo profesional",
		"descripcion": "Radio del cursor mucho mayor (+6 px más).",
		"precio": 80,
		"requiere": "cepillo",
		"efecto": {"tipo": "radio_plus", "valor": 6},
		"icono_color": Color("#FF8020"),
	},
	{
		"id": "vista_aguda_2",
		"nombre": "Vista aguda II",
		"descripcion": "+2% probabilidad prendas alien.",
		"precio": 100,
		"requiere": "vista_aguda_1",
		"efecto": {"tipo": "suerte", "valor": 0.02},
		"icono_color": Color("#CC60FF"),
	},
]

# ============================================================
# ESTADO INTERNO
# ============================================================
var euros_actuales: float = 0.0
var upgrades_comprados: Array[String] = []  # IDs de los comprados

# Referencias a las cards (para refrescar su estado)
var cards: Dictionary = {}  # upgrade_id → Panel del card
var botones: Dictionary = {}  # upgrade_id → Button


# ============================================================
# REFERENCIAS A NODOS
# ============================================================
# El items_container se construye en _ready() — no usamos @onready
# para evitar problemas si los hijos no existen en la escena.
var items_container: VBoxContainer
var titulo_label: Label


# ============================================================
# INICIALIZACIÓN
# ============================================================
func _ready() -> void:
	# Estilo del panel general
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("#12122A")
	estilo.border_color = Color("#2A2A4A")
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", estilo)

	# Construimos la estructura interna por código
	# (así funciona aunque no tengas los hijos creados a mano)
	_construir_estructura_interna()

	# Crear todas las cards
	for upgrade in UPGRADES:
		_crear_card(upgrade)

	_refrescar_todo()


## Crea Titulo + ScrollContainer + ItemsContainer si no existen.
func _construir_estructura_interna() -> void:
	# Si ya hay un Titulo en la escena, lo usamos; si no, lo creamos
	if has_node("Titulo"):
		titulo_label = get_node("Titulo")
	else:
		titulo_label = Label.new()
		titulo_label.name = "Titulo"
		titulo_label.text = "TIENDA"
		titulo_label.position = Vector2(15, 10)
		titulo_label.size = Vector2(320, 30)
		titulo_label.add_theme_font_size_override("font_size", 22)
		titulo_label.add_theme_color_override("font_color", Color("#6060FF"))
		titulo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(titulo_label)

	# ScrollContainer
	var scroll: ScrollContainer
	if has_node("ScrollContainer"):
		scroll = get_node("ScrollContainer")
	else:
		scroll = ScrollContainer.new()
		scroll.name = "ScrollContainer"
		scroll.position = Vector2(10, 50)
		scroll.size = Vector2(330, 440)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		add_child(scroll)

	# ItemsContainer dentro del scroll
	if scroll.has_node("ItemsContainer"):
		items_container = scroll.get_node("ItemsContainer")
	else:
		items_container = VBoxContainer.new()
		items_container.name = "ItemsContainer"
		items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		items_container.add_theme_constant_override("separation", 8)
		scroll.add_child(items_container)


# ============================================================
# API PÚBLICA — la usa Main.gd
# ============================================================

## Main avisa cuántos euros hay para que se actualice la disponibilidad
## de los botones (habilitados/deshabilitados según pueda pagar).
func actualizar_euros(euros: float) -> void:
	euros_actuales = euros
	_refrescar_todo()


## Main confirma que el upgrade se compró correctamente.
## Lo añadimos a la lista de comprados y refrescamos el visual.
func confirmar_compra(upgrade_id: String) -> void:
	if upgrade_id in upgrades_comprados:
		return
	upgrades_comprados.append(upgrade_id)
	_refrescar_todo()


## Devuelve los datos completos de un upgrade por su ID.
func get_upgrade(upgrade_id: String) -> Dictionary:
	for u in UPGRADES:
		if u["id"] == upgrade_id:
			return u
	return {}


# ============================================================
# UI — CREACIÓN DE CARDS
# ============================================================
func _crear_card(upgrade: Dictionary) -> void:
	# PanelContainer externo (la "card")
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 90)

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("#0D0D1A")
	estilo.border_color = Color("#2A2A4A")
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(6)
	estilo.content_margin_left = 10
	estilo.content_margin_right = 10
	estilo.content_margin_top = 8
	estilo.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", estilo)

	# Layout horizontal: icono | textos | botón
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)

	# Icono coloreado
	var icono := ColorRect.new()
	icono.custom_minimum_size = Vector2(40, 40)
	icono.color = upgrade["icono_color"]
	icono.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(icono)

	# VBox con nombre + descripción
	var textos_vbox := VBoxContainer.new()
	textos_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textos_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(textos_vbox)

	var nombre_label := Label.new()
	nombre_label.text = upgrade["nombre"]
	nombre_label.add_theme_color_override("font_color", Color("#D0D0F0"))
	nombre_label.add_theme_font_size_override("font_size", 14)
	textos_vbox.add_child(nombre_label)

	var desc_label := Label.new()
	desc_label.text = upgrade["descripcion"]
	desc_label.add_theme_color_override("font_color", Color("#8888BB"))
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textos_vbox.add_child(desc_label)

	# Botón de compra
	var boton := Button.new()
	boton.text = "%d€" % upgrade["precio"]
	boton.custom_minimum_size = Vector2(70, 36)
	boton.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_estilizar_boton(boton, false)
	boton.pressed.connect(_on_boton_pressed.bind(upgrade["id"]))
	hbox.add_child(boton)

	# Lo añadimos al contenedor y guardamos referencias
	items_container.add_child(card)
	cards[upgrade["id"]] = card
	botones[upgrade["id"]] = boton


## Aplica el estilo del botón. Si comprado, verde; si no, neutro.
func _estilizar_boton(boton: Button, comprado: bool) -> void:
	var estilo_normal := StyleBoxFlat.new()
	var estilo_disabled := StyleBoxFlat.new()
	for s in [estilo_normal, estilo_disabled]:
		s.set_corner_radius_all(4)

	if comprado:
		estilo_normal.bg_color = Color("#40FF80")
		estilo_disabled.bg_color = Color("#40FF80")
		boton.add_theme_color_override("font_color", Color("#0D0D1A"))
		boton.add_theme_color_override("font_disabled_color", Color("#0D0D1A"))
	else:
		estilo_normal.bg_color = Color("#3A3A6A")
		estilo_disabled.bg_color = Color("#1A1A2A")
		boton.add_theme_color_override("font_color", Color("#FFAA00"))
		boton.add_theme_color_override("font_disabled_color", Color("#555577"))

	boton.add_theme_stylebox_override("normal", estilo_normal)
	boton.add_theme_stylebox_override("hover", estilo_normal)
	boton.add_theme_stylebox_override("pressed", estilo_normal)
	boton.add_theme_stylebox_override("disabled", estilo_disabled)
	boton.add_theme_font_size_override("font_size", 13)


# ============================================================
# UI — REFRESCO DE ESTADO
# ============================================================
func _refrescar_todo() -> void:
	for upgrade in UPGRADES:
		_refrescar_card(upgrade)


func _refrescar_card(upgrade: Dictionary) -> void:
	var id: String = upgrade["id"]
	var boton: Button = botones[id]
	var comprado: bool = id in upgrades_comprados

	if comprado:
		boton.text = "✓"
		boton.disabled = true
		_estilizar_boton(boton, true)
		return

	# Comprobar si el prerrequisito está cumplido
	var requiere: String = upgrade["requiere"]
	var prereq_ok: bool = requiere == "" or requiere in upgrades_comprados

	# Comprobar si puede pagarse
	var puede_pagar: bool = euros_actuales >= upgrade["precio"]

	if not prereq_ok:
		boton.text = "🔒"
		boton.disabled = true
	elif not puede_pagar:
		boton.text = "%d€" % upgrade["precio"]
		boton.disabled = true
	else:
		boton.text = "%d€" % upgrade["precio"]
		boton.disabled = false

	_estilizar_boton(boton, false)


# ============================================================
# CLICKS
# ============================================================
func _on_boton_pressed(upgrade_id: String) -> void:
	var datos: Dictionary = get_upgrade(upgrade_id)
	if datos.is_empty():
		return
	# Emitimos a Main, que decide si cobra y aplica
	upgrade_solicitado.emit(upgrade_id, int(datos["precio"]))
