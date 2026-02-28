import
  json, options

import  
  ../tui/ask,
  ../media/types

type 
  AnimeData* = ref object of Questionable
    url*: string

  EpisodeData* = ref object of Questionable
    key*: int
    url*: string = ""
    addictional*: Option[JsonNode] = none(JsonNode)

  ExFormatData* = ref object of Questionable
    format_identifier*: string
    addictional*: Option[JsonNode] = none(JsonNode)

  FormatResolution* = enum
    bad, great, best

  AllEpisodeFormats* = tuple[
    titles: seq[string],
    formats: seq[MediaFormatData]
  ]

# Fallback & Callback
type
  FBExtractEpisodeFormats* = proc(fIndex: var int; formats: seq[ExFormatData]; spami: string = "") {.gcsafe.}
  FBExtractEpisodeSubtitles* = proc(sIndex: var int; subtitles: seq[MediaSubtitle]; spami: string = "") {.gcsafe.}
  CBNormalizeIndex* = proc(max: int) : HSlice[int, int] {.gcsafe.}
  
  CallbacksGetAllEpisodes* = tuple[
    episodeFormats: FbExtractEpisodeFormats,
    episodeSubtitles: FbExtractEpisodeSubtitles,
    normalizeIndex: CBNormalizeIndex 
  ]

# Exceptions
type
  AnimeNotFoundError* = object of ValueError
    message: string
  EpisodeNotFoundError* = object of CatchableError
