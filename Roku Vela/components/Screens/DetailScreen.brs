' DetailScreen - Movie / Show details with season/episode picker
sub init()
    m.backdrop = m.top.findNode("backdrop")
    m.poster = m.top.findNode("poster")
    m.titleLabel = m.top.findNode("titleLabel")
    m.metaLabel = m.top.findNode("metaLabel")
    m.overviewLabel = m.top.findNode("overviewLabel")
    m.buttonGroup = m.top.findNode("buttonGroup")
    m.seasonList = m.top.findNode("seasonList")
    m.episodeList = m.top.findNode("episodeList")

    m.top.observeField("mediaItem", "onMediaItemChanged")
    m.buttonGroup.observeField("buttonSelected", "onButtonSelected")
    m.seasonList.observeField("itemSelected", "onSeasonSelected")
    m.episodeList.observeField("itemSelected", "onEpisodeSelected")

    m.currentMedia = invalid
    m.currentSeason = 1
    m.currentEpisode = 1
    m.seasonData = []
    m.episodeData = []
end sub

sub onMediaItemChanged()
    item = m.top.mediaItem
    if item = invalid then return
    m.currentMedia = item

    m.titleLabel.text = item.title
    year = ""
    if item.releaseDate <> invalid and item.releaseDate.len() >= 4
        year = item.releaseDate.left(4)
    end if
    rating = ""
    if item.rating <> invalid then rating = " ★ " + item.rating
    m.metaLabel.text = year + rating
    m.overviewLabel.text = item.overview

    if item.backdropUrl <> invalid
        m.backdrop.uri = item.backdropUrl
    else if item.posterUrl <> invalid
        m.backdrop.uri = item.posterUrl
    end if
    if item.posterUrl <> invalid
        m.poster.uri = item.posterUrl
    end if

    ' Update watchlist button text
    updateWatchlistButton()

    ' Fetch external IDs to get IMDB id
    task = CreateObject("roSGNode", "TMDbTask")
    if item.mediaType = "tv"
        task.endpoint = "/tv/" + item.id + "/external_ids"
    else
        task.endpoint = "/movie/" + item.id + "/external_ids"
    end if
    task.observeField("response", "onExternalIdsLoaded")
    task.control = "RUN"

    ' For TV, fetch seasons
    if item.mediaType = "tv"
        m.seasonList.visible = true
        m.episodeList.visible = true
        fetchSeasons(item.id)
    else
        m.seasonList.visible = false
        m.episodeList.visible = false
    end if

    m.buttonGroup.setFocus(true)
end sub

sub updateWatchlistButton()
    btn = m.buttonGroup.getChild(2)
    if m.currentMedia = invalid then return
    if IsWatchlisted(m.currentMedia.id)
        btn.text = "✓ Watchlisted"
    else
        btn.text = "+ Watchlist"
    end if
end sub

sub onExternalIdsLoaded(event)
    task = event.getRoSGNode()
    resp = task.response
    if resp <> invalid and resp.imdb_id <> invalid
        m.currentMedia.imdbId = resp.imdb_id
    end if
end sub

sub fetchSeasons(showId as String)
    task = CreateObject("roSGNode", "TMDbTask")
    task.endpoint = "/tv/" + showId
    task.observeField("response", "onShowDetailsLoaded")
    task.control = "RUN"
end sub

sub onShowDetailsLoaded(event)
    task = event.getRoSGNode()
    resp = task.response
    if resp = invalid or resp.seasons = invalid then return

    m.seasonData = resp.seasons
    seasonContent = CreateObject("roSGNode", "ContentNode")
    for each s in resp.seasons
        if s.season_number = 0 then continue for ' skip specials for now
        node = seasonContent.createChild("ContentNode")
        node.title = "S" + s.season_number.toStr()
        node.seasonNumber = s.season_number
    end for
    m.seasonList.content = seasonContent
    if m.seasonList.content.getChildCount() > 0
        m.seasonList.jumpToItem = 0
        fetchEpisodes(m.currentMedia.id, m.seasonData[0].season_number)
    end if
end sub

sub onSeasonSelected()
    idx = m.seasonList.itemSelected
    if idx < 0 then return
    season = m.seasonList.content.getChild(idx)
    m.currentSeason = season.seasonNumber
    fetchEpisodes(m.currentMedia.id, m.currentSeason)
end sub

sub fetchEpisodes(showId as String, seasonNum as Integer)
    task = CreateObject("roSGNode", "TMDbTask")
    task.endpoint = "/tv/" + showId + "/season/" + seasonNum.toStr()
    task.observeField("response", "onEpisodesLoaded")
    task.control = "RUN"
end sub

sub onEpisodesLoaded(event)
    task = event.getRoSGNode()
    resp = task.response
    if resp = invalid or resp.episodes = invalid then return

    m.episodeData = resp.episodes
    epContent = CreateObject("roSGNode", "ContentNode")
    for each ep in resp.episodes
        node = epContent.createChild("ContentNode")
        node.title = ep.episode_number.toStr() + ". " + ep.name
        node.episodeNumber = ep.episode_number
        node.description = ep.overview
        if ep.still_path <> invalid
            node.hdPosterUrl = "https://image.tmdb.org/t/p/w300" + ep.still_path
        end if
    end for
    m.episodeList.content = epContent
end sub

sub onEpisodeSelected()
    idx = m.episodeList.itemSelected
    if idx < 0 then return
    ep = m.episodeList.content.getChild(idx)
    m.currentEpisode = ep.episodeNumber
    ' Focus back to buttons so user can hit Play
    m.buttonGroup.setFocus(true)
end sub

sub onButtonSelected()
    idx = m.buttonGroup.buttonSelected
    if m.currentMedia = invalid then return

    if idx = 0 ' Play
        if m.currentMedia.mediaType = "tv"
            openSourcePicker(true) ' true = autoplay first source
        else
            openSourcePicker(true)
        end if
    else if idx = 1 ' Sources
        openSourcePicker(false)
    else if idx = 2 ' Watchlist
        ToggleWatchlist(m.currentMedia.id)
        updateWatchlistButton()
    end if
end sub

sub openSourcePicker(autoplay as Boolean)
    if m.currentMedia.imdbId = invalid or m.currentMedia.imdbId = ""
        ' Show error — need IMDB id for Torrentio
        return
    end if

    args = {
        mediaItem: m.currentMedia,
        season: m.currentSeason,
        episode: m.currentEpisode,
        autoplay: autoplay
    }
    m.top.getScene().screenArgs = args
    m.top.getScene().pushScreen = "SourcePickerScreen"
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if press and key = "up"
        if m.episodeList.hasFocus()
            m.seasonList.setFocus(true)
            return true
        else if m.seasonList.hasFocus()
            m.buttonGroup.setFocus(true)
            return true
        end if
    end if
    if press and key = "down"
        if m.buttonGroup.hasFocus() and m.seasonList.visible
            m.seasonList.setFocus(true)
            return true
        else if m.seasonList.hasFocus()
            m.episodeList.setFocus(true)
            return true
        end if
    end if
    return false
end function
