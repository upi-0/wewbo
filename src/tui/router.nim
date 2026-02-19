import
  questionable/router,
  logger, ask

from strutils import `%`
from sequtils import toSeq
from marshal import
  `$$`,
  to

proc start*(route: Route): void =
  route.actions.add RouteAction(title: "Back")

  var selectedAction: RouteAction

  while true:
    selectedAction = route.actions.ask(route.title)
    
    if selectedAction.isNil or selectedAction.title == "Back":
      break

    try:
      route.data = selectedAction.data
      selectedAction.action(route)
    except RouteActionError:
      route.logger.error("[$#] $#" % [route.logger.name, getCurrentExceptionMsg()])

proc raiseError*[T: RouteActionError](route: Route; error: typedesc[T]; message: string): void =
  raise newException(error, message)

proc session*[T: tuple](kimito: typedesc[T]): ptr T {.inline.} =
  result = cast[ptr kimito](alloc0 sizeof T)

proc action*(title: string, action: RouteActionProc; data: string = ""): RouteAction {.inline.} =
  result = RouteAction(title: title, action: action, data: data)

proc app*(title: string; actions: openArray[RouteAction]): Route {.inline.} =
  result = Route(title: title, actions: actions.toSeq(), logger: useWewboLogger(title))

export
  Route, RouteAction, RouteActionProc

export
  ask, `$$`, to

when isMainModule:
  type Surijal = object
    name: string

  let
    streamSession = session tuple[playerName: string, episodes: seq[string]]
    surijal = Surijal(name: "upi")

  proc changePlayer(r: Route) =
    let skamto = to[Surijal](r.data)
    streamSession.playerName = skamto.name

  proc addEpisodes(r: Route) =
    streamSession.episodes.add "New Episode"

  proc showAll(r: Route) =
    if streamSession.playerName == "":
      r.logger.info("Saat. AAA. Bayang mu pun tak mampu lihat lagi!!!")
      r.logger.info("Pernah kah kau merasa?")

      r.raiseError(error = RouteActionError, message = "Player Name is nil")

    r.logger.info(streamSession.playerName)
    r.logger.info($streamSession.episodes)

  let
    actions = @[
      action("Change Player", changePlayer, $$surijal),
      action("Add Episodes", addEpisodes),
      action("Show Data", showAll)
    ]    

  app("hime", actions).start()
  streamSession[].reset()
