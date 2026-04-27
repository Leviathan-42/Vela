' RDResolveTask - Magnet → direct playable URL via Real-Debrid
sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    token = GetRDAccessToken()
    if token = ""
        m.top.error = "Not authenticated with Real-Debrid"
        return
    end if

    headers = {"Authorization": "Bearer " + token}

    ' Step 1: Add magnet
    addReq = CreateObject("roUrlTransfer")
    addReq.setUrl("https://api.real-debrid.com/rest/1.0/torrents/addMagnet")
    addReq.setCertificatesFile("common:/certs/ca-bundle.crt")
    addReq.initClientCertificates()
    addReq.addHeader("Authorization", "Bearer " + token)
    addReq.addHeader("Content-Type", "application/x-www-form-urlencoded")

    body = "magnet=" + m.top.magnet
    addJson = addReq.postFromString(body)
    addResp = ParseJson(addJson)
    if addResp = invalid or addResp.id = invalid
        m.top.error = "Failed to add magnet"
        return
    end if
    torrentId = addResp.id

    ' Step 2: Poll for files
    info = invalid
    for i = 1 to 30
        sleep(2000)
        infoReq = CreateObject("roUrlTransfer")
        infoReq.setUrl("https://api.real-debrid.com/rest/1.0/torrents/info/" + torrentId)
        infoReq.setCertificatesFile("common:/certs/ca-bundle.crt")
        infoReq.initClientCertificates()
        infoReq.addHeader("Authorization", "Bearer " + token)
        infoJson = infoReq.getToString()
        info = ParseJson(infoJson)
        if info <> invalid and info.files <> invalid and info.files.count() > 0
            exit for
        end if
    end for

    if info = invalid or info.files = invalid or info.files.count() = 0
        m.top.error = "No files found in torrent"
        return
    end if

    ' Step 3: Pick largest non-sample video
    chosenId = invalid
    maxSize = 0
    videoExts = ["mkv", "mp4", "avi", "mov", "m4v", "flv", "webm", "ts", "wmv"]
    for each f in info.files
        path = f.path.lcase()
        if path.instr("/sample") >= 0 or path.instr("sample/") >= 0 or path.instr(".sample.") >= 0
            continue for
        end if
        isVideo = false
        for each ext in videoExts
            if path.right(ext.len()) = ext
                isVideo = true
                exit for
            end if
        end for
        if isVideo and f.bytes > maxSize
            maxSize = f.bytes
            chosenId = f.id.toStr()
        end if
    end for

    if chosenId = invalid
        ' Fallback: use fileIndex if provided
        if m.top.fileIndex >= 0 and m.top.fileIndex < info.files.count()
            chosenId = info.files[m.top.fileIndex].id.toStr()
        else
            m.top.error = "Could not find a video file"
            return
        end if
    end if

    ' Step 4: Select file
    selReq = CreateObject("roUrlTransfer")
    selReq.setUrl("https://api.real-debrid.com/rest/1.0/torrents/selectFiles/" + torrentId)
    selReq.setCertificatesFile("common:/certs/ca-bundle.crt")
    selReq.initClientCertificates()
    selReq.addHeader("Authorization", "Bearer " + token)
    selReq.addHeader("Content-Type", "application/x-www-form-urlencoded")
    selReq.postFromString("files=" + chosenId)

    ' Step 5: Poll until downloaded
    for i = 1 to 60
        sleep(3000)
        pollReq = CreateObject("roUrlTransfer")
        pollReq.setUrl("https://api.real-debrid.com/rest/1.0/torrents/info/" + torrentId)
        pollReq.setCertificatesFile("common:/certs/ca-bundle.crt")
        pollReq.initClientCertificates()
        pollReq.addHeader("Authorization", "Bearer " + token)
        pollJson = pollReq.getToString()
        pollInfo = ParseJson(pollJson)
        if pollInfo <> invalid and pollInfo.status = "downloaded" and pollInfo.links <> invalid and pollInfo.links.count() > 0
            exit for
        else if pollInfo <> invalid and pollInfo.status = "error"
            m.top.error = "Torrent error: " + pollInfo.status
            return
        end if
    end for

    if pollInfo = invalid or pollInfo.links = invalid or pollInfo.links.count() = 0
        m.top.error = "Torrent did not finish downloading"
        return
    end if

    ' Step 6: Unrestrict link
    link = pollInfo.links[0]
    unreq = CreateObject("roUrlTransfer")
    unreq.setUrl("https://api.real-debrid.com/rest/1.0/unrestrict/link")
    unreq.setCertificatesFile("common:/certs/ca-bundle.crt")
    unreq.initClientCertificates()
    unreq.addHeader("Authorization", "Bearer " + token)
    unreq.addHeader("Content-Type", "application/x-www-form-urlencoded")
    unJson = unreq.postFromString("link=" + link)
    unResp = ParseJson(unJson)

    if unResp <> invalid and unResp.download <> invalid
        m.top.result = {url: unResp.download, filename: unResp.filename}
    else
        m.top.error = "Unrestrict failed"
    end if
end sub
