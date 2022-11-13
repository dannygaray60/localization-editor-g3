tool
extends Control

const TranslationItem = preload("res://addons/translation_manager_plugin/HBxItemTranslation.tscn")

var _translations : Dictionary
var _langs : Array

var _current_file : String
var _current_path : String

## carpeta en donde se guardan datos internos del addon, como guardar anotaciones de los keystr
var _self_data_folder_path : String = "res://addons/translation_manager_plugin/self_data"

func _ready() -> void:
	
	## conectar señales
	get_node("%MenuFile").get_popup().connect("id_pressed", self, "_on_FileMenu_id_pressed")

	_on_CloseAll()
	
	## si se ejecuta en editor, solo se accederá al res://
	if Engine.is_editor_hint() == true:
		get_node("%FileDialog").access = FileDialog.ACCESS_RESOURCES
	else:
		get_node("%FileDialog").access = FileDialog.ACCESS_FILESYSTEM
		_self_data_folder_path = OS.get_executable_path().get_base_dir() + "/self_data"
	
	## crear directorio self data en caso de no existir
	var Dir := Directory.new()
	if Dir.dir_exists(_self_data_folder_path) == false:
		Dir.make_dir(_self_data_folder_path)

func get_opened_file() -> String:
	return _current_path + "/" + _current_file
	
## obtener el lenguaje seleccionado (ref o trans)
func get_selected_lang(mode:String="ref") -> String:
	var nod : String = "%RefLangItemList"
	if mode != "ref":
		nod = "%TransLangItemList"
	return get_node(nod).get_item_text(
		get_node(nod).selected
	)

func _set_visible_content(vis:bool=true) -> void:
	get_node("%HBxFileAndLangSelect").visible = vis
	get_node("%HBxContentFile").visible = vis

func _on_FileMenu_id_pressed(id:int) -> void:
	match id:
		1:
			get_node("%FileDialog").popup_centered()
		2:
			_on_CloseAll()

func _on_FilesLoaded() -> void:
	_set_visible_content(true)

func _on_CloseAll() -> void:
	## seteo inicial
	_set_visible_content(false)
	_on_Popup_hide()
	## limpiar campos
	_current_file = ""
	_current_path = ""
	get_node("%OpenedFilesList").clear()


## Se muestra u oculta un popup
func _on_Popup_about_to_show() -> void:
	get_node("%PopupBG").visible = true
func _on_Popup_hide() -> void:
	get_node("%PopupBG").visible = false


func _on_FileDialog_files_selected(paths: PoolStringArray) -> void:
	
	if paths.size() == 0:
		_set_visible_content(false)
		return
	
	_current_path = paths[0].get_base_dir()
	
	get_node("%OpenedFilesList").clear()
	
	## mostrar el path del archivo
	get_node("%LblOpenedPath").text = "[%s]" % [_current_path]
	
	var i : int = 0
	for p in paths:
		get_node("%OpenedFilesList").add_item(
			p.get_file(), i
		)
		i += 1
	
	## enviar señal de primer item seleccionado ya que no se activa por default
	_on_OpenedFilesList_item_selected(0)
	
	_on_FilesLoaded()

## se seleccionó un archivo de la lista
func _on_OpenedFilesList_item_selected(index: int) -> void:
	_current_file = get_node("%OpenedFilesList").get_item_text(index)
	
	## diccionario con keys de los textos, y adentro de cada uno otro dict con keys de lenguajes
	## ej: {STRGOODBYE:{en:Goodbye!, es:Adiós!}, STRHELLO:{en:Hello!, es:Hola!}}
	_translations = CSVLoader.load_csv_translation(get_opened_file())
	## obtener array de los idiomas del archivo a partir de los keys del primer item del diccionario
	_langs = _translations[_translations.keys()[0]].keys()
	
	## limpiar listas de langs
	get_node("%RefLangItemList").clear()
	get_node("%TransLangItemList").clear()
	## añadir los idiomas que contiene el archivo
	var i : int = 0
	for l in _langs:
		get_node("%RefLangItemList").add_item(
			l, i
		)
		get_node("%TransLangItemList").add_item(
			l, i
		)
		i += 1
	
	## cargar traducciones
	_on_LangItemList_item_selected(0)

## se cambiado el idioma seleccionado en los itemlist
func _on_LangItemList_item_selected(_index: int) -> void:
	## limpiar lista de traducciones en pantalla
	for t in get_node("%VBxTranslations").get_children():
		t.queue_free()

	for t_key in _translations:
		var TransInstance = TranslationItem.instance()
		
		TransInstance.key_str = t_key
		
		TransInstance.orig_txt = _translations[t_key][get_selected_lang("ref")]
		TransInstance.trans_txt = _translations[t_key][get_selected_lang("trans")]
		
		get_node("%VBxTranslations").add_child(TransInstance)
