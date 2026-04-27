' HomeScreen - Netflix-style rows of content categories
sub init()
    m.contentGrid = m.top.findNode("contentGrid")
    m.loading = m.top.findNode("loading")

    m.contentGrid.observeField("rowItemSelected", "onItemSelected")

    ' Build the empty row scaffold first so async fetches can fill into it
    m.rowEndpoints = [
        { title: "Trending Movies", endpoint: "/trending/movie/day" },
        { title: "Trending Shows",  endpoint: "/trending/tv/day"   },
        { title: "Popular Movies",  endpoint: "/movie/popular"     },
        { title: "Popular Shows",   endpoint: "/tv/popular"        },
        { title: "Watchlist",       endpoint: "watchlist"          }
    ]

    gridContent = CreateObject("roSGNode", "ContentNode")
    for each row in m.rowEndpoints
        rowNode = gridContent.createChild("ContentNode")
        rowNode.title = row.title
    end for
    m.contentGrid.content = gridContent

    m.loading.control = "start"
    m.pendingRows = 0
    for i = 0 to m.rowEndpoints.count() - 1
        ep = m.rowEndpoints[i]
        if ep.endpoint = "watchlist"
            loadWatchlistRow(i)
        else
            fetchCategory(i, ep.endpoint)
        end if
    end for
end sub

sub fetchCategory(rowIdx as Integer, endpoint as String)
    m.pendingRows = m.pendingRows + 1
    task = CreateObject("roSGNode", "TMDbTask")
    task.endpoint = endpoint
    task.observeField("response", "onCategoryLoaded")
    task.control = "RUN"
end sub

sub onCategoryLoaded(event)
    task = event.getRoSGNode()
    response = task.response
    endpoint = task.endpoint

    rowIdx = -1
    for i = 0 to m.rowEndpoints.count() - 1
        if m.rowEndpoints[i].endpoint = endpoint
            rowIdx = i
            exit for
        end if
    end for

    decrementPending()
    if rowIdx < 0 then return
    if response = invalid or response.results = invalid then return
    if m.contentGrid.content = invalid then return

    row = m.contentGrid.content.getChild(rowIdx)
    if row = invalid then return

    for each item in response.results
        node = row.createChild("ContentNode")
        title = item.title
        if title = invalid then title = item.name
        if title = invalid then title = ""
        node.title = title
        if item.id <> invalid
            node.id = item.id.toStr()
            node.tmdbId = item.id.toStr()
        end if
        if item.poster_path <> invalid
            node.hdPosterUrl = "https://image.tmdb.org/t/p/w500" + item.poster_path
        end if
        if item.overview <> invalid then node.description = item.overview
        if item.release_date <> invalid then node.releaseDate = item.release_date
        if item.first_air_date <> invalid then node.releaseDate = item.first_air_date
        if item.media_type <> invalid
            node.mediaType = item.media_type
        else if item.title <> invalid
            node.mediaType = "movie"
        else
            node.mediaType = "tv"
        end if
        if item.vote_average <> invalid then node.rating = item.vote_average.toStr()
        if item.runtime <> invalid then node.runtime = item.runtime
        if item.backdrop_path <> invalid
            node.backdropUrl = "https://image.tmdb.org/t/p/original" + item.backdrop_path
        end if
    end for
end sub

sub loadWatchlistRow(rowIdx as Integer)
    ids = GetWatchlist()
    if ids = invalid or ids.count() = 0 then return
    m.watchlistRowIdx = rowIdx
    for each id in ids
        m.pendingRows = m.pendingRows + 1
        task = CreateObject("roSGNode", "TMDbTask")
        task.endpoint = "/movie/" + id
        task.observeField("response", "onWatchlistItemLoaded")
        task.control = "RUN"
    end for
end sub

sub onWatchlistItemLoaded(event)
    decrementPending()
    task = event.getRoSGNode()
    item = task.response
    if item = invalid then return
    if m.contentGrid.content = invalid then return
    row = m.contentGrid.content.getChild(m.watchlistRowIdx)
    if row = invalid then return
    title = item.title
    if title = invalid then title = item.name
    if title = invalid then return

    node = row.createChild("ContentNode")
    node.title = title
    if item.id <> invalid
        node.id = item.id.toStr()
        node.tmdbId = item.id.toStr()
    end if
    if item.poster_path <> invalid
        node.hdPosterUrl = "https://image.tmdb.org/t/p/w500" + item.poster_path
    end if
    if item.overview <> invalid then node.description = item.overview
    if item.title <> invalid
        node.mediaType = "movie"
    else
        node.mediaType = "tv"
    end if
end sub

sub decrementPending()
    m.pendingRows = m.pendingRows - 1
    if m.pendingRows <= 0 then m.loading.control = "stop"
end sub

sub onItemSelected()
    sel = m.contentGrid.rowItemSelected
    if sel = invalid or sel.count() < 2 then return
    rowIdx = sel[0]
    colIdx = sel[1]
    if m.contentGrid.content = invalid then return
    row = m.contentGrid.content.getChild(rowIdx)
    if row = invalid then return
    item = row.getChild(colIdx)
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

function onKeyEvent(key as String, press as Boolean) as Boolean
    return false
end function
