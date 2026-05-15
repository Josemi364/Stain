extends Control
##
## SinkArea.gd — FASE 4 + ASSETS PRO
## ============================================================
## Sistema de manchas con PERSONALIDAD: cada tipo de mancha
## tiene su propio perfil (chorretones, salpicaduras, halos,
## bordes irregulares, glow...).
##
## Mantiene: auto-completar al 80%, FIFO, sin bonus.
##

# === Configuración ===
const TEX_SIZE: int = 256
const RADIO_FROTADO: int = 14
const FUERZA_BORRADO: float = 0.12
const UMBRAL_ENTREGA: float = 0.80
const FRAMES_ENTRE_MEDICIONES: int = 5

const SPONGE_PATH: String = "res://assets/cursor/esponja.svg"

# ============================================================
# PERFILES DE MANCHA
# ============================================================
# Cada perfil define cómo se pinta una mancha de ese tipo.
# Si no hay perfil para un tipo concreto, se usa "default".
const PERFILES_MANCHA: Dictionary = {
	"Café": {
		"num_blobs": 2,
		"radio_min": 25,
		"radio_max": 38,
		"borde_irregular": 0.35,        # cuánto se desvía el borde del círculo
		"halo": true,                   # halo más claro alrededor
		"chorretones": 3,               # nº de chorros verticales
		"chorreton_largo": 70,
		"salpicaduras": 4,              # gotitas pequeñas alrededor
		"variacion_color": 0.15,
	},
	"Vino tinto": {
		"num_blobs": 2,
		"radio_min": 28,
		"radio_max": 42,
		"borde_irregular": 0.4,
		"halo": true,
		"chorretones": 2,
		"chorreton_largo": 60,
		"salpicaduras": 8,
		"variacion_color": 0.2,
	},
	"Barro": {
		"num_blobs": 4,
		"radio_min": 18,
		"radio_max": 32,
		"borde_irregular": 0.55,        # muy irregular, grumoso
		"halo": false,
		"chorretones": 0,                # el barro no chorrea
		"chorreton_largo": 0,
		"salpicaduras": 12,             # muchos terrones pequeños
		"variacion_color": 0.25,
	},
	"Ketchup": {
		"num_blobs": 3,
		"radio_min": 22,
		"radio_max": 32,
		"borde_irregular": 0.3,
		"halo": false,
		"chorretones": 1,
		"chorreton_largo": 35,
		"salpicaduras": 6,
		"variacion_color": 0.1,
	},
	"Aceite de motor": {
		"num_blobs": 2,
		"radio_min": 30,
		"radio_max": 45,
		"borde_irregular": 0.2,         # bordes lisos, el aceite se extiende
		"halo": true,
		"chorretones": 4,                # chorrea mucho
		"chorreton_largo": 90,
		"salpicaduras": 3,
		"variacion_color": 0.05,
	},
	"Sangre": {
		"num_blobs": 3,
		"radio_min": 20,
		"radio_max": 35,
		"borde_irregular": 0.45,
		"halo": false,
		"chorretones": 2,
		"chorreton_largo": 50,
		"salpicaduras": 10,             # muchas salpicaduras pequeñas
		"variacion_color": 0.15,
	},
	# === ALIENÍGENAS — más dramáticas ===
	"Plasma interestelar": {
		"num_blobs": 2,
		"radio_min": 30,
		"radio_max": 45,
		"borde_irregular": 0.5,
		"halo": true,
		"chorretones": 0,
		"chorreton_largo": 0,
		"salpicaduras": 14,             # estrellas alrededor
		"variacion_color": 0.3,
	},
	"Materia oscura": {
		"num_blobs": 3,
		"radio_min": 25,
		"radio_max": 40,
		"borde_irregular": 0.6,
		"halo": false,
		"chorretones": 1,
		"chorreton_largo": 40,
		"salpicaduras": 6,
		"variacion_color": 0.4,
	},
	"Cronofluido": {
		"num_blobs": 2,
		"radio_min": 28,
		"radio_max": 42,
		"borde_irregular": 0.3,
		"halo": true,
		"chorretones": 5,                # chorrea hacia ARRIBA y abajo (lo veremos)
		"chorreton_largo": 55,
		"salpicaduras": 8,
		"variacion_color": 0.2,
	},
	"¿Sangre humana?": {
		"num_blobs": 4,
		"radio_min": 22,
		"radio_max": 38,
		"borde_irregular": 0.5,
		"halo": false,
		"chorretones": 3,
		"chorreton_largo": 65,
		"salpicaduras": 12,
		"variacion_color": 0.2,
	},
	"default": {
		"num_blobs": 3,
		"radio_min": 22,
		"radio_max": 38,
		"borde_irregular": 0.4,
		"halo": false,
		"chorretones": 2,
		"chorreton_largo": 45,
		"salpicaduras": 6,
		"variacion_color": 0.15,
	},
}

# === Referencias a nodos hijos ===
@onready var garment_image: TextureRect = $GarmentImage
@onready var stain_texture: TextureRect = $StainTexture
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var deliver_button: Button = $DeliverButton
@onready var info_label: Label = $InfoLabel

var sponge_sprite: Sprite2D
var foam_particles: CPUParticles2D

# === Estado interno ===
var stain_image: Image
var stain_image_texture: ImageTexture
var prenda_actual: Dictionary = {}
var pixeles_mancha_total: int = 0
var pixeles_mancha_actual: int = 0
var clean_pct: float = 0.0
var frotando: bool = false
var contador_eventos: int = 0
var tiene_prenda: bool = false
var ya_autocompletado: bool = false
var _scrub_sfx_cooldown: float = 0.0

var bonus_fuerza: float = 0.0
var bonus_radio: int = 0
# Fase 10: bonus temporal de evento (no se persiste)
var bonus_fuerza_evento: float = 0.0

signal garment_delivered(garment: Dictionary, earned: float)


func _ready() -> void:
	deliver_button.pressed.connect(_on_deliver_pressed)
	deliver_button.disabled = true
	deliver_button.tooltip_text = "Atajo: ESPACIO"
	tooltip_text = "Frota con el ratón para limpiar la mancha"
	_crear_esponja()
	_crear_foam_particles()


# ============================================================
# CARGAR PRENDA
# ============================================================
func cargar_prenda(datos: Dictionary) -> void:
	prenda_actual = datos
	tiene_prenda = true
	ya_autocompletado = false

	var path: String = datos.get("texture_path", "")
	if path != "" and ResourceLoader.exists(path):
		garment_image.texture = load(path)
		garment_image.modulate = Color.WHITE
	else:
		push_warning("No se encontró %s — usando color plano" % path)
		garment_image.texture = null
		garment_image.modulate = datos.get("color_prenda", Color.WHITE)

	info_label.text = "%s · %s · %d€" % [
		datos.get("nombre", "?"),
		datos.get("tipo_mancha", "?"),
		int(datos.get("recompensa", 0.0))
	]

	_generar_manchas(
		datos.get("color_mancha", Color("#5C3A1E")),
		datos.get("tipo_mancha", "default")
	)
	clean_pct = 0.0
	progress_bar.value = 0
	deliver_button.disabled = true
	frotando = false


# ============================================================
# ESPONJA
# ============================================================
func _crear_esponja() -> void:
	sponge_sprite = Sprite2D.new()
	if ResourceLoader.exists(SPONGE_PATH):
		sponge_sprite.texture = load(SPONGE_PATH)
	sponge_sprite.z_index = 100
	sponge_sprite.visible = false
	add_child(sponge_sprite)


## Burbujas blancas que suben mientras el jugador frota.
func _crear_foam_particles() -> void:
	foam_particles = CPUParticles2D.new()
	foam_particles.z_index = 99
	foam_particles.emitting = false
	foam_particles.amount = 20
	foam_particles.lifetime = 0.5
	foam_particles.explosiveness = 0.0
	foam_particles.randomness = 0.7
	foam_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	foam_particles.emission_sphere_radius = 12.0
	foam_particles.direction = Vector2(0, -1)
	foam_particles.spread = 35.0
	foam_particles.initial_velocity_min = 30.0
	foam_particles.initial_velocity_max = 70.0
	foam_particles.gravity = Vector2(0, -120)
	foam_particles.scale_amount_min = 0.5
	foam_particles.scale_amount_max = 1.2
	# Fade-out por curva de color (alpha)
	var grad := Gradient.new()
	grad.add_point(0.0, Color(1, 1, 1, 0.85))
	grad.add_point(0.7, Color(0.85, 0.92, 1.0, 0.55))
	grad.add_point(1.0, Color(0.85, 0.92, 1.0, 0.0))
	foam_particles.color_ramp = grad
	add_child(foam_particles)


func _process(delta: float) -> void:
	_scrub_sfx_cooldown = max(0.0, _scrub_sfx_cooldown - delta)

	if sponge_sprite == null:
		return
	var pos_local: Vector2 = get_local_mouse_position()
	var rect := Rect2(Vector2.ZERO, size)
	var sobre_prenda: bool = tiene_prenda and rect.has_point(pos_local)

	if sobre_prenda:
		sponge_sprite.visible = true
		sponge_sprite.position = pos_local
		if frotando:
			sponge_sprite.rotation = sin(Time.get_ticks_msec() / 60.0) * 0.15
			sponge_sprite.scale = Vector2(0.95, 0.95)
		else:
			sponge_sprite.rotation = 0.0
			sponge_sprite.scale = Vector2(1.0, 1.0)
	else:
		sponge_sprite.visible = false

	# Partículas de espuma siguen al cursor y emiten al frotar
	if foam_particles != null:
		foam_particles.position = pos_local
		foam_particles.emitting = frotando and sobre_prenda


# ============================================================
# GENERACIÓN DE MANCHAS CON PERSONALIDAD
# ============================================================
func _generar_manchas(color_base: Color, tipo_mancha: String) -> void:
	stain_image = Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	stain_image.fill(Color(0, 0, 0, 0))

	var perfil: Dictionary = PERFILES_MANCHA.get(tipo_mancha, PERFILES_MANCHA["default"])

	# Generar los blobs principales con su personalidad
	var num_blobs: int = perfil["num_blobs"]
	for i in num_blobs:
		var cx: int = randi_range(70, TEX_SIZE - 70)
		var cy: int = randi_range(70, TEX_SIZE - 70)
		var radio: int = randi_range(perfil["radio_min"], perfil["radio_max"])
		var color_blob: Color = _variar_color(color_base, perfil["variacion_color"])

		# Halo: capa más grande con menos opacidad alrededor
		if perfil["halo"]:
			_pintar_blob_irregular(cx, cy, int(radio * 1.4), color_blob, 0.35, perfil["borde_irregular"] * 1.2)

		# Blob principal
		_pintar_blob_irregular(cx, cy, radio, color_blob, 1.0, perfil["borde_irregular"])

		# Chorretones verticales saliendo del blob
		var chorr: int = perfil["chorretones"]
		var chorr_largo: int = perfil["chorreton_largo"]
		for c in chorr:
			var offset_x: int = randi_range(-(radio / 2), radio / 2)
			# El cronofluido chorrea en ambas direcciones
			var direccion: int = 1 if tipo_mancha != "Cronofluido" else (1 if randf() < 0.5 else -1)
			var largo_real: int = randi_range(int(chorr_largo * 0.5), chorr_largo)
			_pintar_chorreton(cx + offset_x, cy, largo_real * direccion, color_blob)

		# Salpicaduras alrededor
		var salp: int = perfil["salpicaduras"]
		for s in salp:
			var angulo: float = randf() * TAU
			var distancia: float = randf_range(radio * 1.2, radio * 2.5)
			var sx: int = cx + int(cos(angulo) * distancia)
			var sy: int = cy + int(sin(angulo) * distancia)
			var radio_salp: int = randi_range(2, 5)
			if sx >= 0 and sx < TEX_SIZE and sy >= 0 and sy < TEX_SIZE:
				_pintar_blob_irregular(sx, sy, radio_salp, color_blob, 0.9, 0.3)

	pixeles_mancha_total = _contar_pixeles_manchados()
	pixeles_mancha_actual = pixeles_mancha_total
	stain_image_texture = ImageTexture.create_from_image(stain_image)
	stain_texture.texture = stain_image_texture


## Pinta un blob con borde irregular usando varias frecuencias de seno.
## intensidad: multiplicador del alpha final (0.35 para halos, 1.0 para blob principal).
## irregularidad: cuánto se desvía el borde (0=círculo, 1=muy irregular).
func _pintar_blob_irregular(cx: int, cy: int, radio: int, color: Color, intensidad: float, irregularidad: float) -> void:
	# Pre-calcular semillas de fase para tres frecuencias distintas
	var fase1: float = randf() * TAU
	var fase2: float = randf() * TAU
	var fase3: float = randf() * TAU

	var radio_max: int = int(radio * (1.0 + irregularidad * 0.5))
	for y in range(max(0, cy - radio_max), min(TEX_SIZE, cy + radio_max + 1)):
		for x in range(max(0, cx - radio_max), min(TEX_SIZE, cx + radio_max + 1)):
			var dx: float = x - cx
			var dy: float = y - cy
			var dist: float = sqrt(dx * dx + dy * dy)
			var angulo: float = atan2(dy, dx)
			# Borde irregular con tres frecuencias: forma orgánica
			var deformacion: float = (
				sin(angulo * 3.0 + fase1) * 0.5 +
				sin(angulo * 7.0 + fase2) * 0.3 +
				sin(angulo * 13.0 + fase3) * 0.2
			)
			var radio_local: float = radio + deformacion * radio * irregularidad
			if dist <= radio_local:
				var alpha: float = clamp(1.0 - (dist / radio_local), 0.0, 1.0)
				alpha = pow(alpha, 0.55) * intensidad
				# Mezclar con lo que ya hay (no sobrescribir si hay más opacidad)
				var existente: Color = stain_image.get_pixel(x, y)
				if alpha > existente.a:
					stain_image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))


## Pinta un chorretón vertical (líquido cayendo). Largo positivo = abajo, negativo = arriba.
func _pintar_chorreton(cx: int, cy: int, largo: int, color: Color) -> void:
	var ancho_inicial: int = randi_range(3, 5)
	var paso: int = 1 if largo > 0 else -1
	var distancia_total: int = abs(largo)

	for i in range(0, distancia_total):
		var y: int = cy + (i * paso)
		if y < 0 or y >= TEX_SIZE:
			break
		# El chorretón se va estrechando
		var ancho_actual: float = ancho_inicial * (1.0 - float(i) / float(distancia_total))
		# Pequeño zigzag aleatorio
		var jitter: int = randi_range(-1, 1)
		var alpha: float = 0.85 * (1.0 - float(i) / float(distancia_total))
		alpha = max(alpha, 0.15)
		# Pintar línea horizontal de ese ancho
		for offset in range(-int(ancho_actual), int(ancho_actual) + 1):
			var x: int = cx + offset + jitter
			if x < 0 or x >= TEX_SIZE:
				continue
			# Atenuación en bordes del chorretón
			var atenuacion: float = 1.0 - abs(float(offset)) / max(ancho_actual, 1.0)
			atenuacion = clamp(atenuacion, 0.0, 1.0)
			var alpha_final: float = alpha * atenuacion
			var existente: Color = stain_image.get_pixel(x, y)
			if alpha_final > existente.a:
				stain_image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha_final))


## Devuelve el color con una pequeña variación aleatoria de tono.
func _variar_color(base: Color, cantidad: float) -> Color:
	if cantidad <= 0.0:
		return base
	var r: float = clamp(base.r + randf_range(-cantidad, cantidad), 0.0, 1.0)
	var g: float = clamp(base.g + randf_range(-cantidad, cantidad), 0.0, 1.0)
	var b: float = clamp(base.b + randf_range(-cantidad, cantidad), 0.0, 1.0)
	return Color(r, g, b, base.a)


func _contar_pixeles_manchados() -> int:
	var count: int = 0
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			if stain_image.get_pixel(x, y).a > 0.1:
				count += 1
	return count


# ============================================================
# INPUT — FROTADO (sin cambios respecto a v2)
# ============================================================
func _input(event: InputEvent) -> void:
	if not tiene_prenda:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			frotando = event.pressed
			if frotando:
				_frotar_en_posicion(get_local_mouse_position())
	elif event is InputEventMouseMotion:
		if frotando:
			_frotar_en_posicion(get_local_mouse_position())


func _frotar_en_posicion(pos_local: Vector2) -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if not rect.has_point(pos_local):
		return

	var pos_textura: Vector2 = pos_local - stain_texture.position
	if pos_textura.x < 0 or pos_textura.y < 0:
		return
	if pos_textura.x >= TEX_SIZE or pos_textura.y >= TEX_SIZE:
		return

	var cx: int = int(pos_textura.x)
	var cy: int = int(pos_textura.y)
	var pixeles_borrados: int = 0

	var radio_efectivo: int = RADIO_FROTADO + bonus_radio
	var fuerza_efectiva: float = FUERZA_BORRADO + bonus_fuerza + bonus_fuerza_evento
	var radio_sq: int = radio_efectivo * radio_efectivo

	for y in range(max(0, cy - radio_efectivo), min(TEX_SIZE, cy + radio_efectivo + 1)):
		for x in range(max(0, cx - radio_efectivo), min(TEX_SIZE, cx + radio_efectivo + 1)):
			var dx: float = x - cx
			var dy: float = y - cy
			if dx * dx + dy * dy <= radio_sq:
				var pixel: Color = stain_image.get_pixel(x, y)
				if pixel.a > 0.0:
					var alpha_anterior: float = pixel.a
					var nuevo_alpha: float = max(0.0, pixel.a - fuerza_efectiva)
					stain_image.set_pixel(x, y, Color(pixel.r, pixel.g, pixel.b, nuevo_alpha))
					if alpha_anterior > 0.1 and nuevo_alpha <= 0.1:
						pixeles_borrados += 1

	pixeles_mancha_actual -= pixeles_borrados
	pixeles_mancha_actual = max(0, pixeles_mancha_actual)
	stain_image_texture.update(stain_image)

	# SFX de frotado, con cooldown para no saturar
	if pixeles_borrados > 0 and _scrub_sfx_cooldown <= 0.0:
		AudioManager.play_sfx("scrub", randf_range(0.85, 1.15))
		_scrub_sfx_cooldown = 0.08

	contador_eventos += 1
	if contador_eventos >= FRAMES_ENTRE_MEDICIONES:
		contador_eventos = 0
		_actualizar_progreso()


func _actualizar_progreso() -> void:
	if pixeles_mancha_total <= 0:
		clean_pct = 1.0
	else:
		clean_pct = 1.0 - (float(pixeles_mancha_actual) / float(pixeles_mancha_total))
		clean_pct = clamp(clean_pct, 0.0, 1.0)

	progress_bar.value = clean_pct * 100.0

	if clean_pct >= UMBRAL_ENTREGA and not ya_autocompletado:
		_autocompletar_limpieza()


func _autocompletar_limpieza() -> void:
	ya_autocompletado = true
	if stain_image:
		stain_image.fill(Color(0, 0, 0, 0))
		if stain_image_texture:
			stain_image_texture.update(stain_image)
	pixeles_mancha_actual = 0
	clean_pct = 1.0
	progress_bar.value = 100.0
	deliver_button.disabled = false
	AudioManager.play_sfx("deliver", 1.1)


# ============================================================
# PRESTIGIO
# ============================================================

## API canónica: resetea bonuses de mejoras y limpia el estado de la prenda actual.
## Llamada por prestige_realizado y por el debug F2.
func reset_sink() -> void:
	bonus_fuerza = 0.0
	bonus_radio = 0
	tiene_prenda = false
	prenda_actual = {}
	ya_autocompletado = false
	frotando = false
	if stain_image != null:
		stain_image.fill(Color(0, 0, 0, 0))
		if stain_image_texture != null:
			stain_image_texture.update(stain_image)
	garment_image.texture = null
	progress_bar.value = 0
	deliver_button.disabled = true
	info_label.text = ""


## Compatibilidad con señal prestige_realizado (delega a reset_sink).
func reset_para_prestigio() -> void:
	reset_sink()


## [Debug F5] Completa la limpieza de la prenda actual al instante.
func limpiar_instantaneo() -> void:
	if not tiene_prenda:
		return
	_autocompletar_limpieza()


func _on_deliver_pressed() -> void:
	intentar_entregar()


## API pública: entrega la prenda actual si está lista. Devuelve true si entregó.
## Usado por _on_deliver_pressed y por el atajo SPACE en Main.
func intentar_entregar() -> bool:
	if not tiene_prenda:
		return false
	if clean_pct < UMBRAL_ENTREGA:
		return false

	var recompensa_final: float = float(prenda_actual.get("recompensa", 0.0))
	var prenda_entregada: Dictionary = prenda_actual.duplicate()

	tiene_prenda = false
	frotando = false
	deliver_button.disabled = true

	garment_delivered.emit(prenda_entregada, recompensa_final)
	return true


# ============================================================
# FASE 6 — PERSISTENCIA
# ============================================================
func serializar() -> Dictionary:
	return {
		"bonus_fuerza": bonus_fuerza,
		"bonus_radio": bonus_radio,
		"prenda_actual_id": String(prenda_actual.get("id", "")) if tiene_prenda else "",
	}


## Restaura bonuses y, si había una prenda en curso, la recarga fresca.
## El pixel state de la mancha NO se persiste: la prenda recargada arranca con manchas nuevas.
## Devuelve true si recargó una prenda (Main sabrá que no llame consumir_siguiente).
func cargar_estado(data: Dictionary) -> bool:
	bonus_fuerza = float(data.get("bonus_fuerza", 0.0))
	bonus_radio = int(data.get("bonus_radio", 0))
	var prenda_id: String = String(data.get("prenda_actual_id", ""))
	if prenda_id == "":
		return false
	var prenda: Dictionary = GarmentData.get_prenda_por_id(prenda_id)
	if prenda.is_empty():
		return false
	cargar_prenda(prenda)
	return true
