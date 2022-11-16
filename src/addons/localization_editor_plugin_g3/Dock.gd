tool
extends Control

const GodetteTexture = preload("res://addons/localization_editor_plugin_g3/godette.png")
const GodetteWowTexture = preload("res://addons/localization_editor_plugin_g3/godette_wow.png")

const LinkBtnFile = preload("res://addons/localization_editor_plugin_g3/LinkButtonRecentFile.tscn")
const TranslationItem = preload("res://addons/localization_editor_plugin_g3/HBxItemTranslation.tscn")

var Locales = load("res://addons/localization_editor_plugin_g3/localization_locale_list.gd").new()

var Conf := ConfigFile.new()

var _translations : Dictionary
var _langs : Array

var _selected_translation_panel : String

var _current_file : String
var _current_path : String

## carpeta en donde se guardan datos internos del addon, como guardar anotaciones de los keystr
var _self_data_folder_path : String = "res://addons/localization_editor_plugin_g3"

func _ready() -> void:
	
	get_node("%LblTextBottom").text = "%s v%s - %s" % [
		get_plugin_info("name"),
		get_plugin_info("version"),
		get_plugin_info("author")
	]
	
	get_node("%LblCreditTitle").text = get_plugin_info("name")
	get_node("%LblCreditDescription").text = get_plugin_info("description")

	var i : int = 0
	for l in Locales.LOCALES:
		get_node("%OptionButtonAvailableLangsList").add_item(
			"%s, %s" % [l["name"], l["code"]], i
		)
		get_node("%OptionButtonLangsNewFile").add_item(
			"%s, %s" % [l["name"], l["code"]], i
		)
		i += 1
	
	## conectar señales
	get_node("%MenuFile").get_popup().connect("id_pressed", self, "_on_FileMenu_id_pressed")
	get_node("%MenuEdit").get_popup().connect("id_pressed", self, "_on_EditMenu_id_pressed")
	get_node("%MenuHelp").get_popup().connect("id_pressed", self, "_on_HelpMenu_id_pressed")

	_on_CloseAll()
	
	## si se ejecuta en editor, solo se accederá al res://
	if Engine.is_editor_hint() == true:
		get_node("%FileDialog").access = FileDialog.ACCESS_RESOURCES
		get_node("%FileDialogNewFilePath").access = FileDialog.ACCESS_RESOURCES
	else:
		get_node("%FileDialog").access = FileDialog.ACCESS_FILESYSTEM
		get_node("%FileDialogNewFilePath").access = FileDialog.ACCESS_FILESYSTEM
		_self_data_folder_path = OS.get_executable_path().get_base_dir()
	
	## crear directorio self data en caso de no existir
	var Dir := Directory.new()
	if Dir.dir_exists(_self_data_folder_path) == false:
		Dir.make_dir(_self_data_folder_path)

	Conf.load(_self_data_folder_path+"/translation_manager_conf.ini")
	Conf.save(_self_data_folder_path+"/translation_manager_conf.ini")
	
	if Engine.is_editor_hint() == false:
		OS.window_maximized = Conf.get_value("main","maximized", false)
	
	get_node("%TxtSettingFCell").text = Conf.get_value("csv","f_cell","keys")
	get_node("%TxtSettingDelimiter").text = Conf.get_value("csv","delimiter",",")
	get_node("%CheckBoxSettingReopenFile").pressed = Conf.get_value("main","reopen_last_file",false)

	load_recent_files_list()

	## reabrir el ultimo archivo
	if get_node("%CheckBoxSettingReopenFile").pressed == true:
		if Dir.file_exists(
			Conf.get_value("main", "last_file_path", "")
		) == true:
			_on_FileDialog_files_selected([Conf.get_value("main", "last_file_path", "")])

func load_recent_files_list() -> void:
	## mostrar archivos recientes
	var recent_list:Array = Conf.get_value("main","recent_files",[])
	for n in get_node("%VBxRecentFiles").get_children():
		n.queue_free()
	for rl in recent_list:
		var Btn := LinkBtnFile.instance()
		Btn.f_path = rl
		Btn.connect("opened", self, "_OnRecentFile_opened")
		Btn.connect("removed", self, "_OnRecentFile_removed")
		get_node("%VBxRecentFiles").add_child(Btn)

func _OnRecentFile_opened(f_path:String) -> void:
	_on_FileDialog_files_selected([f_path])

func _OnRecentFile_removed(NodeName:String,f_path:String) -> void:
	var recent_list:Array = Conf.get_value("main", "recent_files", [])
	
	recent_list.erase(f_path)
	Conf.get_value("main", "recent_files", recent_list)
	
	Conf.save(_self_data_folder_path+"/translation_manager_conf.ini")

	get_node("%VBxRecentFiles").get_node(NodeName).queue_free()


func get_plugin_info(val:String) -> String:
	var ConfPlugin := ConfigFile.new()
	ConfPlugin.load("res://addons/localization_editor_plugin_g3/plugin.cfg")
	return ConfPlugin.get_value("plugin", val, "")

func start_search() -> void:
	var searchtxt:String = get_node("%LineEditSearchBox").text.strip_edges().to_lower()
	var hide_translated:bool = get_node("%CheckBoxHideCompleted").pressed
	var hide_no_need_rev:bool = get_node("%CheckBoxHideNoNeedRev").pressed
	
	for tp in get_node("%VBxTranslations").get_children():
		tp.visible = true
		## busqueda por texto
		if searchtxt.empty()== false:
			if (
				(get_node("%CheckBoxSearchKeyID").pressed and searchtxt in tp.key_str.to_lower())
				or (get_node("%CheckBoxSearchRefText").pressed and searchtxt in tp.orig_txt.to_lower())
				or (get_node("%CheckBoxSearchTransText").pressed and searchtxt in tp.trans_txt.to_lower())
			):
				tp.visible = true
			else:
				tp.visible = false
		
		## ocultar los que no tienen traduccion
		if hide_translated and tp.has_translation() == true:
			tp.visible = false
		## ocultar los que no necesitan revision
		if hide_no_need_rev and tp.need_revision == false:
			tp.visible = false

func clear_search() -> void:
	get_node("%BtnClearSearch").disabled = true
	get_node("%LineEditSearchBox").text = ""
	get_node("%CheckBoxSearchKeyID").pressed = true
	get_node("%CheckBoxSearchRefText").pressed = true
	get_node("%CheckBoxSearchTransText").pressed = true
	get_node("%CheckBoxHideCompleted").pressed = false
	get_node("%CheckBoxHideNoNeedRev").pressed = false

func alert(txt:String,title:String="Alert!") -> void:
	get_node("%WindowDialogAlert").window_title = title
	get_node("%WindowDialogAlert").get_node("Label").text = txt
	get_node("%WindowDialogAlert").popup_centered()

func add_translation_panel(
	strkey:String, ref_txt:String, trans_txt:String, focus_lineedit:bool=false
) -> void:
	
	var TransInstance = TranslationItem.instance()
	var extra_data_path : String = _current_path+"/translation_manager_extra_data.ini"
	var TransConf := ConfigFile.new()
	
	TransConf.load(extra_data_path)

	TransInstance.connect("translate_requested", self, "_on_Translation_translate_requested")
	TransInstance.connect("text_updated", self, "_on_Translation_text_updated")
	TransInstance.connect("edit_requested", self, "_on_Translation_edit_requested")
	TransInstance.connect("need_revision_check_pressed", self, "_on_Translation_need_revision_check_pressed")

	TransInstance.focus_on_ready = focus_lineedit

	TransInstance.key_str = strkey

	TransInstance.orig_txt = ref_txt
	TransInstance.trans_txt = trans_txt
	TransInstance.need_revision = TransConf.get_value(strkey, "need_rev", false)
	TransInstance.annotations = TransConf.get_value(strkey, "annotations", "")

	get_node("%VBxTranslations").call_deferred("add_child", TransInstance)


func get_opened_file() -> String:
	return _current_path + "/" + _current_file

## obtener lista de lenguages disponibles
func get_langs() -> Array:
	var langs_list:Array
	var available_langs_count:int = get_node("%RefLangItemList").get_item_count()
	var i:int = 0
	for l in available_langs_count:
		langs_list.append(
			get_node("%RefLangItemList").get_item_text(i)
		)
		i += 1
	return langs_list

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
	get_node("%ControlNoOpenedFiles").visible = ! vis

func _on_FileMenu_id_pressed(id:int) -> void:
	match id:
		1:
			get_node("%WindowDialogCreateFile").popup_centered()
			get_node("%LineEditNewFileName").grab_focus()
		2:
			get_node("%FileDialog").popup_centered()
		3:
			_on_CloseAll()

func _on_EditMenu_id_pressed(id:int) -> void:
	match id:
		1:
			## add new lang
			if get_node("%ControlNoOpenedFiles").visible == false:
				get_node("%WindowDialogAddNewLang").popup_centered()
		2:
			## delete lang
			if get_node("%ControlNoOpenedFiles").visible == false and _langs.size() > 0:
				
				get_node("%OptionButtonLangsToRemoveList").clear()
				var i:int = 0
				for l in _langs:
					get_node("%OptionButtonLangsToRemoveList").add_item(l,i)
					i += 1
				
				get_node("%WindowDialogRemoveLang").popup_centered()
		3:
			## abrir ajustes del programa
			get_node("%Preferences").popup_centered()

func _on_HelpMenu_id_pressed(id:int) -> void:
	match id:
		1:
			_on_LinkHowToUse_pressed()
		2:
			## creditos
			get_node("%WindowDialogCredits").popup_centered()

func _on_FilesLoaded() -> void:
	_set_visible_content(true)

func _on_CloseAll() -> void:
	load_recent_files_list()
	## limpiar busqueda
	clear_search()
	## seteo inicial
	_set_visible_content(false)
	_on_Popup_hide()
	## limpiar campos
	_current_file = ""
	_current_path = ""
	get_node("%OpenedFilesList").clear()
	get_node("%ControlNoOpenedFiles").visible = true
	_translations = {}
	_langs = []
	
## Se muestra u oculta un popup
func _on_Popup_about_to_show() -> void:
	get_node("%PopupBG").visible = true
func _on_Popup_hide() -> void:
	get_node("%PopupBG").visible = false

func _on_FileDialog_files_selected(paths: PoolStringArray) -> void:
	
	var Dir = Directory.new()
	
	get_node("%OpenedFilesList").clear()

	var i : int = 0
	for p in paths:
		## si algunos de los archivos no existe eliminar de la lista de paths TODO mejorar o asegurarse que funcione bien
		if Dir.file_exists(p) == false:
			paths.remove(i)
		else:
			get_node("%OpenedFilesList").add_item(
				p.get_file(), i
			)
			
			## añadir path a lista de archivos recientes
			var recent_limit:int = 2
			var recent_list:Array = Conf.get_value("main","recent_files",[])
			if recent_list.has(p) == false:
				if recent_list.size() >= recent_limit:
					recent_list.remove(recent_list.size()-1)
				recent_list.append(p)
			## el path ya estaba en lista
			## eliminarlo y colocarlo en la parte superior del array
			else:
				recent_list.erase(p)
				recent_list.push_front(p)
			Conf.set_value("main","recent_files", recent_list)
			
		i += 1
	
	Conf.save(_self_data_folder_path+"/translation_manager_conf.ini")

	if paths.size() == 0:
		_set_visible_content(false)
		return
	
	_current_path = paths[0].get_base_dir()

	## mostrar el path del archivo
	get_node("%LblOpenedPath").text = "[%s]" % [_current_path]
	
	## enviar señal de primer item seleccionado ya que no se activa por default
	_on_OpenedFilesList_item_selected(0)
	
	clear_search()

## se seleccionó un archivo de la lista
func _on_OpenedFilesList_item_selected(index: int) -> void:
	_current_file = get_node("%OpenedFilesList").get_item_text(index)

	## diccionario con keys de los textos, y adentro de cada uno otro dict con keys de lenguajes
	## ej: {STRGOODBYE:{en:Goodbye!, es:Adiós!}, STRHELLO:{en:Hello!, es:Hola!}}
	_translations = CSVLoader.load_csv_translation(get_opened_file(), Conf)

	if _translations.size() == 1 and _translations.keys().has("TMERROR"):
		var err_msg:String = _translations["TMERROR"]
		_on_CloseAll()
		alert(
			err_msg, "Translation Manager - Error"
		)
#		OS.alert(
#			err_msg, "Translation Manager - Error"
#		)
		return

	## no hay nada que mostrar
	if _translations.size() == 0 and _langs.size() == 0:
		_on_CloseAll()
		return
	
	if _translations.size() > 0:
		## si hay un error de que solo contiene la lista de idiomas, vaciar dict de traducciones
		## en adelante solo _langs se usará en el resto de la func
		if _translations.size() == 1 and _translations.keys().has("EMPTYTRANSLATIONS"):
			_langs = _translations["EMPTYTRANSLATIONS"]
			_translations = {}
		else:
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
	
	Conf.set_value("main", "last_file_path", get_opened_file())
	Conf.save(_self_data_folder_path+"/translation_manager_conf.ini")

	## cargar traducciones
	_on_LangItemList_item_selected(0)

	_on_FilesLoaded()

## se cambiado el idioma seleccionado en los itemlist
## esto hace perder cualquier cambio no gaurdado
## cargar paneles de traduccion
func _on_LangItemList_item_selected(_index: int) -> void:

	get_node("%LblCurrentFTitle").text = get_node("%LblCurrentFTitle").text.replace("(*)","")
	
	_selected_translation_panel = ""
	
	## limpiar lista de traducciones en pantalla
	for t in get_node("%VBxTranslations").get_children():
		t.queue_free()

	## añadir paneles de traduccion
	var selected_lang_ref : String = get_selected_lang("ref")
	var selected_lang_trans : String = get_selected_lang("trans")
	for t_key in _translations:
		add_translation_panel(
			t_key,
			_translations[t_key][selected_lang_ref],
			_translations[t_key][selected_lang_trans]
		)

## se solicitó traduccion
func _on_Translation_translate_requested(TransNodeName:String, text_to_trans:String) -> void:
	$ApiTranslate.translate(
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
	
	#get_node("%TxtTranslation").grab_focus()

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
	
	var extra_data_path : String = _current_path+"/translation_manager_extra_data.ini"
	var TransConf = ConfigFile.new()
	TransConf.load(extra_data_path)
	
	## eliminar en diccionario
	_translations.erase(TranslationObj.key_str)
	
	## eliminar en configuracion
	if TransConf.has_section(TranslationObj.key_str):
		TransConf.erase_section(TranslationObj.key_str)
		TransConf.save(extra_data_path)
	
	## eliminar panel
	TranslationObj.queue_free()
	
	## mostrar indicacion que hay cambios sin guardar
	#get_node("%LblCurrentFTitle").text = "(*)" + get_node("%LblCurrentFTitle").text
	
	_selected_translation_panel = ""
	get_node("%DialogEditTranslation").hide()

	_on_BtnSaveFile_pressed()

## guardar datos del string key desde el popup edit
func _on_CTBtnSaveKey_pressed() -> void:
	var extra_data_path : String = _current_path+"/translation_manager_extra_data.ini"
	var TransConf = ConfigFile.new()
	TransConf.load(extra_data_path)
	
	var TranslationObj = get_node("%VBxTranslations").get_node(_selected_translation_panel)
	
	## si el campo del strkey esta checkeado
	## renombrar el keystr a uno nuevo
	if get_node("%CTCheckEditKey").pressed == true:
		
		if get_node("%CTLineEdit").text in _translations.keys():
			OS.alert("The String Key [%s] is already in use"%[get_node("%CTLineEdit").text])
			return
		
		var conf_values : Array
		## crear una nueva entrada con el nuevo key, copiando los valores del anterior
		_translations[get_node("%CTLineEdit").text] = _translations[TranslationObj.key_str]
		##
		if TransConf.has_section(TranslationObj.key_str):
			for c in TransConf.get_section_keys(TranslationObj.key_str):
				## guardar [confkey,value]
				conf_values.append(
					[c, TransConf.get_value(TranslationObj.key_str,c)]
				)
		
		## borrar el antiguo
		_translations.erase(TranslationObj.key_str)
		##
		if TransConf.has_section(TranslationObj.key_str):
			TransConf.erase_section(TranslationObj.key_str)
		
		## setear el nuevo keystr al panel de la traduccion
		TranslationObj.key_str = get_node("%CTLineEdit").text
		##
		if conf_values.empty() == false:
			for c in conf_values:
				TransConf.set_value(
					get_node("%CTLineEdit").text,#seccion
					c[0],c[1]
				)
	
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

## se cambio el check de reabrir ultimo archivo abierto
func _on_CheckBoxSettingReopenFile_toggled(button_pressed: bool) -> void:
	Conf.set_value("main", "reopen_last_file", button_pressed)


func _on_LinkHowToUse_pressed() -> void:
	##enviar a post de kofi
	OS.shell_open("https://dannygaray60.itch.io/localization-editor")
func _on_LinkButtonTwitter_pressed() -> void:
	OS.shell_open("https://twitter.com/dannygaray60")
func _on_LinkButtonGithub_pressed() -> void:
	OS.shell_open("https://github.com/dannygaray60/localization-editor-g3")
func _on_LinkButtonKofi_pressed() -> void:
	OS.shell_open("https://ko-fi.com/dannygaray60")

## se presiono en añadir traduccion
func _on_BtnAddTranslation_pressed() -> void:
	
	get_node("%CheckBoxNewSTRKeyUppercase").pressed = Conf.get_value("main", "uppercase_on_input", true)
	
	get_node("%LineEditKeyStrNewTransItem").text = ""
	get_node("%LineEditRefTxtNewTransItem").placeholder_text = "[%s] Text here..." % [get_selected_lang("ref")]
	get_node("%LineEditRefTxtNewTransItem").text = ""
	get_node("%LineEditTransTxtNewTransItem").placeholder_text = "[%s] Text here... (optional)" % [get_selected_lang("trans")]
	get_node("%LineEditTransTxtNewTransItem").text = ""
	
	get_node("%BtnAddTransItem").disabled = true
	get_node("%WindowDialogAddTranslationItem").popup_centered()
	get_node("%LineEditKeyStrNewTransItem").grab_focus()
	
	if get_selected_lang("ref") == get_selected_lang("trans"):
		get_node("%LineEditTransTxtNewTransItem").visible = false
	else:
		get_node("%LineEditTransTxtNewTransItem").visible = true

## aparece el panel de nuevos lenguajes
func _on_WindowDialogAddNewLang_about_to_show() -> void:
	pass # Replace with function body.
## añadir nuevo lenguaje seleccionado
func _on_BtnAddNewLang_pressed() -> void:
	var lang_to_add:String = get_node("%OptionButtonAvailableLangsList").get_item_text(
		get_node("%OptionButtonAvailableLangsList").selected
	)
	lang_to_add = lang_to_add.split(",")[1].strip_edges()
	
	if lang_to_add in _langs:
		OS.alert("The language already exists in the file.")
		return

	_langs.append(lang_to_add)

	## recorrer cada item (las strkeys)
	##si la entrada no tiene el idioma, agregarlo
	for t_entry in _translations:
		if _translations[t_entry].keys().has(lang_to_add) == false:
			_translations[t_entry][lang_to_add] = ""
	
	get_node("%RefLangItemList").add_item(
		lang_to_add, get_node("%RefLangItemList").get_item_count()
	)
	get_node("%TransLangItemList").add_item(
		lang_to_add, get_node("%TransLangItemList").get_item_count()
	)
	
	_on_BtnSaveFile_pressed()
	
	get_node("%WindowDialogAddNewLang").hide()

func _on_BtnNewFileAddLang_pressed() -> void:
	var delim : String = Conf.get_value("csv","delimiter",",")
	var new_text : String
	var new_lang : String = get_node("%OptionButtonLangsNewFile").get_item_text(
		get_node("%OptionButtonLangsNewFile").selected
	)
	new_lang = new_lang.split(", ")[1]
	
	if new_lang in get_node("%TextEditNewFileLangsAdded").text:
		return

	new_text = "%s%s %s" % [
		get_node("%TextEditNewFileLangsAdded").text, delim, new_lang
	]
	
	new_text = new_text.trim_prefix(delim).strip_edges()
	
	get_node("%TextEditNewFileLangsAdded").text = new_text


func _on_FileDialogNewFilePath_dir_selected(dir: String) -> void:
	get_node("%LineEditNewFilePath").text = dir


func _on_BtnNewFileExplorePath_pressed() -> void:
	get_node("%FileDialogNewFilePath").popup_centered()


func _on_BtnNewFileCreate_pressed() -> void:
	var f_cell : String = Conf.get_value("csv","f_cell","keys")
	var delim : String = Conf.get_value("csv","delimiter",",")
	
	var F = File.new()
	var namefile : String = get_node("%LineEditNewFileName").text.strip_edges()
	var filepath : String = get_node("%LineEditNewFilePath").text
	var langs_txt : String = get_node("%TextEditNewFileLangsAdded").text.replace(" ","")
	var headers_list : Array = langs_txt.split(delim, false)
	
	if filepath.empty() == true:
		OS.alert("Please add a file path.")
		return
	
	if namefile.empty() == true:
		namefile = str(OS.get_ticks_usec())
	
	if headers_list.size() == 0:
		headers_list.append("en")
	
	## añadir el fcell
	headers_list.push_front(f_cell)
	
	var err = F.open(
		"%s/%s.csv" % [filepath,namefile], File.WRITE
	)
	
	if err == OK:
		F.store_csv_line(headers_list,delim)
		F.close()
		## archivo guardado, abrir
		_on_FileDialog_files_selected([
			"%s/%s.csv" % [filepath,namefile]
		])
		
		## limpiar datos
		get_node("%LineEditNewFileName").text = ""
		get_node("%LineEditNewFilePath").text = ""
		get_node("%TextEditNewFileLangsAdded").text = ""
		
		get_node("%WindowDialogCreateFile").hide()
	else:
		OS.alert("Error creating file. Error #"+str(err))
		F.close()

## en el panel de añadir traduccion cualquiera de los lineedit se ha modificado
func _on_NewTransLineEdit_text_changed(_new_text: String) -> void:
	var strkey:String = get_node("%LineEditKeyStrNewTransItem").text.strip_edges()
	var reftxt:String = get_node("%LineEditRefTxtNewTransItem").text.strip_edges()
	var transtxt:String = get_node("%LineEditTransTxtNewTransItem").text.strip_edges()
	
	if (
		strkey.empty() == true 
		or reftxt.empty() == true 
	):
		get_node("%BtnAddTransItem").disabled = true
	else:
		get_node("%BtnAddTransItem").disabled = false

## se clicko en añadir traduccion en el panel de nueva traduccion
func _on_BtnAddTransItem_pressed() -> void:
	var ref_lang:String = get_selected_lang("ref")
	var trans_lang:String = get_selected_lang("trans")
	
	var strkey:String = get_node("%LineEditKeyStrNewTransItem").text.strip_edges()
	var reftxt:String = get_node("%LineEditRefTxtNewTransItem").text.strip_edges()
	var transtxt:String = get_node("%LineEditTransTxtNewTransItem").text.strip_edges()
	
	if _translations.keys().has(strkey) == true:
		OS.alert(
			"The String key: %s already exists." % [strkey]
		)
		return
	
	_translations[strkey] = {}
	
	for l in get_langs():
		if l == ref_lang or ref_lang==trans_lang:
			_translations[strkey][l] = reftxt
		elif l == trans_lang:
			_translations[strkey][l] = transtxt
		else:
			_translations[strkey][l] = ""
	
	## si los idiomas son iguales, copiar ref a trans
	if ref_lang == trans_lang:
		transtxt = reftxt
	
	## añadir panel
	add_translation_panel(strkey, reftxt, transtxt, true)
	
	## mostrar signo de no haber guardado cambios
	if get_node("%LblCurrentFTitle").text.begins_with("(*)") == false:
		get_node("%LblCurrentFTitle").text = "(*)" + get_node("%LblCurrentFTitle").text
	
	get_node("%WindowDialogAddTranslationItem").hide()
	
	yield(get_tree(), "idle_frame")
	get_node("%ScrollContainerTranslationsPanels").ensure_control_visible(get_focus_owner())

func _on_BtnRemoveLang_pressed() -> void:
	
	if _langs.size() < 2:
		OS.alert("You can't remove more languages")
		return
	
	var selected_lang:String = get_node("%OptionButtonLangsToRemoveList").get_item_text(
		get_node("%OptionButtonLangsToRemoveList").selected
	)
	
	for t in _translations:
		_translations[t].erase(selected_lang)
	
	var i:int = 0
	for l in _langs:
		if l == selected_lang:
			get_node("%RefLangItemList").remove_item(i)
			get_node("%TransLangItemList").remove_item(i)
		i += 1
	
	_langs.erase(selected_lang)
	
	get_node("%RefLangItemList").selected = 0
	get_node("%TransLangItemList").selected = 0
	_on_LangItemList_item_selected(0)
	
	_on_BtnSaveFile_pressed()
	
	get_node("%WindowDialogRemoveLang").hide()

## el campo de strkey en el popup de nueva traduccion cambió
func _on_LineEditKeyStrNewTransItem_text_changed(new_text: String) -> void:
	if get_node("%CheckBoxNewSTRKeyUppercase").pressed == true:
		get_node("%LineEditKeyStrNewTransItem").text = get_node("%LineEditKeyStrNewTransItem").text.to_upper().replace(" ","_")
	
	get_node("%LineEditKeyStrNewTransItem").caret_position = get_node("%LineEditKeyStrNewTransItem").text.length()


func _on_CheckBoxNewSTRKeyUppercase_toggled(button_pressed: bool) -> void:
	Conf.set_value("main", "uppercase_on_input", button_pressed)
	Conf.save(_self_data_folder_path+"/translation_manager_conf.ini")
	
	if button_pressed == true:
		get_node("%LineEditKeyStrNewTransItem").text = get_node("%LineEditKeyStrNewTransItem").text.to_upper().replace(" ","_")
	else:
		get_node("%LineEditKeyStrNewTransItem").text = get_node("%LineEditKeyStrNewTransItem").text.to_lower().replace(" ","_")
	get_node("%LineEditKeyStrNewTransItem").caret_position = get_node("%LineEditKeyStrNewTransItem").text.length()


func _on_CheckBoxHideCompleted_pressed() -> void:
	if get_node("%CheckBoxHideCompleted").pressed == true:
		get_node("%BtnClearSearch").disabled = false
	start_search()
func _on_CheckBoxShowNeedRev_pressed() -> void:
	if get_node("%CheckBoxHideNoNeedRev").pressed == true:
		get_node("%BtnClearSearch").disabled = false
	start_search()

func _on_LineEditSearchBox_text_changed(new_text: String) -> void:
	get_node("%BtnClearSearch").disabled = new_text.strip_edges().empty()
	start_search()

## se presiono algun check de la barra de busqueda
func _on_CheckBoxSearch_pressed() -> void:
	
	## al menos de uno de los checks debe estar presionado
	if (
		get_node("%CheckBoxSearchKeyID").pressed == false
		and get_node("%CheckBoxSearchRefText").pressed == false
		and get_node("%CheckBoxSearchTransText").pressed == false
	):
		get_node("%CheckBoxSearchKeyID").pressed = true
	
	## si al menos de uno de los checks está desactivado
	if (
		get_node("%CheckBoxSearchKeyID").pressed == false
		or get_node("%CheckBoxSearchRefText").pressed == false
		or get_node("%CheckBoxSearchTransText").pressed == false
	):
		get_node("%BtnClearSearch").disabled = false
	
	start_search()

func _on_BtnClearSearch_pressed() -> void:
	clear_search()
	start_search()



func _on_BtnWow_mouse_entered() -> void:
	get_node("%TextureRectGodette").texture = GodetteWowTexture
func _on_BtnWow_mouse_exited() -> void:
	get_node("%TextureRectGodette").texture = GodetteTexture
func _on_BtnWow_pressed() -> void:
	_on_LinkButtonKofi_pressed()



func _on_Dock_resized() -> void:
	if Engine.is_editor_hint() == false:
		Conf.set_value("main","maximized",OS.window_maximized)
		Conf.save(_self_data_folder_path+"/translation_manager_conf.ini")
		
