extends Panel
##
## FragmentShopPanel.gd — FASE 7
## ============================================================
## "Altar de Fragmentos": tercer panel de mejoras, permanentes, pagadas
## con la moneda narrativa (fragmentos).
##
## Estructura modelada sobre AshShopPanel pero con paleta púrpura y
## acentos narrativos. Su estado NUNCA se resetea en el prestigio.
##
## Señales:
##   upgrade_fragmento_solicitado(upgrade_id, coste) → Main valida y cobra
##

signal upgrade_fragmento_solicitado(upgrade_id: String, coste: int)

# ============================================================
# DATOS DE MEJORAS DEL ALTAR
# ============================================================
const UPGRADES_FRAGMENTO: Array[Dictionary] = [
	{
		"id": "eco_plasma",
		"nombre": "Eco del Plasma",
		"descripcion": "+1 fragmento extra al limpiar prendas alien. Acumulable.",
		"coste": 3,
		"max_compras": 3,
		"icono_color": Color("#AA40FF"),
	},
	{
		"id": "murmullo_vacio",
		"nombre": "Murmullo del Vacío",
		"descripcion": "+10% € en prendas alien. Acumulable.",
		"coste": 5,
		"max_compras": 4,
		"icono_color": Color("#4060FF"),
	},
	{
		"id": "compas_observador",
		"nombre": "Compás del Observador",
		"descripcion": "+2% probabilidad base de prendas alien.",
		"coste": 10,
		"max_compras": 1,
		"icono_color": Color("#00CCFF"),
	},
	{
		"id": "compresor_temporal",
		"nombre": "Compresor temporal",
		"descripcion": "Lavadora cuántica: -20% tiempo de ciclo.",
		"coste": 12,
		"max_compras": 1,
		"icono_color": Color("#FFAA40"),
	},
	{
		"id": "sudario_mensajero",
		"nombre": "Sudario del Mensajero",
		"descripcion": "Desbloquea una nueva prenda alien (100€, +4 frag).",
		"coste": 15,
		"max_compras": 1,
		"icono_color": Color("#AA80FF"),
	},
	{
		"id": "resonancia_ancestral",
		"nombre": "Resonancia ancestral",
		"descripcion": "Prestigio: +1 ceniza base adicional. Permanente.",
		"coste": 20,
		"max_compras": 1,
		"icono_color": Color("#FF8080"),
	},
	{
		"id": "velo_inicio",
		"nombre": "Velo del Inicio",
		"descripcion": "Desbloquea prenda alien legendaria (150€, +5 frag).",
		"coste": 30,
		"max_compras": 1,
		"icono_color": Color("#FFD0FF"),
	},
	{
		"id": "comunion",
		"nombre": "Comunión",
		"descripcion": "Limpieza manual de alien: 20% prob. de duplicar fragmentos.",
		"coste": 40,
		"max_compras": 1,
		"icono_color": Color("#FF40AA"),
	},
]

# ============================================================
# ESTADO INTERNO — permanente
# ============================================================
var fragmentos_actuales: int = 0
var compras_contador: Dictionary = {}

var items_container: VBoxContainer
var botones: Dictionary = {}
var labels_contador: Dictionary = {}


# ============================================================
# INICIALIZACIÓN
# ============================================================
func _ready() -> void:
	for u in UPGRADES_FRAGMENTO:
		compras_contador[u["id"]] = 0

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("#1A0E2A")
	estilo.border_color = Color("#5A2A8A")
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", estilo)

	_construir_estructura()
	_construir_cards()
	_refrescar_todo()


func _construir_estructura() -> void:
	var titulo := Label.new()
	titulo.text = "ALTAR DE FRAGMENTOS"
	titulo.position = Vector2(15, 10)
	titulo.size = Vector2(320, 30)
	titulo.add_theme_font_size_override("font_size", 18)
	titulo.add_theme_color_override("font_color", Color("#CC80FF"))
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(titulo)

	var subtitulo := Label.new()
	subtitulo.text = "Susurros entre las manchas alien"
	subtitulo.position = Vector2(15, 42)
	subtitulo.size = Vector2(320, 16)
	subtitulo.add_theme_font_size_override("font_size", 10)
	subtitulo.add_theme_color_override("font_color", Color("#8855AA"))
	subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(subtitulo)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10, 64)
	scroll.size = Vector2(330, 424)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	items_container = VBoxContainer.new()
	items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_container.add_theme_constant_override("separation", 8)
	scroll.add_child(items_container)


func _construir_cards() -> void:
	for upgrade in UPGRADES_FRAGMENTO:
		_crear_card(upgrade)


func _crear_card(upgrade: Dictionary) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 92)

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("#15081F")
	estilo.border_color = Color("#3A1A5A")
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

	var icono := ColorRect.new()
	icono.custom_minimum_size = Vector2(40, 40)
	icono.color = upgrade["icono_color"]
	icono.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(icono)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)

	var nombre := Label.new()
	nombre.text = upgrade["nombre"]
	nombre.add_theme_color_override("font_color", Color("#E0C0FF"))
	nombre.add_theme_font_size_override("font_size", 13)
	vbox.add_child(nombre)

	var desc := Label.new()
	desc.text = upgrade["descripcion"]
	desc.add_theme_color_override("font_color", Color("#9070BB"))
	desc.add_theme_font_size_override("font_size", 10)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc)

	var label_cnt := Label.new()
	label_cnt.text = "(0/%d)" % upgrade["max_compras"]
	label_cnt.add_theme_color_override("font_color", Color("#664488"))
	label_cnt.add_theme_font_size_override("font_size", 9)
	vbox.add_child(label_cnt)
	labels_contador[upgrade["id"]] = label_cnt

	var boton := Button.new()
	boton.text = "%d ✧" % upgrade["coste"]
	boton.custom_minimum_size = Vector2(72, 36)
	boton.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_estilizar_boton(boton, false)
	boton.pressed.connect(_on_boton_pressed.bind(upgrade["id"]))
	hbox.add_child(boton)

	items_container.add_child(card)
	botones[upgrade["id"]] = boton


# ============================================================
# API PÚBLICA
# ============================================================
func actualizar_fragmentos(nuevos_fragmentos: int) -> void:
	fragmentos_actuales = nuevos_fragmentos
	_refrescar_todo()


func confirmar_compra(upgrade_id: String) -> void:
	if not compras_contador.has(upgrade_id):
		return
	compras_contador[upgrade_id] += 1
	_flash_compra(upgrade_id)
	_refrescar_todo()


## [Fase 9] Tween de modulate sobre la card recién comprada.
func _flash_compra(upgrade_id: String) -> void:
	if not botones.has(upgrade_id):
		return
	var card: Node = botones[upgrade_id].get_parent().get_parent()
	if card == null or not is_instance_valid(card):
		return
	card.modulate = Color(1.6, 1.6, 1.6)
	var tw := create_tween()
	tw.tween_property(card, "modulate", Color.WHITE, 0.4)


func get_upgrade(upgrade_id: String) -> Dictionary:
	for u in UPGRADES_FRAGMENTO:
		if u["id"] == upgrade_id:
			return u
	return {}


## Cuántas veces se ha comprado una mejora dada. Útil para que Main calcule efectos acumulables.
func get_compras(upgrade_id: String) -> int:
	return int(compras_contador.get(upgrade_id, 0))


## [Debug F2] Reset total. Solo desde el panel de debug.
func reset_completo() -> void:
	for id in compras_contador.keys():
		compras_contador[id] = 0
	_refrescar_todo()


# ============================================================
# UI — REFRESCO
# ============================================================
func _refrescar_todo() -> void:
	for upgrade in UPGRADES_FRAGMENTO:
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

		var puede_pagar: bool = fragmentos_actuales >= upgrade["coste"]
		boton.text = "%d ✧" % upgrade["coste"]
		boton.disabled = not puede_pagar
		_estilizar_boton(boton, not puede_pagar)


func _estilizar_boton(boton: Button, deshabilitado: bool) -> void:
	var en := StyleBoxFlat.new()
	var di := StyleBoxFlat.new()
	en.set_corner_radius_all(4)
	di.set_corner_radius_all(4)

	if deshabilitado:
		en.bg_color = Color("#1A0E2A")
		di.bg_color = Color("#1A0E2A")
		boton.add_theme_color_override("font_color", Color("#664488"))
		boton.add_theme_color_override("font_disabled_color", Color("#664488"))
	else:
		en.bg_color = Color("#3A1A5A")
		di.bg_color = Color("#1A0E2A")
		boton.add_theme_color_override("font_color", Color("#E0C0FF"))
		boton.add_theme_color_override("font_disabled_color", Color("#664488"))

	boton.add_theme_stylebox_override("normal", en)
	boton.add_theme_stylebox_override("hover", en)
	boton.add_theme_stylebox_override("pressed", di)
	boton.add_theme_stylebox_override("disabled", di)
	boton.add_theme_font_size_override("font_size", 13)


func _estilizar_boton_maximo(boton: Button) -> void:
	var e := StyleBoxFlat.new()
	e.set_corner_radius_all(4)
	e.bg_color = Color("#4A2A6A")
	boton.add_theme_color_override("font_color", Color("#FFD0FF"))
	boton.add_theme_color_override("font_disabled_color", Color("#FFD0FF"))
	boton.add_theme_stylebox_override("normal", e)
	boton.add_theme_stylebox_override("disabled", e)
	boton.add_theme_font_size_override("font_size", 13)


# ============================================================
# CLICKS
# ============================================================
func _on_boton_pressed(upgrade_id: String) -> void:
	for u in UPGRADES_FRAGMENTO:
		if u["id"] == upgrade_id:
			upgrade_fragmento_solicitado.emit(upgrade_id, int(u["coste"]))
			return


# ============================================================
# FASE 7 — PERSISTENCIA
# ============================================================
func serializar() -> Dictionary:
	return {
		"compras_contador": compras_contador.duplicate(),
	}


func cargar_estado(data: Dictionary) -> void:
	for id in compras_contador.keys():
		compras_contador[id] = 0
	var dict: Dictionary = data.get("compras_contador", {})
	for id in dict.keys():
		var sid := String(id)
		if compras_contador.has(sid):
			compras_contador[sid] = int(dict[id])
	_refrescar_todo()
