tool
extends Control

##Por ahora, al cargar un csv, primero se cargan todas las lineas del csv,
##luego se recorren esas lineas y en cada ciclo se añade el translationpanel
##TODO esto equivale a recorrer dos veces todas las lineas
##en vez de eso, enviar señal con cada linea csv cargada, y en esa señal añadir el paneltranslation
##para optimizar tiempo de carga

const TranslationItem = preload("res://addons/translation_manager_plugin/HBxItemTranslation.tscn")

var Conf := ConfigFile.new()

var _translations : Dictionary
var _langs : Array

var _selected_translation_panel : String

var _current_file : String
var _current_path : String

## carpeta en donde se guardan datos internos del addon, como guardar anotaciones de los keystr
var _self_data_folder_path : String = "res://addons/translation_manager_plugin"

onready var ApiTranslate = $ApiTranslate

func _ready() -> void:
	
	## conectar señales
	get_node("%MenuFile").get_popup().connect("id_pressed", self, "_on_FileMenu_id_pressed")
	get_node("%MenuEdit").get_popup().connect("id_pressed", self, "_on_EditMenu_id_pressed")

	_on_CloseAll()
	
	## si se ejecuta en editor, solo se accederá al res://
	if Engine.is_editor_hint() == true:
		get_node("%FileDialog").access = FileDialog.ACCESS_RESOURCES
	else:
		get_node("%FileDialog").access = FileDialog.ACCESS_FILESYSTEM
		_self_data_folder_path = OS.get_executable_path().get_base_dir()
	
	## crear directorio self data en caso de no existir
	var Dir := Directory.new()
	if Dir.dir_exists(_self_data_folder_path) == false:
		Dir.make_dir(_self_data_folder_path)

	get_node("%TxtSettingFCell").text = Conf.get_value("csv","f_cell","keys")
	get_node("%TxtSettingDelimiter").text = Conf.get_value("csv","delimiter",",")

	Conf.load(_self_data_folder_path+"/translation_manager_conf.ini")
	Conf.save(_self_data_folder_path+"/translation_manager_conf.ini")

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

func _on_EditMenu_id_pressed(id:int) -> void:
	match id:
		3:
			## abrir ajustes del programa
			get_node("%Preferences").popup_centered()

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
	_translations = CSVLoader.load_csv_translation(get_opened_file(), Conf)
	
	## no hay nada que mostrar
	if _translations.size() == 0 and _langs.size() == 0:
		return
	
	if _translations.size() > 0:
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

	## si hay seleccionado ambos idiomas iguales, pero hay mas de un idioma
	## seleccionar el siguient idioma en translangitemlist
	if (
		(get_node("%RefLangItemList").get_selected_id() == get_node("%TransLangItemList").get_selected_id())
		and _langs.size() > 1
	):
		get_node("%TransLangItemList").select(1)

	## cargar traducciones
	_on_LangItemList_item_selected(0)

## se cambiado el idioma seleccionado en los itemlist
## esto hace perder cualquier cambio no gaurdado
## cargar paneles de traduccion
func _on_LangItemList_item_selected(_index: int) -> void:
	var extra_data_path : String = _current_path+"/translation_manager_extra_data.ini"
	var TransConf := ConfigFile.new()
	
	get_node("%LblCurrentFTitle").text = get_node("%LblCurrentFTitle").text.replace("(*)","")
	
	_selected_translation_panel = ""
	
	TransConf.load(extra_data_path)
	
	## limpiar lista de traducciones en pantalla
	for t in get_node("%VBxTranslations").get_children():
		t.queue_free()

	for t_key in _translations:
		var TransInstance = TranslationItem.instance()
		
		TransInstance.connect("translate_requested", self, "_on_Translation_translate_requested")
		TransInstance.connect("text_updated", self, "_on_Translation_text_updated")
		TransInstance.connect("edit_requested", self, "_on_Translation_edit_requested")
		TransInstance.connect("need_revision_check_pressed", self, "_on_Translation_need_revision_check_pressed")
		
		TransInstance.key_str = t_key
		
		TransInstance.orig_txt = _translations[t_key][get_selected_lang("ref")]
		TransInstance.trans_txt = _translations[t_key][get_selected_lang("trans")]
		
		if TransConf.has_section_key(t_key, "need_rev") == false:
			TransConf.set_value(t_key, "need_rev", false)
		else:
			TransInstance.need_revision = TransConf.get_value(t_key, "need_rev", false)
			
		if TransConf.has_section_key(t_key, "annotations") == false:
			TransConf.set_value(t_key, "annotations", "")
		else:
			TransInstance.annotations = TransConf.get_value(t_key, "annotations", false)
		
		get_node("%VBxTranslations").add_child(TransInstance)

	TransConf.save(extra_data_path)
	get_node("%LblCurrentFTitle").text = get_node("%LblCurrentFTitle").text.replace("(*)","")

## se solicitó traduccion
func _on_Translation_translate_requested(TransNodeName:String, text_to_trans:String) -> void:
	ApiTranslate.translate(
		get_selected_lang("ref"),
		get_selected_lang("trans"),
		text_to_trans, TransNodeName
	)

## se clickó boton editar de la traduccion seleccionada
func _on_Translation_edit_requested(TransNodeName:String) -> void:
	
	_selected_translation_panel = TransNodeName
	
	var TranslationObj = get_node("%VBxTranslations").get_node(TransNodeName)
	
	get_node("%CTCheckEditKey").pressed = false
	_on_CTCheckEditKey_toggled(false)
	get_node("%CTCheckEnableOriginalTxt").pressed = false
	get_node("%TxtOriginalTxt").readonly = true
	
	## setear datos
	
	get_node("%LblOriginalTxt").text = "[%s] Original Text" % [get_selected_lang("ref").capitalize()]
	get_node("%LblTranslation").text = "[%s] Translation" % [get_selected_lang("trans").capitalize()]
	
	get_node("%CTLineEdit").text = TranslationObj.key_str
	get_node("%TxtOriginalTxt").text = TranslationObj.orig_txt
	get_node("%TxtTranslation").text = TranslationObj.trans_txt
	get_node("%TxtAnnotations").text = TranslationObj.annotations
	
	## ocultar panel de texto de referencia si se edita el mismo idioma
	if get_selected_lang("ref") == get_selected_lang("trans"):
		get_node("%VBxRefText").visible = false
		## tambien ocultar barra de diferencia
		get_node("%DifferenceBar").visible = false
	else:
		get_node("%VBxRefText").visible = true
		get_node("%DifferenceBar").visible = true
	
	_on_TextEditPanel_text_changed()
	
	get_node("%DialogEditTranslation").popup_centered()
	
	get_node("%TxtTranslation").grab_focus()

## se editó el line edit de la traduccion seleccionada
func _on_Translation_text_updated(NodeName:String, keystr:String, txt:String) -> void:
	_translations[keystr][get_selected_lang("trans")] = txt
	## mostrar signo de no haber guardado cambios
	if get_node("%LblCurrentFTitle").text.begins_with("(*)") == false:
		get_node("%LblCurrentFTitle").text = "(*)" + get_node("%LblCurrentFTitle").text

	## si esta editando la traduccion del mismo idioma...
	if get_selected_lang("ref") == get_selected_lang("trans"):
		get_node("%VBxTranslations").get_node(NodeName).orig_txt = txt

## se clickeó check de revision
func _on_Translation_need_revision_check_pressed(key:String,pressed:bool) -> void:
	var extra_data_path : String = _current_path+"/translation_manager_extra_data.ini"
	var TransConf = ConfigFile.new()
	TransConf.load(extra_data_path)
	TransConf.set_value(key, "need_rev", pressed)
	TransConf.save(extra_data_path)

## habilitar edicion o eliminacion de stringkey y toda su traduccion
func _on_CTCheckEditKey_toggled(button_pressed: bool) -> void:
	get_node("%CTLineEdit").editable = button_pressed
	#get_node("%CTBtnDeleteKey").disabled = ! button_pressed
	get_node("%CTBtnDeleteKey").visible = button_pressed


## eliminar traduccion en base al string key desde el popup edit
func _on_CTBtnDeleteKey_pressed() -> void:
	var TranslationObj = get_node("%VBxTranslations").get_node(_selected_translation_panel)
	
	## eliminar en diccionario
	_translations.erase(TranslationObj.key_str)
	## eliminar panel
	TranslationObj.queue_free()
	
	## mostrar indicacion que hay cambios sin guardar
	get_node("%LblCurrentFTitle").text = "(*)" + get_node("%LblCurrentFTitle").text
	
	_selected_translation_panel = ""
	get_node("%DialogEditTranslation").hide()


## guardar datos del string key desde el popup edit
func _on_CTBtnSaveKey_pressed() -> void:
	var TranslationObj = get_node("%VBxTranslations").get_node(_selected_translation_panel)
	
	## si el campo del strkey esta checkeado
	## renombrar el keystr a uno nuevo
	if get_node("%CTCheckEditKey").pressed == true:
		## crear una nueva entrada con el nuevo key, copiando los valores del anterior
		_translations[get_node("%CTLineEdit").text] = _translations[TranslationObj.key_str]
		## borrar el antiguo
		_translations.erase(TranslationObj.key_str)
		## setear el nuevo keystr al panel de la traduccion
		TranslationObj.key_str = get_node("%CTLineEdit").text
		
	
	## si el check del texto original está checkeado
	if get_node("%CTCheckEnableOriginalTxt").pressed == true:
		## guadar en el panel
		TranslationObj.orig_txt = get_node("%TxtOriginalTxt").text
		## guardar en el diccionario
		_translations[TranslationObj.key_str][get_selected_lang("ref")] = TranslationObj.orig_txt
	
	## guardar texto traducido en el panel
	TranslationObj.trans_txt = get_node("%TxtTranslation").text
	## y guardar en el diccionario
	_translations[TranslationObj.key_str][get_selected_lang("trans")] = TranslationObj.trans_txt
	
	## si se edita el mismo idioma, guardar tambien la variable de texto orig
	if get_selected_lang("ref") == get_selected_lang("trans"):
		## guadar en el panel
		TranslationObj.orig_txt = TranslationObj.trans_txt
		## guardar en el diccionario
		_translations[TranslationObj.key_str][get_selected_lang("ref")] = TranslationObj.orig_txt
	
	## guardar anotaciones
	TranslationObj.annotations = get_node("%TxtAnnotations").text
	var extra_data_path : String = _current_path+"/translation_manager_extra_data.ini"
	var TransConf = ConfigFile.new()
	TransConf.load(extra_data_path)
	TransConf.set_value(TranslationObj.key_str, "annotations", TranslationObj.annotations)
	TransConf.save(extra_data_path)
	
	## enviar señal de boton guardar todo
	get_node("%BtnSaveFile").emit_signal("pressed")
	
	get_node("%DialogEditTranslation").hide()

func _on_CTCheckEnableOriginalTxt_toggled(button_pressed: bool) -> void:
	get_node("%TxtOriginalTxt").readonly = ! button_pressed

## escribir datos al csv
func _on_BtnSaveFile_pressed() -> void:
	var err = CSVLoader.save_csv_translation(
		get_opened_file(),
		_translations, _langs,
		Conf
	)
	if err == OK:
		get_node("%LblCurrentFTitle").text = get_node("%LblCurrentFTitle").text.replace("(*)","")

## cuando se cierra la ventana de preferencias
func _on_Preferences_popup_hide() -> void:
	Conf.set_value("csv", "f_cell", get_node("%TxtSettingFCell").text)
	Conf.set_value("csv", "delimiter", get_node("%TxtSettingDelimiter").text)
	Conf.save(_self_data_folder_path+"/translation_manager_conf.ini")

## el texto ha cambiado en cualquiera de los paneles de texto
## del panel Edit translation
func _on_TextEditPanel_text_changed() -> void:
	## obtener tamaño de los textos, sin contar espacios, tabulaciones, saltos de linea
	var orig_size:int = get_node("%TxtOriginalTxt").text.strip_edges().strip_escapes().length()
	var trans_size:int = get_node("%TxtTranslation").text.strip_edges().strip_escapes().length()
	var diff:int = 0
	var diff_percent:float = 0
	
	## hay total diferencia si...
	##si la traduccion es mayor al texto original
	## o si los campos estan vacios
	if trans_size > orig_size or trans_size == 0 or orig_size == 0:
		diff_percent = 100
	else:
		## diferencia en la cantidad de caracteres
		diff = abs(orig_size-trans_size)
		## convertir a porcentaje
		diff_percent = (float(diff)/float(orig_size)) * 100.0

	get_node("%DifferenceBar").value = diff_percent
	
	## mostrar colores en la barra
#	if diff_percent < 20:
#		get_node("%DifferenceBar").tint_progress = Color.white
#	elif diff_percent < 50:
#		get_node("%DifferenceBar").tint_progress = Color.yellow
#	elif diff_percent < 80:
#		get_node("%DifferenceBar").tint_progress = Color.orange
#	else:
#		get_node("%DifferenceBar").tint_progress = Color.red

## se ha recibido una traduccion
func _on_ApiTranslate_text_translated(
	id, _from_lang, _to_lang, _original_text, translated_text
) -> void:
	var TransObj = get_node("%VBxTranslations").get_node_or_null(id)
	if TransObj != null:
		TransObj.update_trans_txt(translated_text)
		TransObj._on_LineEditTranslation_text_changed(translated_text)
