discard """
  Belom jadi jir.
  Males banget nyelesainnya.
  Sementara cuma extract info penting-penting aja.
"""

import
  types,
  strutils,
  options,
  sequtils,
  algorithm

import
  ../http/[client, response],
  ../utils,
  ../tui/logger

type
  M3u8XType = enum
    xUnknown
    xStreamInf = "#EXT-X-STREAM-INF:"
    xInf = "#EXTINF:"
    xVersion = "#EXT-X-VERSION:"
    xMediaSequence = "#EXT-X-MEDIA-SEQUENCE:"
    xAudio = "#EXT-X-MEDIA:TYPE=AUDIO"

  M3u8Frame* = object of RootObj
    resolution*: string
    url*: string
    codecs*: string
    bandwidth*: int
    frameRate*: float
    programId* {.deprecated.} : int

  M3u8MasterObject* = object of RootObj
    formats*: seq[M3u8Frame]
    audioUrl*: seq[string]
    version*: int
    baseUrl*: string
    contentUrl*: string
    segments*: seq[string]
    targetDuration*: int
    headers: MediaHttpHeader

proc types(line: string): M3u8XType =
  for typex in M3u8XType:
    if $typex != "" and line.startsWith($typex):
      return typex

  return xUnknown

proc parseM3u8Master*(host: string, url: string, headers: MediaHttpHeader): M3u8MasterObject =
  let
    client = newHttpConnection(host, headers, mode=mSilent)
    contentUrl = url # Save original URL before overwriting
    url = client.req(url).to_readable()
    lines = url.splitLines().toSeq

  proc resolveUrl(uri: string) : string =
    if uri.startsWith("/"):
      result = "https://" & host & uri
    else:
      let basePath = contentUrl[0..<contentUrl.rfind("/") + 1]
      result = basePath & uri  

  for idx, line in lines:
    case line.types
    of xAudio:
      result.audioUrl.add line.getBetween(",URI=\"", "\"").resolveUrl()
    of xVersion:
      result.version = line.getAfter("#EXT-X-VERSION:").parseInt
    of xStreamInf:
      let
        bandwidth = line.getAttribute("BANDWIDTH=")
        frameRateStr = line.getAttribute("FRAME-RATE=")
        # programIdStr  = line.getAttribute("PROGRAM-ID=")
        uri = lines[idx + 1]
        resolvedUrl =
          if uri.startsWith("/"):
            "https://" & host & uri
          else:
            let basePath = contentUrl[0..<contentUrl.rfind("/") + 1]
            basePath & uri

      result.formats.add M3u8Frame(
        resolution: line.getAttribute("RESOLUTION="),
        url: resolvedUrl,
        codecs: line.getBetween("CODECS=\"", "\""),
        bandwidth: if bandwidth.len > 0: bandwidth.parseInt else: 0,
        frameRate: if frameRateStr.len > 0: frameRateStr.parseFloat else: 0.0,
        # programId: if programIdStr.len > 0: programIdStr.parseInt else: 0
      )

    else:
      continue

  result.headers = headers

# Helper functions for format sorting and filtering
func parseResolution(resolution: string): tuple[width: int, height: int] =
  try:
    let parts = resolution.split("x")
    if parts.len == 2:
      return (width: parts[0].parseInt, height: parts[1].parseInt)
  except:
    discard
  return (width: 0, height: 0)

func sortByResolution*(formats: seq[M3u8Frame], descending: bool = true): seq[M3u8Frame] =
  result = formats
  if descending:
    result.sort(proc (a, b: M3u8Frame): int =
      let
        aRes = parseResolution(a.resolution)
        bRes = parseResolution(b.resolution)
      cmp(bRes.height, aRes.height)
    )
  else:
    result.sort(proc (a, b: M3u8Frame): int =
      let
        aRes = parseResolution(a.resolution)
        bRes = parseResolution(b.resolution)
      cmp(aRes.height, bRes.height)
    )

func getFormatByResolution*(master: M3u8MasterObject, targetResolution: string): Option[M3u8Frame] =
  for format in master.formats:
    if format.resolution == targetResolution:
      return some(format)
  return none(M3u8Frame)

func getFormatByMinResolution*(master: M3u8MasterObject, minHeight: int): seq[M3u8Frame] =
  result = @[]
  for format in master.formats:
    let res = parseResolution(format.resolution)
    if res.height >= minHeight:
      result.add(format)

proc `$`*(frame: M3u8Frame): string =
  result = "Resolution: " & frame.resolution
  if frame.bandwidth > 0:
    result &= ", Bandwidth: " & $(frame.bandwidth div 1000) & " kbps"
  if frame.frameRate > 0:
    result &= ", FPS: " & $frame.frameRate
  if frame.codecs.len > 0:
    result &= ", Codecs: " & frame.codecs

proc writeDummyM3u8*(frame: M3u8Frame; audio: string): string =
  result &= "#EXTM3U\n"
  result &= "#EXT-X-INDEPENDENT-SEGMENTS\n"
  result &= "#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID=\"stereo\",NAME=\"Japanese\",DEFAULT=YES,AUTOSELECT=YES,FORCED=YES,LANGUAGE=\"jpn\",URI=\"" & audio & "\"\n"
  result &= "#EXT-X-STREAM-INF:BANDWITH=" & $frame.bandwidth & ",AUDIO=\"stereo\"\n"
  result &= frame.url
  