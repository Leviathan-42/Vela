' Vela Shared Utilities

' ===== Registry Helpers =====
function RegistryRead(key as String, defaultVal as String) as String
    sec = CreateObject("roRegistrySection", "vela")
    if sec.Exists(key)
        return sec.Read(key)
    end if
    return defaultVal
end function

sub RegistryWrite(key as String, value as String)
    sec = CreateObject("roRegistrySection", "vela")
    sec.Write(key, value)
    sec.Flush()
end sub

sub RegistryDelete(key as String)
    sec = CreateObject("roRegistrySection", "vela")
    sec.Delete(key)
    sec.Flush()
end sub

' ===== Progress Helpers =====
function GetProgress(mediaId as String) as Object
    json = RegistryRead("progress_" + mediaId, "")
    if json = "" then return invalid
    return ParseJson(json)
end function

sub SaveProgress(mediaId as String, position as Integer, duration as Integer)
    data = {position: position, duration: duration, updated: CreateObject("roDateTime").AsSeconds().toStr()}
    RegistryWrite("progress_" + mediaId, FormatJson(data))
end sub

' ===== Watchlist Helpers =====
function IsWatchlisted(mediaId as String) as Boolean
    list = GetWatchlist()
    for each id in list
        if id = mediaId then return true
    end for
    return false
end function

function GetWatchlist() as Object
    json = RegistryRead("watchlist", "[]")
    return ParseJson(json)
end function

sub ToggleWatchlist(mediaId as String)
    list = GetWatchlist()
    newList = []
    found = false
    for each id in list
        if id = mediaId
            found = true
        else
            newList.push(id)
        end if
    end for
    if not found then newList.push(mediaId)
    RegistryWrite("watchlist", FormatJson(newList))
end sub

' ===== Real-Debrid Token Helpers =====
function GetRDAccessToken() as String
    return RegistryRead("rd_access_token", "")
end function

function GetRDRefreshToken() as String
    return RegistryRead("rd_refresh_token", "")
end function

function GetRDExpiresAt() as String
    return RegistryRead("rd_expires_at", "0")
end function

sub SaveRDToken(accessToken as String, refreshToken as String, expiresIn as Integer)
    sec = CreateObject("roRegistrySection", "vela")
    sec.Write("rd_access_token", accessToken)
    sec.Write("rd_refresh_token", refreshToken)
    dt = CreateObject("roDateTime")
    sec.Write("rd_expires_at", (dt.AsSeconds() + expiresIn).toStr())
    sec.Flush()
end sub

sub ClearRDToken()
    sec = CreateObject("roRegistrySection", "vela")
    sec.Delete("rd_access_token")
    sec.Delete("rd_refresh_token")
    sec.Delete("rd_expires_at")
    sec.Flush()
end sub

' ===== Formatting Helpers =====
function FormatBytes(bytes as Integer) as String
    if bytes >= 1073741824
        return Str(bytes / 1073741824.0).Trim() + " GB"
    else if bytes >= 1048576
        return Str(bytes / 1048576.0).Trim() + " MB"
    end if
    return bytes.toStr() + " B"
end function

function FormatResolution(res as String) as String
    if res = "uhd2160p" then return "4K"
    if res = "hd1080p" then return "1080p"
    if res = "hd720p" then return "720p"
    if res = "sd480p" then return "480p"
    return res
end function
