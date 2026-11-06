import tables
import nimper/client

type 
  HttpCache* = ref object of RootObj
    all* = initTable[string, Response](10)

proc store*(cache: HttpCache, url: string, response: var Response) =
  if response.statusCode == 200:
    cache.all[url] = response

proc load*(cache: HttpCache, url: string) : Response =
  result = cache.all[url]

proc has*(cache: HttpCache, url: string) : bool =
  cache.all.hasKey(url)

when isMainModule :
  var cac = HttpCache()
  var coc = cac.has("https://httpbin.org/get")

  echo coc

export hasKey
