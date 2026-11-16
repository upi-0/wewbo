import std/[
  base64,
  json,
  options,
  os,
  strutils,
  uri
]

import ../base
import http/[
  client,
  response,
  utils
]
import media/[
  extractHls,
  types
]
import
  utils, nimcrypto

const
  AllanimeBase = "allanime.day"
  AllanimeReferer = "https://youtu-chan.com"
  AllanimeKey = "a254aa27c410f297bd04ba33a0c0df7ff4e706bf3ae27271c6703f84e750f552"
  EpisodeQueryHash = "d405d0edd690624b66baba3068e0edc3ac90f1597d898a1ec8db4e5c43c00fec"

const
  EpisodeEmbedGql = "query ($showId: String!, $translationType: VaildTranslationTypeEnumType!, $episodeString: String!) { episode( showId: $showId translationType: $translationType episodeString: $episodeString ) { episodeString sourceUrls }}"
  SearchGql = "query( $search: SearchInput $limit: Int $page: Int $translationType: VaildTranslationTypeEnumType $countryOrigin: VaildCountryOriginEnumType ) { shows( search: $search limit: $limit page: $page translationType: $translationType countryOrigin: $countryOrigin ) { edges { _id name availableEpisodes __typename } }}"
  EpisodesListGql = "query ($showId: String!) { show( _id: $showId ) { _id availableEpisodesDetail }}"

type
  AllanimeEX* {.final.} = ref object of BaseExtractor
    mode: string

proc newAllanime*(ex: var BaseExtractor) =
  ex = AllanimeEX(
    name: "allanime",
    host: "api." & AllanimeBase,
    supportCompessed: false,
    mode: "sub",
    http_headers: some(%*{
      "Content-Type": "application/json",
      "Origin": AllanimeReferer,
      "Referer": AllanimeReferer
    })
  )

proc hexByte(data: string; index: int): string =
  const Hex = "0123456789abcdef"
  let value = ord(data[index])
  result.add Hex[value shr 4]
  result.add Hex[value and 0x0f]

proc toHex(data: string; first, count: int): string =
  for i in first ..< first + count:
    result.add data.hexByte(i)

proc decryptTobeparsed(encoded: string): string =
  let packed = decode(encoded)
  if packed.len < 30:
    return ""

  let
    ivHex = packed.toHex(1, 12)
    ctrHex = ivHex & "00000002"
    cipherText = packed[13 ..< packed.len - 16]

  var
    keyArray: array[32, byte]
    ivArray: array[16, byte]

  let
    keyBytes = nimcrypto.fromHex(AllanimeKey)
    ivBytes  = nimcrypto.fromHex(ctrHex)

  # Pindahkan ke static array yang diwajibkan oleh aes256
  copyMem(addr keyArray[0], unsafeAddr keyBytes[0], 32)
  copyMem(addr ivArray[0], unsafeAddr ivBytes[0], 16)

  # 3. Persiapan buffer untuk dekripsi
  # Melakukan cast ke seq[byte] langsung di level memori (zero-cost)
  let ctSeq = cast[seq[byte]](cipherText)
  var ptSeq = newSeq[byte](ctSeq.len)

  # 4. Eksekusi dekripsi secara Native
  var ctx: CTR[aes256]
  ctx.init(keyArray, ivArray)
  ctx.decrypt(ctSeq, ptSeq)
  ctx.clear() # Selalu bersihkan memory state demi keamanan

  # 5. Simpan hasil langsung ke `result`
  result = cast[string](ptSeq)

proc processResponse(raw: string): string =
  if not raw.contains("\"tobeparsed\""):
    return raw

  let
    node = raw.parseJson()
    tobeparsed = node["data"]["tobeparsed"].getStr()

  return decryptTobeparsed(tobeparsed)

proc decodeProviderChunk(key: string): string =
  case key
  of "79": "A"
  of "7a": "B"
  of "7b": "C"
  of "7c": "D"
  of "7d": "E"
  of "7e": "F"
  of "7f": "G"
  of "70": "H"
  of "71": "I"
  of "72": "J"
  of "73": "K"
  of "74": "L"
  of "75": "M"
  of "76": "N"
  of "77": "O"
  of "68": "P"
  of "69": "Q"
  of "6a": "R"
  of "6b": "S"
  of "6c": "T"
  of "6d": "U"
  of "6e": "V"
  of "6f": "W"
  of "60": "X"
  of "61": "Y"
  of "62": "Z"
  of "59": "a"
  of "5a": "b"
  of "5b": "c"
  of "5c": "d"
  of "5d": "e"
  of "5e": "f"
  of "5f": "g"
  of "50": "h"
  of "51": "i"
  of "52": "j"
  of "53": "k"
  of "54": "l"
  of "55": "m"
  of "56": "n"
  of "57": "o"
  of "48": "p"
  of "49": "q"
  of "4a": "r"
  of "4b": "s"
  of "4c": "t"
  of "4d": "u"
  of "4e": "v"
  of "4f": "w"
  of "40": "x"
  of "41": "y"
  of "42": "z"
  of "08": "0"
  of "09": "1"
  of "0a": "2"
  of "0b": "3"
  of "0c": "4"
  of "0d": "5"
  of "0e": "6"
  of "0f": "7"
  of "00": "8"
  of "01": "9"
  of "15": "-"
  of "16": "."
  of "67": "_"
  of "46": "~"
  of "02": ":"
  of "17": "/"
  of "07": "?"
  of "1b": "#"
  of "63": "["
  of "65": "]"
  of "78": "@"
  of "19": "!"
  of "1c": "$"
  of "1e": "&"
  of "10": "("
  of "11": ")"
  of "12": "*"
  of "13": "+"
  of "14": ","
  of "03": ";"
  of "05": "="
  of "1d": "%"
  else: ""

proc decodeProviderId(providerId: string): string =
  if not providerId.startsWith("--"):
    return providerId

  var i = 0
  while i + 1 < providerId.len:
    let key = providerId[i .. i + 1]
    if key == "--":
      result.add "\n"
    else:
      result.add decodeProviderChunk(key)
    i += 2

  result = result.replace("/clock", "/clock.json").strip()

proc graphQl(ex: AllanimeEX; payload: JsonNode): string =
  ex.connection.req("/api", mthod = HttpPost, payload = $payload).to_readable()

method animes*(ex: AllanimeEX, title: string): seq[AnimeData] =
  let payload = %*{
    "variables": {
      "search": {"allowAdult": false, "allowUnknown": false, "query": title.decodeUrl()},
      "limit": 40,
      "page": 1,
      "translationType": ex.mode,
      "countryOrigin": "ALL"
    },
    "query": SearchGql
  }

  let data = ex.graphQl(payload).parseJson()
  for anime in data["data"]["shows"]["edges"]:
    let episodes = anime["availableEpisodes"].getOrDefault(ex.mode).getInt()
    if episodes > 0:
      result.add AnimeData(
        title: anime["name"].getStr() & " (" & $episodes & " episodes)",
        url: anime["_id"].getStr()
      )

method episodes*(ex: AllanimeEX, url: string): seq[EpisodeData] =
  let payload = %*{
    "variables": {"showId": url},
    "query": EpisodesListGql
  }
  let data = ex.graphQl(payload).parseJson()
  let episodeList = data["data"]["show"]["availableEpisodesDetail"].getOrDefault(ex.mode)
  var kontol = episodeList.len - 1

  result = newSeq[EpisodeData](episodeList.len)

  for ep in episodeList:
    let epNo =
      case ep.kind
      of JString: ep.getStr()
      of JInt: $ep.getInt()
      of JFloat: $ep.getFloat()
      else: $ep

    result[kontol] = EpisodeData(
      title: "Episode " & epNo,
      url: url & "|" & epNo
    )

    kontol -= 1

proc episodeResponse(ex: AllanimeEX; showId, epNo: string): string =
  let queryVars = %*{"showId": showId, "translationType": ex.mode, "episodeString": epNo}
  let queryExt = %*{"persistedQuery": {"version": 1, "sha256Hash": EpisodeQueryHash}}
  let persistedUrl = "/api?variables=" & encodeUrl($queryVars) & "&extensions=" & encodeUrl($queryExt)
  result = ex.connection.req(persistedUrl).to_readable()

  if result.len == 0 or not result.contains("tobeparsed"):
    let payload = %*{
      "variables": {"showId": showId, "translationType": ex.mode, "episodeString": epNo},
      "query": EpisodeEmbedGql
    }
    result = ex.graphQl(payload)

proc extractFormat(ex: AllanimeEX; parsed: string): seq[ExFormatData] =
  var addictional: JsonNode = %*{
    "source": "",
    "referer": "",
    "nextRequest": "",
    "link": ""
  }

  proc extractLinks(providerId: string) : JsonNode =
    ex.connection.req("https://" & AllanimeBase & decodeProviderId providerId).to_json()["links"]

  for source in parsed.parseJson()["episode"]["sourceUrls"]:
    let
      url = source["sourceUrl"].getStr()
      name = source["sourceName"].getStr()

    if name.contains("mp4upload"):
      addictional["source"] = newJString "mp4upload"
      addictional["nextRequest"] = newJString url
      
      result.add ExFormatData(title: "mp4upload - Not Recommended", addictional: some addictional)
      addictional = %*{}

    elif name == "Default":
      let
        link = url.extractLinks()[1 - 1]["link"].getStr()
        m3u8s = parseM3u8Master(detectHost link, link, MediaHttpHeader())

      for m3u8 in m3u8s.formats:
        addictional["source"] = newJString "Default"
        addictional["link"] = newJString m3u8.url

        result.add ExFormatData(title: "Default - " & m3u8.resolution, addictional: some addictional)
        addictional = %*{}

    elif name == "Ak":
      var heights: seq[int]

      for vids in url.extractLinks()[1 - 1]["rawUrls"]["vids"]:
        let
          height = vids["height"].getInt()
          url = vids["url"].getStr()

        if not heights.contains height:
          addictional["source"] = newJString "Ak"
          addictional["link"] = newJString url

          heights.add height
          result.add ExFormatData(title: "Ak - " & $height, addictional: some addictional)
          addictional = %*{}

method formats*(ex: AllanimeEX, url: string): seq[ExFormatData] =
  let parts = url.split("|", 1)
  if parts.len != 2:
    raise newException(ValueError, "AllAnime episode URL must contain show id and episode number")

  let resp = ex.episodeResponse(parts[0], parts[1]).processResponse()

  return ex.extractFormat(resp)

method get*(ex: AllanimeEX, data: ExFormatData): MediaFormatData =
  var
    referer = AllanimeReferer
    ext = extM3u8
    video = data.format_identifier

  if data.addictional.isSome:
    let addic = data.addictional.get()

    if addic["source"].getStr() == "mp4upload":
      let unsolvedUrl = addic["nextRequest"].getStr()

      block:
        video = ex.connection.req(unsolvedUrl).to_readable().getBetween("src: \"", "\"")
        referer = "https://www.mp4upload.com/"
        ext = extMp4

      echo ex.connection.req(unsolvedUrl.strip).to_readable()        

    else:
      video = addic["link"].getStr()

  result = MediaFormatData(
    video: video,
    typeExt: ext,
    headers: some(MediaHttpHeader(userAgent: ex.userAgent, referer: referer))
  )

export AllanimeEX

when isMainModule:
  import tui/logger

  var ex = BaseExtractor()

  newAllanime(ex)
  ex.init(logMode=mEcho)

  let
    anime = ex.get ex.animes("kaguya")[1 - 1]
    eps = ex.get ex.episodes(anime)[^1]
    fmts = ex.formats eps

  for fm in fmts:
    echo fm.title
    echo (ex.get fm).video
    echo ""

  # discard fmts
