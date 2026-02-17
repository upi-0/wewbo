import
  terminal, options

import
  # ./ask,
  ../opt,
  ../tui/ask,
  ../extractor/[all, base],
  ../player/all,
  ../media/translate,
  ../languages

from httpclient import close
from illwill import illwillDeinit

type
  ControllerAction = enum
    exit,
    prevEpisode,
    nextEpisode,
    changeEpisode,
    selectAndPlay,
    selectAndPlayWithTranslate,
    changePlayer,
    changeSource

  Action = ref object of Questionable
    val: ControllerAction

  ExtractorQuestionable = ref object of Questionable
    val: string

proc controller_loop(
  extractor: BaseExtractor,
  player: PLayer,
  episodes: seq[EpisodeData],
  start_index: int = 0,
  direct: bool = false,
  requestChangeExtractor: var bool
) =
  var
    actions: seq[Action]
    episode: EpisodeData

  var
    idx = start_index
    pler = player

  let
    seAction = Action(title: "Select Resolution & Play", val: selectAndPlay)
    seActionTranslate = Action(title: "Select Resolution & Play with Auto-Translate",
        val: selectAndPlayWithTranslate)
    ceAction = Action(title: "Change Episode", val: changeEpisode)
    cpAction = Action(title: "Change Player", val: changePlayer)
    # csAction = Action(title: "Change Source", val: changeSource) || Kayanya ga skarang deh~
    exitAction = Action(title: "Exit", val: exit)
    nextAction = Action(title: "Next Episode", val: nextEpisode)
    prevAction = Action(title: "Prev Episode", val: prevEpisode)

  while true:
    episode = episodes[idx]
    actions = @[]

    actions.add seAction
    actions.add seActionTranslate
    if idx < episodes.len - 1:
      actions.add nextAction
    if idx > 0:
      actions.add prevAction
    actions.add ceAction
    actions.add cpAction
    # actions.add csAction
    actions.add exitAction

    case actions.ask(title = episode.title).val:
      of exit:
        close(extractor.connection.client)
        illwillDeinit()
        eraseScreen()
        showCursor()
        quit(0)

      of nextEpisode:
        idx += 1
        continue

      of prevEpisode:
        idx -= 1
        continue

      of changeEpisode:
        var eps = episodes.ask(title = episode.title)
        idx = episodes.find(eps)
        continue

      of selectAndPlay:
        let
          format = extractor.formats(extractor.get episode).ask(
              title = "Select Format")
          media_format = extractor.get(format)
          subtitles = extractor.subtitles(format)

        if subtitles.isSome:
          let subtitle = subtitles.get.ask(title = "Select subtitle")
          pler.watch(media_format, subtitle.some)
        else:
          pler.watch(media_format)

        continue

      of selectAndPlayWithTranslate:
        let
          format = extractor.formats(extractor.get episode).ask(
              title = "Select Format")
          media_format = extractor.get(format)
          subtitles = extractor.subtitles(format)

        if subtitles.isSome:
          var translateOption = newJObject()

          translateOption.putEnum(["indonesian,id", "french,fr", "vietnamese,vi"], "targetLang")
          translateOption.putEnum(subtitles.get, "sourceSub")
          translateOption.putEnum(["google", "gemini", "openai"], "provider")
          translateOption.put("-", "apiKey")
          translateOption.ask()

          let
            subtitle = subtitles.get[translateOption["sourceSub"].s]
            targetLang = translateOption["targetLang"].s.getLang()

          # Auto-translate the subtitle
          if media_format.headers.isSome:
            subtitle.translateVTTV2(media_format.headers.get, targetLang)

          pler.watch(media_format, subtitle.some)
        else:
          pler.watch(media_format)

        continue

      of changePlayer:
        var bentar: seq[Questionable]
        for pler in players:
          bentar.add Questionable(title: pler)
        pler = getPlayer(bentar.ask(title = "Select Title").title)
        continue

      of changeSource:
        requestChangeExtractor = true
        return

proc extractors(): seq[ExtractorQuestionable] =
  for eks in listExtractor():
    result.add(
      ExtractorQuestionable(title: eks, val: eks)
    )

proc main_controller_loop*(
  extractor: BaseExtractor,
  player: PLayer,
  episodes: seq[EpisodeData],
  start_index: int = 0,
  direct: bool = false,
) {.deprecated.} =
  var
    rijal: bool = false

  controller_loop(extractor, player, episodes, start_index, false, rijal)

proc main_controller_loop*(
  title: string;
  extractor: BaseExtractor;
  player: Player;
  animeDataOpt: Option[AnimeData] = none(AnimeData)
) =
  let
    anDataOpt = addr animeDataOpt

  var
    rijal = false
    ex = extractor

  var
    start_idx: int
    episodes: seq[EpisodeData]
    animedata: AnimeData

  proc to_controller =
    if anDataOpt[].isSome:
      animedata = anDataOpt[].get

    else:
      animedata = ex.ask(title)

    (start_idx, episodes) = ex.ask(animedata)
    controller_loop(ex, player, episodes, start_idx, false, rijal)

  while true:
    if rijal:
      ex.close()
      anDataOpt[] = none(AnimeData)
      ex = getExtractor(
        extractors().ask(title = "Select new source.").val
      )

    to_controller()
