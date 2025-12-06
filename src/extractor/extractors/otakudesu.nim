import
  xmltree,
  base64,
  q,
  strutils,
  json,
  httpclient,
  options

import  
  ../base,
  ../../http/[
    client,
    response
  ]

from algorithm import reverse  

type
  OtakuSources = enum
    sNone = "none",
    sMoedesu = "moedesu",
    sOtakuwatch = "otakuwatch",
    sOtakuplay = "otakuplay",
    sOtakustream = "otakustream"
    sDesudesu = "desudesu",
    sOndesu = "ondesu",
    sPdrain = "pdrain"

  OtakudesuEX* {.final.} = ref object of BaseExtractor

method sInit*(ex: OtakudesuEX) : InfoExtractor = 
  result.host = "otakudesu.best"
  result.name = "taku"
  result.http_headers = some(%*{
    "Content-Type" : "application/x-www-form-urlencoded; charset=UTF-8"
  })

func source(headTitle: string) : OtakuSources =
  for source in OtakuSources :
    if headTitle.contains($source) :
      return source

func isValidSource*(headTitle: string) : bool =
  headTitle.source != OtakuSources.sNone

method animes*(ex: OtakudesuEX, title: string) : seq[AnimeData] =
  var 
    url = "/?s=$#&post_type=anime" % [title]
    els = ex.main_els(url, "h2 a")

  for h2a in els :
    result.add AnimeData(
      title: h2a.innerText,
      url: h2a.attr("href")
    )

method episodes(ex: OtakudesuEX, url: string) : seq[EpisodeData] =
  var
    ul: seq[XmlNode]

  let
    que = "div.episodelist ul"
    ulEl = ex.main_els(url, que)
  
  ul = ulEl[1].select("li")
  ul.reverse()

  for idx, li in ul :
    result.add EpisodeData(
      title: "Episode " & $(idx + 1),
      url: li.select("a")[0].attr("href")
    )

# Harus dipantau terus nich
proc findNonce(ex: OtakudesuEX): string =
  let linux = ex.connection.req(
    "/wp-admin/admin-ajax.php",
    mthod = HttpPost,
    payload="action=aa1208d27f29ca340c92c66d1926f13f"
  )

  result = getStr linux.to_json()["data"]

method formats(ex: OtakudesuEX, url: string) : seq[ExFormatData] =
  var
    addic: JsonNode
  let
    nonce = ex.findNonce()

  for ul in ex.main_els(url, "div.mirrorstream ul") :
    for li in ul.select("li") :
      if isValidSource(li.innerText) :
        addic = %*{
          "nonce" : nonce,
          "source" : li.innerText,
        }
        result.add ExFormatData(
          title: "$# $#" % [ul.attr("class"), li.innerText],
          format_identifier: li.select("a")[0].attr("data-content"),
          addictional: some(addic)
        )

method get*(ex: OtakudesuEX, data: ExFormatData) : MediaFormatData =
  var 
    iframeUrl: string
    video: string
    response: Response
    nonce: JsonNode    

  let
    addc = data.addictional
    payload = parseJson(data.format_identifier.decode)
    action = newJString("2a3505c93b0035d3f455df82bf976b84")

  if addc.isSome :
    nonce = addc.get["nonce"]
    payload["nonce"] = nonce

  payload["action"] = action

  response = ex.connection.req(
    "/wp-admin/admin-ajax.php",
    mthod = HttpPost,
    payload = jsonToForm(payload)
  )

  iframeUrl = (
    response.to_json()["data"]
      .getStr.decode.to_selector()
      .select("iframe")[0].attr("src")
  )

  if addc.isSome :
    case addc.get["source"].getStr.source
    of sNone :
      raise newException(ValueError, "Invalid Source")  
    of sPdrain :
      video = iframeUrl
    else :
      response = ex.connection.req(iframeUrl, mthod = HttpGet, host = "desustream.info")
      video = response.to_selector().select("source")[0].attr("src")

    let
      header = MediaHttpHeader(userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:146.0) Gecko/20100101 Firefox/146.0")      
      media = MediaFormatData(
        video: video,
        typeExt: extMp4,
        headers: header.some
      )

    return media

  raise newException(ValueError, "Bambang makan lontong awokawokwok")
