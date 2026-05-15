extends Node
##
## Stats.gd — AUTOLOAD (FASE 8)
## ============================================================
## Sistema de estadísticas + logros. Todos los contadores son
## permanentes (sobreviven al prestigio y al cierre del juego).
##
## Main.gd llama a:
##   Stats.incrementar(stat_id, n)            → suma a un contador
##   Stats.set_max(stat_id, valor)            → guarda el máximo
##   Stats.notificar_evento(evento_id)        → desbloqueo directo de logros tipo "evento"
##
## El propio Stats emite:
##   logro_desbloqueado(id) → Main lo escucha para la notificación animada
##

# ============================================================
# DEFINICIÓN DE STATS
# ============================================================
# Lista canónica de IDs. Cualquier otro id en incrementar() emite warning.
const STAT_IDS: Array[String] = [
	"prendas_total_manual",
	"prendas_total_lavadora",
	"aliens_total_manual",
	"aliens_total_lavadora",
	"euros_total_historico",
	"ceniza_total_historico",
	"fragmentos_total_historico",
	"prestigios_total",
	"max_euros_en_run",          # max (no suma)
	"lavadoras_basicas_compradas",
	"lavadoras_industriales_compradas",
	"lavadoras_cuanticas_compradas",
	"upgrades_euros_comprados",
	"upgrades_ceniza_comprados",
	"upgrades_fragmentos_comprados",
	"tiempo_jugado_seg",
	# Fase 10
	"eventos_completados",
	"vips_completados",
	# Fase 13
	"contratos_completados",
]


# ============================================================
# DEFINICIÓN DE LOGROS
# ============================================================
# tipo = "stat":   se desbloquea cuando contadores[stat] >= umbral
# tipo = "evento": se desbloquea cuando Main llama notificar_evento(id)
const LOGROS: Array[Dictionary] = [
	# Limpieza
	{"id": "primera_mancha", "nombre": "Primera mancha", "descripcion": "Limpia tu primera prenda.",
	 "categoria": "Limpieza", "icono": "🧺",
	 "tipo": "stat", "stat": "prendas_total_manual", "umbral": 1},
	{"id": "limpiador_50", "nombre": "Limpiador profesional", "descripcion": "Limpia 50 prendas a mano.",
	 "categoria": "Limpieza", "icono": "🧽",
	 "tipo": "stat", "stat": "prendas_total_manual", "umbral": 50},
	{"id": "limpiador_500", "nombre": "Maestro de la limpieza", "descripcion": "Limpia 500 prendas a mano.",
	 "categoria": "Limpieza", "icono": "⭐",
	 "tipo": "stat", "stat": "prendas_total_manual", "umbral": 500},
	{"id": "limpiador_5000", "nombre": "Leyenda del jabón", "descripcion": "Limpia 5000 prendas a mano.",
	 "categoria": "Limpieza", "icono": "👑",
	 "tipo": "stat", "stat": "prendas_total_manual", "umbral": 5000},

	# Alien
	{"id": "contacto", "nombre": "Contacto", "descripcion": "Limpia tu primera prenda alien.",
	 "categoria": "Alien", "icono": "👽",
	 "tipo": "stat", "stat": "aliens_total_manual", "umbral": 1},
	{"id": "cazador_alien_10", "nombre": "Cazador alien", "descripcion": "Limpia 10 prendas alien.",
	 "categoria": "Alien", "icono": "🛸",
	 "tipo": "evento"},  # se notifica desde Main sumando ambas vías
	{"id": "coleccionista_alien_50", "nombre": "Coleccionista alien", "descripcion": "Limpia 50 prendas alien.",
	 "categoria": "Alien", "icono": "🌌",
	 "tipo": "evento"},

	# Economía
	{"id": "primer_billete", "nombre": "Primer billete", "descripcion": "Gana 100€ en total.",
	 "categoria": "Economía", "icono": "💵",
	 "tipo": "stat", "stat": "euros_total_historico", "umbral": 100},
	{"id": "empresario", "nombre": "Empresario", "descripcion": "Gana 10.000€ en total.",
	 "categoria": "Economía", "icono": "💼",
	 "tipo": "stat", "stat": "euros_total_historico", "umbral": 10000},
	{"id": "magnate", "nombre": "Magnate", "descripcion": "Gana 1.000.000€ en total.",
	 "categoria": "Economía", "icono": "💎",
	 "tipo": "stat", "stat": "euros_total_historico", "umbral": 1000000},
	{"id": "cuenta_llena", "nombre": "Cuenta llena", "descripcion": "Acumula 5.000€ en una sola run.",
	 "categoria": "Economía", "icono": "🏦",
	 "tipo": "stat", "stat": "max_euros_en_run", "umbral": 5000},

	# Prestigio
	{"id": "renacer", "nombre": "Renacer", "descripcion": "Realiza tu primer prestigio.",
	 "categoria": "Prestigio", "icono": "🔥",
	 "tipo": "stat", "stat": "prestigios_total", "umbral": 1},
	{"id": "reincidente", "nombre": "Reincidente", "descripcion": "Realiza 5 prestigios.",
	 "categoria": "Prestigio", "icono": "♻",
	 "tipo": "stat", "stat": "prestigios_total", "umbral": 5},
	{"id": "eterno", "nombre": "Eterno", "descripcion": "Realiza 25 prestigios.",
	 "categoria": "Prestigio", "icono": "♾",
	 "tipo": "stat", "stat": "prestigios_total", "umbral": 25},

	# Hitos
	{"id": "industrialista", "nombre": "Industrialista", "descripcion": "Compra una lavadora industrial.",
	 "categoria": "Hitos", "icono": "🏭",
	 "tipo": "stat", "stat": "lavadoras_industriales_compradas", "umbral": 1},
	{"id": "cuantico", "nombre": "Cuántico", "descripcion": "Compra una lavadora cuántica.",
	 "categoria": "Hitos", "icono": "🌀",
	 "tipo": "stat", "stat": "lavadoras_cuanticas_compradas", "umbral": 1},
	{"id": "iluminado", "nombre": "Iluminado", "descripcion": "Compra una mejora del Altar.",
	 "categoria": "Hitos", "icono": "✧",
	 "tipo": "stat", "stat": "upgrades_fragmentos_comprados", "umbral": 1},
	{"id": "polifacetico", "nombre": "Polifacético", "descripcion": "Compra al menos una mejora de cada tienda.",
	 "categoria": "Hitos", "icono": "🎭",
	 "tipo": "evento"},
	{"id": "susurrador", "nombre": "Susurrador", "descripcion": "Desbloquea las dos prendas alien del Altar.",
	 "categoria": "Hitos", "icono": "🗝",
	 "tipo": "evento"},

	# Eventos (Fase 10)
	{"id": "primera_ronda", "nombre": "Primera ronda", "descripcion": "Vive tu primer evento aleatorio.",
	 "categoria": "Eventos", "icono": "⚡",
	 "tipo": "evento"},
	{"id": "cliente_fiel", "nombre": "Cliente fiel", "descripcion": "Completa un pedido VIP.",
	 "categoria": "Eventos", "icono": "🎩",
	 "tipo": "evento"},
	{"id": "habitual", "nombre": "Habitual", "descripcion": "Vive 10 eventos aleatorios.",
	 "categoria": "Eventos", "icono": "📅",
	 "tipo": "evento"},
	{"id": "vip_frecuente", "nombre": "VIP frecuente", "descripcion": "Completa 5 pedidos VIP.",
	 "categoria": "Eventos", "icono": "💼",
	 "tipo": "evento"},

	# Tutorial (Fase 11A)
	{"id": "aprendiz_aplicado", "nombre": "Aprendiz aplicado", "descripcion": "Completa el tutorial sin saltarlo.",
	 "categoria": "Hitos", "icono": "🎓",
	 "tipo": "evento"},
	{"id": "sin_entrenamiento", "nombre": "Sin entrenamiento", "descripcion": "Salta el tutorial.",
	 "categoria": "Hitos", "icono": "🏃",
	 "tipo": "evento"},

	# Contratos (Fase 13)
	{"id": "primer_contrato", "nombre": "Primer encargo", "descripcion": "Completa tu primer contrato.",
	 "categoria": "Eventos", "icono": "📋",
	 "tipo": "evento"},
	{"id": "contratista_habitual", "nombre": "Contratista habitual", "descripcion": "Completa 10 contratos.",
	 "categoria": "Eventos", "icono": "🗂",
	 "tipo": "evento"},

	# Bestiario (Fase 16)
	{"id": "bestiario_normales", "nombre": "Catálogo civil", "descripcion": "Investiga las 6 prendas normales.",
	 "categoria": "Hitos", "icono": "📖",
	 "tipo": "evento"},
	{"id": "bestiario_completo", "nombre": "Bestiario completo", "descripcion": "Investiga las 12 prendas, alien incluidas.",
	 "categoria": "Hitos", "icono": "📚",
	 "tipo": "evento"},

	# Aliados (Fase 17)
	{"id": "primer_aliado", "nombre": "Primer aliado", "descripcion": "Contrata a tu primer aliado.",
	 "categoria": "Hitos", "icono": "🤝",
	 "tipo": "evento"},
	{"id": "circulo_completo", "nombre": "Círculo completo", "descripcion": "Contrata a los 5 aliados.",
	 "categoria": "Hitos", "icono": "🌟",
	 "tipo": "evento"},
]


# ============================================================
# ESTADO
# ============================================================
var contadores: Dictionary = {}
var desbloqueados: Array[String] = []
# Fase 16: set de prendas investigadas (limpiadas al menos una vez, por id)
var prendas_investigadas: Array[String] = []

# Para "evento" se nota el desbloqueo desde fuera; lo guardamos aquí.
# Para "stat", el chequeo se hace en _check_stat_logros.

signal logro_desbloqueado(id: String)
signal stat_changed(stat_id: String, new_value: float)
signal prenda_investigada(id: String, total: int)


# ============================================================
# INICIALIZACIÓN
# ============================================================
func _ready() -> void:
	for sid in STAT_IDS:
		contadores[sid] = 0.0


# Acumula tiempo de juego automáticamente
func _process(delta: float) -> void:
	contadores["tiempo_jugado_seg"] = float(contadores.get("tiempo_jugado_seg", 0.0)) + delta


# ============================================================
# API PÚBLICA
# ============================================================
func incrementar(stat_id: String, n: float = 1.0) -> void:
	if not contadores.has(stat_id):
		push_warning("Stats.incrementar: stat desconocido '%s'" % stat_id)
		return
	contadores[stat_id] = float(contadores[stat_id]) + n
	stat_changed.emit(stat_id, contadores[stat_id])
	_check_stat_logros(stat_id)


func set_max(stat_id: String, valor: float) -> void:
	if not contadores.has(stat_id):
		push_warning("Stats.set_max: stat desconocido '%s'" % stat_id)
		return
	if valor > float(contadores[stat_id]):
		contadores[stat_id] = valor
		stat_changed.emit(stat_id, valor)
		_check_stat_logros(stat_id)


func get_stat(stat_id: String) -> float:
	return float(contadores.get(stat_id, 0.0))


## [Fase 16] Marca una prenda como investigada (vista al menos una vez).
## Devuelve true si era nueva. Emite señal `prenda_investigada` para que Main
## actualice el bonus pasivo.
func investigar_prenda(prenda_id: String) -> bool:
	if prenda_id.is_empty() or prenda_id in prendas_investigadas:
		return false
	prendas_investigadas.append(prenda_id)
	prenda_investigada.emit(prenda_id, prendas_investigadas.size())
	return true


## Llamada para desbloquear logros tipo "evento" desde Main.
func notificar_evento(logro_id: String) -> void:
	if logro_id in desbloqueados:
		return
	for logro in LOGROS:
		if logro["id"] == logro_id and logro["tipo"] == "evento":
			_desbloquear(logro_id)
			return


# ============================================================
# CHEQUEO DE LOGROS TIPO STAT
# ============================================================
func _check_stat_logros(stat_id: String) -> void:
	var valor: float = float(contadores[stat_id])
	for logro in LOGROS:
		if logro["tipo"] != "stat":
			continue
		if logro["stat"] != stat_id:
			continue
		if logro["id"] in desbloqueados:
			continue
		if valor >= float(logro["umbral"]):
			_desbloquear(logro["id"])


func _desbloquear(logro_id: String) -> void:
	desbloqueados.append(logro_id)
	logro_desbloqueado.emit(logro_id)


# ============================================================
# UTILIDADES PARA EL OVERLAY
# ============================================================
func get_logro(logro_id: String) -> Dictionary:
	for l in LOGROS:
		if l["id"] == logro_id:
			return l
	return {}


func get_categorias() -> Array[String]:
	var cats: Array[String] = []
	for l in LOGROS:
		var c: String = String(l["categoria"])
		if c not in cats:
			cats.append(c)
	return cats


func get_logros_de_categoria(categoria: String) -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for l in LOGROS:
		if String(l["categoria"]) == categoria:
			lista.append(l)
	return lista


func progreso_logros() -> Dictionary:
	return {"desbloqueados": desbloqueados.size(), "total": LOGROS.size()}


## Devuelve el valor "current/umbral" para mostrar progreso en logros tipo stat.
## Para "evento" devuelve {} (no aplica).
func get_progreso(logro_id: String) -> Dictionary:
	var logro: Dictionary = get_logro(logro_id)
	if logro.is_empty() or logro["tipo"] != "stat":
		return {}
	return {
		"actual": float(contadores.get(logro["stat"], 0.0)),
		"umbral": float(logro["umbral"]),
	}


# ============================================================
# PERSISTENCIA
# ============================================================
func serializar() -> Dictionary:
	return {
		"contadores": contadores.duplicate(),
		"desbloqueados": desbloqueados.duplicate(),
		"prendas_investigadas": prendas_investigadas.duplicate(),
	}


func cargar_estado(data: Dictionary) -> void:
	# Reset a defaults
	for sid in STAT_IDS:
		contadores[sid] = 0.0
	desbloqueados.clear()
	prendas_investigadas.clear()

	# Cargar contadores conocidos
	var c: Dictionary = data.get("contadores", {})
	for k in c.keys():
		var sk := String(k)
		if contadores.has(sk):
			contadores[sk] = float(c[k])

	# Cargar logros conocidos
	var lst: Array = data.get("desbloqueados", [])
	for id_v in lst:
		var sid := String(id_v)
		# Solo aceptar IDs que sigan existiendo
		if not get_logro(sid).is_empty() and sid not in desbloqueados:
			desbloqueados.append(sid)

	# Fase 16: prendas investigadas (sin validación contra GarmentData
	# para evitar dependencias circulares al cargar)
	var lstp: Array = data.get("prendas_investigadas", [])
	for id_v in lstp:
		var sid := String(id_v)
		if not sid.is_empty() and sid not in prendas_investigadas:
			prendas_investigadas.append(sid)


func reset_completo() -> void:
	for sid in STAT_IDS:
		contadores[sid] = 0.0
	desbloqueados.clear()
	prendas_investigadas.clear()
