extends Panel
##
## PrestigeDialog.gd — FASE 5
## ============================================================
## Panel modal de confirmación del prestigio.
## Muestra un texto narrativo diferente en cada prestigio,
## el preview de Ceniza que se ganará, y dos botones.
##
## Señales:
##   confirmado → el jugador acepta el prestigio
##   cancelado  → el jugador cancela
##

signal confirmado
signal cancelado

# ============================================================
# TEXTOS NARRATIVOS — uno por prestigio, cicla al llegar al final
# ============================================================
const TEXTOS_NARRATIVOS: Array[String] = [
	# Textos del GDD
	"La lavandería ardió a las 3am. Los bomberos encontraron jabón azul fluorescente en todas las paredes. Tú sobreviviste con lo puesto y tus recuerdos.",
	"Esta vez fue inundación. El agua era de un color que no tiene nombre. Tu instinto te hizo coger la caja de detergente antes de salir.",
	"El inspector de Hacienda llegó justo cuando las paredes empezaban a respirar. Cerraste el local sin dar explicaciones.",
	# Textos adicionales
	"El perito del seguro lo catalogó como 'evento de origen no clasificable'. Las paredes quedaron limpias. La mancha del fondo, no.",
	"Alguien dejó encendida la lavadora cuántica toda la noche. Por la mañana el local estaba exactamente igual que el primer día, con todo el jabón sin estrenar.",
	"Los vecinos dijeron que no oyeron nada. Los del primero dijeron que olía a mar. El local está en el centro de una ciudad sin costa.",
	"La gestoría llamó para preguntar si habías cambiado de actividad. En el catastro ahora figuras como 'punto de tránsito sin clasificar'. No preguntaste qué significaba.",
]

# ============================================================
# ESTADO
# ============================================================
var texto_seleccionado: String = ""   # Main lo lee para la animación

var label_narrativo: Label
var label_ceniza: Label


# ============================================================
# INICIALIZACIÓN
# ============================================================
func _ready() -> void:
	_construir_ui()
	visible = false


func _construir_ui() -> void:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("#1A0A0A")
	estilo.border_color = Color("#FF4040")
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(10)
	add_theme_stylebox_override("panel", estilo)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 22
	vbox.offset_right = -22
	vbox.offset_top = 18
	vbox.offset_bottom = -18
	add_child(vbox)

	# Título
	var titulo := Label.new()
	titulo.text = "¿HACER PRESTIGIO?"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_color_override("font_color", Color("#FF4040"))
	titulo.add_theme_font_size_override("font_size", 20)
	vbox.add_child(titulo)

	var sep := HSeparator.new()
	var sep_estilo := StyleBoxFlat.new()
	sep_estilo.bg_color = Color("#3A1A1A")
	sep.add_theme_stylebox_override("separator", sep_estilo)
	vbox.add_child(sep)

	# Texto narrativo
	label_narrativo = Label.new()
	label_narrativo.add_theme_color_override("font_color", Color("#8888BB"))
	label_narrativo.add_theme_font_size_override("font_size", 12)
	label_narrativo.autowrap_mode = TextServer.AUTOWRAP_WORD
	label_narrativo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_narrativo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(label_narrativo)

	# Ceniza ganada (destacada)
	label_ceniza = Label.new()
	label_ceniza.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_ceniza.add_theme_color_override("font_color", Color("#888888"))
	label_ceniza.add_theme_font_size_override("font_size", 17)
	vbox.add_child(label_ceniza)

	# Aviso de lo que se pierde
	var aviso := Label.new()
	aviso.text = "Se perderán: euros, mejoras y lavadoras."
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.add_theme_color_override("font_color", Color("#442222"))
	aviso.add_theme_font_size_override("font_size", 10)
	vbox.add_child(aviso)

	# Botones
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)

	var btn_cancelar := Button.new()
	btn_cancelar.text = "Cancelar"
	btn_cancelar.custom_minimum_size = Vector2(120, 40)
	_estilizar_boton(btn_cancelar, false)
	btn_cancelar.pressed.connect(func(): cancelado.emit())
	hbox.add_child(btn_cancelar)

	var btn_confirmar := Button.new()
	btn_confirmar.text = "COMENZAR DE NUEVO"
	btn_confirmar.custom_minimum_size = Vector2(185, 40)
	_estilizar_boton(btn_confirmar, true)
	btn_confirmar.pressed.connect(func(): confirmado.emit())
	hbox.add_child(btn_confirmar)


# ============================================================
# API PÚBLICA
# ============================================================

## Muestra el diálogo con el texto narrativo del prestigio num_prestige
## y el preview de ceniza que se ganará.
func mostrar(ceniza_preview: int, num_prestige: int) -> void:
	var idx: int = num_prestige % TEXTOS_NARRATIVOS.size()
	texto_seleccionado = TEXTOS_NARRATIVOS[idx]
	label_narrativo.text = texto_seleccionado
	label_ceniza.text = "Ganarás   %d  🜁 Ceniza" % ceniza_preview
	visible = true


# ============================================================
# ESTILOS
# ============================================================
func _estilizar_boton(boton: Button, es_confirmar: bool) -> void:
	var en := StyleBoxFlat.new()
	var di := StyleBoxFlat.new()
	en.set_corner_radius_all(5)
	di.set_corner_radius_all(5)

	if es_confirmar:
		en.bg_color = Color("#FF4040")
		di.bg_color = Color("#AA2020")
		boton.add_theme_color_override("font_color", Color("#FFFFFF"))
		boton.add_theme_color_override("font_disabled_color", Color("#FFAAAA"))
	else:
		en.bg_color = Color("#3A3A6A")
		di.bg_color = Color("#1A1A3A")
		boton.add_theme_color_override("font_color", Color("#AAAACC"))
		boton.add_theme_color_override("font_disabled_color", Color("#555577"))

	boton.add_theme_stylebox_override("normal", en)
	boton.add_theme_stylebox_override("hover", en)
	boton.add_theme_stylebox_override("pressed", di)
	boton.add_theme_stylebox_override("disabled", di)
	boton.add_theme_font_size_override("font_size", 13)
