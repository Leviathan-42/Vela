' LibraryScreen - Watchlist grid
sub init()
    m.grid = m.top.findNode("grid")
    m.emptyLabel = m.top.findNode("emptyLabel")
    m.grid.observeField("itemSelected", "onItemSelected")
    loadWatchlist()
end sub

sub loadWatchlist()
    ids = GetWatchlist()
    if ids = invalid or ids.count() = 0
        m.emptyLabel.visible = true
        m.grid.visible = false
        return
    end if
    m.emptyLabel.visible = false
    m.grid.visible = true

    ' Set the grid content first so onItemLoaded can append into it
    m.grid.content = CreateObject("roSGNode", "ContentNode")
    for each id in ids
        task = CreateObject("roSGNode", "TMDbTask")
        task.endpoint = "/movie/" + id
        task.observeField("response", "onItemLoaded")
        task.control = "RUN"
    end for
end sub

sub onItemLoaded(event)
    task = event.getRoSGNode()
    item = task.response
    if item = invalid then return
    if m.grid.content = invalid then return

    title = item.title
    if title = invalid then title = item.name
    if title = invalid then return ' skip — not a usable result

    node = m.grid.content.createChild("ContentNode")
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
