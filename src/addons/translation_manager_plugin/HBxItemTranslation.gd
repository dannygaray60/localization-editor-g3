tool
extends HBoxContainer

signal edit_requested(NodeName)
#signal extra_data_changed(NodeName)

var has_translation : bool

var key_str : String = "ItemTranslation"
var orig_txt : String
var trans_txt : String

var need_revision : bool = false
var annotations : String

var _focused : bool = false

func _ready() -> void:
	
	$VBxString1/HBoxContainer/CheckBoxRevision.pressed = need_revision
	
	name = key_str
	
	get_node("%LblOriginalTxt").text = orig_txt
	get_node("%LineEditTranslation").text = trans_txt
	get_node("%LblKeyStr").text = key_str
	
	_on_CheckBoxRevision_toggled(
		$VBxString1/HBoxContainer/CheckBoxRevision.pressed
	)
	
	_on_LineEditTranslation_text_changed(trans_txt)

func _process(delta: float) -> void:
	
	if _focused == false:
		return

	if Input.is_action_just_pressed("ui_accept"):
		##TODO que al hacer enter pasar al siguiente lineedit
		pass

func _on_CheckBoxRevision_toggled(button_pressed: bool) -> void:
	need_revision = button_pressed
	if need_revision == true:
		$IconNormal.visible = false
		$IconAlert.visible = true
	else:
		$IconNormal.visible = true
		$IconAlert.visible = false
	
	#emit_signal("extra_data_changed", name)


func _on_LineEditTranslation_focus_entered() -> void:
	_focused = true
func _on_LineEditTranslation_focus_exited() -> void:
	_focused = false


func _on_LineEditTranslation_text_changed(new_text: String) -> void:
	
	new_text = new_text.replace(" ", "")
	
	if new_text.empty() == true:
		get_node("%LineEditTranslation").modulate = Color("ce5f5f")
		has_translation = false
	else:
		get_node("%LineEditTranslation").modulate = Color("ffffff")
		has_translation = true


func _on_BtnEdit_pressed() -> void:
	emit_signal("edit_requested", name)
