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
    selectedFormat: Option[FormatIdentity] = none(FormatIdentity)
  ]  

  StreamRoute = Route[StreamSession]  

proc setTitle(route: StreamRoute): void =
  let s = route.session
  
  if s.episodeIndex < 0:
    s.episodeIndex = s.episodes.len - 1

  elif s.episodeIndex > s.episodes.len - 1:
    s.episodeIndex = 0

  route.title = (
    s.episodes[s.episodeIndex].title
  )

proc realWatch(route: StreamRoute) =
  let
    ex = route.session.ex
    player = route.session.player
    mediaFormat = to[ExFormatData](route.data)
    media = ex.get mediaFormat
    subtitles = ex.subtitles(mediaFormat)

  if subtitles.isSome:
    let sub = subtitles.get.ask()
    player.watch(media, some sub)    

  if route.session.selectedFormat.isNone:
    route.session.selectedFormat = block:
      mediaFormat.title.detectFormat.some

  player.watch(media)

proc selectAndPlay(route: StreamRoute) =
  let
    ses = route.session
    ex = ses.ex
    eps = ses.episodes[ses.episodeIndex]
    listFormat = ex.formats ex.get eps

  if listFormat.len < 1:
    route.error("No format available")    
    return

  let mediaFormat = ex.ask(listFormat, route.session.selectedFormat)
  route.data = $$mediaFormat
  route.realWatch()

proc askEpisodeIdx(route: StreamRoute) =
  let s = route.session
  s.episodeIndex = s.episodes.find s.episodes.ask("Select Episode")
  route.setTitle()

proc nextEpisode(route: StreamRoute) =
  route.session.episodeIndex += 1
  route.setTitle()
  
proc prevEpisode(route: StreamRoute) =
  route.session.episodeIndex -= 1
  route.setTitle()

proc peekLog(route: StreamRoute) =
  route.logger.writeBottomText("[?] Enter to back.")
  route.logger.renderLogs()
  route.logger.tb.display()
  waitFor(Key.Enter)

proc exportLogRoute(route: StreamRoute) =
  route.logger.exportLog()

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
    appAnime.setSession(ses)
    
  block exec:    
    appAnime.setTitle()
    appAnime.start()

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
