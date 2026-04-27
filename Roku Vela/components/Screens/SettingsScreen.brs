' SettingsScreen - RD auth, proxy URL, status
sub init()
    m.menu = m.top.findNode("menu")
    m.statusLabel = m.top.findNode("statusLabel")

    m.menu.observeField("itemSelected", "onMenuSelected")
    m.menu.observeField("itemFocused", "onMenuFocused")
    refreshMenu()
end sub

sub refreshMenu()
    content = CreateObject("roSGNode", "ContentNode")
    token = GetRDAccessToken()
    if token = ""
        node = content.createChild("ContentNode")
        node.title = "Connect Real-Debrid"
    else
        node = content.createChild("ContentNode")
        node.title = "Disconnect Real-Debrid"
    end if
    node = content.createChild("ContentNode")
    node.title = "Check Proxy Server"
    m.menu.content = content
    m.menu.setFocus(true)
end sub

sub onMenuFocused()
    idx = m.menu.itemFocused
    if idx = 0
        token = GetRDAccessToken()
        if token = ""
            m.statusLabel.text = "Connect your Real-Debrid account to resolve sources."
        else
            m.statusLabel.text = "Account connected. Select to disconnect."
        end if
    else if idx = 1
        m.statusLabel.text = "Verify the transcoding proxy is reachable at 192.168.7.114:8000"
    end if
end sub

sub onMenuSelected()
    idx = m.menu.itemSelected
    if idx = 0
        token = GetRDAccessToken()
        if token = ""
            startRDAuth()
        else
            ClearRDToken()
            refreshMenu()
            m.statusLabel.text = "Disconnected."
        end if
    else if idx = 1
        checkProxy()
    end if
end sub

sub startRDAuth()
    m.statusLabel.text = "Requesting device code..."
    task = CreateObject("roSGNode", "RDAuthTask")
    task.observeField("deviceCode", "onDeviceCode")
    task.observeField("tokens", "onTokensReceived")
    task.observeField("error", "onAuthError")
    task.control = "RUN"
end sub

sub onDeviceCode(event)
    code = event.getData()
    m.statusLabel.text = "Go to real-debrid.com/device and enter: " + code
end sub

sub onTokensReceived(event)
    tokens = event.getData()
    if tokens = invalid or tokens.access_token = invalid then return
    refresh = tokens.refresh_token
    if refresh = invalid then refresh = ""
    expires = tokens.expires_in
    if expires = invalid then expires = 2592000
    SaveRDToken(tokens.access_token, refresh, expires)
    refreshMenu()
    m.statusLabel.text = "Real-Debrid connected."
end sub

sub onAuthError(event)
    m.statusLabel.text = "Auth error: " + event.getData()
end sub

sub checkProxy()
    m.statusLabel.text = "Checking proxy at 192.168.7.114:8000..."
    request = CreateObject("roUrlTransfer")
    request.setUrl("http://192.168.7.114:8000/health")
    request.setCertificatesFile("common:/certs/ca-bundle.crt")
    request.initClientCertificates()
    response = request.getToString()
    if response <> invalid and response <> ""
        m.statusLabel.text = "Proxy reachable. Response: " + response
    else
        m.statusLabel.text = "Proxy unreachable at 192.168.7.114:8000"
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    return false
end function
