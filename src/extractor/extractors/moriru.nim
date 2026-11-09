import ../base

import
  http/[client, response]

import
  media/extractHls

import 
  base64, strutils, json, options, utils

import
  zippy

type
  MoriruEX = ref object of BaseExtractor

const
  OBF_KEY = "71951034f8fbcf53d89db52ceb3dc22c"
  PROVIDERS = ["sun", "kiwi", "hop"]

proc newMoriru*(ex: var BaseExtractor) =
  ex = MoriruEX(
    name: "mori",
    host: "miruro.cx"
  )

proc decode(ex: MoriruEX; text: string): string =
  var b64 = text.replace("-", "+").replace("_", "/")
  let padLen = (4 - b64.len mod 4) mod 4
  
  b64.add(repeat('=', padLen))
  
  var data = decode(b64)
  let key = parseHexStr(OBF_KEY)
  
  # XOR deobfuscation
  for i in 0 ..< data.len:
    data[i] = char(uint8(data[i]) xor uint8(key[i mod key.len]))
  
  return uncompress(data, dataFormat = dfGzip)

proc toSlug(title: string): string =
  const notAllowed = ["’", ",", "@", "#", "'"]

  result = title.toLowerAscii().replace(" ", "-")

  for niga in notAllowed:
    result = result.replace(niga)

method animes*(ex: MoriruEX; title: string) : seq[AnimeData] =
  let
    encodedResp = ex.connection.req("/api/search/browse?type=ANIME&limit=8&q=" & title).to_readable()
    decodedResp = encodedResp.parseJson["data"]
  
  for anime in decodedResp:
    let
      title = anime["title"]["romaji"].getStr()
      id = anime["id"].getStr()
      totalEpisode = anime.getOrDefault("episode_count").getInt(1)
      url = ["/info", $id].join("/") & "|" & $totalEpisode
    
    result.add AnimeData(
      title: title,
      url: url
    )

  # echo decodedResp    
  
method episodes*(ex: MoriruEX; aur: string) : seq[EpisodeData] =
  let
    metadata = aur.split("|")
    totalEpisode = parseInt metadata[1]
    animeUrl = metadata[0]
    location = ex.connection.req(animeUrl).url.replace("/info", "/watch")

  for eps in 1 .. totalEpisode:
    result.add EpisodeData(
      title: "Episode " & $eps,
      url: $location & "?ep=" & $eps
    )

proc parseFormats(rawResponse, targetProvider: string): Option[JsonNode] =
  try:
    let
      queryStart = join ["provider:", "\"", targetProvider, "\"", ",skipTimes:"]
      queryEnd = ",thumbnails:"
      metadata = rawResponse.getBetween(queryStart, queryEnd)[2 .. ^1]

    result = some parseJson jsToJson join ["{", metadata, "}"]

  except Exception:
    return none(JsonNode)

method formats*(ex: MoriruEX; episodeUrl: string) : seq[ExFormatData] =
  let resp = ex.connection.req(episodeUrl).to_readable()

  for provider in PROVIDERS:
    let formats = parseFormats(resp, provider)
    var data: JsonNode

    if formats.isNone:
      continue

    data = formats.get

    for server in data["servers"]:
      for stream in server["streams"]:
        if stream["quality"].kind == JNull:
          let
            headers = MediaHttpHeader(
              referer: server["headers"].getOrDefault("Referer").getStr("https://miruro.cx/"),
              origin: server["headers"].getOrDefault("Origin").getStr("https://miruro.cx")
            )
            jajat: M3u8MasterObject = parseM3u8Master(stream["url"].str, headers)

          for format in jajat.formats:
            result.add ExFormatData(
              title: [server["server"].str, format.resolution].join(" "),
              format_identifier: format.url,
              addictional: some %*{
                "headers": server["headers"],
                "subtitles": data["subtitles"]                
              }
            )  

        else:
          result.add ExFormatData(
            title: [provider, server["server"].str, stream["quality"].getStr()].join(" "),
            addictional: some %*{
              "headers": server["headers"],
              "subtitles": data["subtitles"]
            },
            format_identifier: stream["url"].str
          )

method get*(ex: MoriruEX; data: ExFormatData) : MediaFormatData =
  let header = MediaHttpHeader(
    referer: data.addictional.get["headers"].getOrDefault("Referer").getStr("https://miruro.cx/"),
    origin: data.addictional.get["headers"].getOrDefault("Origin").getStr("https://miruro.cx")
  )
  
  result = MediaFormatData(
    video: data.format_identifier,
    headers: some header,
    typeExt: extM3u8
  )

when isMainModule:
  import tui/logger
  var ex = BaseExtractor()

  block:
    newMoriru(ex)
    init(ex, logMode = mEcho)


  block:
    let anime = ex.animes("slow loop")[0]
    let episode = ex.episodes ex.get anime
    let formats = ex.formats ex.get episode[0]

    
    echo formats[6].format_identifier
