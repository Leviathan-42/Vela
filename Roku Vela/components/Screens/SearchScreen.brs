' SearchScreen - Search movies and shows
sub init()
    m.keyboard = m.top.findNode("keyboard")
    m.resultsGrid = m.top.findNode("resultsGrid")
    m.loading = m.top.findNode("loading")

    m.keyboard.textEditBox.observeField("text", "onSearchTextChanged")
    m.resultsGrid.observeField("itemSelected", "onItemSelected")
    m.keyboard.setFocus(true)
end sub

sub onSearchTextChanged()
    text = m.keyboard.textEditBox.text
    if text.len() < 3 then return

    m.loading.control = "start"
    if m.searchTask <> invalid then m.searchTask.control = "STOP"

    m.searchTask = CreateObject("roSGNode", "TMDbTask")
    m.searchTask.endpoint = "/search/multi?query=" + text
    m.searchTask.observeField("response", "onResultsLoaded")
    m.searchTask.control = "RUN"
end sub

sub onResultsLoaded(event)
    m.loading.control = "stop"
    task = event.getRoSGNode()
    response = task.response
    if response = invalid or response.results = invalid then return

    gridContent = CreateObject("roSGNode", "ContentNode")
    for each item in response.results
        if item.media_type <> "movie" and item.media_type <> "tv" then continue for
        node = gridContent.createChild("ContentNode")
        node.title = item.title
        if item.title = invalid then node.title = item.name
        node.id = item.id.toStr()
        node.tmdbId = item.id.toStr()
        if item.poster_path <> invalid
            node.hdPosterUrl = "https://image.tmdb.org/t/p/w500" + item.poster_path
        end if
        node.description = item.overview
        node.releaseDate = item.release_date
        if item.first_air_date <> invalid then node.releaseDate = item.first_air_date
        node.mediaType = item.media_type
        node.rating = item.vote_average.toStr()
    end for
    m.resultsGrid.content = gridContent
end sub

sub onItemSelected()
    idx = m.resultsGrid.itemSelected
    if idx < 0 then return
    item = m.resultsGrid.content.getChild(idx)
    if item = invalid then return

    mediaItem = {
        id: item.id,
        tmdbId: item.tmdbId,
        title: item.title,
        overview: item.description,
        posterUrl: item.hdPosterUrl,
        releaseDate: item.releaseDate,
        mediaType: item.mediaType,
        rating: item.rating
    }
    m.top.getScene().screenArgs = {mediaItem: mediaItem}
    m.top.getScene().pushScreen = "DetailScreen"
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if press and key = "down" and m.keyboard.hasFocus()
        if m.resultsGrid.content <> invalid and m.resultsGrid.content.getChildCount() > 0
            m.resultsGrid.setFocus(true)
            return true
        end if
    end if
    if press and key = "up" and m.resultsGrid.hasFocus()
        m.keyboard.setFocus(true)
        return true
    end if
    return false
end function
