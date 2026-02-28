import xmltree
import json
import q
import options

import ../base
import ../../utils
import ../../media/[
  types,
  extractHls
]
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
    name: "hime",
    host: "hianime.to",
    supportCompessed: false,
    http_headers: some %*{
      "Referer" : "https://hianime.to/"
    }
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
      content = ex.connection.req(link, host="megacloud.blog", useCache=false).to_readable()
      fileId = content.to_selector().select("div.fix-area")[0].attr("data-id")
      nonce = content.forcedGetBetween(nonceIdRule)

      if nonce.strip.len < 48 :
        ex.info("Failed. Try again.")
        findNonce()

    except IndexDefect:
      ex.info("Failed. Try again.")
      findNonce()

  ex.info("Finding Nonce")
  ex.info("Archive Info: " & link)
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
  
  var t: Option[JsonNode] = some(tracks)

  for format in allFormats:
    if tracks.len < 2:
      t = none(JsonNode)

    result.add ExFormatData(
      title: format.resolution,
      addictional: t,
      format_identifier: format.url
    )

method subtitles(ex: HianimeEX; fmt: ExFormatData): Option[seq[MediaSubtitle]] =
  if fmt.addictional.isNone:
    return none(seq[MediaSubtitle])

  var target: seq[MediaSubtitle]

  for track in fmt.addictional.get:
    if track.getOrDefault("label").isNil:
      break
    target.add MediaSubtitle(
      title: track["label"].getStr,
      url: track["file"].getStr,
      ext: sVtt
    )

  result = target.some

method get*(ex: HianimeEX, data: ExFormatData) : MediaFormatData =
  let
    video = data.format_identifier
    headers = ex.header.some
  
  return MediaFormatData(
    video: video,
    typeExt: extM3u8,
    headers: headers,
  )
