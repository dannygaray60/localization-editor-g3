tool
extends Node

signal text_translated(id, from_lang, to_lang, original_text, translated_text)

func translate(from_lang:String, to_lang:String, text:String, id:String="0") -> void:
	_create_request(from_lang, to_lang, text, id)

func _create_request(from_lang:String, to_lang:String, text:String, id:String) -> void:
	var url = _create_url(from_lang, to_lang, text)
	var http_request = HTTPRequest.new()
	var translation_data := {
		"id": id,
		"from_lang": from_lang,
		"to_lang": to_lang,
		"text": text
	}
	http_request.timeout = 5
	add_child(http_request)
	http_request.connect(
		"request_completed", self, 
		"http_request_completed", [http_request, translation_data]
	)
	http_request.request(url, [], false, HTTPClient.METHOD_GET)

func _create_url(from_lang:String, to_lang:String, text:String) -> String:
	var url = "https://translate.googleapis.com/translate_a/single?client=gtx"
	url += "&sl=" + from_lang
	url += "&tl=" + to_lang
	url += "&dt=t"
	url += "&q=" + text.http_escape()
	return url

func http_request_completed(result, response_code, headers, body, http_request, translation_data:Dictionary):
	
	if result != HTTPRequest.RESULT_SUCCESS:
		OS.alert(
			"ApiTranslate error #" + str(result), "HttpRequest Error"
		)
		return

	var result_body := JSON.parse(body.get_string_from_utf8())

	emit_signal(
		"text_translated",
		translation_data["id"],
		translation_data["from_lang"],
		translation_data["to_lang"],
		translation_data["text"],
		result_body.result[0][0][0]
	)
	#_add_progress()
	remove_child(http_request)
