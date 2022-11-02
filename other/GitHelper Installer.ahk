#SingleInstance, Force
#NoEnv
SendMode Input
SetWorkingDir %A_ScriptDir% 

newversion := getlatestversion()
IniRead, currentversion, %A_AppData%\GitHelper\config.ini, settings, version
if (newversion = currentversion){
    MsgBox, You already have the latest update.
    ExitApp
}

Process, Close, githelper.exe
Process, Close, githelperupdater.exe

destination := A_AppData . "\GitHelper"

sourceProgram := "https://github.com/timothymhuang/githelper/releases/latest/download/githelper.exe"
sourceUpdater := "https://github.com/timothymhuang/githelper/releases/latest/download/githelperupdater.exe"

destinationProgram := destination . "\githelper.exe"
destinationUpdater := destination . "\githelperupdater.exe"
destinationIni := destination . "\config.ini"

; GET THE CURRENT REPOSITORY
splitpath := StrSplit(A_ScriptDir, "\")
Loop % splitpath.Length()
{
    checkpath := ""
    checklength := splitpath.Length() - (A_Index-1)
    Loop % checklength
    {
        checkpath .= splitpath[A_Index] "\"
    }
    localrepo := SubStr(checkpath, 1, -1)
    checkpath .= ".git\HEAD"
    if(FileExist(checkpath)){
        reponame := splitpath[checklength]
        Break
    } else if (splitpath.Length() = A_Index) {
        MsgBox, 4096, GitHub Desktop Helper, Couldn't locate your local repository. Please ask Timothy Huang for help.
        Exit
    }

}

; WRITE THE FILES
FileCreateDir, %destination%
if (ErrorLevel) {
    Msgbox, Couldn't create DIR %A_LastError%
    Exit
}

try {
    UrlDownloadToFile, %sourceProgram%, %destinationProgram%
    UrlDownloadToFile, %sourceUpdater%, %destinationUpdater%
} catch e {
    MsgBox, Could not download files. Check your internet connection.
    ExitApp
}
IniWrite, %localrepo%, %destinationIni%, settings, localrepo
IniWrite, %reponame%, %destinationIni%, settings, reponame
IniWrite, %newversion%, %destinationIni%, settings, version

; CHECK IF THE FILES HAVE BEEN WRITTEN
if (FileExist(destinationProgram) && FileExist(destinationUpdater) && FileExist(destinationIni)) {
    FileCreateShortcut, %destinationProgram%, %A_Startup%\GitHelper.lnk, %destination%
    if (FileExist(A_Startup . "\GitHelper.lnk")) {
        Msgbox, Installation complete
        Run, %destinationProgram%
    } else {
        Msgbox, Auto start on login failed to work.
    }
} else {
    MsgBox, 1 or more files failed to write. Please try again.
}


Exit


getlatestversion(){
    try {
        whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", "https://github.com/timothymhuang/githelper/releases/latest", true)
        whr.SetRequestHeader("Pragma", "no-cache")
        whr.SetRequestHeader("Cache-Control", "no-cache")
        whr.Send()
        whr.WaitForResponse()
        api := geturl " | " whr.ResponseText
        start := InStr(api, "Release v") + 9
        end := InStr(api, " ",,start)
        length := end - start
        output := Substr(api, start, length)
    } catch e {
        MsgBox, Could not find latest version. Check your internet connection.
        ExitApp
    }
    Return %output%
}

getini(payload,input){
    config := StrSplit(payload, "`n")
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