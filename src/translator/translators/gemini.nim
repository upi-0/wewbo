import ../base, std/envvars

type
  GeminiTranslator* = ref object of Translator
    defaultModel = "gemini-flash-lite-latest"

proc newGeminiTranslator*(tl: var Translator) =
  tl = GeminiTranslator()
  tl.host = "generativelanguage.googleapis.com"
  tl.name = "gemini"

method processApiKey(tl: Translator) : Option[JsonNode] =
  let
    apiKeyFieldName = "WB_" & tl.name.toUpper() & "_KEY"
    headerJson = newJObject()

  var
    apiKey = getEnv(apiKeyFieldName)    

  if tl.requireApiKey and apiKey != "":
    headerJson["x-goog-api-key"] = %apiKey
    return some headerJson

  elif apiKey == "":
    raise newException(ValueError, "The API KEY is missing. " & apiKeyFieldName)

  none JsonNode

method translate*(tl: GeminiTranslator; content: string; inputLang: Languages): string =
  var
    modelName = tl.defaultModel

  if modelName == "":
    tl.log.info("Using default model.")
    modelName = tl.defaultModel

  let
    prompt = tl.promptTemplate % [inputLang.getCountryName(), tl.outputLang.getCountryName(), content]
    url = "/v1beta/models/$#:generateContent" % [modelName]
    payload = %*{
      "contents": [{
        "parts": [{
          "text": prompt
      }]
    }]
    }

  let
    response = tl.con.req(url, HttpPost, payload = payload)
    jsonNode = response.to_json()

  try:
    if jsonNode.hasKey("candidates") and jsonNode["candidates"].len > 0:
      let candidate = jsonNode["candidates"][0]
      if candidate.hasKey("content") and candidate["content"].hasKey("parts"):
        return candidate["content"]["parts"][0]["text"].getStr()

    if jsonNode.hasKey("error"):
      return "Error: " & $jsonNode["error"]

    return ""
  except:
    return "Exception parsing response"
