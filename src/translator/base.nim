import
  options, json, strutils, std/envvars

import
  ../http/[client, response],
  ../tui/[ask, logger],
  ../languages,
  ../opt

import
  ./types  

const promptTemplateRaw = """
SEP: " ||| "
SYSTEM: Translate this TEXT from $# to $# non-formal and dont answer anything else. And dont replace the {{SEP}} symbol if any.
TEXT: $#

"""

type
  Translator* = ref object of RootObj
    # Requireq
    name*: string
    host*: string
    outputLang*: Languages
    requireApiKey*: bool = true

    # AI (gemini, openai)
    aiOption* {.deprecated.}: Option[AITranslatorOption] = none(AITranslatorOption)
    option*: OptionJson = newJObject()
    promptTemplate*: string = promptTemplateRaw
    metadata* {.deprecated.}: JsonNode = newJObject()

    # Internal
    headers: Option[JsonNode]
    con*: HttpConnection
    log*: WewboLogger

method translate*(tl: Translator; content: string; inputLang: Languages = laEn) : string {.gcsafe,base.} = discard
method translate*(tl: Translator; content: Content; inputLang: Languages = laEn) : Content{.gcsafe,base.}  = discard

method defaultAiOption(tl: Translator): AITranslatorOption {.base.} =
  result.apiKey = ""
  result.model = ""
  result.baseUrl = ""

method processApiKey(tl: Translator) : Option[JsonNode] {.gcsafe,base.} =
  let
    apiKeyFieldName = "WB_" & tl.name.toUpper() & "_KEY"
    headerJson = newJObject()

  var
    apiKey = getEnv(apiKeyFieldName)    

  if tl.requireApiKey and apiKey != "":
    headerJson["Authorization"] = %("Bearer " & apiKey)
    return some headerJson

  elif apiKey == "":
    raise newException(ValueError, "The API KEY is missing. " & apiKeyFieldName)

  none JsonNode

proc processHeader(tl: Translator) =
  let
    headerApiKey = tl.processApiKey()

  if headerApiKey.isSome and tl.headers.isSome:
    # Merge prev headers
    for key, val in tl.headers.get:
      headerApiKey.get[key] = val

  elif headerApiKey.isSome and tl.headers.isNone:
    tl.headers = headerApiKey

proc init*[T: Translator](translator: T; outputLang: Languages; mode: WewboLogMode = mSilent) = 
  translator.log = useWewboLogger(translator.name, mode=mode)
  translator.processHeader()
  translator.outputLang = outputLang
  translator.con = newHttpConnection(
    translator.host,
    "wewbo Translator",
    translator.headers,
    mode
  )
  translator.option.putRange(5, 12, "Max Request")

proc ask*(translator: Translator): void {.gcsafe.} =
  if translator.option.len > 0:
    translator.option.ask()

proc close*[T: Translator](translator: T) =
  translator.con.close()
  translator.log.stop()
  translator.con = nil
  translator.log = nil

export
  languages,
  options,
  client,
  response,
  json,
  strutils,
  types,
  logger
