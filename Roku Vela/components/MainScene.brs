' MainScene - Root scene, handles navigation and global state
sub init()
    m.top.backgroundColor = "0x0a0a0aff"
    m.top.backgroundUri = ""

    m.overhang = m.top.findNode("overhang")
    m.panelSet = m.top.findNode("panelSet")

    ' Global state
    m.global.addFields({
        tmdb_api_key: "",
        rd_access_token: "",
        rd_refresh_token: "",
        rd_expires_at: 0,
        settings: {},
        watchlist: []
    })

    ' Show home screen
    showHomeScreen()
end sub

sub showHomeScreen()
    homeScreen = CreateObject("roSGNode", "HomeScreen")
    m.panelSet.replaceChild(homeScreen, 0)
    homeScreen.setFocus(true)
end sub
