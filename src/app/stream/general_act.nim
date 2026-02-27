import ../tui
from tui/utils import waitFor

import extractor/all
import player/all
import marshal

import sequtils

type
  StreamSession* = tuple[
    ex: BaseExtractor,
    anime: AnimeData,
    episodes: seq[EpisodeData],
    episodeIndex: int
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
    player = getPlayer("mpv")
    media = route.session.ex.get to[ExFormatData](route.data)

  player.watch(media)

proc selectAndPlay(route: StreamRoute) =
  let
    ses = route.session
    ex = ses.ex
    eps = ses.episodes[ses.episodeIndex]
    mediaFormat = (ex.formats ex.get eps).ask()

  route.data = $$mediaFormat
  route.realWatch()

proc askEpisodeIdx(route: StreamRoute) =
  let s = route.session
  s.episodeIndex = s.episodes.find s.episodes.ask()
  route.setTitle()

proc nextEpisode(route: StreamRoute) =
  route.session.episodeIndex += 1
  route.setTitle()
  
proc prevEpisode(route: StreamRoute) =
  route.session.episodeIndex -= 1
  route.setTitle()

proc peekLog(route: StreamRoute) =
  route.logger.renderLogs()
  route.logger.tb.display()
  waitFor(Key.Enter)

proc routeAnime(route: StreamRoute) =
  let
    ses = route.session
    anime = to[AnimeData](route.data)
    actions = [
      action("Select Format & Play", selectAndPlay),
      action("Next Episode", nextEpisode),
      action("Prev Episode", prevEpisode),
      action("Select Episode", askEpisodeIdx),
      action("Peek Log", peekLog)
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

  route.ask(animes, routeAnime, title)

export
  selectAndPlay, nextEpisode, prevEpisode, selectAnime
