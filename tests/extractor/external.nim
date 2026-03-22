discard """
  exitcode: 0
  cmd: "nim c --skipParentCfg $file"
  targets: c cpp
"""

import
  unittest, random

import
  ../../src/extractor/[base, all]

randomize()

suite "Animepahe Tests":
  setup:
    const
      availableSource = ["pahe", "taku"]
      animeTitle = "slow loop"

  test "Scrape for each extractor":
    var ex: BaseExtractor

    for exName in availableSource:
      ex = getExtractor(exName, "silent")
      
      let
        animeDatas = ex.animes(animeTitle)
        animeSelectR = rand(0 ..< animeDatas.len)
        anime = ex.get animeDatas[animeSelectR]

      let
        episodeDatas = ex.episodes(anime)
        episodeSelectR = rand(0 ..< episodeDatas.len)    
        episode = ex.get(episodeDatas[episodeSelectR])

      check ex.formats(episode).len > 0

    # Test closing
    close(ex)
    check ex.connection.isNil
    check ex.lg.isNil
