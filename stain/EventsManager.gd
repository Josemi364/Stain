extends Node
##
## EventsManager.gd — AUTOLOAD (FASE 10)
## ============================================================
## Dispara eventos aleatorios temporales que modifican el juego.
## Un único evento activo a la vez. Cooldown variable entre eventos.
##
## Señales:
##   evento_iniciado(id)                     → Main aplica modificadores + muestra banner
##   evento_finalizado(id, exito: bool)      → Main revierte + cierra banner (exito solo aplica a VIP)
##   evento_actualizado(id, restante, datos) → tick por segundo para refrescar banner
##
## Gating: ningún evento dispara hasta que el jugador llega a 500€ totales
## o realiza su primer prestigio (lo que ocurra antes). Evita abrumar al
## jugador nuevo durante el onboarding.
##
## NO se persiste estado: al cargar partida los cooldowns se reinician.
##

# ============================================================
# CONFIGURACIÓN GLOBAL
# ============================================================
const PRIMER_COOLDOWN_SEG: float = 60.0
const COOLDOWN_BASE_SEG: float = 90.0
const COOLDOWN_VARIANZA_SEG: float = 30.0  # ± varianza

# Umbrales de "gating" (cualquiera basta)
const GATE_EUROS_TOTAL: float = 500.0
const GATE_PRESTIGIOS: int = 1

# ============================================================
# DEFINICIÓN DE EVENTOS
# ============================================================
const EVENTOS: Array[Dictionary] = [
	{
		"id": "lluvia_alien",
		"nombre": "Lluvia alien",
		"descripcion": "Las prendas alien aparecen mucho más a menudo.",
		"icono": "👽",
		"color": "#AA40FF",
		"duracion": 30.0,
		"tipo": "modificador",
	},
	{
		"id": "hora_dorada",
		"nombre": "Hora dorada",
		"descripcion": "Todas las ganancias en € se duplican.",
		"icono": "🌟",
		"color": "#FFD060",
		"duracion": 20.0,
		"tipo": "modificador",
	},
	{
		"id": "pedido_vip",
		"nombre": "Cliente VIP",
		"descripcion": "Limpia 6 prendas en 45 s y gana 500€ + 2 ✧.",
		"icono": "🎩",
		"color": "#40D0FF",
		"duracion": 45.0,
		"tipo": "vip",
		"vip_objetivo": 6,
		"vip_recompensa_euros": 500,
		"vip_recompensa_fragmentos": 2,
	},
	{
		"id": "susurro_altar",
		"nombre": "Susurro del Altar",
		"descripcion": "Las prendas alien dan +1 fragmento adicional.",
		"icono": "✧",
		"color": "#FF40AA",
		"duracion": 25.0,
		"tipo": "modificador",
	},
	{
		"id": "frenesi_frotador",
		"nombre": "Frenesí frotador",
		"descripcion": "Tu esponja borra mucho más rápido.",
		"icono": "🧽",
		"color": "#80FFAA",
		"duracion": 20.0,
		"tipo": "modificador",
	},
	{
		"id": "pulso_cuantico",
		"nombre": "Pulso cuántico",
		"descripcion": "Las lavadoras procesan 50% más rápido.",
		"icono": "🌀",
		"color": "#40A0FF",
		"duracion": 40.0,
		"tipo": "modificador",
	},
]


# ============================================================
# ESTADO INTERNO
# ============================================================
var evento_activo: Dictionary = {}  # vacío = ninguno
var tiempo_restante: float = 0.0
var cooldown_restante: float = PRIMER_COOLDOWN_SEG
var habilitado: bool = false        # se enciende al pasar el gate

# Estado VIP
var vip_progreso: int = 0

# Para cuenta atrás visual (emitir cada segundo)
var _tick_acumulado: float = 0.0


signal evento_iniciado(id: String)
signal evento_finalizado(id: String, exito: bool)
signal evento_actualizado(id: String, restante: float, datos: Dictionary)


# ============================================================
# CICLO PRINCIPAL
# ============================================================
func _process(delta: float) -> void:
	if not habilitado:
		return

	if not evento_activo.is_empty():
		tiempo_restante -= delta
		_tick_acumulado += delta
		if _tick_acumulado >= 0.25:
			_tick_acumulado = 0.0
			_emitir_actualizacion()
		if tiempo_restante <= 0.0:
			_finalizar_evento(false)
	else:
		cooldown_restante -= delta
		if cooldown_restante <= 0.0:
			_disparar_evento()


# ============================================================
# API PÚBLICA
# ============================================================

## Main llama esto cada vez que cambian euros_totales o num_prestigios.
## Activa el sistema una vez se cumpla el gate. Es idempotente.
func comprobar_gate(euros_totales: float, num_prestigios: int) -> void:
	if habilitado:
		return
	if euros_totales >= GATE_EUROS_TOTAL or num_prestigios >= GATE_PRESTIGIOS:
		habilitado = true


## Main avisa cuando entrega una prenda manualmente. Solo cuenta para VIP.
func notificar_prenda_entregada() -> void:
	if evento_activo.is_empty() or evento_activo.get("tipo", "") != "vip":
		return
	vip_progreso += 1
	_emitir_actualizacion()
	if vip_progreso >= int(evento_activo.get("vip_objetivo", 9999)):
		_finalizar_evento(true)


## ¿Hay evento activo? útil para Main al aplicar modificadores.
func es_activo(id: String) -> bool:
	return not evento_activo.is_empty() and evento_activo.get("id", "") == id


## Reset usado en F2 (debug full reset).
func reset_completo() -> void:
	if not evento_activo.is_empty():
		var id_act: String = String(evento_activo.get("id", ""))
		evento_activo = {}
		tiempo_restante = 0.0
		vip_progreso = 0
		evento_finalizado.emit(id_act, false)
	cooldown_restante = PRIMER_COOLDOWN_SEG
	habilitado = false


# ============================================================
# INTERNAS
# ============================================================
func _disparar_evento() -> void:
	var ev: Dictionary = EVENTOS[randi() % EVENTOS.size()]
	evento_activo = ev
	tiempo_restante = float(ev["duracion"])
	vip_progreso = 0
	_tick_acumulado = 0.0
	evento_iniciado.emit(String(ev["id"]))
	_emitir_actualizacion()


func _finalizar_evento(exito: bool) -> void:
	if evento_activo.is_empty():
		return
	var id: String = String(evento_activo["id"])
	evento_activo = {}
	tiempo_restante = 0.0
	vip_progreso = 0
	# Cooldown aleatorio para el siguiente
	cooldown_restante = COOLDOWN_BASE_SEG + randf_range(-COOLDOWN_VARIANZA_SEG, COOLDOWN_VARIANZA_SEG)
	evento_finalizado.emit(id, exito)


func _emitir_actualizacion() -> void:
	if evento_activo.is_empty():
		return
	var datos: Dictionary = {}
	if evento_activo.get("tipo", "") == "vip":
		datos["progreso"] = vip_progreso
		datos["objetivo"] = int(evento_activo.get("vip_objetivo", 0))
	evento_actualizado.emit(String(evento_activo["id"]), tiempo_restante, datos)


## Utilidad para Main: definición completa de un evento por id.
func get_evento(id: String) -> Dictionary:
	for e in EVENTOS:
		if e["id"] == id:
			return e
	return {}
