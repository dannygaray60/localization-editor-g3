tool
extends Reference
class_name CSVLoader

static func load_csv_translation(filepath: String, conf:ConfigFile) -> Dictionary:
	
	var f_cell:String = conf.get_value("csv","f_cell","keys")
	var delimiter:String = conf.get_value("csv","delimiter",",")
	
	var f := File.new()
	var err := f.open(filepath, File.READ)
	
	if err != OK:
		OS.alert(
			"Can't open file: {0}, code {1}".format([filepath, err]),
			"Translation Manager - Error"
		)
		return {}
	
	var first_row := f.get_csv_line(delimiter)
	if first_row[0] != f_cell:
		OS.alert(
			"Translation file is missing the `id` (f_cell) column",
			"Translation Manager - Error"
		)
		return {}
	
	var languages := PoolStringArray()
	for i in range(1, len(first_row)):
		languages.append(first_row[i])
	
	var ids := []
	var rows := []
	while not f.eof_reached():
		var row := f.get_csv_line(delimiter)
		if len(row) < 1 or row[0].strip_edges() == "":
			#print_debug("Found an empty row")
			continue
		if len(row) < len(first_row):
			print_debug("Found row smaller than header, resizing")
			row.resize(len(first_row))
		ids.append(row[0])
		var trans = PoolStringArray()
		for i in range(1, len(row)):
			trans.append(row[i])
		rows.append(trans)
	f.close()
	
	var translations := {}
	for i in len(ids):
		var t := {}
		for language_index in len(rows[i]):
			t[languages[language_index]] = rows[i][language_index]
		translations[ids[i]] = t
	
	return translations

static func save_csv_translation(
	filepath: String, data: Dictionary, langs: Array, conf:ConfigFile
) -> int:
	
	var f_cell:String = conf.get_value("csv","f_cell","keys")
	var delimiter:String = conf.get_value("csv","delimiter",",")
	
	## encabezados del csv, la primera fila
	var f = File.new()
	var err = f.open(filepath, File.WRITE)
	var csv_headers : Array = [f_cell]
	csv_headers.append_array(langs)

	if err != OK:
		OS.alert(
			"Can't open file: {0}, code {1}".format([filepath, err]),
			"Translation Manager - Error"
		)
		return err
	
	## insertar primera fila, con los encabezados
	f.store_csv_line(csv_headers, delimiter)
	
	## recorrer fila de datos
	for str_key in data.keys():
		## obtener array con las traducciones del strkey [en,es,etc]
		var str_translations : Array = data[str_key].values()
		## rowdata tendra el strkey y luego los demas textos que serian las traducciones
		var row_data : Array = [str_key]
		row_data.append_array(str_translations)
		## recorrer columna de datos
		f.store_csv_line(row_data, delimiter)

	return OK

