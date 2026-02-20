import
  questionable/router,
  logger, ask

from strutils import `%`
from sequtils import toSeq
from marshal import
  `$$`,
  to

proc start*[T](route: Route[T]): void =
  route.actions.add RouteAction[T](title: "Back")

  var selectedAction: RouteAction[T]

  while true:
    selectedAction = route.actions.ask(route.title)
    
    if selectedAction.isNil or selectedAction.title == "Back":
      break

    try:
      route.data = selectedAction.data
      selectedAction.action(route)
    except RouteActionError:
      route.logger.error("[$#] $#" % [route.logger.name, getCurrentExceptionMsg()])

  block closeDirectly:
    route.session[].reset()

proc raiseError*[T: RouteActionError](route: Route; error: typedesc[T]; message: string): void =
  raise newException(error, message)

proc creteSession*[T: tuple](terlaluLama: Route[T]; defaultValue: T = T.default): void {.inline.} =
  terlaluLama.session = cast[ptr T](alloc0 sizeof T)
  terlaluLama.session[] = defaultValue

proc action*[T](title: string, action: RouteActionProc[T]; data: string = ""): RouteAction[T] {.inline.} =
  result = RouteAction[T](title: title, action: action, data: data)

proc app*[T](title: string; actions: openArray[RouteAction[T]]): Route[T] {.inline.} =
  result = Route[T](title: title, actions: actions.toSeq(), logger: useWewboLogger(title))

export
  Route, RouteAction, RouteActionProc

export
  ask, `$$`, to

when isMainModule:
  discard """This is an example"""
  
  import
    terminal, os

  type
    Session = tuple[playerName: string, episodes: seq[string]]
    RouteRijal = Route[Session]    

  proc changePlayer(r: RouteRijal) =
    r.session.playerName = "SUDAPDAP"

  proc addEpisodes(r: RouteRijal) =
    for i in 0 .. 100_000:
      r.session.episodes.add "New Episode"

    sleep(1_000)      

  proc showAll(r: RouteRijal) =
    if r.session.playerName == "":
      r.logger.info("Saat. AAA. Bayang mu pun tak mampu lihat lagi!!!")
      r.logger.info("Pernah kah kau merasa?")

      r.raiseError(error = RouteActionError, message = "Player Name is nil")

    block cetakInfo:
      r.logger.info(r.session.playerName)
      r.logger.info($r.session.episodes)
      sleep(3_000)

  let
    actions = @[
      action("Add Episodes", addEpisodes),
      action("Change Player", changePlayer),
      action("Show Data", showAll)
    ]
    himeApp = app("hime", actions)

  himeApp.creteSession((playerName: "ini dari awal", episodes: @[]))
  himeApp.start()
  sleep(3_000)
