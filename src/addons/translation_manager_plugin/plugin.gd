tool
extends EditorPlugin

const icon = preload("res://addons/translation_manager_plugin/icon.svg")

const Dock = preload("res://addons/translation_manager_plugin/Dock.tscn")
var dock_instance

func _enter_tree() -> void:
	dock_instance = Dock.instance()
	# Add the main panel to the editor's main viewport.
	get_editor_interface().get_editor_viewport().add_child(dock_instance)
	# Hide the main panel. Very much required.
	make_visible(false)

func _exit_tree():
	if dock_instance:
		dock_instance.queue_free()

func has_main_screen():
	return true

func make_visible(visible):
	if dock_instance:
		dock_instance.visible = visible

func get_plugin_name():
	return "Localization"

func get_plugin_icon():
	return icon
