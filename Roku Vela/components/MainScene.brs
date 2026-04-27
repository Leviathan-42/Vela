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

    ' Show home by default and keep focus on the sidebar so the remote always has a target
    showTabScreen("HomeScreen")
    m.tabs.setFocus(true)
end sub

sub focusScreenContent()
    if m.screenStack.count() = 0 then return
    screen = m.screenStack.peek()
    candidates = ["contentGrid", "menuList", "menu", "keyboard", "buttonGroup", "sourceList", "resultsGrid", "grid"]
    for each cid in candidates
        child = screen.findNode(cid)
        if child <> invalid and child.visible <> false
            child.setFocus(true)
            return
        end if
    end for
    screen.setFocus(true)
end sub

sub onTabFocused()
    idx = m.tabs.itemFocused
    screens = ["HomeScreen", "SearchScreen", "LibraryScreen", "SettingsScreen"]
    ' Clear any pushed screens when switching tabs (leave the root tab screen on the stack)
    while m.screenStack.count() > 1
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
    ' Don't steal focus from the sidebar — user enters the screen via right arrow
end sub

sub onPushScreen(event)
    screenName = event.getData()
    if screenName = "" or screenName = invalid then return
    args = m.top.screenArgs
    if args = invalid then args = {}

    screen = CreateObject("roSGNode", screenName)
    if screen = invalid then return
    screen.id = screenName
    for each key in args
        screen[key] = args[key]
    end for

    m.screenContainer.appendChild(screen)
    m.screenStack.push(screen)
    focusScreenContent()
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
        focusScreenContent()
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if press and key = "back"
        if m.screenStack.count() > 1
            popScreen()
            return true
        else if not m.tabs.hasFocus()
            ' Back from inside a tab screen → return focus to sidebar
            m.tabs.setFocus(true)
            return true
        else
            ' On the sidebar — let system handle back (exit app)
            return false
        end if
    end if
    if press and key = "right"
        if m.tabs.hasFocus()
            focusScreenContent()
            return true
        end if
        ' Sidebar is already escaped — if a grid exists in the current screen
        ' and it isn't already focused, jump focus into it. This lets the user
        ' move from a left-side menu list to a right-side grid even when the
        ' inner LabelList swallows the right arrow.
        if m.screenStack.count() > 0
            screen = m.screenStack.peek()
            gridCandidates = ["contentGrid", "resultsGrid", "grid"]
            for each gid in gridCandidates
                g = screen.findNode(gid)
                if g <> invalid and g.visible <> false and not g.hasFocus()
                    g.setFocus(true)
                    return true
                end if
            end for
        end if
    end if
    ' Only let "left" jump back to the sidebar from a root tab screen,
    ' not from a pushed screen (which has its own internal nav).
    if press and key = "left" and not m.tabs.hasFocus() and m.screenStack.count() <= 1
        m.tabs.setFocus(true)
        return true
    end if
    return false
end function
