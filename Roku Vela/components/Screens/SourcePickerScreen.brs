' SourcePickerScreen - Fetch and pick a torrent source
sub init()
    m.header = m.top.findNode("header")
    m.loading = m.top.findNode("loading")
    m.sourceList = m.top.findNode("sourceList")
    m.sourceList.observeField("itemSelected", "onSourceSelected")
    m.top.observeField("mediaItem", "onMediaItemReady")
end sub

sub onMediaItemReady()
    if m.top.mediaItem = invalid then return
    m.header.text = "Sources: " + m.top.mediaItem.title
    fetchSources()
end sub

sub fetchSources()
    m.loading.visible = true
    task = CreateObject("roSGNode", "TorrentioTask")
    task.imdbId = m.top.mediaItem.imdbId
    task.mediaType = m.top.mediaItem.mediaType
    task.season = m.top.season
    task.episode = m.top.episode
    task.observeField("sources", "onSourcesLoaded")
    task.control = "RUN"
end sub

sub onSourcesLoaded(event)
    m.loading.visible = false
    task = event.getRoSGNode()
    sources = task.sources
    if sources = invalid or sources.count() = 0
        m.header.text = "No sources found"
        return
    end if

    content = CreateObject("roSGNode", "ContentNode")
    for each src in sources
        node = content.createChild("ContentNode")
        badges = ""
        if src.cached then badges = badges + "[CACHED] "
        badges = badges + FormatResolution(src.resolution) + " "
        if src.sizeBytes <> invalid
            badges = badges + FormatBytes(src.sizeBytes) + " "
        end if
        if src.codec <> invalid
            badges = badges + src.codec + " "
        end if
        if src.hdrType <> invalid
            badges = badges + src.hdrType + " "
        end if
        node.title = src.displayName
        node.description = badges.trim()
        node.sourceData = src
    end for
    m.sourceList.content = content
    m.sourceList.setFocus(true)

    if m.top.autoplay = true and sources.count() > 0
        playSource(sources[0])
    end if
end sub

sub onSourceSelected()
    idx = m.sourceList.itemSelected
    if idx < 0 then return
    item = m.sourceList.content.getChild(idx)
    src = item.sourceData
    if src = invalid then return
    playSource(src)
end sub

sub playSource(src as Object)
    m.loading.visible = true
    m.header.text = "Resolving..."

    task = CreateObject("roSGNode", "RDResolveTask")
    task.magnet = src.magnet
    task.fileIndex = src.fileIndex
    task.observeField("result", "onResolved")
    task.observeField("error", "onResolveError")
    task.control = "RUN"
end sub

sub onResolved(event)
    m.loading.visible = false
    task = event.getRoSGNode()
    result = task.result
    if result = invalid or result.url = invalid
        m.header.text = "Resolve failed"
        return
    end if

    ' Now send to proxy for transcoding
    proxyTask = CreateObject("roSGNode", "StreamTask")
    proxyTask.mediaUrl = result.url
    proxyTask.title = m.top.mediaItem.title
    proxyTask.observeField("manifestUrl", "onManifestReady")
    proxyTask.observeField("error", "onProxyError")
    proxyTask.control = "RUN"
end sub

sub onResolveError(event)
    m.loading.visible = false
    m.header.text = "Real-Debrid error: " + event.getData()
end sub

sub onManifestReady(event)
    m.loading.visible = false
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
    m.loading.visible = false
    m.header.text = "Proxy error: " + event.getData()
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    return false
end function
