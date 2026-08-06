import ../base, uri

type
  GoogleTranslator* = ref object of Translator

proc newGoogleTranslator*(tl: var Translator; options: Option[AITranslatorOption] = none(AITranslatorOption)) =
  tl = GoogleTranslator()
  tl.host = "translate.google.com"
  tl.name = "google"

func getBetween(text: string, start: string, endd: string): string {.noSideEffect.} =
  try:
    let
      stato = text.find(start) + start.len
      smento = text[stato .. text.len - 1]
      endoo = smento.find(endd) - 1

    return smento[0 .. endoo]

  except RangeDefect:
    return ""

method translate*(tl: GoogleTranslator; content: string; inputLang: Languages = laEn) : string =
  let
    sourceLang = inputLang.getCountryCode()
    targetLang = tl.outputLang.getCountryCode()
    url = "/m?sl=$#&tl=$#&hl=$#&q=" % [sourceLang, targetLang, sourceLang] & content.encodeUrl()
    resp = tl.con.req(url)

  let    
    html = resp.to_readable()
    text = html.getBetween("<div class=\"result-container\">", "</div><div class=\"links-container\">")

  result = text

when isMainModule:
  var tl = Translator()
  
  tl.newGoogleTranslator()
  tl.init(laId)

  echo tl.translate("Jeg elsker dig", inputLang=laDa)
