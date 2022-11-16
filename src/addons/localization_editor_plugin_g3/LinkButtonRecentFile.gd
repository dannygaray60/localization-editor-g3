tool
extends HBoxContainer

signal opened(f_path)
signal removed(NodeName,f_path)

var f_path:String

func _ready() -> void:
	$Lnk.text = "%s" % [
		f_path.get_file()
	]
	
	$Lnk.hint_tooltip = "%s/%s" % [
		f_path.get_base_dir(),
		f_path.get_file()
	] 


func _on_BtnRemove_pressed() -> void:
	emit_signal("removed",name, f_path)

func _on_Lnk_pressed() -> void:
	emit_signal("opened",f_path)
