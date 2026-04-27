' TMDbTask - Async HTTP calls to TMDb API
sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    endpoint = m.top.endpoint
    apiKey = m.global.tmdb_api_key

    if apiKey = ""
        ' Fallback / placeholder — in production load from registry
        apiKey = "YOUR_TMDB_API_KEY"
    end if

    url = "https://api.themoviedb.org/3" + endpoint + "?api_key=" + apiKey
    request = CreateObject("roUrlTransfer")
    request.setUrl(url)
    request.setCertificatesFile("common:/certs/ca-bundle.crt")
    request.initClientCertificates()

    json = request.getToString()
    response = ParseJson(json)

    m.top.response = response
end sub
