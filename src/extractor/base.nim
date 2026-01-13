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
import ../tui/logger

type
  BaseExtractor {.inheritable.} = ref object of RootObj
    host*: string
    name*: string
    userAgent*: string
    http_headers*: Option[JsonNode] = none(JsonNode)
    connection*: HttpConnection
    lg*: WewboLogger
    initialized: bool = false

method animes*(ex: BaseExtractor, title: string) : seq[AnimeData] {.base, gcsafe.} = discard
method get*(ex: BaseExtractor, data: AnimeData) : string {.base.} = data.url

method episodes*(ex: BaseExtractor, url: string) : seq[EpisodeData] {.base.} = discard
method get*(ex: BaseExtractor, data: EpisodeData) : string {.base.} = data.url

method formats*(ex: BaseExtractor, url: string) : seq[ExFormatData] {.base.} = discard
method get*(ex: BaseExtractor, data: ExFormatData) : MediaFormatData {.base.} = discard

method subtitles*(ex: BaseExtractor; fmt: ExFormatData) : Option[seq[MediaSubtitle]] {.base.} = none(seq[MediaSubtitle])

method getAllEpisodeFormats*(ex: BaseExtractor, animeUrl: string, s: int = -1; e: int = -1, fb: CallbacksGetAllEpisodes) : AllEpisodeFormats {.base.} = 
  let
    episodes = ex.episodes(animeUrl)

  var
    episodeTitle: seq[string]
    episodeFormat: seq[MediaFormatData]
    allFormat: seq[ExFormatData]
    episodemed: MediaFormatData
    res: MediaResolution
    episodeUrl: string

  var
    sub = none(seq[MediaSubtitle])
    sIndex: int = -1    
    fIndex: int = -1

  proc extractFormat(ept: EpisodeData) =
    episodeUrl = ex.get(ept)
    allFormat = ex.formats(episodeUrl)

    if fIndex == -1:
      fb.episodeFormats(fIndex, allFormat, ept.title)
      res = allFormat[fIndex].title.detectResolution()

    try:
      assert allFormat[fIndex].title.detectResolution() == res
      ex.lg.info("[$#] $#" % [ex.name, "Auto selecting format for: " & ept.title])

      episodeMed = ex.get(allFormat[fIndex])
      sub = ex.subtitles(allFormat[fIndex])

      if sIndex == -1 and sub.isSome:
        fb.episodeSubtitles(sIndex, sub.get, "Select Subtitle")
        episodeMed.subtitle = sub.get[sIndex].some

      elif sIndex >= -1 and sub.isSome:
        episodeMed.subtitle = sub.get[sIndex].some

      else:
        discard        

    except RangeDefect, IndexDefect, AssertionDefect:
      fb.episodeFormats(fIndex, allFormat, ept.title)
      episodeMed = ex.get(allFormat[fIndex])
      
    episodeFormat.add(episodemed)      

  for ept in episodes[fb.normalizeIndex(episodes.len)]:
    episodeTitle.add(ept.title)
    extractFormat(ept)

  result = (titles: episodeTitle, formats: episodeFormat)    

proc info*(ex: BaseExtractor, text: string) =
  ex.lg.info("[$#] $#" % [ex.name, text])

proc init*[T: BaseExtractor](
  extractor: T,
  proxy: string = "",
  userAgent: string = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:146.0) Gecko/20100101 Firefox/146.0",
  resolution: FormatResolution = best,
  logMode: WewboLogMode = mTui
) =
  extractor.lg = useWewboLogger(extractor.name, mode=logMode)
  extractor.userAgent = userAgent
  extractor.connection = newHttpConnection(
    extractor.host,
    userAgent,
    extractor.http_headers,
    mode=logMode
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

proc close*(extractor: BaseExtractor) =
  extractor.lg.stop()
  extractor.connection.close()

  extractor.lg = nil
  extractor.connection = nil

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
