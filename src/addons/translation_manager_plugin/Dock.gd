tool
extends Control

const TranslationItem = preload("res://addons/translation_manager_plugin/HBxItemTranslation.tscn")

var _translations : Dictionary
var _langs : Array

var _selected_str_key : String

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
	
	
	## no hay nada que mostrar
	if _translations.size() == 0 or _langs.size() == 0:
		return

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
	var extra_data_path : String = _current_path+"/translation_manager_extra_data.ini"
	var Conf := ConfigFile.new()
	
	Conf.load(extra_data_path)
	
	## si hay seleccionado ambos idiomas iguales, pero hay mas de un idioma
	## seleccionar el siguient idioma en translangitemlist
	if (
		(get_node("%RefLangItemList").get_selected_id() == get_node("%TransLangItemList").get_selected_id())
		and _langs.size() > 1
	):
		get_node("%TransLangItemList").select(1)
	
	## limpiar lista de traducciones en pantalla
	for t in get_node("%VBxTranslations").get_children():
		t.queue_free()

	for t_key in _translations:
		var TransInstance = TranslationItem.instance()
		
		TransInstance.key_str = t_key
		
		TransInstance.connect("edit_requested", self, "_on_Translation_edit_requested")
		
		TransInstance.orig_txt = _translations[t_key][get_selected_lang("ref")]
		TransInstance.trans_txt = _translations[t_key][get_selected_lang("trans")]
		
		if Conf.has_section_key(t_key, "need_rev") == false:
			Conf.set_value(t_key, "need_rev", false)
		else:
			TransInstance.need_revision = Conf.get_value(t_key, "need_rev", false)
			
		if Conf.has_section_key(t_key, "annotations") == false:
			Conf.set_value(t_key, "annotations", "")
		else:
			TransInstance.annotations = Conf.get_value(t_key, "annotations", false)
		
		get_node("%VBxTranslations").add_child(TransInstance)

	Conf.save(extra_data_path)

## se clickó editar de la traduccion seleccionada
func _on_Translation_edit_requested(TransNodeName:String) -> void:
	
	var TranslationObj = get_node("%VBxTranslations").get_node(TransNodeName)
	
	get_node("%CTCheckEditKey").pressed = false
	_on_CTCheckEditKey_toggled(false)
	get_node("%CTCheckEnableOriginalTxt").pressed = false
	get_node("%TxtOriginalTxt").readonly = true
	
	## setear datos
	
	get_node("%LblOriginalTxt").text = "[%s] Original Text..." % [get_selected_lang("ref").capitalize()]
	get_node("%LblTranslation").text = "[%s] Translation..." % [get_selected_lang("trans").capitalize()]
	
	_selected_str_key = TranslationObj.key_str
	
	get_node("%CTLineEdit").text = TranslationObj.key_str
	get_node("%TxtOriginalTxt").text = TranslationObj.orig_txt
	get_node("%TxtTranslation").text = TranslationObj.trans_txt
	get_node("%TxtAnnotations").text = TranslationObj.annotations
	
	get_node("%DialogEditTranslation").popup_centered()
	
	get_node("%TxtTranslation").grab_focus()

## habilitar edicion o eliminacion de stringkey y toda su traduccion
func _on_CTCheckEditKey_toggled(button_pressed: bool) -> void:
	get_node("%CTLineEdit").editable = button_pressed
	get_node("%CTBtnDeleteKey").disabled = ! button_pressed


## eliminar traduccion en base al string key desde el popup edit
func _on_CTBtnDeleteKey_pressed() -> void:
	#_selected_str_key
	get_node("%DialogEditTranslation").hide()
## guardar datos del string key desde el popup edit
func _on_CTBtnSaveKey_pressed() -> void:
	#_selected_str_key
	get_node("%DialogEditTranslation").hide()

func _on_CTCheckEnableOriginalTxt_toggled(button_pressed: bool) -> void:
	get_node("%TxtOriginalTxt").readonly = ! button_pressed
