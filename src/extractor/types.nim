import
  json,
  options,
  ../ui/ask

type 
  InfoExtractor* = object of RootObj
    host*: string
    name*: string
    userAgent*: string
    http_headers*: Option[JsonNode] = none(JsonNode)

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

# Exceptions
type
  AnimeNotFoundError* = object of ValueError
    message: string
  EpisodeNotFoundError* = object of CatchableError
