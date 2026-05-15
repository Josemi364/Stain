extends Node
##
## AudioManager.gd — AUTOLOAD (FASE 9)
## ============================================================
## Genera tonos procedurales (sin assets externos) y los reproduce
## bajo demanda con `play_sfx(id)`. Cada sonido es un AudioStreamWAV
## sintetizado al arranque y cacheado.
##
## Si en el futuro hay assets de audio reales, basta con sustituir
## el diccionario `_streams` por archivos cargados con `load()`.
##

# ============================================================
# CONFIGURACIÓN
# ============================================================
const SAMPLE_RATE: int = 22050

# Volumen master (-80 a 0 dB)
var volumen_db: float = -8.0

# Cache de streams generados, id → AudioStreamWAV
var _streams: Dictionary = {}

# Pool de AudioStreamPlayers reutilizables (evita crear nodos en hot path)
const POOL_SIZE: int = 8
var _pool: Array[AudioStreamPlayer] = []
var _pool_idx: int = 0


# ============================================================
# INICIALIZACIÓN
# ============================================================
func _ready() -> void:
	_generar_todos()
	_construir_pool()


func _construir_pool() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.volume_db = volumen_db
		add_child(p)
		_pool.append(p)


# ============================================================
# API PÚBLICA
# ============================================================

## Reproduce un SFX por su id. Si el id no existe, no hace nada.
## Múltiples sonidos pueden solaparse hasta POOL_SIZE simultáneos.
func play_sfx(id: String, pitch: float = 1.0) -> void:
	if not _streams.has(id):
		return
	var p: AudioStreamPlayer = _pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % POOL_SIZE
	p.stream = _streams[id]
	p.pitch_scale = pitch
	p.play()


## Cambia el volumen master de todos los SFX. db ∈ [-80, 6].
## -80 efectivamente silencia. Aplica al pool inmediatamente.
func set_volumen_db(db: float) -> void:
	volumen_db = clamp(db, -80.0, 6.0)
	for p in _pool:
		p.volume_db = volumen_db


## Devuelve el volumen actual en dB (para serializar en el save).
func get_volumen_db() -> float:
	return volumen_db


# ============================================================
# GENERACIÓN DE SFX
# ============================================================
func _generar_todos() -> void:
	# Frotar: ráfaga breve de ruido blanco con envelope rápido
	_streams["scrub"] = _generar_ruido(0.06, 0.6)

	# Entregar prenda: chime alegre (C5 → E5)
	_streams["deliver"] = _generar_arpegio([523.25, 659.25], 0.15)

	# Comprar mejora: dos notas ascendentes (C5, G5)
	_streams["buy"] = _generar_arpegio([523.25, 783.99], 0.10)

	# Alien en cola / entrega: tono grave inquietante (G3 con vibrato)
	_streams["alien"] = _generar_tono_vibrato(196.0, 0.35, 8.0, 0.05)

	# Lavadora completa ciclo: campana brillante (G5)
	_streams["machine_done"] = _generar_tono(783.99, 0.25, 1.0, 0.4)

	# Logro desbloqueado: arpegio triunfal (C5, E5, G5)
	_streams["achievement"] = _generar_arpegio([523.25, 659.25, 783.99], 0.18)

	# Prestigio: acorde grave largo
	_streams["prestige"] = _generar_acorde([130.81, 196.00, 261.63], 0.9)

	# Compra denegada: tono grave corto
	_streams["denied"] = _generar_tono(174.61, 0.10, 0.8, 0.6)


## Tono sinusoidal con envelope ADR simple.
##   freq: frecuencia en Hz
##   duracion: segundos
##   amp: amplitud (0..1)
##   decay_exp: cuánto se acelera el decay (1.0 lineal, >1 más abrupto)
func _generar_tono(freq: float, duracion: float, amp: float = 1.0, decay_exp: float = 1.0) -> AudioStreamWAV:
	var n: int = int(duracion * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var env: float = pow(1.0 - float(i) / float(n), decay_exp)
		var sample: float = sin(t * freq * TAU) * env * amp
		_escribir_sample(data, i, sample)
	return _crear_stream(data)


## Tono con vibrato (modulación de frecuencia).
func _generar_tono_vibrato(freq: float, duracion: float, vib_freq: float, vib_depth: float) -> AudioStreamWAV:
	var n: int = int(duracion * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var f: float = freq * (1.0 + sin(t * vib_freq * TAU) * vib_depth)
		var env: float = pow(1.0 - float(i) / float(n), 1.2)
		var sample: float = sin(t * f * TAU) * env
		_escribir_sample(data, i, sample)
	return _crear_stream(data)


## Notas tocadas en secuencia (arpeggio). Cada nota dura `duracion_nota` segundos.
func _generar_arpegio(freqs: Array, duracion_nota: float) -> AudioStreamWAV:
	var n_nota: int = int(duracion_nota * SAMPLE_RATE)
	var n: int = n_nota * freqs.size()
	var data := PackedByteArray()
	data.resize(n * 2)
	for nota_idx in freqs.size():
		var freq: float = float(freqs[nota_idx])
		for i in n_nota:
			var t: float = float(i) / SAMPLE_RATE
			var env: float = pow(1.0 - float(i) / float(n_nota), 1.4)
			var sample: float = sin(t * freq * TAU) * env
			_escribir_sample(data, nota_idx * n_nota + i, sample)
	return _crear_stream(data)


## Acorde: varias frecuencias simultáneas.
func _generar_acorde(freqs: Array, duracion: float) -> AudioStreamWAV:
	var n: int = int(duracion * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var amp_por_nota: float = 1.0 / float(freqs.size())
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var env: float = pow(1.0 - float(i) / float(n), 1.0)
		var sample: float = 0.0
		for f_v in freqs:
			sample += sin(t * float(f_v) * TAU) * amp_por_nota
		_escribir_sample(data, i, sample * env)
	return _crear_stream(data)


## Ruido blanco con envelope decreciente.
func _generar_ruido(duracion: float, amp: float) -> AudioStreamWAV:
	var n: int = int(duracion * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var env: float = pow(1.0 - float(i) / float(n), 0.6)
		var sample: float = (randf() * 2.0 - 1.0) * env * amp
		_escribir_sample(data, i, sample)
	return _crear_stream(data)


# ============================================================
# UTILIDADES
# ============================================================
func _escribir_sample(buffer: PackedByteArray, idx: int, sample: float) -> void:
	var s: int = int(clamp(sample, -1.0, 1.0) * 32767.0)
	if s < 0:
		s += 65536  # complemento a dos en 16 bits
	buffer[idx * 2] = s & 0xFF
	buffer[idx * 2 + 1] = (s >> 8) & 0xFF


func _crear_stream(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
