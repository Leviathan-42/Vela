' StreamTask - Sends a media URL to the Vela proxy and gets back an HLS manifest
sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    proxyUrl = m.top.proxyUrl
    if proxyUrl = "" then proxyUrl = "http://192.168.7.114:8000"

    url = proxyUrl + "/stream"

    body = FormatJson({
        url: m.top.mediaUrl,
        title: m.top.title
    })

    request = CreateObject("roUrlTransfer")
    request.setUrl(url)
    request.setCertificatesFile("common:/certs/ca-bundle.crt")
    request.initClientCertificates()
    request.addHeader("Content-Type", "application/json")

    responseText = request.postFromString(body)
    if responseText = ""
        m.top.error = "Proxy unreachable or returned empty"
        return
    end if

    response = ParseJson(responseText)
    if response = invalid
        m.top.error = "Invalid JSON from proxy"
        return
    end if

    if response.manifest_url <> invalid
        m.top.manifestUrl = proxyUrl + response.manifest_url
        m.top.strategy = response.strategy
    else if response.detail <> invalid
        m.top.error = response.detail
    else
        m.top.error = "Unknown proxy error"
    end if
end sub
