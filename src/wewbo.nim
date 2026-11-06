import
  extractor/[all, types, base]

export
  listExtractor, findMatch, getExtractor,
  animes, episodes, formats, subtitles, get,
  AnimeData, EpisodeData, ExFormatData, FormatResolution, AllEpisodeFormats

import
  media/[types, format]

export
  detectExt, detectFormat,
  MediaHttpHeader, MediaSubtitle, MediaSubtitleExt, MediaResolution, MediaFormatData

import
  tui/logger

export
  detectLogMode, newWewboLogger, useWewboLogger, info, text, warn, error, exportLog,
  WewboLogger, WewboLogMode

when isMainModule:
  import
    app/wewbo
  import
    malebolgia
  import
    nimper,
    nimper_proxy/[
      config,
      server
    ]

  var
    m = createMaster()
    nimperProxyConfig = initDefaultProxyConfig()

  block:
    nimperProxyConfig.verbose = false
    nimperProxyConfig.port = 3001

  block:
    ensureGlobalInit()

    m.awaitAll:
      m.spawn main()
      m.spawn runProxyServer(nimperProxyConfig)
