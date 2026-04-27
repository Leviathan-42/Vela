' PlayerScreen - Native Video node with proxy HLS
sub init()
    m.video = m.top.findNode("video")
    m.video.observeField("position", "onPositionChanged")
    m.video.observeField("state", "onStateChanged")
    m.positionTimer = invalid
    m.top.observeField("manifestUrl", "onManifestUrlReady")
end sub

sub onManifestUrlReady()
    if m.top.manifestUrl = "" then return

    content = CreateObject("roSGNode", "ContentNode")
    content.url = m.top.manifestUrl
    content.title = m.top.title
    content.streamFormat = "hls"

    m.video.content = content

    ' Resume if we have progress
    progress = GetProgress(buildMediaKey())
    if progress <> invalid and progress.position > 120 and progress.duration > 0
        pct = progress.position / progress.duration
        if pct < 0.95
            m.video.seek = progress.position
        end if
    end if

    m.video.control = "play"
    m.video.setFocus(true)

    ' Save progress every 10 seconds
    m.positionTimer = CreateObject("roSGNode", "Timer")
    m.positionTimer.duration = 10
    m.positionTimer.repeat = true
    m.positionTimer.observeField("fire", "saveProgress")
    m.positionTimer.control = "start"
end sub

sub onPositionChanged()
    ' Handled by timer
end sub

sub onStateChanged()
    state = m.video.state
    if state = "error"
        print "Video error: " + m.video.errorMsg
    else if state = "finished"
        ' Mark watched
        SaveProgress(buildMediaKey(), 0, 0)
        m.top.getScene().popScreen = true
    end if
end sub

sub saveProgress()
    if m.video.position > 0 and m.video.duration > 0
        SaveProgress(buildMediaKey(), m.video.position, m.video.duration)
    end if
end sub

function buildMediaKey() as String
    key = m.top.mediaId
    if m.top.mediaType = "tv"
        key = key + "_s" + m.top.season.toStr() + "e" + m.top.episode.toStr()
    end if
    return key
end function

function onKeyEvent(key as String, press as Boolean) as Boolean
    if press and key = "back"
        saveProgress()
        if m.positionTimer <> invalid
            m.positionTimer.control = "stop"
        end if
        m.video.control = "stop"
        return false
    end if
    return false
end function
