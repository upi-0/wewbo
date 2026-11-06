import std/[
  strutils,
  json,
  uri,
  options,
  tables,
  httpcore
]

import nimper
import
  ../media/types,
  ../tui/logger,
  ./cache

type
  HttpConnection* = ref object of RootObj
    host*: string
    session*: ImpersonateSession
    headers*: HttpHeaders
    cache*: HttpCache
    target*: ImpersonateTarget
    log*: WewboLogger

  HttpLocalData* = tuple[
    target: ImpersonateTarget,
    logMode: WewboLogMode
  ]

let
  cptr = cast[ptr HttpLocalData](alloc0 sizeof HttpLocalData)

proc client*(connection: HttpConnection): ImpersonateSession {.inline.} =
  connection.session

proc status*(response: Response): string {.inline.} =
  $response.statusCode & " OK"

proc info(con: HttpConnection, text: string) =
  con.log.info("[$#] " % [con.host] & text)

proc newHttpConnection*(
  host: string,
  ua: string = "",
  headers: options.Option[JsonNode] = none(JsonNode),
  mode: WewboLogMode = mTui,
  useCompress: bool = true,
  target: ImpersonateTarget = itFirefox155
): HttpConnection =
  cptr.logMode = mode
  cptr.target = target

  let log = useWewboLogger(host, mode=mode)
  var httpHeaders = newHttpHeaders()

  if headers.isSome:
    for k, v in headers.get.pairs():
      httpHeaders.add(k, v.getStr)

  if ua.len > 0:
    httpHeaders["User-Agent"] = ua

  let session = newImpersonateSession(
    target = target,
    defaultHeaders = true,
    headers = @[],
    maxRedirects = 0
  )

  result = HttpConnection(
    host: host,
    session: session,
    headers: httpHeaders,
    cache: HttpCache(),
    target: target,
    log: log
  )

  result.info("Target: $#" % [$target])
  result.info("Use gzip: $#" % [if useCompress: "YES" else: "NO"])

proc newHttpConnection*(host: string, header: MediaHttpHeader, mode: WewboLogMode = mTui): HttpConnection =
  var goblok = newJObject()

  for ky, val in header.fieldPairs():
    if ky != "" and val != "" and ky != "userAgent":
      goblok.add(ky, val.newJString)

  newHttpConnection(host, header.userAgent, goblok.some, mode)

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
    if not real_url.startsWith "/":
      real_url = "/" & real_url
    return schema & host & real_url

  return real_url

proc reNewClient(connection: HttpConnection) =
  if connection.session != nil:
    try:
      connection.session.close()
    except CatchableError:
      discard

  connection.session = newImpersonateSession(
    target = connection.target,
    defaultHeaders = true,
    headers = @[]
  )

proc jsonToForm*(j: JsonNode): string {.deprecated: "use http/utils instead".} =
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

proc reqq*(session: ImpersonateSession, url: string, mthod: HttpMethod, payload: string): Response =
  session.request(
    url = url,
    httpMethod = $mthod,
    body = payload
  )

proc reqq*(session: ImpersonateSession, url: string, mthod: HttpMethod, payload: string, host: string): Response {.deprecated: "Param 'host' is deprecated".} =
  reqq(session, url, mthod, payload)

proc extractCookie(cookies: string, cookie: string): string =
  for line in cookies.split("\n"):
    let cookieValue = line.split(";")[0].strip()
    if cookieValue.len > 0:
      if cookie.len > 0:
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
  payload: string = "",
  useCache: bool = false
): Response {.gcsafe.} =
  var
    content: Response
    url = connection.normalize_url(url)

  proc toReqHeaders(hdrs: HttpHeaders): seq[(string, string)] =
    result = @[]
    if hdrs != nil:
      for k, v in hdrs.pairs:
        result.add((k, v))

  proc loadContent(): Response =
    connection.info(url)
    try:
      return connection.session.request(
        url = url,
        httpMethod = $mthod,
        headers = toReqHeaders(connection.headers),
        body = payload
      )
    except CurlImpersonateError as e:
      connection.info("Connection error: " & e.msg & "; renewing session")
      connection.reNewClient()
      return connection.session.request(
        url = url,
        httpMethod = $mthod,
        headers = toReqHeaders(connection.headers),
        body = payload
      )

  if useCache and mthod == HttpGet:
    if connection.cache.has(url):
      content = connection.cache.load(url)
    else:
      content = loadContent()
      connection.cache.store(url, content)
  else:
    content = loadContent()

  if save_cookie:
    let existingCookie = if connection.headers.hasKey("Cookie"): $connection.headers["Cookie"] else: ""
    if content.cookies.len > 0:
      var cookieParts: seq[string] = @[]
      for c in content.cookies:
        let parts = c.split('\t')
        if parts.len >= 7:
          cookieParts.add(parts[5] & "=" & parts[6])
        else:
          cookieParts.add(c)
      if cookieParts.len > 0:
        connection.headers["Cookie"] = cookieParts.join("; ")
    elif content.headers.hasKey("Set-Cookie"):
      var setCookies: seq[string] = @[]
      if content.headers.table != nil:
        for val in content.headers.table.getOrDefault("set-cookie", @[]):
          setCookies.add(val)
      let scStr = if setCookies.len > 0: setCookies.join("\n") else: $content.headers["Set-Cookie"]
      connection.headers["Cookie"] = extractCookie(scStr, existingCookie)

  return content

proc req*(
  connection: HttpConnection,
  url: string,
  mthod: HttpMethod = HttpGet,
  save_cookie: bool = true,
  host: string,
  payload: string = "",
  useCache: bool = false
): Response {.deprecated: "Param 'host' is deprecated".} =
  req(connection, url, mthod, save_cookie, payload, useCache)

proc req*(
  connection: HttpConnection,
  url: string,
  mthod: HttpMethod = HttpGet,
  save_cookie: bool = true,
  useCache: bool = false,
  payload: JsonNode
): Response {.gcsafe.} =
  req(connection, url, mthod, save_cookie, $payload, useCache)

proc req*(
  connection: HttpConnection,
  url: string,
  mthod: HttpMethod = HttpGet,
  save_cookie: bool = true,
  host: string,
  useCache: bool = false,
  payload: JsonNode
): Response {.deprecated: "Param 'host' is deprecated".} =
  req(connection, url, mthod, save_cookie, $payload, useCache)

proc close*(connection: HttpConnection) =
  if connection.log != nil:
    connection.log.stop()
    connection.log = nil
  if connection.session != nil:
    connection.session.close()
    connection.session = nil

export HttpConnection, Response, HttpMethod, ImpersonateTarget
