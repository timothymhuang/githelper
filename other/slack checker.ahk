#SingleInstance, Force

#if winactive("ahk_exe slack.exe")

enter::
MsgBox, 4, GitHelper, Are you sure you are you want to send this message?, 4106
WinActivate, ahk_exe slack.exe
IfMsgBox, Yes
{
    Send, {ctrl down}
    Send, {enter}
    Send, {ctrl up}
}
Return

#if