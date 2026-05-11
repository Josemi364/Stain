extends Panel
##
## AshShopPanel.gd — FASE 5
## ============================================================
## Tienda de mejoras permanentes compradas con Ceniza.
## Su estado NUNCA se resetea en el prestigio.
##
## Señales:
##   upgrade_ceniza_solicitado(upgrade_id, coste) → Main valida y cobra
##

signal upgrade_ceniza_solicitado(upgrade_id: String, coste: int)

# ============================================================
# DATOS DE UPGRADES DE CENIZA
# ============================================================
const UPGRADES_CENIZA: Array[Dictionary] = [
	{
		"id": "multi_ganancias",
		"nombre": "Multiplicador de ganancias",
		"descripcion": "+5% a todos los euros ganados. Acumulable.",
		"coste": 1,
		"max_compras": 40,
		"icono_color": Color("#FFAA00"),
	},
	{
		"id": "alien_boost",
		"nombre": "Sensor alienígena",
		"descripcion": "+5% de probabilidad de prendas alien.",
		"coste": 5,
		"max_compras": 3,
		"icono_color": Color("#AA40FF"),
	},
	{
		"id": "velocidad_cola",
		"nombre": "Cola rápida",
		"descripcion": "Las prendas llegan un 25% más rápido a la cola.",
		"coste": 2,
		"max_compras": 1,
		"icono_color": Color("#40D0FF"),
	},
	{
		"id": "memoria_prendas",
		"nombre": "Memoria de prendas",
		"descripcion": "Las lavadoras básica e industrial también aceptan prendas alien.",
		"coste": 10,
		"max_compras": 1,
		"icono_color": Color("#40FF80"),
	},
]

# ============================================================
# ESTADO INTERNO — permanente, nunca se resetea
# ============================================================
var ceniza_actual: int = 0
var compras_contador: Dictionary = {}   # id → nº de veces comprado

var items_container: VBoxContainer
var botones: Dictionary = {}
var labels_contador: Dictionary = {}
var label_mult_actual: Label


# ============================================================
# INICIALIZACIÓN
# ============================================================
func _ready() -> void:
	for u in UPGRADES_CENIZA:
		compras_contador[u["id"]] = 0

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("#12122A")
	estilo.border_color = Color("#444444")
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", estilo)

	_construir_estructura()
	_construir_cards()
	_refrescar_todo()


func _construir_estructura() -> void:
	var titulo := Label.new()
	titulo.text = "TIENDA DE CENIZA"
	titulo.position = Vector2(15, 10)
	titulo.size = Vector2(320, 30)
	titulo.add_theme_font_size_override("font_size", 20)
	titulo.add_theme_color_override("font_color", Color("#888888"))
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(titulo)

	# Muestra el multiplicador activo para que el jugador sepa cuánto tiene
	label_mult_actual = Label.new()
	label_mult_actual.text = "Mult. actual: ×1.00"
	label_mult_actual.position = Vector2(15, 42)
	label_mult_actual.size = Vector2(320, 20)
	label_mult_actual.add_theme_font_size_override("font_size", 11)
	label_mult_actual.add_theme_color_override("font_color", Color("#FFAA00"))
	label_mult_actual.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label_mult_actual)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10, 68)
	scroll.size = Vector2(330, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	items_container = VBoxContainer.new()
	items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_container.add_theme_constant_override("separation", 8)
	scroll.add_child(items_container)


func _construir_cards() -> void:
	for upgrade in UPGRADES_CENIZA:
		_crear_card(upgrade)


func _crear_card(upgrade: Dictionary) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 90)

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("#0D0D1A")
	estilo.border_color = Color("#333355")
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(6)
	estilo.content_margin_left = 10
	estilo.content_margin_right = 10
	estilo.content_margin_top = 8
	estilo.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", estilo)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)

	# Icono de color
	var icono := ColorRect.new()
	icono.custom_minimum_size = Vector2(40, 40)
	icono.color = upgrade["icono_color"]
	icono.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(icono)

	# Textos
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)

	var nombre := Label.new()
	nombre.text = upgrade["nombre"]
	nombre.add_theme_color_override("font_color", Color("#D0D0F0"))
	nombre.add_theme_font_size_override("font_size", 13)
	vbox.add_child(nombre)

	var desc := Label.new()
	desc.text = upgrade["descripcion"]
	desc.add_theme_color_override("font_color", Color("#8888BB"))
	desc.add_theme_font_size_override("font_size", 10)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc)

	var label_cnt := Label.new()
	label_cnt.text = "(0/%d)" % upgrade["max_compras"]
	label_cnt.add_theme_color_override("font_color", Color("#555577"))
	label_cnt.add_theme_font_size_override("font_size", 9)
	vbox.add_child(label_cnt)
	labels_contador[upgrade["id"]] = label_cnt

	# Botón de compra
	var boton := Button.new()
	boton.text = "%d 🜁" % upgrade["coste"]
	boton.custom_minimum_size = Vector2(68, 36)
	boton.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_estilizar_boton(boton, false)
	boton.pressed.connect(_on_boton_pressed.bind(upgrade["id"]))
	hbox.add_child(boton)

	items_container.add_child(card)
	botones[upgrade["id"]] = boton


# ============================================================
# API PÚBLICA
# ============================================================

## Main llama esto cuando cambia la Ceniza disponible.
func actualizar_ceniza(nueva_ceniza: int) -> void:
	ceniza_actual = nueva_ceniza
	_refrescar_todo()


## Main llama esto cuando confirma que se compró la mejora.
func confirmar_compra(upgrade_id: String) -> void:
	compras_contador[upgrade_id] += 1
	_refrescar_todo()


## Llamado vía señal prestige_realizado: la tienda no resetea nada,
## pero refresca la UI para reflejar el nuevo saldo de Ceniza.
func on_prestige_realizado() -> void:
	_refrescar_todo()


## [Debug F2] Reset total: borra todas las compras permanentes.
## Solo debe llamarse desde el panel de debug.
func reset_completo() -> void:
	for id in compras_contador.keys():
		compras_contador[id] = 0
	_refrescar_todo()


# ============================================================
# UI — REFRESCO
# ============================================================
func _refrescar_todo() -> void:
	# Actualizar label del multiplicador activo
	var n_multi: int = compras_contador.get("multi_ganancias", 0)
	var mult: float = min(1.0 + n_multi * 0.05, 3.0)
	label_mult_actual.text = "Mult. actual: ×%.2f" % mult

	for upgrade in UPGRADES_CENIZA:
		var id: String = upgrade["id"]
		var boton: Button = botones[id]
		var label_cnt: Label = labels_contador[id]
		var cnt: int = compras_contador.get(id, 0)
		var max_c: int = upgrade["max_compras"]

		label_cnt.text = "(%d/%d)" % [cnt, max_c]

		if cnt >= max_c:
			boton.text = "✓"
			boton.disabled = true
			_estilizar_boton_maximo(boton)
			continue

		var puede_pagar: bool = ceniza_actual >= upgrade["coste"]
		boton.text = "%d 🜁" % upgrade["coste"]
		boton.disabled = not puede_pagar
		_estilizar_boton(boton, not puede_pagar)


func _estilizar_boton(boton: Button, deshabilitado: bool) -> void:
	var en := StyleBoxFlat.new()
	var di := StyleBoxFlat.new()
	en.set_corner_radius_all(4)
	di.set_corner_radius_all(4)

	if deshabilitado:
		en.bg_color = Color("#1A1A2A")
		di.bg_color = Color("#1A1A2A")
		boton.add_theme_color_override("font_color", Color("#555577"))
		boton.add_theme_color_override("font_disabled_color", Color("#555577"))
	else:
		en.bg_color = Color("#3A3A3A")
		di.bg_color = Color("#1A1A1A")
		boton.add_theme_color_override("font_color", Color("#888888"))
		boton.add_theme_color_override("font_disabled_color", Color("#444444"))

	boton.add_theme_stylebox_override("normal", en)
	boton.add_theme_stylebox_override("hover", en)
	boton.add_theme_stylebox_override("pressed", di)
	boton.add_theme_stylebox_override("disabled", di)
	boton.add_theme_font_size_override("font_size", 13)


func _estilizar_boton_maximo(boton: Button) -> void:
	var e := StyleBoxFlat.new()
	e.set_corner_radius_all(4)
	e.bg_color = Color("#2A4A2A")
	boton.add_theme_color_override("font_color", Color("#40FF80"))
	boton.add_theme_color_override("font_disabled_color", Color("#40FF80"))
	boton.add_theme_stylebox_override("normal", e)
	boton.add_theme_stylebox_override("disabled", e)
	boton.add_theme_font_size_override("font_size", 13)


# ============================================================
# CLICKS
# ============================================================
func _on_boton_pressed(upgrade_id: String) -> void:
	for u in UPGRADES_CENIZA:
		if u["id"] == upgrade_id:
			upgrade_ceniza_solicitado.emit(upgrade_id, int(u["coste"]))
			return
