import
  ../base

import
  htmlentity, sugar, json,
  options, strutils, sequtils,
  marshal, oids, os

import
  http/[client, response],
  media/extractHls,
  tui/logger,
  temp

from utils import getBetween
from http/utils import detectHost

type
  KickassEX = ref object of BaseExtractor

proc newKickass*(ex: var BaseExtractor) =
  ex = KickassEX()
  ex.name = "kass"
  ex.host = "kaa.lt"
  ex.http_headers = some %*{"Content-Type": "application/json"}

method animes(ex: KickassEX; title = "") : seq[AnimeData] =
  let
    animeData = ex.connection.req("/api/search", mthod=HttpPost, payload = %*{"query": title})

  for ad in animeData.to_json():
    result.add AnimeData(
      title: ad["title"].getStr(),
      url: ad["slug"].getStr())

method episodes(ex: KickassEX; animeSlug: string) : seq[EpisodeData] =
  let
    episodeData = ex.connection.req("/api/show/" & animeSlug & "/episodes?ep=1&lang=ja-JP")

  for epd in episodeData.to_json()["result"]:
    let
      epString = epd["episode_string"].getStr()
      slug = epd["slug"].getStr()
      title = epd["title"].getStr()
    
    result.add EpisodeData(
      title: "[$#] $#" % [epString, title],
      url: "/" & animeSlug & "/" & "ep-$#-$#" % [epString, slug]
    )

method formats(ex: KickassEX; url: string) : seq[ExFormatData] =
  let
    episodePage = ex.connection.req(url).to_readable()
    iframeUrl = episodePage.getBetween(",src:\"", "\"}]").replace("\\u002F", "/")
  
  if iframeUrl.contains("\n"):
    return

  let
    iframePage = ex.connection.req(host=detectHost(iframeUrl), url=iframeUrl)
    iframeData = iframePage.to_readable().getBetween("props=\"", "\" ssr")
    formatData = iframeData.encode().parseJson()

  let
    m3u8MasterUrl = "https:" & formatData["manifest"][1].getStr()
    m3u8Format = parseM3u8Master(
      host = detectHost(m3u8MasterUrl),
      url = m3u8MasterUrl,
      headers = MediaHttpHeader(referer: "https://kaa.lt")
    )

  proc exFrame(frame: M3u8Frame): ExFormatData =
    result = ExFormatData()
    result.title = frame.resolution
    result.formatIdentifier = frame.resolution
    result.addictional = some %*{
      "audio": m3u8Format.audioUrl[0],
      "frame": parseJson $$frame,
      "subtitles": formatData["subtitles"][1]
    }

  m3u8Format.formats.map(frame => exFrame(frame))

method get(ex: KickassEX; fmt: ExFormatData) : MediaFormatData =
  let
    data = get fmt.addictional
    frame = data["frame"].to M3u8Frame
    content = frame.writeDummyM3u8 getStr data["audio"]
    m3u8Path = ex.temp.write(content, ".m3u8")

  block setMedia:
    result.video = m3u8Path
    result.typeExt = extM3u8  

method subtitles(ex: KickassEX; fmt: ExFormatData) : Option[seq[MediaSubtitle]] =
  let subs = fmt.addictional.get["subtitles"]
  var hasl : seq[MediaSubtitle]
  
  for sub in subs:
    hasl.add MediaSubtitle(
      title: sub[1]["name"][1].getStr(),
      url: sub[1]["src"][1].getStr().replace("///", "//"),
      lang: sub[1]["language"][1].getStr()
    )

  return some hasl    

when isMainModule:
  var ex = BaseExtractor()

  block init:
    newKickass(ex)
    ex.init(logMode=mEcho)

  let
    anime = ex.get ex.animes("slow loop")[0]
    episode = ex.get ex.episodes(anime)[0]
    subs = ex.subtitles ex.formats(episode)[0]

  for sub in subs.get:
    echo sub.url
  

