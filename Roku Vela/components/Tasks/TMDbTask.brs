' TMDbTask - Async HTTP calls to TMDb API
sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    endpoint = m.top.endpoint
    if endpoint = invalid or endpoint = "" then return

    apiKey = m.global.tmdb_api_key
    if apiKey = invalid or apiKey = ""
        apiKey = "1330fb5d167bfc239614afd096e1fff2"
    end if

    url = "https://api.themoviedb.org/3" + endpoint
    if endpoint.instr("?") >= 0
        url = url + "&api_key=" + apiKey
    else
        url = url + "?api_key=" + apiKey
    end if

    request = CreateObject("roUrlTransfer")
    request.setUrl(url)
    request.setCertificatesFile("common:/certs/ca-bundle.crt")
    request.initClientCertificates()
    request.retainBodyOnError(true)

    json = request.getToString()
    if json = invalid or json = "" then return
    response = ParseJson(json)
    if response = invalid then return

    m.top.response = response
end sub
