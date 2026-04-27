' PosterCard - grid item: poster + title
sub init()
    m.poster = m.top.findNode("poster")
    m.title = m.top.findNode("title")
    m.placeholder = m.top.findNode("placeholder")
end sub

sub onContentChange()
    content = m.top.itemContent
    if content = invalid then return
    if content.hdPosterUrl <> invalid and content.hdPosterUrl <> ""
        m.poster.uri = content.hdPosterUrl
    else
        m.poster.uri = ""
    end if
    if content.title <> invalid
        m.title.text = content.title
    else
        m.title.text = ""
    end if
end sub
