extends Node
##
## GarmentData.gd — AUTOLOAD (FASE 5 · REBALANCE)
## ============================================================
## Cambios de rebalance:
##   - Rewards normales +36% (avg 4.67€ → 6.33€)
##   - Rewards alien ×2 (avg 25€ → 55€), jackpot más visible
##   - ceniza_bonus = 0 en TODAS las alien (la Ceniza sale solo del prestigio)
##   - fragmentos_bonus +1 en cada alien para compensar
##
## Cambio FASE 5: suerte separada en suerte_euros (reseteable) y suerte_ceniza (permanente).
## Cambio depuración: flag _forzar_siguiente_alien para el panel de debug.
##

# ============================================================
# PRENDAS NORMALES
# ============================================================
const PRENDAS_NORMALES: Array[Dictionary] = [
	{
		"id": "camiseta_blanca",
		"nombre": "Camiseta blanca",
		"tipo_mancha": "Ketchup",
		"recompensa": 3.0,
		"color_prenda": Color("#D8D8D8"),
		"color_mancha": Color("#CC2200"),
		"es_alien": false,
		"ceniza_bonus": 0,
		"fragmentos_bonus": 0,
		"forma": "camiseta",
		"texture_path": "res://assets/garments/camiseta_blanca.svg"
	},
	{
		"id": "camisa_oficina",
		"nombre": "Camisa de oficina",
		"tipo_mancha": "Café",
		"recompensa": 4.0,
		"color_prenda": Color("#3A4A6E"),
		"color_mancha": Color("#5C3A1E"),
		"es_alien": false,
		"ceniza_bonus": 0,
		"fragmentos_bonus": 0,
		"forma": "camiseta",
		"texture_path": "res://assets/garments/camisa_oficina.svg"
	},
	{
		"id": "pantalon_vaquero",
		"nombre": "Pantalón vaquero",
		"tipo_mancha": "Barro",
		"recompensa": 6.0,
		"color_prenda": Color("#2B4A7E"),
		"color_mancha": Color("#4A3520"),
		"es_alien": false,
		"ceniza_bonus": 0,
		"fragmentos_bonus": 0,
		"forma": "pantalon",
		"texture_path": "res://assets/garments/pantalon_vaquero.svg"
	},
	{
		"id": "vestido_fiesta",
		"nombre": "Vestido de fiesta",
		"tipo_mancha": "Vino tinto",
		"recompensa": 7.0,
		"color_prenda": Color("#5A1A2E"),
		"color_mancha": Color("#7A0A1E"),
		"es_alien": false,
		"ceniza_bonus": 0,
		"fragmentos_bonus": 0,
		"forma": "vestido",
		"texture_path": "res://assets/garments/vestido_fiesta.svg"
	},
	{
		"id": "abrigo_lana",
		"nombre": "Abrigo de lana",
		"tipo_mancha": "Aceite de motor",
		"recompensa": 8.0,
		"color_prenda": Color("#5A3E28"),
		"color_mancha": Color("#1A1A1A"),
		"es_alien": false,
		"ceniza_bonus": 0,
		"fragmentos_bonus": 0,
		"forma": "abrigo",
		"texture_path": "res://assets/garments/abrigo_lana.svg"
	},
	{
		"id": "traje_negocios",
		"nombre": "Traje de negocios",
		"tipo_mancha": "Sangre",
		"recompensa": 10.0,
		"color_prenda": Color("#1A1A2A"),
		"color_mancha": Color("#8B0000"),
		"es_alien": false,
		"ceniza_bonus": 0,
		"fragmentos_bonus": 0,
		"forma": "abrigo",
		"texture_path": "res://assets/garments/traje_negocios.svg"
	},
]

# ============================================================
# PRENDAS ALIENÍGENAS
# ============================================================
# ceniza_bonus = 0 en todas: la Ceniza sale EXCLUSIVAMENTE del prestigio.
# fragmentos_bonus sube para compensar: alien → progreso narrativo (Fase 6).
const PRENDAS_ALIEN: Array[Dictionary] = [
	{
		"id": "tunica_dimensional",
		"nombre": "Túnica dimensional",
		"tipo_mancha": "Plasma interestelar",
		"recompensa": 30.0,
		"color_prenda": Color("#3A1A5E"),
		"color_mancha": Color("#AA40FF"),
		"es_alien": true,
		"ceniza_bonus": 0,
		"fragmentos_bonus": 2,
		"forma": "vestido",
		"texture_path": "res://assets/garments/tunica_dimensional.svg"
	},
	{
		"id": "traje_vacio",
		"nombre": "Traje de vacío",
		"tipo_mancha": "Materia oscura",
		"recompensa": 45.0,
		"color_prenda": Color("#0A0A1E"),
		"color_mancha": Color("#2A2AFF"),
		"es_alien": true,
		"ceniza_bonus": 0,
		"fragmentos_bonus": 2,
		"forma": "abrigo",
		"texture_path": "res://assets/garments/traje_vacio.svg"
	},
	{
		"id": "manto_observador",
		"nombre": "Manto del Observador",
		"tipo_mancha": "Cronofluido",
		"recompensa": 65.0,
		"color_prenda": Color("#0A2A3E"),
		"color_mancha": Color("#00CCFF"),
		"es_alien": true,
		"ceniza_bonus": 0,
		"fragmentos_bonus": 3,
		"forma": "vestido",
		"texture_path": "res://assets/garments/manto_observador.svg"
	},
	{
		"id": "uniforme_agente",
		"nombre": "Uniforme del Agente",
		"tipo_mancha": "¿Sangre humana?",
		"recompensa": 80.0,
		"color_prenda": Color("#1A1A1A"),
		"color_mancha": Color("#CC0000"),
		"es_alien": true,
		"ceniza_bonus": 0,
		"fragmentos_bonus": 3,
		"forma": "abrigo",
		"texture_path": "res://assets/garments/uniforme_agente.svg"
	},
]

# ============================================================
# SISTEMA DE SUERTE — separado por fuente de mejora
# ============================================================
const PROBABILIDAD_BASE: float = 0.015
const PROBABILIDAD_MAX: float = 0.25

var suerte_euros: float = 0.0    # de upgrades con €, se resetea en prestigio
var suerte_ceniza: float = 0.0   # de upgrades con Ceniza, nunca se resetea

# ============================================================
# DEBUG — forzar siguiente prenda como alien
# ============================================================
var _forzar_siguiente_alien: bool = false


func get_probabilidad_alien() -> float:
	return min(PROBABILIDAD_BASE + suerte_euros + suerte_ceniza, PROBABILIDAD_MAX)


func añadir_suerte(cantidad: float) -> void:
	suerte_euros += cantidad
	suerte_euros = max(suerte_euros, 0.0)


func añadir_suerte_ceniza(cantidad: float) -> void:
	suerte_ceniza += cantidad
	suerte_ceniza = max(suerte_ceniza, 0.0)


func resetear_suerte_euros() -> void:
	suerte_euros = 0.0


func resetear_suerte() -> void:
	suerte_euros = 0.0
	suerte_ceniza = 0.0


## [Debug] Fuerza que la siguiente prenda generada sea alien. Se consume al usarse.
func forzar_siguiente_alien() -> void:
	_forzar_siguiente_alien = true


func get_prenda_aleatoria() -> Dictionary:
	if _forzar_siguiente_alien:
		_forzar_siguiente_alien = false
		return PRENDAS_ALIEN[randi() % PRENDAS_ALIEN.size()].duplicate()
	if randf() < get_probabilidad_alien():
		return PRENDAS_ALIEN[randi() % PRENDAS_ALIEN.size()].duplicate()
	return PRENDAS_NORMALES[randi() % PRENDAS_NORMALES.size()].duplicate()


func get_cola_inicial(cantidad: int) -> Array[Dictionary]:
	var cola: Array[Dictionary] = []
	for i in cantidad:
		cola.append(get_prenda_aleatoria())
	return cola


func get_prenda_por_id(id: String) -> Dictionary:
	for p in PRENDAS_NORMALES:
		if p["id"] == id:
			return p.duplicate()
	for p in PRENDAS_ALIEN:
		if p["id"] == id:
			return p.duplicate()
	push_error("GarmentData: prenda '%s' no encontrada." % id)
	return {}
