import ../[base, types], options
import ../../opt
import std/envvars, strutils

from ../../utils import getBetween

type
  OpenaiTranslator = ref object of Translator

const
  modelEnv = "WB_MODEL_NAME"
  baseEnv = "WB_BASE_URL"
  modelNameField = "model name ($#)" % modelEnv
  baseUrlField = "base url ($#)" % baseEnv  

proc newOpenaiTranslator*(tl: var Translator) =
  tl = OpenaiTranslator()
  tl.host = ""
  tl.name = "openai"

  let
    modelNameEnv = getEnv(modelEnv, "moonshotai/kimi-k2-instruct-0905")
    basaeUrlEnv = getEnv(baseEnv, "https://api.openai.com/v1/")
  
  block setOption:
    tl.option.put(modelNameEnv, modelNameField)
    tl.option.put(basaeUrlEnv, baseUrlField)

func addSlash(i: string): string =
  if not i.endsWith("/"): i & "/"
  else: i

method translate(tl: OpenaiTranslator; content: string; inputLang: Languages = laEn): string =
  let
    sourceLang = inputLang.getCountryName()
    targetLang = tl.outputLang.getCountryName()
    baseUrl = tl.option[baseUrlField].s.addSlash()
    host = baseUrl.getBetween("https://", "/")

  tl.log.info("HOST: " & host)

  let
    payload = %*{
      "messages": [
        {
          "role": "user",
          "content": tl.promptTemplate % [sourceLang, targetLang, content]
        }
      ],
      "model": tl.option[modelNameField].s,
      "stream": false
    }

  let
    response = tl.con.req(baseUrl & "chat/completions", HttpPost, payload=payload, host=host)
    jsonNode = response.to_json()

  try:
    if jsonNode.hasKey("choices") and jsonNode["choices"].len > 0:
      return jsonNode["choices"][0]["message"]["content"].getStr()

    if jsonNode.hasKey("error"): 
      tl.log.warn("Error while sending request: " & jsonNode["error"]["message"].getStr())

  except:
    # tl.log.warn("ERROR!: " & getCurrentExceptionMsg())
    tl.log.error(getCurrentExceptionMsg())

  return content    
