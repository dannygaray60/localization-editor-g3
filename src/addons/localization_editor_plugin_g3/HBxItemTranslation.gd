tool
extends HBoxContainer

signal translate_requested(NodeName, base_text)
signal text_updated(NodeName,key_str,txt)
signal edit_requested(NodeName)
signal need_revision_check_pressed(StringKey, pressed)

var focus_on_ready : bool

var key_str : String = "ItemTranslation" setget _key_str_txt_changed
var orig_txt : String = "Original Text" setget _orig_txt_changed
var trans_txt : String = "Text Translated" setget update_trans_txt

var need_revision : bool = false
var annotations : String ## no está siendo usado con relevancia...

var _focused : bool = false

## flag para evitar emitir señales apenas el objeto se añade al tree
var _is_ready_for_emit_signals : bool

func _ready() -> void:
	
	$VBxString1/HBoxContainer/CheckBoxRevision.pressed = need_revision
	
	name = key_str

	_on_CheckBoxRevision_toggled(
		$VBxString1/HBoxContainer/CheckBoxRevision.pressed
	)

	_on_LineEditTranslation_text_changed(trans_txt)
	
	_is_ready_for_emit_signals = true
	
	if focus_on_ready == true:
		get_node("%LineEditTranslation").grab_focus()
		get_node("%LineEditTranslation").caret_position = get_node("%LineEditTranslation").text.length()

#func _process(delta: float) -> void:
#
#	if _focused == false:
#		return
#
#	if Input.is_action_just_pressed("ui_accept"):
#		##TODO que al hacer enter pasar al siguiente lineedit
#		pass

func has_translation() -> bool:
	return ! get_node("%LineEditTranslation").text.strip_edges().empty()

## la variable orig_txt ha cambiado
func _orig_txt_changed(txt:String) -> void:
	orig_txt = txt
	
	if orig_txt.empty() == true:
		orig_txt = "EMPTY TEXT"
	
	get_node("%LblOriginalTxt").text = orig_txt
	## desactivado ya que puede confundir con el contenido de traduccion los puntos suspensivos
	## recortar texto largo (funciona?)
#	if orig_txt.length() > 10:
#		get_node("%LblOriginalTxt").text.erase(0,10)
#		get_node("%LblOriginalTxt").text = get_node("%LblOriginalTxt").text + "..." 

func update_trans_txt(txt:String) -> void:
	trans_txt = txt
	get_node("%LineEditTranslation").text = trans_txt
	## ocultar texto original si es lo mismo que la traduccion
	## ocuyltar tambien el boton translate
#	if trans_txt == orig_txt:
#		#get_node("%LblOriginalTxt").visible = false
#		get_node("%BtnTranslate").visible = false
#	else:
#		#get_node("%LblOriginalTxt").visible = true
#		get_node("%BtnTranslate").visible = true
	
	_on_LineEditTranslation_text_changed(trans_txt)

func _key_str_txt_changed(txt:String) -> void:
	key_str = txt
	get_node("%LblKeyStr").text = "Identifier: " + key_str

func _on_CheckBoxRevision_toggled(button_pressed: bool) -> void:
	need_revision = button_pressed
	if need_revision == true:
		$IconNormal.visible = false
		$IconAlert.visible = true
	else:
		$IconNormal.visible = true
		$IconAlert.visible = false
	
	if _is_ready_for_emit_signals == true:
		emit_signal("need_revision_check_pressed", key_str, need_revision)

func _on_LineEditTranslation_focus_entered() -> void:
	_focused = true
func _on_LineEditTranslation_focus_exited() -> void:
	_focused = false


func _on_LineEditTranslation_text_changed(new_text: String) -> void:
	
	new_text = new_text.strip_edges()
	
	if new_text.empty() == true:
		get_node("%LineEditTranslation").modulate = Color("ce5f5f")
		#has_translation = false
	else:
		get_node("%LineEditTranslation").modulate = Color("ffffff")
		#has_translation = true
	
	if _is_ready_for_emit_signals == true:
		emit_signal("text_updated", name, key_str, get_node("%LineEditTranslation").text)

	trans_txt = new_text

func _on_BtnEdit_pressed() -> void:
	emit_signal("edit_requested", name)

func _on_BtnTranslate_pressed() -> void:
	trans_txt = "Translating: [%s] please wait..." % [orig_txt]
	get_node("%LineEditTranslation").text = trans_txt
	emit_signal("translate_requested", name, orig_txt)
