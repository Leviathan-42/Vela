' LibraryScreen - Watchlist grid
sub init()
    m.grid = m.top.findNode("grid")
    m.emptyLabel = m.top.findNode("emptyLabel")
    m.grid.observeField("itemSelected", "onItemSelected")
    loadWatchlist()
end sub

sub loadWatchlist()
    ids = GetWatchlist()
    if ids.count() = 0
        m.emptyLabel.visible = true
        m.grid.visible = false
        return
    end if
    m.emptyLabel.visible = false
    m.grid.visible = true

    content = CreateObject("roSGNode", "ContentNode")
    for each id in ids
        task = CreateObject("roSGNode", "TMDbTask")
        ' Try movie first, then TV
        task.endpoint = "/movie/" + id
        task.observeField("response", "onItemLoaded")
        task.control = "RUN"
    end for
    m.grid.content = content
end sub

sub onItemLoaded(event)
    task = event.getRoSGNode()
    item = task.response
    if item = invalid
        ' Try TV
        ' TODO: handle TV shows in watchlist
        return
    end if

    grid = m.grid
    node = grid.content.createChild("ContentNode")
    node.title = item.title
    if item.title = invalid then node.title = item.name
    node.id = item.id.toStr()
    node.tmdbId = item.id.toStr()
    if item.poster_path <> invalid
        node.hdPosterUrl = "https://image.tmdb.org/t/p/w500" + item.poster_path
    end if
    node.description = item.overview
    node.mediaType = "movie"
    if item.title = invalid then node.mediaType = "tv"
end sub

sub onItemSelected()
    idx = m.grid.itemSelected
    if idx < 0 then return
    item = m.grid.content.getChild(idx)
    if item = invalid then return

    mediaItem = {
        id: item.id,
        tmdbId: item.tmdbId,
        title: item.title,
        overview: item.description,
        posterUrl: item.hdPosterUrl,
        mediaType: item.mediaType
    }
    m.top.getScene().screenArgs = {mediaItem: mediaItem}
    m.top.getScene().pushScreen = "DetailScreen"
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    return false
end function
