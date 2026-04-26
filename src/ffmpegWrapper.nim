import
  os,
  options,
  strutils,
  sequtils,
  tables

import
  ./process,
  ./media/types,
  ./tui/logger

type
  FfmpegWrapperOption* = tuple[
    crf: int = 28,
    fps: int = 25,
    sub: bool = true,
  ]

  FfmpegWrapper* = ref object of CliApplication
    outdir*: string
    targetExt: string = "mp4"
    options*: FfmpegWrapperOption

proc newFfmpegWrapper*(outdir: string; options: FfmpegWrapperOption; logMode: WewboLogMode = mTui): FfmpegWrapper =
  result = FfmpegWrapper(name: "ffmpeg", outdir: outdir, options: options, logMode: logMode).setUp()

method failureHandler(ffmpeg: FfmpegWrapper, context: CLiError) =
  raise newException(ValueError, "ffmpeg is not detected on your system.")

method specialLineCb(cli: CliApplication) : SpecialLineProc =
  (
    proc (x: string) : bool =
      x.contains("frame=")
  )

proc setHeader(ffmpeg: FfmpegWrapper, ty, val: string) =
  let ngantukCok = {
    "userAgent" : "User-Agent",
    "referer" : "Referer",
    "cookie" : "Cookie"
  }.toTable

  ffmpeg.addArg "-headers"
  ffmpeg.addArg "$#: $#" % [ngantukCok[ty], val]

proc setUpHeader(ffmpeg: FfmpegWrapper, headers: Option[MediaHttpHeader]) =
  if headers.isNone :
    return

  for chi, no in headers.get.fieldPairs() :
    if no != "" :
      ffmpeg.setHeader(chi, no)

proc setCodec(ffmpeg: FfmpegWrapper) =
  ffmpeg.addArg "-vcodec"
  ffmpeg.addArg "libx264"

  ffmpeg.addArg "-crf"
  ffmpeg.addArg $ffmpeg.options.crf

  ffmpeg.addArg "-r"
  ffmpeg.addArg $ffmpeg.options.fps

proc setInput(ffmpeg: FfmpegWrapper, media: MediaFormatData) =
  ffmpeg.addArg "-i"
  ffmpeg.addArg media.video

proc setOutput(ffmpeg: FfmpegWrapper, output: string) =
  proc parseTargetFile(s: string) : string =
    const nega = ["[", "]", "/", "\\", "?", ","]
    result = s.replace(" ", "-")

    for ne in nega:
      result = result.replace(ne)

  if not dirExists(ffmpeg.outdir) :
    createDir(ffmpeg.outdir)

  ffmpeg.addArg "$#.$#" % [ffmpeg.outdir / output.parseTargetFile(), ffmpeg.targetExt]

proc handleSubtitle(ffmpeg: FfmpegWrapper, media: MediaFormatData) =
  let
    file = media.subtitle.get.url
    tempFile = "wewbo_sub_file" & ".ass"

  ffmpeg.addArg "-i"
  ffmpeg.addArg file

  ffmpeg.addArg "-c:s"
  ffmpeg.addArg "ass"

  ffmpeg.addArg tempFile

  if ffmpeg.execute("Downloading Subtitle...") < 1 :
    ffmpeg.setUpHeader(media.headers)
    ffmpeg.setInput(media)
    ffmpeg.addArg "-vf"
    ffmpeg.addArg "ass=" & tempFile

  else :
    raise newException(ValueError, "Gagal Download Subtitle Jir")

proc deleteTempFile {.nimcall.} = removeFile("wewbo_sub_file.ass")

proc download*(ffmpeg: FfmpegWrapper, input: MediaFormatData, output: string) : int =
  if input.subtitle.isSome and ffmpeg.options.sub:
    ffmpeg.log.info("Extracting subtitle.")
    ffmpeg.setUpHeader(input.headers)
    ffmpeg.handleSubtitle(input)
  else:
    ffmpeg.setUpHeader(input.headers)
    ffmpeg.setInput(input)

  ffmpeg.setCodec()
  ffmpeg.setOutput(output)

  ffmpeg.execute("Downloading " & output, after = some(deleteTempFile))

proc downloadAll*(ffmpeg: FfmpegWrapper, inputs: openArray[MediaFormatData], outputs: openArray[string]) : seq[int] =
  assert inputs.len == outputs.len

  ffmpeg.log.info("Downloading Options: " & $ffmpeg.options)
  sleep(3_000)

  for (input, output) in zip(inputs, outputs) :
    result.add(
      ffmpeg.download(input, output))
