' HomeScreen - Trending, Popular, Continue Watching rows
sub init()
    m.menuList = m.top.findNode("menuList")
    m.contentGrid = m.top.findNode("contentGrid")
    m.loading = m.top.findNode("loading")

    ' Menu items
    menuContent = CreateObject("roSGNode", "ContentNode")
    items = ["Trending Movies", "Trending Shows", "Popular Movies", "Popular Shows", "Continue Watching", "Watchlist"]
    for each item in items
        node = menuContent.createChild("ContentNode")
        node.title = item
    end for
    m.menuList.content = menuContent

    ' Focus handling
    m.menuList.observeField("itemFocused", "onMenuFocused")
    m.contentGrid.observeField("itemSelected", "onItemSelected")

    m.menuList.setFocus(true)

    ' Fetch trending movies on load
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
    end if
end sub

sub onItemSelected()
    ' Navigate to detail screen
    selected = m.contentGrid.content.getChild(m.contentGrid.itemSelected)
    if selected <> invalid
        ' TODO: Open detail screen
        print "Selected: " + selected.title
    end if
end sub

sub fetchTrendingMovies()
    m.loading.visible = true
    task = CreateObject("roSGNode", "TMDbTask")
    task.endpoint = "/trending/movie/day"
    task.observeField("response", "onContentLoaded")
    task.control = "RUN"
end sub

sub fetchTrendingShows()
    m.loading.visible = true
    task = CreateObject("roSGNode", "TMDbTask")
    task.endpoint = "/trending/tv/day"
    task.observeField("response", "onContentLoaded")
    task.control = "RUN"
end sub

sub fetchPopularMovies()
    m.loading.visible = true
    task = CreateObject("roSGNode", "TMDbTask")
    task.endpoint = "/movie/popular"
    task.observeField("response", "onContentLoaded")
    task.control = "RUN"
end sub

sub fetchPopularShows()
    m.loading.visible = true
    task = CreateObject("roSGNode", "TMDbTask")
    task.endpoint = "/tv/popular"
    task.observeField("response", "onContentLoaded")
    task.control = "RUN"
end sub

sub onContentLoaded(event)
    m.loading.visible = false
    task = event.getRoSGNode()
    response = task.response

    if response <> invalid and response.results <> invalid
        gridContent = CreateObject("roSGNode", "ContentNode")
        for each item in response.results
            node = gridContent.createChild("ContentNode")
            node.title = item.title
            if item.title = invalid then node.title = item.name
            node.hdPosterUrl = "https://image.tmdb.org/t/p/w500" + item.poster_path
            node.description = item.overview
            node.releaseDate = item.release_date
            node.id = item.id.toStr()
        end for
        m.contentGrid.content = gridContent
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if press and key = "back"
        return false
    end if
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
