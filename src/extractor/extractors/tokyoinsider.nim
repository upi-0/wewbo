import
  ../base,
  http/[client, response]

import  
  xmltree, q,
  fts, strutils,
  sequtils

type
  TokyoInsiderEX = ref object of BaseExtractor

proc newTokyoInsider*(ex: var BaseExtractor) =
  ex = TokyoInsiderEX()
  ex.name = "toyo"
  ex.host = "www.tokyoinsider.com"

method animes*(ex: TokyoInsiderEX; title: string) : seq[AnimeData] =
  let
    url = "/anime/" & title[0].toUpperAscii()
    res = ex.connection.req(url).to_selector()
    tds = res.select(".c_h2 div a").concat res.select(".c_h2b div a")

  for anchor in tds:
    let
      pasaage = anchor.innerText.toLowerAscii()
      ignore = "/search?g="

    if pasaage.startsWith(title[0 .. 2].toLowerAscii()) and not anchor.attr("href").contains(ignore):
      result.add AnimeData(
        title: anchor.innerText,
        url: anchor.attr("href"))

  return result.find(title, (proc (d: AnimeData) : string = d.title))

method episodes*(ex: TokyoInsiderEX; url: string) : seq[EpisodeData] =
  let
    anchors = ex.main_els(url, "#inner_page a")

  for i in 1 ..< anchors.len:
    var index = anchors.len - i
    let href = anchors[index].attr("href")

    if href.contains(url & "/episode"):
      result.add EpisodeData(
        url: href,
        title: "Episode " & $i
      )

method formats*(ex: TokyoInsiderEX; url: string) : seq[ExFormatData] =
  let
    anchors = ex.main_els(url, "#inner_page a")

  for anchor in anchors[0 ..< ^1]:
    let
      href = anchor.attr("href")
      title = anchor.innerText

    if not (href.contains("/episode/") or href.contains("/comment")):
      result.add ExFormatData(
        title: title,
        format_identifier: href)     

method get*(ex: TokyoInsiderEX; format: ExFormatData) : MediaFormatData =
  result = MediaFormatData()
  result.video = format.format_identifier
  result.typeExt = extMp4
