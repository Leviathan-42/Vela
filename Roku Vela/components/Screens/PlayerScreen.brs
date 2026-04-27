' PlayerScreen - Native Video node with proxy HLS
sub init()
    m.video = m.top.findNode("video")
    m.video.observeField("position", "onPositionChanged")
    m.video.observeField("state", "onStateChanged")
    m.positionTimer = invalid
    m.top.observeField("manifestUrl", "onManifestUrlReady")
end sub

sub onManifestUrlReady()
    if m.top.manifestUrl = "" or m.top.manifestUrl = invalid then return

    content = CreateObject("roSGNode", "ContentNode")
    content.url = m.top.manifestUrl
    content.title = m.top.title
    content.streamFormat = "hls"

    m.video.content = content

    progress = GetProgress(buildMediaKey())
    if progress <> invalid and progress.position <> invalid and progress.duration <> invalid
        if progress.position > 120 and progress.duration > 0
            pct = progress.position / progress.duration
            if pct < 0.95
                m.video.seek = progress.position
            end if
        end if
    end if

    m.video.control = "play"
    m.video.setFocus(true)

    m.positionTimer = CreateObject("roSGNode", "Timer")
    m.positionTimer.duration = 10
    m.positionTimer.repeat = true
    m.positionTimer.observeField("fire", "onProgressTick")
    m.positionTimer.control = "start"
end sub

sub onPositionChanged()
    ' handled by timer
end sub

sub onStateChanged()
    state = m.video.state
    if state = "error"
        print "Video error: "; m.video.errorMsg
        if m.positionTimer <> invalid then m.positionTimer.control = "stop"
    else if state = "finished"
        SaveProgress(buildMediaKey(), 0, 0)
        if m.positionTimer <> invalid then m.positionTimer.control = "stop"
        m.top.getScene().popScreen = true
    end if
end sub

sub onProgressTick()
    if m.video.position > 0 and m.video.duration > 0
        SaveProgress(buildMediaKey(), m.video.position, m.video.duration)
    end if
end sub

function buildMediaKey() as String
    key = m.top.mediaId
    if key = invalid then key = ""
    if m.top.mediaType = "tv"
        key = key + "_s" + m.top.season.toStr() + "e" + m.top.episode.toStr()
    end if
    return key
end function

function onKeyEvent(key as String, press as Boolean) as Boolean
    if press and key = "back"
        onProgressTick()
        if m.positionTimer <> invalid
            m.positionTimer.control = "stop"
        end if
        m.video.control = "stop"
        return false
    end if
    return false
end function
