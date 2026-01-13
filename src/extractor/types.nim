import
  json, options

import  
  ../ui/ask,
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

# Fallback
type
  FbExtractEpisodeFormats* = proc(fIndex: var int; formats: seq[ExFormatData]; spami: string = "")
  FbExtractEpisodeSubtitles* = proc(sIndex: var int; subtitles: seq[MediaSubtitle]; spami: string = "")
  FallbackEpisodes* = tuple[
    episodeFormats: FbExtractEpisodeFormats,
    episodeSubtitles: FbExtractEpisodeSubtitles
  ]

# Exceptions
type
  AnimeNotFoundError* = object of ValueError
    message: string
  EpisodeNotFoundError* = object of CatchableError
