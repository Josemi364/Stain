extends Control
##
## SinkArea.gd — FASE 3 + ASSETS
## ============================================================
## Mecánica de lavado con:
##  - TextureRect que muestra el SVG de la prenda (en vez de Polygon2D)
##  - Sprite2D de esponja que sigue al ratón mientras está sobre el área
##  - Sistema aditivo de bonos (estilo Scritchy Scratchy)
##

# === Configuración ===
const TEX_SIZE: int = 256
const RADIO_FROTADO: int = 14
const FUERZA_BORRADO: float = 0.12
const UMBRAL_ENTREGA: float = 0.75
const BONUS_LIMPIEZA_PERFECTA: float = 1.20
const FRAMES_ENTRE_MEDICIONES: int = 5

# Path al sprite de la esponja
const SPONGE_PATH: String = "res://assets/cursor/esponja.svg"

# === Referencias a nodos hijos ===
@onready var garment_image: TextureRect = $GarmentImage
@onready var stain_texture: TextureRect = $StainTexture
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var deliver_button: Button = $DeliverButton
@onready var info_label: Label = $InfoLabel

# La esponja se crea por código y se añade como hijo
var sponge_sprite: Sprite2D

# === Estado interno ===
var stain_image: Image
var stain_image_texture: ImageTexture
var prenda_actual: Dictionary = {}
var pixeles_mancha_total: int = 0
var pixeles_mancha_actual: int = 0
var clean_pct: float = 0.0
var frotando: bool = false
var contador_eventos: int = 0

# === Bonos aditivos de upgrades ===
var bonus_fuerza: float = 0.0
var bonus_radio: int = 0

# === Señales ===
signal garment_delivered(garment: Dictionary, earned: float)

func _ready() -> void:
	deliver_button.pressed.connect(_on_deliver_pressed)
	_crear_esponja()

# ============================================================
# CARGAR PRENDA
# ============================================================
func cargar_prenda(datos: Dictionary) -> void:
	prenda_actual = datos
	print(datos)

	# === DEBUG TEMPORAL ===
	print("───────────────────────────────")
	print("Cargando prenda: ", datos.get("nombre", "?"))
	print("garment_image existe?: ", garment_image != null)
	if garment_image:
		print("garment_image size: ", garment_image.size)
		print("garment_image position: ", garment_image.position)

	# Cargar el SVG de la prenda
	var path: String = datos.get("texture_path", "")
	print("Buscando textura en: ", path)
	print("¿Existe el recurso?: ", ResourceLoader.exists(path))

	if path != "" and ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		print("Textura cargada: ", tex)
		garment_image.texture = tex
		garment_image.modulate = Color.WHITE
	else:
		# Fallback: si no hay textura, usar un color sólido
		push_warning("No se encontró %s — usando color plano" % path)
		garment_image.texture = null
		garment_image.modulate = datos.get("color_prenda", Color.WHITE)
	print("───────────────────────────────")

	# Info label
	info_label.text = "%s · %s · %d€" % [
		datos.get("nombre", "?"),
		datos.get("tipo_mancha", "?"),
		int(datos.get("recompensa", 0.0))
	]

	# Generar manchas nuevas
	_generar_manchas(datos.get("color_mancha", Color("#5C3A1E")))
	clean_pct = 0.0
	progress_bar.value = 0
	deliver_button.disabled = true
	frotando = false


# ============================================================
# ESPONJA — sprite que sigue al ratón
# ============================================================
func _crear_esponja() -> void:
	sponge_sprite = Sprite2D.new()
	if ResourceLoader.exists(SPONGE_PATH):
		sponge_sprite.texture = load(SPONGE_PATH)
	else:
		push_warning("No se encontró la esponja en %s" % SPONGE_PATH)

	# La esponja se dibuja por encima de todo dentro del SinkArea
	sponge_sprite.z_index = 100
	sponge_sprite.visible = false  # Solo se ve cuando el ratón está dentro
	add_child(sponge_sprite)


func _process(_delta: float) -> void:
	# Mover la esponja a la posición del ratón si está dentro del fregadero
	if sponge_sprite == null:
		return

	var pos_local: Vector2 = get_local_mouse_position()
	var rect := Rect2(Vector2.ZERO, size)

	if rect.has_point(pos_local):
		sponge_sprite.visible = true
		sponge_sprite.position = pos_local
		# Pequeño "tilt" cuando frota, para sensación de movimiento
		if frotando:
			sponge_sprite.rotation = sin(Time.get_ticks_msec() / 60.0) * 0.15
			sponge_sprite.scale = Vector2(0.95, 0.95)
		else:
			sponge_sprite.rotation = 0.0
			sponge_sprite.scale = Vector2(1.0, 1.0)
	else:
		sponge_sprite.visible = false


# ============================================================
# GENERACIÓN DE MANCHAS
# ============================================================
func _generar_manchas(color_mancha: Color) -> void:
	stain_image = Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	stain_image.fill(Color(0, 0, 0, 0))

	var num_blobs: int = randi_range(3, 5)
	for i in num_blobs:
		var cx: int = randi_range(60, TEX_SIZE - 60)
		var cy: int = randi_range(60, TEX_SIZE - 60)
		var radio: int = randi_range(20, 40)
		_pintar_blob(cx, cy, radio, color_mancha)

	pixeles_mancha_total = _contar_pixeles_manchados()
	pixeles_mancha_actual = pixeles_mancha_total

	stain_image_texture = ImageTexture.create_from_image(stain_image)
	stain_texture.texture = stain_image_texture


func _pintar_blob(cx: int, cy: int, radio: int, color: Color) -> void:
	for y in range(max(0, cy - radio), min(TEX_SIZE, cy + radio + 1)):
		for x in range(max(0, cx - radio), min(TEX_SIZE, cx + radio + 1)):
			var dx: float = x - cx
			var dy: float = y - cy
			var dist: float = sqrt(dx * dx + dy * dy)
			var radio_local: float = radio + sin(atan2(dy, dx) * 4.0) * 3.0
			if dist <= radio_local:
				var alpha: float = clamp(1.0 - (dist / radio_local), 0.0, 1.0)
				alpha = pow(alpha, 0.5)
				var c := Color(color.r, color.g, color.b, alpha)
				stain_image.set_pixel(x, y, c)


func _contar_pixeles_manchados() -> int:
	var count: int = 0
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			if stain_image.get_pixel(x, y).a > 0.1:
				count += 1
	return count


# ============================================================
# INPUT — FROTADO
# ============================================================
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			frotando = event.pressed
			if frotando:
				var pos_local := get_local_mouse_position()
				_frotar_en_posicion(pos_local)
	elif event is InputEventMouseMotion:
		if frotando:
			var pos_local := get_local_mouse_position()
			_frotar_en_posicion(pos_local)


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

	# Bonos aditivos (no multiplicativos)
	var radio_efectivo: int = RADIO_FROTADO + bonus_radio
	var fuerza_efectiva: float = FUERZA_BORRADO + bonus_fuerza
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

	if clean_pct >= UMBRAL_ENTREGA and deliver_button.disabled:
		deliver_button.disabled = false
	elif clean_pct < UMBRAL_ENTREGA and not deliver_button.disabled:
		deliver_button.disabled = true


func _on_deliver_pressed() -> void:
	_actualizar_progreso()
	if clean_pct < UMBRAL_ENTREGA:
		return

	var recompensa_base: float = prenda_actual.get("recompensa", 0.0)
	var recompensa_final: float = recompensa_base
	if clean_pct >= 0.99:
		recompensa_final = recompensa_base * BONUS_LIMPIEZA_PERFECTA
		print("¡Limpieza perfecta! Bonus +20%%")

	garment_delivered.emit(prenda_actual, recompensa_final)
