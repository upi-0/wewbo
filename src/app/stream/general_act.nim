import ../tui
from tui/utils import waitFor

import
  extractor/all, player/all, media/format
import
  marshal, options

type
  StreamSession* = tuple[
    ex: BaseExtractor,
    anime: AnimeData,
    player: Player,
    episodes: seq[EpisodeData],
    episodeIndex: int,
    selectedFormat: Option[FormatIdentity] = none(FormatIdentity),
    autoSelectFormat = false
  ]  

  StreamRoute = Route[StreamSession]  

proc realWatch(route: StreamRoute) =
  let
    ex = route.session.ex
    player = route.session.player
    mediaFormat = to[ExFormatData](route.data)
    media = ex.get mediaFormat
    subtitles = ex.subtitles(mediaFormat)

  if route.session.selectedFormat.isNone:
    route.session.selectedFormat = block:
      mediaFormat.title.detectFormat.some

  if subtitles.isSome:
    let sub = subtitles.get.ask()
    player.watch(media, some sub)

  else:
    player.watch(media)
    
  route.defaultActionIdx = 1

proc selectAndPlay(route: StreamRoute) =
  let
    ses = route.session
    ex = ses.ex
    eps = ses.episodes[ses.episodeIndex]
    listFormat = ex.formats ex.get eps

  if listFormat.len < 1:
    route.error("No format available")    
    return

  var mediaFormat: ExFormatData
  
  if ses.autoSelectFormat:
    mediaFormat = findMatch(listFormat, ses.selectedFormat)
  else:
    mediaFormat = listFormat.ask("Select Format")

  ses.selectedFormat = some detectFormat mediaFormat.title
  ses.autoSelectFormat = false

  route.data = $$mediaFormat
  route.realWatch()

proc askEpisodeIdx(route: StreamRoute) =
  let s = route.session
  s.episodeIndex = s.episodes.find s.episodes.ask("Select Episode")
  route.defaultActionIdx = 0

proc nextEpisode(route: StreamRoute) =
  route.session.episodeIndex += 1
  route.session.autoSelectFormat = route.session.selectedFormat.isSome()
  route.defaultActionIdx = 1

  if route.session.autoSelectFormat:
    route.selectAndPlay()
  
proc prevEpisode(route: StreamRoute) =
  route.session.episodeIndex -= 1
  route.session.selectedFormat = none(FormatIdentity)
  route.defaultActionIdx = 2

proc peekLog(route: StreamRoute) =
  route.logger.writeBottomText("[?] Enter to back.")
  route.logger.renderLogs()
  route.logger.tb.display()

  waitFor(Key.Enter)

proc exportLogRoute(route: StreamRoute) =
  route.logger.exportLog()

proc entryLoop(route: StreamRoute): void =
  let
    s = route.session
    nextAct = route.getAction nextEpisode
    prevAct = route.getAction prevEpisode
    selectAct = route.getAction askEpisodeIdx

  if s.episodeIndex < 0:
    s.episodeIndex = 0

  if route.session.selectedFormat.isSome:
    nextAct.title = "Watch Next Episode"

  else:
    nextAct.title = "Next Episode"    

  block:
    prevAct.hidden = s.episodeIndex == 0        
    nextAct.hidden = s.episodeIndex == s.episodes.len - 1
    selectAct.hidden = s.episodes.len == 1
    route.title = s.episodes[s.episodeIndex].title

proc routeAnime(route: StreamRoute) =
  let
    ses = route.session
    anime = to[AnimeData](route.data)
    actions = [
      action("Select Format & Play", selectAndPlay),
      action("Next Episode", nextEpisode),
      action("Prev Episode", prevEpisode),
      action("Select Episode", askEpisodeIdx),
      action("Peek Log", peekLog),
      action("Export Log", exportLogRoute)
    ]
    appAnime = app(anime.title, actions)
  
  block prepare:
    route.logger.text(anime.title, color(fgBlack, bgYellow))
    ses.anime = anime
    ses.episodes = ses.ex.episodes (ses.ex.get anime)
    ses.episodeIndex = ses.episodes.find ses.episodes.ask("Select Episode")
    appAnime.setSession(ses)
    
  block exec:    
    appAnime.start(entryLoop)

  block afterExec:
    route.session.anime.reset()
    route.session.episodes.reset()

proc selectAnime*(route: StreamRoute) =
  let
    title = route.data
    animes = route.session.ex.animes(title)  

  if animes.len < 1:
    route.error("Anime Not Found.")
    return

  route.ask(animes, routeAnime, title)

export
  selectAndPlay, nextEpisode, prevEpisode, selectAnime
