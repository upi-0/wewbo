discard """
  exitcode: 0
  cmd: "nim c --skipParentCfg $file"
"""

import
  unittest, os

import
  ../../src/media/[downloader, types],
  ../../src/process

suite "Downloader Test":
  setup:
    const
      output = "testVideo"        
      url = "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4"

  test "download using FFMPEG":
    let
      downloader = FfmpegDownloader(name: "ffmpeg", outdir: ".", options: (28, 25, false), logMode: mEcho).setup()
      media = MediaFormatData(
        video: url,
        typeExt: extMp4)
      exOutput = output & ".mp4"        

    check downloader.download(media, output) < 1
    check fileExists(exOutput)
    removeFile(exOutput)
    check not fileExists(exOutput)
