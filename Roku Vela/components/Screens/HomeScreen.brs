' HomeScreen - Trending / Popular / Continue Watching
sub init()
    m.menuList = m.top.findNode("menuList")
    m.contentGrid = m.top.findNode("contentGrid")
    m.loading = m.top.findNode("loading")

    menuContent = CreateObject("roSGNode", "ContentNode")
    items = ["Trending Movies", "Trending Shows", "Popular Movies", "Popular Shows", "Continue Watching", "Watchlist"]
    for each item in items
        node = menuContent.createChild("ContentNode")
        node.title = item
    end for
    m.menuList.content = menuContent

    m.menuList.observeField("itemFocused", "onMenuFocused")
    m.contentGrid.observeField("itemSelected", "onItemSelected")

    m.menuList.setFocus(true)
    fetchTrendingMovies()
end sub

sub onMenuFocused()
    idx = m.menuList.itemFocused
    if idx = 0
        fetchTrendingMovies()
    else if idx = 1
        fetchTrendingShows()
    else if idx = 2
        fetchPopularMovies()
    else if idx = 3
        fetchPopularShows()
    else if idx = 4
        loadContinueWatching()
    else if idx = 5
        loadWatchlist()
    end if
end sub

sub onItemSelected()
    idx = m.contentGrid.itemSelected
    if idx < 0 then return
    item = m.contentGrid.content.getChild(idx)
    if item = invalid then return

    mediaItem = {
        id: item.id,
        tmdbId: item.tmdbId,
        imdbId: item.imdbId,
        title: item.title,
        overview: item.description,
        posterUrl: item.hdPosterUrl,
        backdropUrl: item.backdropUrl,
        releaseDate: item.releaseDate,
        mediaType: item.mediaType,
        rating: item.rating,
        runtime: item.runtime
    }

    m.top.getScene().screenArgs = {mediaItem: mediaItem}
    m.top.getScene().pushScreen = "DetailScreen"
end sub

sub fetchTrendingMovies()
    m.loading.control = "start"
    task = CreateObject("roSGNode", "TMDbTask")
    task.endpoint = "/trending/movie/day"
    task.observeField("response", "onContentLoaded")
    task.control = "RUN"
end sub

sub fetchTrendingShows()
    m.loading.control = "start"
    task = CreateObject("roSGNode", "TMDbTask")
    task.endpoint = "/trending/tv/day"
    task.observeField("response", "onContentLoaded")
    task.control = "RUN"
end sub

sub fetchPopularMovies()
    m.loading.control = "start"
    task = CreateObject("roSGNode", "TMDbTask")
    task.endpoint = "/movie/popular"
    task.observeField("response", "onContentLoaded")
    task.control = "RUN"
end sub

sub fetchPopularShows()
    m.loading.control = "start"
    task = CreateObject("roSGNode", "TMDbTask")
    task.endpoint = "/tv/popular"
    task.observeField("response", "onContentLoaded")
    task.control = "RUN"
end sub

sub loadContinueWatching()
    m.loading.control = "start"
    ' Build from registry progress entries
    gridContent = CreateObject("roSGNode", "ContentNode")
    ' TODO: iterate registry keys starting with progress_
    m.contentGrid.content = gridContent
    m.loading.control = "stop"
end sub

sub loadWatchlist()
    m.loading.control = "start"
    watchlistIds = GetWatchlist()
    if watchlistIds.count() = 0
        m.loading.control = "stop"
        m.contentGrid.content = CreateObject("roSGNode", "ContentNode")
        return
    end if
    ' Fetch details for each watchlisted item
    gridContent = CreateObject("roSGNode", "ContentNode")
    for each id in watchlistIds
        task = CreateObject("roSGNode", "TMDbTask")
        task.endpoint = "/movie/" + id
        task.observeField("response", "onWatchlistItemLoaded")
        task.control = "RUN"
    end for
    m.contentGrid.content = gridContent
    m.loading.control = "stop"
end sub

sub onContentLoaded(event)
    m.loading.control = "stop"
    task = event.getRoSGNode()
    response = task.response
    if response = invalid or response.results = invalid then return

    gridContent = CreateObject("roSGNode", "ContentNode")
    for each item in response.results
        node = gridContent.createChild("ContentNode")
        node.title = item.title
        if item.title = invalid then node.title = item.name
        node.id = item.id.toStr()
        node.tmdbId = item.id.toStr()
        node.hdPosterUrl = "https://image.tmdb.org/t/p/w500" + item.poster_path
        node.description = item.overview
        node.releaseDate = item.release_date
        if item.first_air_date <> invalid then node.releaseDate = item.first_air_date
        node.mediaType = item.media_type
        if item.media_type = invalid
            if item.title <> invalid
                node.mediaType = "movie"
            else
                node.mediaType = "tv"
            end if
        end if
        node.rating = item.vote_average.toStr()
        node.runtime = item.runtime
        if item.backdrop_path <> invalid
            node.backdropUrl = "https://image.tmdb.org/t/p/original" + item.backdrop_path
        end if
    end for
    m.contentGrid.content = gridContent
end sub

sub onWatchlistItemLoaded(event)
    task = event.getRoSGNode()
    item = task.response
    if item = invalid then return
    grid = m.contentGrid
    node = grid.content.createChild("ContentNode")
    node.title = item.title
    if item.title = invalid then node.title = item.name
    node.id = item.id.toStr()
    node.tmdbId = item.id.toStr()
    node.hdPosterUrl = "https://image.tmdb.org/t/p/w500" + item.poster_path
    node.description = item.overview
    node.releaseDate = item.release_date
    if item.first_air_date <> invalid then node.releaseDate = item.first_air_date
    node.mediaType = "movie"
    if item.title = invalid then node.mediaType = "tv"
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if press and key = "left" and m.contentGrid.hasFocus()
        m.menuList.setFocus(true)
        return true
    end if
    if press and key = "right" and m.menuList.hasFocus()
        m.contentGrid.setFocus(true)
        return true
    end if
    return false
end function
