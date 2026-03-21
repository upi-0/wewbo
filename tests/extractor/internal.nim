discard """
  exitcode: 0
  cmd: "nim c --skipParentCfg $file"
  targets: c cpp
"""

import
  unittest

import
  ../../src/extractor/base,
  ../../src/extractor/types

import
  ../../src/tui/logger

type
  DummyExtractor = ref object of BaseExtractor

method animes*(ex: DummyExtractor, title: string): seq[AnimeData] =
  return @[]

method episodes*(ex: DummyExtractor, url: string): seq[EpisodeData] =
  return @[]

suite "BaseExtractor Tests":
  setup:
    var defaultHost = "https://example.com"
    var defaultName = "dummy_extractor"
    var ex = DummyExtractor(host: defaultHost, name: defaultName)

  test "Initialization of BaseExtractor":
    ex.init(logMode = mSilent)
    check ex.name == defaultName
    check ex.host == defaultHost
    check ex.userAgent == "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:146.0) Gecko/20100101 Firefox/146.0"
    check not ex.connection.isNil
    check not ex.lg.isNil

    # Test closing
    ex.close()
    check ex.connection.isNil
    check ex.lg.isNil

  test "Base Extractor Default Methods":
    var dummyAnime = AnimeData(url: "https://example.com/anime")
    check ex.get(dummyAnime) == "https://example.com/anime"

    var dummyEpisode = EpisodeData(url: "https://example.com/episode")
    check ex.get(dummyEpisode) == "https://example.com/episode"
