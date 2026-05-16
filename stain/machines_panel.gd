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
		"descripcion": "Procesa prendas normales.",
		"precio": 75,
		"ceniza": 0,
		"ciclo_seg": 20.0,
		"acepta_alien": false,
		"max_unidades": 3,
		"color": Color("#4080CC"),
		"cuerpo_path": "res://assets/lavadoras/basica_cuerpo.svg",
		"tambor_path": "res://assets/lavadoras/basica_tambor.svg",
		"tambor_offset": Vector2(64, 72),
		"velocidad_giro": 4.0,
	},
	"industrial": {
		"nombre": "Lavadora industrial",
		"descripcion": "Más rápida. Solo prendas normales.",
		"precio": 350,
		"ceniza": 3,
		"ciclo_seg": 15.0,
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
		"precio": 1200,
		"ceniza": 12,
		"ciclo_seg": 12.0,
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
# Cuando es true, todas las lavadoras aceptan prendas alien (mejora de Ceniza)
var memoria_prendas: bool = false
# Reducción del ciclo de la lavadora cuántica (0..0.9). Lo aplica el altar de fragmentos.
var bonus_reduccion_ciclo_cuantica: float = 0.0
# Fase 15: reducción global aplicada a TODAS las lavadoras (bendición tiempo_lento).
var bonus_reduccion_global: float = 0.0
# Fase 17: reducción del aliado relojero (apila multiplicativo con global).
var bonus_reduccion_aliados: float = 0.0
# Fase 18: bonus de capacidad para la lavadora básica (mejora "cuna_abierta")
var bonus_max_basica: int = 0
# Fase 10: multiplicador temporal de velocidad para Pulso cuántico (no persiste)
var mult_velocidad_evento: float = 1.0

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
		# Con memoria_prendas activa todas las lavadoras aceptan alien
		if es_alien and not lav["acepta_alien"] and not memoria_prendas:
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
			# Fase 23: card sin prenda vuelve a su posición base
			var card_idle: Control = lav["card"] as Control
			if card_idle != null:
				card_idle.position = Vector2.ZERO
			continue

		lav["tiempo"] += delta * mult_velocidad_evento
		var pct: float = clamp(lav["tiempo"] / lav["ciclo_seg"], 0.0, 1.0)
		lav["barra"].value = pct * 100.0

		var nombre_corto: String = String(lav["prenda_actual"].get("nombre", "?")).split(" ")[0]
		lav["label_estado"].text = "Lavando: %s" % nombre_corto

		# Hacer girar el sprite del tambor
		lav["tambor"].rotation += delta * lav["velocidad_giro"]

		# Fase 23: vibración sutil de la card mientras lava (más intensa al final)
		var card: Control = lav["card"] as Control
		if card != null:
			var intensidad: float = 0.6 + (1.5 if pct > 0.85 else 0.0)
			card.position = Vector2(
				randf_range(-intensidad, intensidad),
				randf_range(-intensidad, intensidad),
			)

		if lav["tiempo"] >= lav["ciclo_seg"]:
			var prenda: Dictionary = lav["prenda_actual"]
			var recompensa: float = float(prenda.get("recompensa", 0.0))
			var es_cuantica: bool = (lav["tipo"] == "cuantica")
			prenda_procesada.emit(prenda, recompensa, es_cuantica)
			_flash_card(lav["card"])
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

	# Aplica el bonus de velocidad cuántica solo a la cuántica
	var ciclo_real: float = float(datos["ciclo_seg"])
	if tipo == "cuantica" and bonus_reduccion_ciclo_cuantica > 0.0:
		ciclo_real *= (1.0 - bonus_reduccion_ciclo_cuantica)
	# Fase 15: reducción global de la bendición tiempo_lento (apila multiplicativo)
	if bonus_reduccion_global > 0.0:
		ciclo_real *= (1.0 - bonus_reduccion_global)
	# Fase 17: reducción del aliado relojero (apila también)
	if bonus_reduccion_aliados > 0.0:
		ciclo_real *= (1.0 - bonus_reduccion_aliados)

	lavadoras.append({
		"tipo": tipo,
		"ciclo_seg": ciclo_real,
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
		# Fase 18: bonus de capacidad por mejora "cuna_abierta"
		if tipo == "basica":
			max_unidades += bonus_max_basica
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


# ============================================================
# PRESTIGIO
# ============================================================

## API canónica: destruye todas las lavadoras activas y reinicia contadores.
## Llamada por prestige_realizado y por el debug F2.
func reset_lavadoras() -> void:
	for lav in lavadoras:
		if lav.has("card") and is_instance_valid(lav["card"]):
			lav["card"].queue_free()
	lavadoras.clear()
	contador_por_tipo = {"basica": 0, "industrial": 0, "cuantica": 0}
	memoria_prendas = false
	_refrescar_botones()


## Compatibilidad con señal prestige_realizado (delega a reset_lavadoras).
func reset_para_prestigio() -> void:
	reset_lavadoras()


## [Fase 15/17] Recalcula el ciclo de TODAS las lavadoras existentes aplicando los
## bonus actuales (cuántica + global de bendición + aliado relojero). Mantiene el
## progreso parcial.
func _recalcular_ciclos_lavadoras() -> void:
	for lav in lavadoras:
		var tipo: String = String(lav["tipo"])
		var datos: Dictionary = TIPOS_LAVADORA[tipo]
		var nuevo_ciclo: float = float(datos["ciclo_seg"])
		if tipo == "cuantica" and bonus_reduccion_ciclo_cuantica > 0.0:
			nuevo_ciclo *= (1.0 - bonus_reduccion_ciclo_cuantica)
		if bonus_reduccion_global > 0.0:
			nuevo_ciclo *= (1.0 - bonus_reduccion_global)
		if bonus_reduccion_aliados > 0.0:
			nuevo_ciclo *= (1.0 - bonus_reduccion_aliados)
		var pct: float = (lav["tiempo"] / lav["ciclo_seg"]) if lav["ciclo_seg"] > 0.0 else 0.0
		lav["ciclo_seg"] = nuevo_ciclo
		lav["tiempo"] = pct * nuevo_ciclo


## [Fase 15] Setter para bonus_reduccion_global con reaplicación inmediata.
func aplicar_bonus_velocidad_global(reduccion: float) -> void:
	bonus_reduccion_global = clamp(reduccion, 0.0, 0.9)
	_recalcular_ciclos_lavadoras()


## [Fase 17] Setter para bonus_reduccion_aliados con reaplicación inmediata.
func aplicar_bonus_velocidad_aliados(reduccion: float) -> void:
	bonus_reduccion_aliados = clamp(reduccion, 0.0, 0.9)
	_recalcular_ciclos_lavadoras()


## [Fase 12] Calcula cuántos ciclos completarían las lavadoras activas en N segundos.
## Asume que la cola tiene siempre prendas (FIFO infinita) y que cada ciclo procesa
## una prenda independientemente del progreso parcial guardado (aproximación).
func contar_ciclos_offline(segundos: float) -> int:
	if segundos <= 0.0 or lavadoras.is_empty():
		return 0
	var total: int = 0
	for lav in lavadoras:
		var ciclo: float = float(lav.get("ciclo_seg", 20.0))
		if ciclo <= 0.0:
			continue
		total += int(floor(segundos / ciclo))
	return total


## [Debug F4] Completa instantáneamente todos los ciclos activos y emite sus recompensas.
func completar_todos_los_ciclos() -> void:
	for lav in lavadoras:
		if lav["prenda_actual"].is_empty():
			continue
		var prenda: Dictionary = lav["prenda_actual"]
		var recompensa: float = float(prenda.get("recompensa", 0.0))
		var es_cuantica: bool = (lav["tipo"] == "cuantica")
		prenda_procesada.emit(prenda, recompensa, es_cuantica)
		lav["prenda_actual"] = {}
		lav["tiempo"] = 0.0
		lav["barra"].value = 0.0
		lav["label_estado"].text = "Esperando asignación..."


## Activa que todas las lavadoras acepten prendas alien (mejora permanente de Ceniza).
func activar_memoria_prendas() -> void:
	memoria_prendas = true


## [Fase 9] Flash de la card al completar un ciclo.
func _flash_card(card: PanelContainer) -> void:
	if card == null or not is_instance_valid(card):
		return
	card.modulate = Color(1.7, 1.7, 1.7)
	var tw := create_tween()
	tw.tween_property(card, "modulate", Color.WHITE, 0.45)


## [Fase 7] Aplica una reducción del ciclo (0..0.9) a la lavadora cuántica.
## También actualiza las cuánticas ya existentes para que el bonus sea retroactivo.
func aplicar_bonus_velocidad_cuantica(reduccion: float) -> void:
	bonus_reduccion_ciclo_cuantica = clamp(reduccion, 0.0, 0.9)
	var base: float = float(TIPOS_LAVADORA["cuantica"]["ciclo_seg"])
	var nuevo_ciclo: float = base * (1.0 - bonus_reduccion_ciclo_cuantica)
	for lav in lavadoras:
		if lav["tipo"] == "cuantica":
			# Re-escalamos el tiempo transcurrido para no perder progreso visible
			var pct: float = (lav["tiempo"] / lav["ciclo_seg"]) if lav["ciclo_seg"] > 0.0 else 0.0
			lav["ciclo_seg"] = nuevo_ciclo
			lav["tiempo"] = pct * nuevo_ciclo


# ============================================================
# FASE 6 — PERSISTENCIA (extendido en Fase 7)
# ============================================================
func serializar() -> Dictionary:
	var lavs: Array = []
	for lav in lavadoras:
		var prenda: Dictionary = lav["prenda_actual"]
		lavs.append({
			"tipo": lav["tipo"],
			"tiempo": float(lav["tiempo"]),
			"prenda_id": String(prenda.get("id", "")) if not prenda.is_empty() else "",
		})
	return {
		"memoria_prendas": memoria_prendas,
		"bonus_reduccion_ciclo_cuantica": bonus_reduccion_ciclo_cuantica,
		"bonus_reduccion_global": bonus_reduccion_global,
		"bonus_reduccion_aliados": bonus_reduccion_aliados,
		"bonus_max_basica": bonus_max_basica,
		"lavadoras": lavs,
	}


func cargar_estado(data: Dictionary) -> void:
	reset_lavadoras()
	memoria_prendas = bool(data.get("memoria_prendas", false))
	# Aplicar los bonus ANTES de crear las lavadoras para que se creen con el ciclo correcto
	bonus_reduccion_ciclo_cuantica = float(data.get("bonus_reduccion_ciclo_cuantica", 0.0))
	bonus_reduccion_global = float(data.get("bonus_reduccion_global", 0.0))
	bonus_reduccion_aliados = float(data.get("bonus_reduccion_aliados", 0.0))
	bonus_max_basica = int(data.get("bonus_max_basica", 0))
	var lavs: Array = data.get("lavadoras", [])
	for entry_v in lavs:
		var entry: Dictionary = entry_v
		var tipo: String = String(entry.get("tipo", ""))
		if not TIPOS_LAVADORA.has(tipo):
			continue
		var cap: int = int(TIPOS_LAVADORA[tipo]["max_unidades"])
		if tipo == "basica":
			cap += bonus_max_basica
		if contador_por_tipo[tipo] >= cap:
			continue
		contador_por_tipo[tipo] += 1
		_crear_lavadora_activa(tipo)
		var lav: Dictionary = lavadoras[lavadoras.size() - 1]
		var prenda_id: String = String(entry.get("prenda_id", ""))
		if prenda_id != "":
			var prenda: Dictionary = GarmentData.get_prenda_por_id(prenda_id)
			if not prenda.is_empty():
				lav["prenda_actual"] = prenda
				lav["tiempo"] = clamp(float(entry.get("tiempo", 0.0)), 0.0, lav["ciclo_seg"])
				lav["barra"].value = (lav["tiempo"] / lav["ciclo_seg"]) * 100.0
	_refrescar_botones()
