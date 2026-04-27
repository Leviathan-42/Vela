' RDAuthTask - Real-Debrid device-code OAuth flow
sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    clientId = "X245A4XAIBGVM"  ' Replace with your RD app client_id if you have one

    ' Step 1: Get device code
    req = CreateObject("roUrlTransfer")
    req.setUrl("https://api.real-debrid.com/oauth/v2/device/code?client_id=" + clientId + "&new_credentials=yes")
    req.setCertificatesFile("common:/certs/ca-bundle.crt")
    req.initClientCertificates()

    json = req.getToString()
    resp = ParseJson(json)
    if resp = invalid or resp.device_code = invalid
        m.top.error = "Failed to get device code"
        return
    end if

    deviceCode = resp.device_code
    interval = resp.interval
    if interval = invalid then interval = 5
    m.top.deviceCode = resp.user_code

    ' Step 2: Poll for credentials
    maxAttempts = 60
    for i = 1 to maxAttempts
        sleep(interval * 1000)

        pollReq = CreateObject("roUrlTransfer")
        pollUrl = "https://api.real-debrid.com/oauth/v2/device/credentials?client_id=" + clientId + "&code=" + deviceCode
        pollReq.setUrl(pollUrl)
        pollReq.setCertificatesFile("common:/certs/ca-bundle.crt")
        pollReq.initClientCertificates()

        pollJson = pollReq.getToString()
        pollResp = ParseJson(pollJson)

        if pollResp <> invalid and pollResp.access_token <> invalid
            m.top.tokens = {
                access_token: pollResp.access_token,
                refresh_token: "",  ' device flow may not return refresh token
                expires_in: 2592000  ' ~30 days default
            }
            return
        else if pollResp <> invalid and pollResp.error <> invalid
            if pollResp.error = "authorization_pending"
                ' Keep polling
            else
                m.top.error = pollResp.error
                return
            end if
        end if
    end for

    m.top.error = "Authorization timed out"
end sub
