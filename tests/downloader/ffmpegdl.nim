discard """
  exitcode: 0
  cmd: "nim c --skipParentCfg $file"
"""

import
  unittest, os, osproc

import
  ../../src/media/[downloader, types],
  ../../src/tui/logger

suite "Downloader Test":
  test "download local video using FFMPEG":
    let tmpDir = getTempDir() / "wewbo_ffmpegdl_test"
    createDir(tmpDir)
    defer: removeDir(tmpDir)

    let srcVideo = tmpDir / "sample_src.mp4"
    let (_, genCode) = execCmdEx(
      "ffmpeg -y -hide_banner -loglevel error -f lavfi -i color=c=blue:s=160x120:d=1 " &
      "-f lavfi -i anullsrc=r=44100:cl=mono -t 1 -c:v libx264 -pix_fmt yuv420p -c:a aac " &
      quoteShell(srcVideo)
    )
    require genCode == 0

    let
      opts = FfmpegDownloaderOption(
        subtitleMode: smNone,
        keepFormat: true,
        container: cfMp4,
        overwrite: true,
        retries: 0
      )
      downloader = newFfmpegDownloader(outdir = tmpDir, options = opts, logMode = mSilent)
      media = MediaFormatData(
        video: srcVideo,
        typeExt: extMp4
      )
      outName = "testVideo"
      exOutput = tmpDir / (outName & ".mp4")

    check downloader.download(media, outName) == 0
    check fileExists(exOutput)
    check getFileSize(exOutput) > 0
