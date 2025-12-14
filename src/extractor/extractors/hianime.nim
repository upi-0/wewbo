import xmltree
import json
import q
import options

import ../base
import ../../utils
import ../../media/extractHls
import ../../http/[
  client,
  response
]
from strutils import
  split,
  removeSuffix,
  find,
  strip,
  replace,
  contains,
  `%`

type
  HianimeEX* {.final.} = ref object of BaseExtractor
    header = MediaHttpHeader(
      referer: "https://megacloud.blog/"
    )

proc newHianime*(extractor: var BaseExtractor) =
  extractor = HianimeEX(
    name: "hian",
    host: "hianime.to",
    http_headers: some(%*{
      "Referer" : "https://hianime.to/"
    })
  )

method animes*(ex: HianimeEX, title: string = "") : seq[AnimeData] =
  var
    aUrl: string
  
  let
    url = "/search?keyword=" & title
    aEl = ex.main_els(url, "h3.film-name a")

  for a in aEl :
    aUrl = a.attr("href")
    aUrl.removeSuffix("?ref=search")
    aUrl = "/watch" & aUrl

    result.add AnimeData(
      title: a.attr("title"),
      url: aUrl
    )

method episodes*(ex: HianimeEX, url: string) : seq[EpisodeData] =
  var
    animeId = url.split("-")[^1]
    realUrl = "/ajax/v2/episode/list/" & animeId
    dataJson = ex.connection.req(realUrl).to_json()
    dataHtml = dataJson["html"].getStr().to_selector()
    aEl = dataHtml.select("a.ssl-item")
  
  for i, a in aEl :
    result.add EpisodeData(
      title: "[$#] $#" % [$(i + 1), a.attr("title")],
      url: "/ajax/v2/episode/servers?episodeId=" & a.attr("data-id")
    )

proc getMainHLS(ex: HianimeEX, megaCloudId: string) : JsonNode =
  var
    content: string
    nonce: string
    fileId: string
    formatURL: string
    formatData: JsonNode
    url = strip("/ajax/v2/episode/sources?id=" & megaCloudId)
  
  let
    link = ex.connection.req(url).to_json()["link"].getStr()
    nonceIdRule = [
      ["<script nonce=\"", "\">/* empty nonce script */</script>"],
      ["<script>window._xy_ws = \"", "\";</script>"],
      ["<!-- _is_th:", " -->"],
      ["<div data-dpi=\"", "\" style=\"display:none\"></div>"]
    ]        

  proc findNonce() =
    try:
      ex.info("Archive Info: " & link)
      content = ex.connection.req(link, host="megacloud.blog", useCache=false).to_readable()
      fileId = content.to_selector().select("div.fix-area")[0].attr("data-id")
      nonce = content.forcedGetBetween(nonceIdRule)

      if nonce.strip.len < 48 :
        ex.info("Failed. Try again...")
        findNonce()

    except IndexDefect:
      ex.info("Failed. Try again...")
      findNonce()

  ex.info("Finding Nonce")
  findNonce()
  formatURL = link.replace(fileId & "?k=1", "getSources?id=$#&_k=$#" % [fileId, nonce])
  formatData = ex.connection.req(formatURL, host="megacloud.blog").to_json()

  return formatData

method formats*(ex: HianimeEX, url: string) : seq[ExFormatData] =
  let
    dataJson = ex.connection.req(url).to_json()
    dataHtml = dataJson["html"].getStr.to_selector()
    divEl = dataHtml.select("div.server-item")
    megaId = divEl[0].attr("data-id")

  let
    hlsInfo = ex.getMainHLS(megaId)     
    m3u8Url = hlsInfo["sources"][0]["file"].getStr()
    m3u8Format = parseM3u8Master(
      host = m3u8Url.split("/")[2],
      url = m3u8Url,
      headers = ex.header
    )
    tracks = hlsInfo.getOrDefault("tracks")
    allFormats = m3u8Format.formats.sortByResolution()

  if not tracks.isNil and tracks.len > 1 :
    for track in tracks:
      for format in allFormats :
        if track.getOrDefault("label").isNil :
          break
        result.add ExFormatData(
          title: "$# - $#" % [format.resolution, track["label"].getStr()],
          formatIdentifier: format.url,
          addictional: some(%*{
            "subUrl": track["file"],
            "subLabel": track["label"]
          })
        )

  else :
    for format in allFormats :
      result.add ExFormatData(
        title: format.resolution,
        formatIdentifier: format.url
      )

method get*(ex: HianimeEX, data: ExFormatData) : MediaFormatData =
  let
    video = data.format_identifier
    headers = ex.header.some

  if data.addictional.isSome :    
    var subtitle = MediaSubtitle(url: data.addictional.get["subUrl"].getStr)
    return MediaFormatData(
      video: video,
      subtitle: subtitle.some,
      typeExt: extM3u8,
      headers: headers,
    )

  result.video = video    
  result.typeExt = extM3u8
    