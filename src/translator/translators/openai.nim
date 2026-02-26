import ../[base, types], options
from ../../utils import getBetween

type
  OpenaiTranslator = ref object of Translator    

proc newOpenaiTranslator*(tl: var Translator; option: Option[AITranslatorOption]) =
  tl = OpenaiTranslator()
  tl.host = option.get.baseUrl.getBetween("https://", "/") # Updated in http/client.
  tl.name = "openai"
  tl.aiOption = option

method translate(tl: OpenaiTranslator; content: string; inputLang: Languages = laEn): string =
  let
    sourceLang = inputLang.getCountryName()
    targetLang = tl.outputLang.getCountryName()

  let
    payload = %*{
      "messages": [
        {
          "role": "user",
          "content": tl.promptTemplate % [sourceLang, targetLang, content]
        }
      ],
      "model": tl.aiOption.get.model,
      "stream": false
    }

  let
    response = tl.con.req(tl.host & "v1/chat/completions", HttpPost, payload=payload)
    jsonNode = response.to_json()

  try:
    if jsonNode.hasKey("choices") and jsonNode["choices"].len > 0:
      return jsonNode["choices"][0]["message"]["content"].getStr()

    if jsonNode.hasKey("error"): 
      tl.log.warn("Error while sending request: " & jsonNode["error"]["message"].getStr())

  except:
    tl.log.warn("ERROR!: " & getCurrentExceptionMsg())

  return content    
