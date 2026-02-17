import
  tui/ask, strutils

type
  Languages* = enum
    laId = "indonesian,id",
    laSu = "sundanese,su"
    laEn = "english,en",
    laZh = "chinese,zh",
    laJa = "japanese,ja",
    laKo = "korean,ko",
    laFr = "french,fr",
    laDe = "german,de",
    laEs = "spanish,es",
    laPt = "portuguese,pt",
    laRu = "russian,ru",
    laAr = "arabic,ar",
    laHi = "hindi,hi",
    laIt = "italian,it",
    laNl = "dutch,nl",
    laPl = "polish,pl",
    laTr = "turkish,tr",
    laVi = "vietnamese,vi",
    laTh = "thai,th",
    laSv = "swedish,sv",
    laNo = "norwegian,no",
    laDa = "danish,da",
    laFi = "finnish,fi",
    laCs = "czech,cs",
    laHu = "hungarian,hu",
    laRo = "romanian,ro",
    laUk = "ukrainian,uk",
    laEl = "greek,el",
    laHe = "hebrew,he",
    laMs = "malay,ms",
    laTl = "filipino,tl"

  Language* = ref object of Questionable
    value: Languages
    countryCode: string
  

proc getCountryMetadata(lang: Languages) : array[2, string] =
  let
    saga = $lang
    sega = saga.split(",")
  
  result[0] = sega[0]
  result[1] = sega[1]

proc getCountryCode*(lang: Languages) : string =
  result = lang.getCountryMetadata()[1]

proc getCountryName*(lang: Languages) : string =
  result = lang.getCountryMetadata()[0]

proc listLang*: seq[Language] {.gcsafe.} =
  for a in Languages:
    result.add Language(
      title: $a,
      value: a,
      countryCode: a.getCountryCode()
    )

proc getLang*(lang: string) : Languages =
  for la in Languages:
    if lang == $la:
      return la
