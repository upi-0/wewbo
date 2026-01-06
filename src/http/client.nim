{.define: ssl.}

import std/[
  strutils,
  httpclient,
  json,
  uri,
  options,
  net,
  os
]
import ../media/types
import ./cache

# from ../logger import log, info
import ../tui/logger as tl

type
  HttpConnection = ref object of RootObj
    host*: string
    client*: HttpClient
    headers*: HttpHeaders
    cache*: HttpCache
    ssl: SslContext
    log: WewboLogger

proc info(con: HttpConnection, text: string) =
  con.log.info("[HTTP] " & text)

proc ensureCACert(): string =
  let pemName = getAppDir() / "cacert.pem"

  if fileExists(pemName):
    return pemName
  
  const url = "https://curl.se/ca/cacert.pem"
  var
    context = newContext(verifyMode = CVerifyNone)
    client = newHttpClient(sslContext = context)

  pemName.writeFile(client.getContent(url))
  client.close()

  return pemName

proc newHttpConnection*(host: string, ua: string, headers: Option[JsonNode] = none(JsonNode)): HttpConnection =
  var
    accept: array[5, string] = [
      "text/html,application/xhtml+xml,application/xml",
      "q=0.9,image/avif,image/webp,image/apng,*/*",
      "q=0.8,application/signed-exchange",
      "v=b3",
      "q=0.7"
    ]
    base_headers = @[
      ("Accept-Language", "en-US,en;q=0.9"),
      ("Sec-Ch-Ua-Mobile", "?0"),
      ("Sec-Ch-Ua-Platform", "'macOS'"),
      ("Sec-Fetch-Dest", "document"),
      ("Sec-Fetch-Mode", "navigate"),
      ("Sec-Fetch-User", "?1"),
      ("Upgrade-Insecure-Requests", "1"),
      ("User-Agent", ua),
    ]

  if headers.isSome:
    for k, v in headers.get.pairs():
      base_headers.add(
        (k, v.getStr)
      )

  base_headers.add(("Accept", join(accept, ";")))
  base_headers.add(("Host", host))

  let
    caFile = ensureCACert()
    context = newContext(caFile = caFile)
    headers = newHttpHeaders(base_headers)
    client = newHttpClient(
      headers = headers,
      sslContext = context
    )

  return HttpConnection(
    host: host,
    client: client,
    headers: headers,
    cache: HttpCache(),
    ssl: context,
    log: useWewboLogger(host)
  )

proc newHttpConnection*(host: string, header: MediaHttpHeader) : HttpConnection =
  var goblok = newJObject()
  
  for ky, val in header.fieldPairs() :
    if ky != "" and val != "" and ky != "userAgent":
      goblok.add(ky, val.newJString)

  newHttpConnection(host, header.userAgent, goblok.some)  

proc normalize_url*(connection: HttpConnection, url: string): string =
  var
    real_url = url.replace(" ", "+") # Halal dari user input (Kayanya)
    host = connection.host
    schema = "https://"

  if schema in url:
    return url

  if not (
      url.contains(host) or
      url.startsWith(schema & host)
    ):
    if not url.startsWith "/":
      real_url = "/" & url
    return schema & host & real_url

  return real_url

proc reNewClient(connection: HttpConnection) =
  var
    headers = connection.headers
    client = newHttpClient(
      headers = headers,
      sslContext = connection.ssl
    )

  connection.client = client

proc jsonToForm*(j: JsonNode): string =
  var parts: seq[string] = @[]

  for k, v in j.pairs:
    let key = encodeUrl(k)
    let value =
      case v.kind
      of JString: encodeUrl(v.getStr)
      of JInt: encodeUrl($v.getInt)
      of JFloat: encodeUrl($v.getFloat)
      of JBool: encodeUrl($v.getBool)
      else: encodeUrl($v)

    parts.add(key & "=" & value)

  result = parts.join("&")

proc reqq*(client: HttpClient, url: string, mthod: HttpMethod, payload: string, host: string = ""): Response =
  var
    newHeader: seq[(string, string)]

  if host.len > 0:
    newHeader.add(("Host", host))

  if newHeader.len > 0:
    result = client.request(
        url, mthod,
        body = payload,
        headers = newHttpHeaders(newHeader)
      )

  else:
    result = client.request(
      url, mthod,
      body = payload,
    )

proc extractCookie(cookies: string, cookie: string) : string =
  for line in cookies.split("\n"):
    let cookieValue = line.split(";")[0].strip()
    if cookieValue.len > 0:
      if not cookie.isNil :
        var existing = cookie
        if cookieValue notin existing:
          return existing & "; " & cookieValue
      else:
        return cookieValue  

proc req*(
  connection: HttpConnection,
  url: string,
  mthod: HttpMethod = HttpGet,
  save_cookie: bool = true,
  host: string = "",
  payload: string = "",
  useCache: bool = true
): Response =
  var
    content: Response
    url = connection.normalize_url url

  proc loadContent() : Response =
    try:
      return connection.client.reqq(url, mthod, payload, host)
    except ProtocolError:
      connection.info("Renew Http Client")
      connection.reNewClient()
      return connection.client.reqq(url, mthod, payload, host)

  if useCache and mthod == HttpGet :
    if connection.cache.has(url) :
      content = connection.cache.load(url)
    else :
      content = loadContent()
      connection.cache.store(url, content)
  else :
    content = loadContent()

  if save_cookie and content.headers.hasKey("Set-Cookie") and connection.headers.hasKey("Cookie"):
    connection.headers["Cookie"] = extractCookie(
      content.headers["Set-Cookie"],
      connection.headers["Cookie"]
    )

  return content

proc req*(
  connection: HttpConnection,
  url: string,
  mthod: HttpMethod = HttpGet,
  save_cookie: bool = true,
  host: string = "",
  payload: JsonNode = %*{},
  useCache: bool = true
): Response =
  req(connection, url, mthod, save_cookie, host, $payload, useCache)

export HttpConnection, Response, HttpMethod
