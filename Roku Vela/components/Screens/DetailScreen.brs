' DetailScreen - Show metadata, season picker, play/sources buttons
sub init()
    m.backdrop = m.top.findNode("backdrop")
    m.poster = m.top.findNode("poster")
    m.titleLabel = m.top.findNode("titleLabel")
    m.metaLabel = m.top.findNode("metaLabel")
    m.overviewLabel = m.top.findNode("overviewLabel")
    m.buttonGroup = m.top.findNode("buttonGroup")

    m.top.observeField("mediaItem", "onMediaItemChanged")
    m.buttonGroup.observeField("buttonSelected", "onButtonSelected")
end sub

sub onMediaItemChanged()
    item = m.top.mediaItem
    if item = invalid then return

    title = item.title
    if title = invalid then title = item.name
    m.titleLabel.text = title

    year = ""
    if item.releaseDate <> invalid and item.releaseDate.len() >= 4
        year = item.releaseDate.left(4)
    end if
    m.metaLabel.text = year

    m.overviewLabel.text = item.overview

    if item.backdropUrl <> invalid
        m.backdrop.uri = item.backdropUrl
    else if item.hdPosterUrl <> invalid
        m.backdrop.uri = item.hdPosterUrl
    end if

    if item.hdPosterUrl <> invalid
        m.poster.uri = item.hdPosterUrl
    end if

    m.buttonGroup.setFocus(true)
end sub

sub onButtonSelected()
    ' 0 = Play, 1 = Sources, 2 = Watchlist
    idx = m.buttonGroup.buttonSelected
    if idx = 0 or idx = 1
        ' TODO: fetch sources, then go to source picker or player
        print "Play / Sources pressed"
    else if idx = 2
        ' TODO: toggle watchlist in registry
        print "Watchlist pressed"
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    return false
end function
