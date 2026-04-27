' SourcePickerScreen - Fetch and pick a torrent source
sub init()
    m.header = m.top.findNode("header")
    m.status = m.top.findNode("status")
    m.loading = m.top.findNode("loading")
    m.sourceList = m.top.findNode("sourceList")
    m.sourceList.observeField("itemSelected", "onSourceSelected")
    m.top.observeField("mediaItem", "onMediaItemReady")
end sub

sub onMediaItemReady()
    if m.top.mediaItem = invalid then return
    title = m.top.mediaItem.title
    if title = invalid then title = ""
    m.header.text = "Sources — " + title
    m.status.text = "Searching Torrentio..."
    fetchSources()
end sub

sub fetchSources()
    m.loading.control = "start"
    imdb = m.top.mediaItem.imdbId
    if imdb = invalid then imdb = ""
    print "SourcePicker: fetchSources imdbId="; imdb
    m.status.text = "Creating TorrentioTask for " + imdb + "..."

    m.torrentioTask = CreateObject("roSGNode", "TorrentioTask")
    if m.torrentioTask = invalid
        m.status.text = "ERROR: TorrentioTask node could not be created"
        m.loading.control = "stop"
        return
    end if
    m.torrentioTask.imdbId = imdb
    m.torrentioTask.mediaType = m.top.mediaItem.mediaType
    if m.top.season <> invalid then m.torrentioTask.season = m.top.season
    if m.top.episode <> invalid then m.torrentioTask.episode = m.top.episode
    m.torrentioTask.observeField("sources", "onSourcesLoaded")
    m.torrentioTask.observeField("state", "onTaskState")
    m.torrentioTask.control = "RUN"
    m.status.text = "Task started (state=" + m.torrentioTask.state + "), waiting on Torrentio for " + imdb + "..."
end sub

sub onTaskState()
    state = m.torrentioTask.state
    print "SourcePicker: TorrentioTask state="; state
    if state = "stop"
        ' Task finished — read sources directly in case the observer missed it
        srcs = m.torrentioTask.sources
        if srcs = invalid
            m.status.text = "Task finished but sources is invalid"
            m.loading.control = "stop"
        else if srcs.count() = 0
            m.status.text = "Task finished — no sources returned"
            m.loading.control = "stop"
        end if
    end if
end sub

sub onSourcesLoaded(event)
    m.loading.control = "stop"
    task = event.getRoSGNode()
    sources = task.sources
    if sources = invalid or sources.count() = 0
        m.status.text = "No sources found."
        return
    end if

    m.status.text = sources.count().toStr() + " sources available"
    content = CreateObject("roSGNode", "ContentNode")
    for each src in sources
        node = content.createChild("ContentNode")
        badges = ""
        if src.cached = true then badges = badges + "[CACHED] "
        if src.resolution <> invalid then badges = badges + FormatResolution(src.resolution) + "  "
        if src.sizeBytes <> invalid then badges = badges + FormatBytes(src.sizeBytes) + "  "
        if src.codec <> invalid then badges = badges + src.codec + "  "
        if src.hdrType <> invalid then badges = badges + src.hdrType + "  "
        name = src.displayName
        if name = invalid then name = "Source"
        node.title = badges + " " + name
    end for
    m.sourceList.content = content
    m.sourceList.setFocus(true)

    ' Stash the source array so onSourceSelected can look up by index
    m.sourceArray = sources

    if m.top.autoplay = true and sources.count() > 0
        playSource(sources[0])
    end if
end sub

sub onSourceSelected()
    idx = m.sourceList.itemSelected
    if idx < 0 then return
    if m.sourceArray = invalid or idx >= m.sourceArray.count() then return
    src = m.sourceArray[idx]
    if src = invalid then return
    playSource(src)
end sub

sub playSource(src as Object)
    m.loading.control = "start"
    m.status.text = "Adding to Real-Debrid..."

    m.rdTask = CreateObject("roSGNode", "RDResolveTask")
    m.rdTask.magnet = src.magnet
    m.rdTask.fileIndex = src.fileIndex
    m.rdTask.observeField("result", "onResolved")
    m.rdTask.observeField("error", "onResolveError")
    m.rdTask.control = "RUN"
end sub

sub onResolved(event)
    task = event.getRoSGNode()
    result = task.result
    if result = invalid or result.url = invalid
        m.loading.control = "stop"
        m.status.text = "Resolve failed."
        return
    end if

    m.status.text = "Preparing stream..."
    m.proxyTask = CreateObject("roSGNode", "StreamTask")
    m.proxyTask.mediaUrl = result.url
    m.proxyTask.title = m.top.mediaItem.title
    m.proxyTask.observeField("manifestUrl", "onManifestReady")
    m.proxyTask.observeField("error", "onProxyError")
    m.proxyTask.control = "RUN"
end sub

sub onResolveError(event)
    m.loading.control = "stop"
    m.status.text = "Real-Debrid error: " + event.getData()
end sub

sub onManifestReady(event)
    m.loading.control = "stop"
    manifestUrl = event.getData()
    args = {
        manifestUrl: manifestUrl,
        title: m.top.mediaItem.title,
        mediaId: m.top.mediaItem.id,
        mediaType: m.top.mediaItem.mediaType,
        season: m.top.season,
        episode: m.top.episode
    }
    m.top.getScene().screenArgs = args
    m.top.getScene().pushScreen = "PlayerScreen"
end sub

sub onProxyError(event)
    m.loading.control = "stop"
    m.status.text = "Proxy error: " + event.getData()
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    return false
end function
