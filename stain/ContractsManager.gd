extends Node
##
## ContractsManager.gd — AUTOLOAD (FASE 13)
## ============================================================
## Sistema de contratos opcionales: cada cierto tiempo aparece un cliente
## con un pedido (X prendas en T segundos a cambio de Y€ + Z ✧). El jugador
## puede aceptarlo o rechazarlo. Si lo acepta, debe completarlo en el plazo.
##
## Diferencias con EventsManager (Fase 10):
##   - Requiere aceptación explícita (no se autodispara)
##   - No modifica modificadores globales (no afecta multiplicadores)
##   - Al completar exitosamente, recompensa fija
##   - Compatible con eventos activos al mismo tiempo
##
## Estados:
##   IDLE       — cooldown corriendo, sin contrato disponible
##   DISPONIBLE — contrato_disponible no vacío, esperando decisión del jugador
##   ACTIVO     — contrato_activo no vacío, corriendo
##
## Señales:
##   contrato_disponible(contrato)   → Main muestra banner con Aceptar/Rechazar
##   contrato_aceptado(contrato)     → Main cambia banner a tracker
##   contrato_completado(contrato, exito) → Main da reward (si éxito) y cierra banner
##   contrato_actualizado(progreso, restante) → tick para refrescar progreso
##
## Gating: igual que EventsManager (>= 200€ o >= 1 prestigio).
## NO se persiste estado: al cargar partida, cooldown limpio.
##

# ============================================================
# CONFIGURACIÓN
# ============================================================
const PRIMER_COOLDOWN_SEG: float = 90.0
const COOLDOWN_BASE_SEG: float = 120.0
const COOLDOWN_VARIANZA_SEG: float = 30.0
const TIEMPO_OFERTA_SEG: float = 25.0  # cuánto tiempo está disponible para aceptar
const GATE_EUROS_TOTAL: float = 200.0
const GATE_PRESTIGIOS: int = 1

# ============================================================
# DEFINICIÓN DE CONTRATOS
# ============================================================
# tipo_prenda: "any" cuenta cualquier entrega; "alien" solo prendas alien
const CONTRATOS: Array[Dictionary] = [
	{
		"id": "lavanderia_rapida",
		"nombre": "Lavandería rápida",
		"descripcion": "Limpia 8 prendas en 90s.",
		"icono": "🧺",
		"objetivo": 8,
		"tipo_prenda": "any",
		"duracion": 90.0,
		"reward_euros": 80,
		"reward_fragmentos": 1,
		"reward_ceniza": 0,
	},
	{
		"id": "lote_completo",
		"nombre": "Lote del hotel",
		"descripcion": "Limpia 20 prendas en 240s.",
		"icono": "🏨",
		"objetivo": 20,
		"tipo_prenda": "any",
		"duracion": 240.0,
		"reward_euros": 250,
		"reward_fragmentos": 2,
		"reward_ceniza": 0,
	},
	{
		"id": "cazador_alien",
		"nombre": "Cazador alien",
		"descripcion": "Limpia 3 prendas alien en 180s.",
		"icono": "👽",
		"objetivo": 3,
		"tipo_prenda": "alien",
		"duracion": 180.0,
		"reward_euros": 200,
		"reward_fragmentos": 5,
		"reward_ceniza": 0,
	},
	{
		"id": "marathon",
		"nombre": "Maratón de lavado",
		"descripcion": "Limpia 50 prendas en 600s.",
		"icono": "🏃",
		"objetivo": 50,
		"tipo_prenda": "any",
		"duracion": 600.0,
		"reward_euros": 700,
		"reward_fragmentos": 5,
		"reward_ceniza": 2,
	},
	{
		"id": "exprés",
		"nombre": "Pedido exprés",
		"descripcion": "Limpia 5 prendas en 30s.",
		"icono": "⚡",
		"objetivo": 5,
		"tipo_prenda": "any",
		"duracion": 30.0,
		"reward_euros": 60,
		"reward_fragmentos": 1,
		"reward_ceniza": 0,
	},
]


# ============================================================
# ESTADO INTERNO
# ============================================================
var contrato_disponible: Dictionary = {}
var contrato_activo: Dictionary = {}
var tiempo_restante: float = 0.0   # de la oferta o del activo
var progreso: int = 0
var cooldown_restante: float = PRIMER_COOLDOWN_SEG
var habilitado: bool = false

var _tick_acumulado: float = 0.0


signal contrato_disponible_aparece(contrato: Dictionary)
signal contrato_aceptado(contrato: Dictionary)
signal contrato_completado(contrato: Dictionary, exito: bool)
signal contrato_actualizado(restante: float, progreso_actual: int)
signal contrato_disponible_expirado(contrato: Dictionary)


# ============================================================
# CICLO PRINCIPAL
# ============================================================
func _process(delta: float) -> void:
	if not habilitado:
		return

	# Activo: cuenta atrás del plazo
	if not contrato_activo.is_empty():
		tiempo_restante -= delta
		_tick_acumulado += delta
		if _tick_acumulado >= 0.25:
			_tick_acumulado = 0.0
			contrato_actualizado.emit(tiempo_restante, progreso)
		if tiempo_restante <= 0.0:
			_finalizar(false)
		return

	# Disponible: cuenta atrás de la oferta
	if not contrato_disponible.is_empty():
		tiempo_restante -= delta
		if tiempo_restante <= 0.0:
			var c: Dictionary = contrato_disponible
			contrato_disponible = {}
			cooldown_restante = COOLDOWN_BASE_SEG + randf_range(-COOLDOWN_VARIANZA_SEG, COOLDOWN_VARIANZA_SEG)
			contrato_disponible_expirado.emit(c)
		return

	# Idle: cooldown
	cooldown_restante -= delta
	if cooldown_restante <= 0.0:
		_ofrecer_contrato()


# ============================================================
# API PÚBLICA
# ============================================================

## Main lo llama tras cambios de € o prestigio. Es idempotente.
func comprobar_gate(euros_totales: float, num_prestigios: int) -> void:
	if habilitado:
		return
	if euros_totales >= GATE_EUROS_TOTAL or num_prestigios >= GATE_PRESTIGIOS:
		habilitado = true


## Llamado por Main en cada entrega/proceso de prenda.
## Solo cuenta si hay contrato activo y la prenda casa con su tipo_prenda.
func notificar_prenda(prenda: Dictionary) -> void:
	if contrato_activo.is_empty():
		return
	var tipo_requerido: String = String(contrato_activo.get("tipo_prenda", "any"))
	var es_alien: bool = bool(prenda.get("es_alien", false))
	if tipo_requerido == "alien" and not es_alien:
		return
	# tipo_requerido == "any" pasa siempre
	progreso += 1
	contrato_actualizado.emit(tiempo_restante, progreso)
	if progreso >= int(contrato_activo.get("objetivo", 999999)):
		_finalizar(true)


## El jugador acepta el contrato disponible.
func aceptar() -> void:
	if contrato_disponible.is_empty():
		return
	contrato_activo = contrato_disponible
	contrato_disponible = {}
	progreso = 0
	tiempo_restante = float(contrato_activo.get("duracion", 60.0))
	_tick_acumulado = 0.0
	contrato_aceptado.emit(contrato_activo)
	contrato_actualizado.emit(tiempo_restante, progreso)


## El jugador rechaza el contrato disponible. Cooldown normal.
func rechazar() -> void:
	if contrato_disponible.is_empty():
		return
	var c: Dictionary = contrato_disponible
	contrato_disponible = {}
	cooldown_restante = COOLDOWN_BASE_SEG + randf_range(-COOLDOWN_VARIANZA_SEG, COOLDOWN_VARIANZA_SEG)
	contrato_disponible_expirado.emit(c)


## Reset (debug F2).
func reset_completo() -> void:
	if not contrato_activo.is_empty():
		var act: Dictionary = contrato_activo
		contrato_activo = {}
		progreso = 0
		contrato_completado.emit(act, false)
	contrato_disponible = {}
	tiempo_restante = 0.0
	cooldown_restante = PRIMER_COOLDOWN_SEG
	habilitado = false


## Utilidad: definición de un contrato por id.
func get_contrato(id: String) -> Dictionary:
	for c in CONTRATOS:
		if c["id"] == id:
			return c
	return {}


# ============================================================
# INTERNAS
# ============================================================
func _ofrecer_contrato() -> void:
	contrato_disponible = CONTRATOS[randi() % CONTRATOS.size()]
	tiempo_restante = TIEMPO_OFERTA_SEG
	contrato_disponible_aparece.emit(contrato_disponible)


func _finalizar(exito: bool) -> void:
	if contrato_activo.is_empty():
		return
	var c: Dictionary = contrato_activo
	contrato_activo = {}
	progreso = 0
	tiempo_restante = 0.0
	cooldown_restante = COOLDOWN_BASE_SEG + randf_range(-COOLDOWN_VARIANZA_SEG, COOLDOWN_VARIANZA_SEG)
	contrato_completado.emit(c, exito)
