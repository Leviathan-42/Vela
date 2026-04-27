' TorrentioTask - Fetches torrent sources via the Vela proxy (which calls Torrentio for us).
' Direct Roku → torrentio.strem.fun fails on this firmware (likely Cloudflare/TLS).
sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    print "TorrentioTask: execute() entered"

    if m.top.imdbId = invalid or m.top.imdbId = ""
        print "TorrentioTask: no imdbId, returning empty"
        m.top.sources = []
        return
    end if

    proxyBase = "http://192.168.7.114:8000"
    url = proxyBase + "/sources?imdbId=" + m.top.imdbId + "&mediaType=" + m.top.mediaType
    if m.top.mediaType = "tv"
        url = url + "&season=" + m.top.season.toStr() + "&episode=" + m.top.episode.toStr()
    end if
    print "TorrentioTask: GET "; url

    request = CreateObject("roUrlTransfer")
    request.setUrl(url)

    print "TorrentioTask: getToString starting..."
    json = request.getToString()
    print "TorrentioTask: got "; Len(json); " bytes"

    if json = invalid or json = ""
        m.top.sources = []
        return
    end if

    response = ParseJson(json)
    if response = invalid or response.streams = invalid
        print "TorrentioTask: invalid/empty response, returning empty"
        m.top.sources = []
        return
    end if

    print "TorrentioTask: parsing "; response.streams.count(); " streams"
    parsed = []

    for each s in response.streams
        if s.infoHash = invalid then continue for

        src = {}
        fi = 0
        if s.fileIdx <> invalid then fi = s.fileIdx
        src.id = s.infoHash + ":" + fi.toStr()
        src.infoHash = s.infoHash
        if s.fileIdx <> invalid then src.fileIndex = s.fileIdx else src.fileIndex = 0

        name = s.title
        if name = invalid then name = s.name
        if name = invalid then name = "Unknown source"
        lines = name.split(chr(10))
        src.displayName = lines[0]

        haystack = ""
        if s.name <> invalid then haystack = haystack + " " + s.name
        if s.title <> invalid then haystack = haystack + " " + s.title
        haystack = haystack.lcase()

        if haystack.instr("2160p") >= 0 or haystack.instr("4k") >= 0 or haystack.instr("uhd") >= 0
            src.resolution = "uhd2160p"
        else if haystack.instr("1080p") >= 0 or haystack.instr("fhd") >= 0
            src.resolution = "hd1080p"
        else if haystack.instr("720p") >= 0
            src.resolution = "hd720p"
        else if haystack.instr("480p") >= 0
            src.resolution = "sd480p"
        else
            src.resolution = "unknown"
        end if

        src.sizeBytes = invalid
        if s.title <> invalid
            regex = CreateObject("roRegex", "(\d+(?:\.\d+)?)\s*(gb|mb)", "i")
            match = regex.match(s.title)
            if match <> invalid and match.count() >= 3
                val = match[1].toFloat()
                unit = match[2].lcase()
                if unit = "gb"
                    src.sizeBytes = int(val * 1073741824)
                else if unit = "mb"
                    src.sizeBytes = int(val * 1048576)
                end if
            end if
        end if

        src.hdrType = invalid
        if haystack.instr("dolby vision") >= 0 or haystack.instr(" dv ") >= 0 or haystack.instr(".dv.") >= 0
            src.hdrType = "DV"
        else if haystack.instr("hdr10+") >= 0
            src.hdrType = "HDR10+"
        else if haystack.instr("hdr") >= 0
            src.hdrType = "HDR"
        end if

        src.codec = invalid
        if haystack.instr("x265") >= 0 or haystack.instr("hevc") >= 0 or haystack.instr("h.265") >= 0
            src.codec = "HEVC"
        else if haystack.instr("x264") >= 0 or haystack.instr("h.264") >= 0 or haystack.instr("avc") >= 0
            src.codec = "H.264"
        else if haystack.instr("av1") >= 0
            src.codec = "AV1"
        end if

        src.cached = false
        if haystack.instr("rd+") >= 0 then src.cached = true

        trackers = [
            "udp://tracker.opentrackr.org:1337/announce",
            "udp://tracker.openbittorrent.com:6969/announce",
            "udp://tracker.torrent.eu.org:451/announce",
            "udp://open.stealth.si:80/announce",
            "udp://tracker.coppersurfer.tk:6969/announce"
        ]
        dn = src.displayName
        dn = dn.replace(" ", "%20")
        dn = dn.replace("&", "%26")
        magnet = "magnet:?xt=urn:btih:" + s.infoHash + "&dn=" + dn
        for each tr in trackers
            magnet = magnet + "&tr=" + tr
        end for
        src.magnet = magnet

        score = 0.0
        if src.cached then score = score + 10000.0
        if src.resolution = "uhd2160p" then score = score + 400.0
        if src.resolution = "hd1080p" then score = score + 300.0
        if src.resolution = "hd720p" then score = score + 200.0
        if src.resolution = "sd480p" then score = score + 100.0
        if src.sizeBytes <> invalid
            score = score + src.sizeBytes / 1073741824.0
        end if
        src.rankScore = score

        parsed.push(src)
    end for

    n = parsed.count()
    if n > 1
        for i = 0 to n - 2
            for j = 0 to n - 2 - i
                if parsed[j].rankScore < parsed[j + 1].rankScore
                    tmp = parsed[j]
                    parsed[j] = parsed[j + 1]
                    parsed[j + 1] = tmp
                end if
            end for
        end for
    end if

    print "TorrentioTask: returning "; parsed.count(); " sources"
    m.top.sources = parsed
end sub
