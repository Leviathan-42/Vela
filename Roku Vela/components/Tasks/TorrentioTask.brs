' TorrentioTask - Fetch and parse sources from Torrentio
sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    base = "https://torrentio.strem.fun"
    if m.top.mediaType = "tv"
        url = base + "/stream/series/" + m.top.imdbId + ":" + m.top.season.toStr() + ":" + m.top.episode.toStr() + ".json"
    else
        url = base + "/stream/movie/" + m.top.imdbId + ".json"
    end if

    request = CreateObject("roUrlTransfer")
    request.setUrl(url)
    request.setCertificatesFile("common:/certs/ca-bundle.crt")
    request.initClientCertificates()

    json = request.getToString()
    response = ParseJson(json)
    if response = invalid or response.streams = invalid
        m.top.sources = []
        return
    end if

    parsed = []
    for each s in response.streams
        if s.infoHash = invalid then continue for

        src = {}
        src.id = s.infoHash + ":" + (s.fileIdx ?? 0).toStr()
        src.infoHash = s.infoHash
        src.fileIndex = s.fileIdx ?? 0

        ' Build display name from title or name
        name = s.title
        if name = invalid then name = s.name
        if name = invalid then name = "Unknown source"
        lines = name.split(chr(10))
        src.displayName = lines[0]

        haystack = ""
        if s.name <> invalid then haystack = haystack + " " + s.name
        if s.title <> invalid then haystack = haystack + " " + s.title
        haystack = haystack.lcase()

        ' Resolution
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

        ' Size
        src.sizeBytes = invalid
        regex = CreateObject("roRegex", "(\d+(?:\.\d+)?)\s*(gb|mb)", "i")
        match = regex.match(s.title)
        if match.count() >= 3
            val = match[1].toFloat()
            unit = match[2].lcase()
            if unit = "gb"
                src.sizeBytes = int(val * 1073741824)
            else if unit = "mb"
                src.sizeBytes = int(val * 1048576)
            end if
        end if

        ' HDR
        src.hdrType = invalid
        if haystack.instr("dolby vision") >= 0 or haystack.instr(" dv ") >= 0 or haystack.instr(".dv.") >= 0
            src.hdrType = "DV"
        else if haystack.instr("hdr10+") >= 0
            src.hdrType = "HDR10+"
        else if haystack.instr("hdr") >= 0
            src.hdrType = "HDR"
        end if

        ' Codec
        src.codec = invalid
        if haystack.instr("x265") >= 0 or haystack.instr("hevc") >= 0 or haystack.instr("h.265") >= 0
            src.codec = "HEVC"
        else if haystack.instr("x264") >= 0 or haystack.instr("h.264") >= 0 or haystack.instr("avc") >= 0
            src.codec = "H.264"
        else if haystack.instr("av1") >= 0
            src.codec = "AV1"
        end if

        ' Cached
        src.cached = false
        if haystack.instr("rd+") >= 0 then src.cached = true

        ' Build magnet
        trackers = [
            "udp://tracker.opentrackr.org:1337/announce",
            "udp://tracker.openbittorrent.com:6969/announce",
            "udp://tracker.torrent.eu.org:451/announce",
            "udp://open.stealth.si:80/announce",
            "udp://tracker.coppersurfer.tk:6969/announce"
        ]
        dn = src.displayName
        ' URL encode basic characters for dn
        dn = dn.replace(" ", "%20")
        dn = dn.replace("&", "%26")
        magnet = "magnet:?xt=urn:btih:" + s.infoHash + "&dn=" + dn
        for each tr in trackers
            magnet = magnet + "&tr=" + tr
        end for
        src.magnet = magnet

        ' Rank score
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

    ' Sort by rankScore descending (bubble sort since BrightScript is limited)
    n = parsed.count()
    for i = 0 to n - 2
        for j = 0 to n - 2 - i
            if parsed[j].rankScore < parsed[j + 1].rankScore
                tmp = parsed[j]
                parsed[j] = parsed[j + 1]
                parsed[j + 1] = tmp
            end if
        end for
    end for

    m.top.sources = parsed
end sub
