import
  questionable/router,
  logger, ask

import  
  sequtils

proc start*(route: Route): void =
  route.actions.add RouteAction(title: "Back")

  var selectedAction: RouteAction

  while true:
    selectedAction = route.actions.ask(route.title)
    if selectedAction.isNil or selectedAction.title == "Back":
      break
    selectedAction.action(route)

proc session*[T: tuple](kimito: typedesc[T]): ptr T {.inline.} =
  result = cast[ptr kimito](alloc0 sizeof T)

proc action*(title: string, action: RouteActionProc): RouteAction {.inline.} =
  result = RouteAction(title: title, action: action)

proc app*(title: string; actions: openArray[RouteAction]): Route {.inline.} =
  result = Route(title: title, actions: actions.toSeq(), logger: useWewboLogger(title))


when isMainModule:
  import os
  let streamSession = session tuple[playerName: string, episodes: seq[string]]

  proc changePlayer(r: Route) =
    streamSession.playerName = "MPV"

  proc addEpisodes(r: Route) =
    streamSession.episodes.add "New Episode"

  proc showAll(r: Route) =
    r.logger.info(streamSession.playerName)
    r.logger.info($streamSession.episodes)
    sleep(2_000)

  let
    actions = @[
      action("Change Player", changePlayer),
      action("Add Episodes", addEpisodes),
      action("Show Data", showAll)
    ]    

  app("Streaming", actions).start()
  streamSession[].reset()
