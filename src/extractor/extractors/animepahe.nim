import json
import strutils
import re
import xmltree
import options
import ../base
import ../types
import ../../http/[
  client,
  response
]
import ../../utils

type 
  AnimepaheEX {.final.} = ref object of BaseExtractor

method sInit*(ex: AnimepaheEX) : InfoExtractor =
  result.name = "pahe"
  result.host = "animepahe.si"
  result.http_headers = some(%*{
    "Cookie" : "__ddgid_=yF8PHfOsX4Hja1YA; __ddg2_=txfoen42BeK4Kp13; __ddg1_=rxGMTN3zVY213Uxo849v; res=1080; aud=jpn; av1=0; XSRF-TOKEN=eyJpdiI6InRyUHlDUVZZMGY0SGhHRFdodHoxNVE9PSIsInZhbHVlIjoiME5FZUtub1FKNmVhQ0FOZmtBNXpTUlVZalFJTjE0bm9XYlVxT3lCSStzUzYvbjhOZys5TmVZNXlXMCt6cmN5YVdaZ3VhVlVJRFBkQ28rRE9sTURxeE5YY1laellTQ1lYWnFHWmJVb3JEVDZ1ZHZVUS9sYitBb2dIVlFwN1laWGYiLCJtYWMiOiI3ZDNhYTdiM2Q1NTM4YTJjYjM1ZTM4OTVlODc5NzJjNzNhY2YzNGFkZTdjNzk2MjFlM2ZiYmE4NTA4YjgzNjRkIiwidGFnIjoiIn0%3D;",
    "Referer" : "https://animepahe.si"
  })

method animes*(ex: AnimepaheEX, title: string) : seq[AnimeData] =
  var res_json = ex.connection.req("/api?m=search&q=" & title).to_json()
  if res_json.hasKey("data") :
    for anime in res_json["data"] :
      result.add AnimeData(
        title: anime["title"].getStr(),
        url: ex.connection.normalize_url(
          "/anime/" & anime["session"].getStr()
        )
      )
  else : raise newException(AnimeNotFoundError, "Animepahe Gagal jir")      


proc get_by_index(ex: AnimepaheEX, session: string, index: int = 1, sort: string = "asc") : tuple[all: JsonNode, total: int] =
  var
    url_format = "/api?m=release&id=$#&sort=episode_$#&page=$#"
    real_url = url_format % [session, sort, $index]
    sukamto = ex.connection.req(real_url).to_json()

  return (
    all: sukamto["data"],
    total: sukamto["total"].getInt()
  )

method episodes*(ex: AnimepaheEX, url: string) : seq[EpisodeData] =
  var
    session = url.split("/")[^1]
    ells = ex.get_by_index(session, 1)
    episodes = ells.all
    total_eps = ells.total

  if total_eps <= 30 :    
    for eps in episodes :
      result.add EpisodeData(
        title: "Episode " & $eps["episode"].getInt(),
        key: eps["episode"].getInt(),
        url: ex.connection.normalize_url(
          "/play/$#/$#" % [session, eps["session"].getStr()]
        )
      )
  else :
    for eps in 1..total_eps :
      result.add EpisodeData(
        title: "Episode " & $eps,
        key: eps,
        addictional: some(%*{
          "session" : session,
          "total_eps" : total_eps
        })
      )

method get(ex: AnimepaheEX, data: EpisodeData): string =
  if data.url.len > 1 :
    return data.url

  var
    session = data.addictional.get["session"].getStr()
    index = data.key.find_episode(
      data.addictional.get["total_eps"].getInt(), 30)

  for ep in ex.get_by_index(session, index, "desc").all :
    if ep["episode"].getInt() == data.key :
      return "/play/$#/$#" % [session, ep["session"].getStr()]

  raise newException(ValueError, "Failed to fetch at animepahe")

method formats*(ex: AnimepaheEX, url: string) : seq[ExFormatData] =
  var
    buttons = ex.main_els(url, "button")
    src: string

  for button in buttons :
    src = button.attr("data-src")
    if src != "" :
      var
        source = button.attr("data-src")
        fansub = button.attr("data-fansub")
        audio = button.attr("data-audio")
        resolution = button.attr("data-resolution")
      result.add ExFormatData(
        title: "$#, $#, $#" % [fansub, audio, resolution],
        format_identifier: source,
        addictional: some(%*{
          "source" : source,
          "res" : resolution
        })
      )

proc vault(url: string): string =
  let pattern = re(r"//vault-(.*?)\.(kwikie|padorupado|owocdn|uwucdn)\.(top|si|ru)")
  var matches: array[3, string]
  if url.find(pattern, matches) != -1:
    return matches[0]
  else:
    raise newException(ValueError, "Vault not found in URL")

proc host(url: string, vault: string): string =
  let pattern = re(r"//vault-" & vault & r"\.([^.]+)\.(top|si|ru)")
  var matches: array[2, string]
  if url.find(pattern, matches) != -1:
    return matches[0]
  else:
    raise newException(ValueError, "Host not found in URL")      

proc force_get_index(script: string, vault: string) : string =
  try:
    let vaultPattern = vault & "/"
    let start = script.find(vaultPattern) + vaultPattern.len
    let endPos = start + 2
    let index = script[start ..< endPos]
    
    if index.allCharsInSet({'0'..'9'}):
      return index
    else:
      raise newException(ValueError, "Not digit")
  except:
    # Method 2: "m3u8|uwu|" + 9 + 65
    try:
      let start = script.find("m3u8|uwu|") + 9 + 65
      let endPos = start + 2
      var index = script[start ..< endPos]
      
      if index.allCharsInSet({'0'..'9'}):
        return index
      
      # Method 3: "|source|" + 8
      let start2 = script.find("|source|") + 8
      let endPos2 = start2 + 2
      index = script[start2 ..< endPos2]
      
      if index.allCharsInSet({'0'..'9'}):
        return index
      
      # Method 4: "/H/" + 3
      let start3 = script.find("/H/") + 3
      let endPos3 = start3 + 2
      index = script[start3 ..< endPos3]
      
      return index
    except:
      raise newException(ValueError, "Index not found")

proc get_m3u8_id(script: string) : string =
  var
    startt = script.find("m3u8|uwu|") + 9
    endd = startt + 63

  result = script[startt .. endd]

proc get_m3u8_data(url: string, page: XmlNode) : array[8, string] =
  let
    base_uri = page.select("link")[2].attr("href")
    script = page.select("script")[^1].innerText
    vault = base_uri.vault()

  result = [
    "vault", vault,
    "host", base_uri.host(vault),
    "index", script.force_get_index(vault),
    "m3u8_id", script.get_m3u8_id()
  ]

method get*(ex: AnimepaheEX, format: ExFormatData) : MediaFormatData =
  let
    format_page = ex.connection.req(format.format_identifier, host="kwik.cx").to_selector()
    m3u8_data = format.format_identifier.get_m3u8_data(format_page)

  result.video = "https://vault-$vault.$host.top/stream/$vault/$index/$m3u8_id/uwu.m3u8" % m3u8_data
  result.typeExt = extM3u8

export AnimepaheEX
