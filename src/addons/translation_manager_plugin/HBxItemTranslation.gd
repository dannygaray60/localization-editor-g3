tool
extends HBoxContainer

signal extra_data_changed(NodeName)

var key_str : String = "ItemTranslation"
var orig_txt : String
var trans_txt : String

var need_revision : bool = false
var annotations : String

func _ready() -> void:
	
	name = key_str
	
	get_node("%LblOriginalTxt").text = orig_txt
	get_node("%LineEditTranslation").text = trans_txt
	get_node("%LblKeyStr").text = key_str
	
	_on_CheckBoxRevision_toggled(
		$VBxString1/HBoxContainer/CheckBoxRevision.pressed
	)

func _on_CheckBoxRevision_toggled(button_pressed: bool) -> void:
	need_revision = button_pressed
	if need_revision == true:
		$IconNormal.visible = false
		$IconAlert.visible = true
	else:
		$IconNormal.visible = true
		$IconAlert.visible = false
	
	emit_signal("extra_data_changed", name)
