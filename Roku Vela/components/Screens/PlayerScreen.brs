' PlayerScreen - Roku native Video node playing HLS from Vela proxy
sub init()
    m.video = m.top.findNode("video")

    m.top.observeField("manifestUrl", "onManifestReady")
    m.video.observeField("position", "onPositionChanged")
    m.video.observeField("state", "onStateChanged")
end sub

sub onManifestReady()
    if m.top.manifestUrl = "" then return

    content = CreateObject("roSGNode", "ContentNode")
    content.url = m.top.manifestUrl
    content.title = m.top.title
    content.streamFormat = "hls"

    m.video.content = content

    if m.top.resumePosition > 0
        m.video.seek = m.top.resumePosition
    end if

    m.video.control = "play"
    m.video.setFocus(true)
end sub

sub onPositionChanged()
    ' TODO: send progress back to proxy or registry for resume
    ' print "Position: " + m.video.position.toStr()
end sub

sub onStateChanged()
    state = m.video.state
    if state = "error"
        print "Video error: " + m.video.errorMsg
        ' TODO: Show error UI
    else if state = "finished"
        ' TODO: Mark as watched
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if press and key = "back"
        m.video.control = "stop"
        return false
    end if
    return false
end function
