extends Node
##
## GarmentData.gd — AUTOLOAD (FASE 2 · BALANCE SCRATCHCARD)
## ============================================================
## Sistema tipo Scritchy Scratchy:
##  - Probabilidad base de alien MUY baja (1.5%)
##  - "Suerte" acumulable mediante upgrades y prestigio
##  - Tope máximo para que nunca se sienta gratis
##
## Recompensas reducidas para grind más satisfactorio.
##

# ============================================================
# PRENDAS NORMALES
# ============================================================
const PRENDAS_NORMALES: Array[Dictionary] = [
	{
		"id": "camiseta_blanca",
		"nombre": "Camiseta blanca",
		"tipo_mancha": "Ketchup",
		"recompensa": 2.0,
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
		"recompensa": 3.0,
		"color_prenda": Color("#3A4A6E"),
		"color_mancha": Color("#5C3A1E"),
		"es_alien": false,
		"ceniza_bonus": 0,
		"fragmentos_bonus": 0,
		"forma": "camiseta",
		"texture_path": "res://assets/garments/camiseta_blanca.svg" #¿?
	},
	{
		"id": "pantalon_vaquero",
		"nombre": "Pantalón vaquero",
		"tipo_mancha": "Barro",
		"recompensa": 4.0,
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
		"recompensa": 5.0,
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
		"recompensa": 6.0,
		"color_prenda": Color("#5A3E28"),
		"color_mancha": Color("#1A1A1A"),
		"es_alien": false,
		"ceniza_bonus": 0,
		"fragmentos_bonus": 0,
		"forma": "abrigo",
		"texture_path": "res://assets/garments/camiseta_blanca.svg" #¿?
	},
	{
		"id": "traje_negocios",
		"nombre": "Traje de negocios",
		"tipo_mancha": "Sangre",
		"recompensa": 8.0,
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
# PRENDAS ALIENÍGENAS (jackpot raro)
# ============================================================
const PRENDAS_ALIEN: Array[Dictionary] = [
	{
		"id": "tunica_dimensional",
		"nombre": "Túnica dimensional",
		"tipo_mancha": "Plasma interestelar",
		"recompensa": 15.0,
		"color_prenda": Color("#3A1A5E"),
		"color_mancha": Color("#AA40FF"),
		"es_alien": true,
		"ceniza_bonus": 1,
		"fragmentos_bonus": 1,
		"forma": "vestido",
		"texture_path": "res://assets/garments/tunica_dimensional.svg"
	},
	{
		"id": "traje_vacio",
		"nombre": "Traje de vacío",
		"tipo_mancha": "Materia oscura",
		"recompensa": 20.0,
		"color_prenda": Color("#0A0A1E"),
		"color_mancha": Color("#2A2AFF"),
		"es_alien": true,
		"ceniza_bonus": 1,
		"fragmentos_bonus": 1,
		"forma": "abrigo",
		"texture_path": "res://assets/garments/traje_vacio.svg"
	},
	{
		"id": "manto_observador",
		"nombre": "Manto del Observador",
		"tipo_mancha": "Cronofluido",
		"recompensa": 28.0,
		"color_prenda": Color("#0A2A3E"),
		"color_mancha": Color("#00CCFF"),
		"es_alien": true,
		"ceniza_bonus": 1,
		"fragmentos_bonus": 2,
		"forma": "vestido",
		"texture_path": "res://assets/garments/manto_observador.svg"
	},
	{
		"id": "uniforme_agente",
		"nombre": "Uniforme del Agente",
		"tipo_mancha": "¿Sangre humana?",
		"recompensa": 40.0,
		"color_prenda": Color("#1A1A1A"),
		"color_mancha": Color("#CC0000"),
		"es_alien": true,
		"ceniza_bonus": 2,
		"fragmentos_bonus": 2,
		"forma": "abrigo",
		"texture_path": "res://assets/garments/uniforme_agente.svg"
	},
]

# ============================================================
# SISTEMA DE SUERTE (estilo Scritchy Scratchy)
# ============================================================
const PROBABILIDAD_BASE: float = 0.015   # 1.5% sin mejoras (1 de cada ~67)
const PROBABILIDAD_MAX: float = 0.25     # 25% — tope máximo con upgrades

var suerte_acumulada: float = 0.0        # Bonus de upgrades/prestigio


# ============================================================
# API PÚBLICA — PROBABILIDAD
# ============================================================

## Devuelve la probabilidad final de que salga una alien.
## Es la suma de la base + suerte acumulada, capada al máximo.
func get_probabilidad_alien() -> float:
	return min(PROBABILIDAD_BASE + suerte_acumulada, PROBABILIDAD_MAX)


## Suma una cantidad a la suerte acumulada (la usan upgrades de tienda).
## Ej: añadir_suerte(0.01) sube la probabilidad un +1%.
func añadir_suerte(cantidad: float) -> void:
	suerte_acumulada += cantidad
	suerte_acumulada = max(suerte_acumulada, 0.0)
	print("Suerte acumulada: %.1f%% (probabilidad final: %.1f%%)" % [
		suerte_acumulada * 100.0,
		get_probabilidad_alien() * 100.0
	])


## Resetea la suerte (útil al hacer prestigio si se quiere).
## OJO: por defecto el prestigio NO resetea suerte si viene de Ceniza permanente.
func resetear_suerte() -> void:
	suerte_acumulada = 0.0


# ============================================================
# API PÚBLICA — PRENDAS
# ============================================================

## Devuelve una prenda aleatoria según la probabilidad actual.
func get_prenda_aleatoria() -> Dictionary:
	if randf() < get_probabilidad_alien():
		return PRENDAS_ALIEN[randi() % PRENDAS_ALIEN.size()].duplicate()
	else:
		return PRENDAS_NORMALES[randi() % PRENDAS_NORMALES.size()].duplicate()


## Devuelve N prendas aleatorias para llenar la cola inicial.
func get_cola_inicial(cantidad: int) -> Array[Dictionary]:
	var cola: Array[Dictionary] = []
	for i in cantidad:
		cola.append(get_prenda_aleatoria())
	return cola


## Devuelve una prenda concreta por su ID.
func get_prenda_por_id(id: String) -> Dictionary:
	for p in PRENDAS_NORMALES:
		if p["id"] == id:
			return p.duplicate()
	for p in PRENDAS_ALIEN:
		if p["id"] == id:
			return p.duplicate()
	push_error("GarmentData: prenda '%s' no encontrada." % id)
	return {}
