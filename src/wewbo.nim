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

when defined(musl) and defined(curlimpersonate):
  {.emit: """
  #include <stdint.h>
  extern uint32_t SSL_CTX_set_mode(void *ctx, uint32_t mode);
  extern int SSL_set_tlsext_host_name(void *ssl, const char *name);

  long SSL_CTX_ctrl(void *ctx, int cmd, long larg, void *parg) {
    if (cmd == 33 /* SSL_CTRL_MODE */) return (long)SSL_CTX_set_mode(ctx, (uint32_t)larg);
    return 1;
  }
  long SSL_ctrl(void *ssl, int cmd, long larg, void *parg) {
    if (cmd == 55 /* SSL_CTRL_SET_TLSEXT_HOSTNAME */) return (long)SSL_set_tlsext_host_name(ssl, (const char *)parg);
    return 1;
  }
  int SSL_CTX_set_ciphersuites(void *ctx, const char *str) {
    return 1;
  }
  """.}

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
