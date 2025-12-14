import xmltree
import q
import options
import ../base
import ../../http/[
  client,
  response
]
from strutils import split, parseInt

type
  KuramanimeEX {.final.} = ref object of BaseExtractor

proc newKuramanime*(ex: var BaseExtractor) =
  ex = KuramanimeEX(name: "kura", host: "v8.kuramanime.tel")

method animes*(ex: KuramanimeEX, title: string = "") : seq[AnimeData] =
  var
    url: string = "/anime?search=" & title
    que: string = "div.product__item__text h5"
    els: seq[XmlNode] = ex.main_els(url, que)

  for h5 in els :
    var ael = h5.select("a")[0]
    result.add AnimeData(
      title: ael.innerText,
      url: ael.attr("href")
    )

method episodes*(ex: KuramanimeEX, url: string) : seq[EpisodeData] = 
  var
    que: string = "a#episodeLists"
    ael: seq[XmlNode] = ex.main_el(url, que).attr("data-content").to_selector().select("a")
    tkn: string = ex.connection.req("/assets/Ks6sqSgloPTlHMl.txt").to_readable()
    eps: int = len ael
    
    startt: int
    endd: int 

  template url_g(ex: KuramanimeEX, url: string, episode: int, token: string) : string =
    ex.connection.normalize_url(
      url & "/episode/" & $episode & "?Ub3BzhijicHXZdv=" & token & "&C2XAPerzX1BM7V9=kuramadrive")

  template sE(el) : int =
    parseInt(el.attr("href").split("/")[^1])

  if eps >= 16 :
    startt = ael[0].sE
    endd = ael[1].sE

  else :
    startt = 1
    endd = eps

  for i in startt .. endd :
    result.add EpisodeData(
      title: "Episode " & $i,
      key: i,
      url: ex.url_g(url, i, tkn)
    )

method formats*(ex: KuramanimeEX, url: string) : seq[ExFormatData] =
  var
    sources: seq[XmlNode] = ex.main_els(url, "video source")

  for source in sources :
    result.add ExFormatData(
      title: source.attr("size"),
      format_identifier: source.attr("src")
    )

method get*(ex: KuramanimeEX, data: ExFormatData) : MediaFormatData =
  result.video = data.format_identifier
  result.typeExt = extMp4

export KuramanimeEX
