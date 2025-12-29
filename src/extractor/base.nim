import
  xmltree,
  q,
  strutils,
  options

import  
  ./types,
  ../http/[
    client,
    response
  ]  

import ../media/[types]
import ../logger

type
  BaseExtractor {.inheritable.} = ref object of RootObj
    host*: string
    name*: string
    userAgent*: string
    http_headers*: Option[JsonNode] = none(JsonNode)
    connection*: HttpConnection
    lg*: WewboLogger
    initialized: bool = false

method animes*(ex: BaseExtractor, title: string) : seq[AnimeData] {.base.} = discard
method get*(ex: BaseExtractor, data: AnimeData) : string {.base.} = data.url

method episodes*(ex: BaseExtractor, url: string) : seq[EpisodeData] {.base.} = discard
method get*(ex: BaseExtractor, data: EpisodeData) : string {.base.} = data.url

method formats*(ex: BaseExtractor, url: string) : seq[ExFormatData] {.base.} = discard
method get*(ex: BaseExtractor, data: ExFormatData) : MediaFormatData {.base.} = discard

method getAllEpisodeFormats*(ex: BaseExtractor; animeUrl: string; fb: FbExtractEpisodeFormats) : AllEpisodeFormats {.base.} = 
  let
    episodes = ex.episodes(animeUrl)

  var
    episodeTitle: seq[string]
    episodeFormat: seq[MediaFormatData]
    allFormat: seq[ExFormatData]
    episodemed: MediaFormatData
    res: MediaResolution
    episodeUrl: string
    fIndex: int = -1

  proc extractFormat(ept: EpisodeData) =
    episodeUrl = ex.get(ept)
    allFormat = ex.formats(episodeUrl)

    if fIndex == -1:
      fb(fIndex, allFormat, ept.title)
      res = allFormat[fIndex].title.detectResolution()

    try:
      assert allFormat[fIndex].title.detectResolution() == res
      log.info("[$#] $#" % [ex.name, "Auto selecting format for: " & ept.title])
      episodeMed = ex.get(allFormat[fIndex])

    except RangeDefect, IndexDefect, AssertionDefect:
      fb(fIndex, allFormat, ept.title)
      episodeMed = ex.get(allFormat[fIndex])
      
    episodeFormat.add(episodemed)      

  for ept in episodes:
    episodeTitle.add(ept.title)
    extractFormat(ept)

  return (titles: episodeTitle, formats: episodeFormat)    

proc info*(ex: BaseExtractor, text: string) =
  ex.lg.info("[$#] $#" % [ex.name, text])

proc init*[T: BaseExtractor](
  extractor: T,
  proxy: string = "",
  userAgent: string = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:146.0) Gecko/20100101 Firefox/146.0",
  resolution: FormatResolution = best
) =
  extractor.lg = log
  extractor.userAgent = userAgent
  extractor.connection = newHttpConnection(
    extractor.host,
    userAgent,
    extractor.http_headers,
  )
  extractor.initialized = true

proc main_el*(extractor: BaseExtractor, url: string, query: string) : XmlNode =
  extractor.connection
    .req(url)
    .to_selector()
    .select(query)[0]

proc main_els*(extractor: BaseExtractor, url: string, query: string) : seq[XmlNode] =
  extractor.connection
    .req(url)
    .to_selector()
    .select(query)

export
  WewboLogger,
  info

export
  BaseExtractor

export  
  AnimeData,
  EpisodeData,
  ExFormatData

export  
  MediaFormatData,
  MediaSubtitle,
  MediaExt,
  MediaHttpHeader
