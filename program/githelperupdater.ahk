#SingleInstance, Force
SendMode Input
SetWorkingDir, %A_ScriptDir%

Process, Close, githelper.exe
UrlDownloadToFile, https://github.com/timothymhuang/githelper/releases/latest/download/githelper.exe, %A_ScriptDir%\githelper.exe
version := getlatestversion()
IniWrite, %version%, %A_ScriptDir%\config.ini, settings, version
Run, %A_ScriptDir%\githelper.exe
Exit

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
        Return "ERROR"
    }
    Return %output%
}

/*
getapi(){
    whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    whr.Open("GET", "https://raw.githubusercontent.com/timothymhuang/api/main/rocketry/githelper.ini", true)
    whr.Send()
    whr.WaitForResponse()
    api := whr.ResponseText
    Return %api%
}
*/

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