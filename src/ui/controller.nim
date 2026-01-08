import
  terminal, options

import
  ./ask,
  ../extractor/all,
  ../player/all,
  ../media/types

from httpclient import close
from illwill import illwillDeinit

type
  ControllerAction = enum
    exit,
    prevEpisode,
    nextEpisode,
    changeEpisode,
    selectAndPlay,
    changePlayer,

  Action = ref object of Questionable
    val: ControllerAction

proc main_controller_loop(
  extractor: BaseExtractor,
  player: PLayer,
  episodes: seq[EpisodeData],
  start_index: int = 0,
  direct: bool = false,
) = 
  var
    actions: seq[Action]
    episode: EpisodeData

  var
    idx = start_index
    pler = player

  let    
    seAction = Action(title: "Select Resolution & Play", val: selectAndPlay)
    ceAction = Action(title: "Change Episode", val: changeEpisode)
    cpAction = Action(title: "Change Player", val: changePlayer)
    exitAction = Action(title: "Exit", val: exit)
    nextAction = Action(title: "Next Episode", val: nextEpisode)
    prevAction = Action(title: "Prev Episode", val: prevEpisode)

  while true :
    episode = episodes[idx]
    actions = @[]

    actions.add seAction
    if idx < episodes.len - 1 :
      actions.add nextAction
    if idx > 0 :
      actions.add prevAction
    actions.add ceAction
    actions.add cpAction
    actions.add exitAction      

    case actions.ask(title = episode.title).val:
      of exit:
        close(extractor.connection.client)
        illwillDeinit()
        eraseScreen()
        showCursor()
        quit(0)

      of nextEpisode :
        idx += 1
        continue

      of prevEpisode :
        idx -= 1
        continue

      of changeEpisode :
        var eps = episodes.ask(title = episode.title)
        idx = episodes.find(eps)
        continue

      of selectAndPlay :
        let
          format = extractor.formats(extractor.get episode).ask(title="Select Format")
          media_format = extractor.get(format)
          subtitles = extractor.subtitles(format)

        if subtitles.isSome:
          let subtitle = subtitles.get.ask(title="Select subtitle")
          pler.watch(media_format, subtitle.some)
        else:
          pler.watch(media_format)

        continue

      of changePlayer :
        var bentar: seq[Questionable]
        for pler in players :
          bentar.add Questionable(title: pler)
        pler = getPlayer(bentar.ask(title="Select Title").title)
        continue

export 
  main_controller_loop