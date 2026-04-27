' MainScene - Root scene with tab bar and screen stack
sub init()
    m.top.backgroundColor = "0x0a0a0aff"
    m.top.backgroundUri = ""

    m.tabBar = m.top.findNode("tabBar")
    m.tabs = m.top.findNode("tabs")
    m.screenContainer = m.top.findNode("screenContainer")
    m.screenStack = []

    ' Tab setup
    tabContent = CreateObject("roSGNode", "ContentNode")
    tabItems = ["Home", "Search", "Library", "Settings"]
    for each item in tabItems
        node = tabContent.createChild("ContentNode")
        node.title = item
    end for
    m.tabs.content = tabContent
    m.tabs.observeField("itemFocused", "onTabFocused")

    m.top.observeField("pushScreen", "onPushScreen")
    m.top.observeField("popScreen", "onPopScreen")

    ' Show home by default
    showTabScreen("HomeScreen")
    m.tabs.setFocus(true)
end sub

sub onTabFocused()
    idx = m.tabs.itemFocused
    screens = ["HomeScreen", "SearchScreen", "LibraryScreen", "SettingsScreen"]
    ' Clear any pushed screens when switching tabs
    while m.screenStack.count() > 0
        popScreen()
    end while
    showTabScreen(screens[idx])
end sub

sub showTabScreen(screenName as String)
    ' Remove existing tab screen
    for each child in m.screenContainer.getChildren(-1, 0)
        m.screenContainer.removeChild(child)
    end for
    m.screenStack.clear()

    screen = CreateObject("roSGNode", screenName)
    screen.id = screenName
    m.screenContainer.appendChild(screen)
    m.screenStack.push(screen)
    screen.setFocus(true)
end sub

sub onPushScreen(event)
    screenName = event.getData()
    args = m.top.screenArgs
    if args = invalid then args = {}

    screen = CreateObject("roSGNode", screenName)
    screen.id = screenName
    for each key in args
        screen[key] = args[key]
    end for

    m.screenContainer.appendChild(screen)
    m.screenStack.push(screen)
    screen.setFocus(true)
end sub

sub onPopScreen(event)
    if event.getData() = true
        popScreen()
    end if
end sub

sub popScreen()
    if m.screenStack.count() > 1
        screen = m.screenStack.pop()
        m.screenContainer.removeChild(screen)
        m.screenStack.peek().setFocus(true)
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if press and key = "back"
        if m.screenStack.count() > 1
            popScreen()
            return true
        else
            ' On root tab screen, let system handle back (exit app)
            return false
        end if
    end if
    return false
end function
