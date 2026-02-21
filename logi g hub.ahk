#NoEnv
#SingleInstance Force
#UseHook On
SendMode Input
SetWorkingDir %A_ScriptDir%

; ===============================
; CONFIG
; ===============================
CooldownMS := 380
CooldownTick := 10
ShiftCheckTick := 5

ReloadDelay := 50
Slot2ClickHold := 75

; Duck timing
DUCK_PREWAIT_MS := 25
DUCK_SPACE_HOLD_MS := 25
DUCK_C_GAP1_MS := 150
DUCK_SHIFT_REHOLD_MS := 68   ;
DUCK_C_TAP_MS := 5          ;

; ===============================
; STATE
; ===============================
shiftEnabled := false
isRunning := false
lbuttonDown := false
duckRunning := false
suppressC := false

resetCount := 0
resetWindow := 950

; ===============================
; GUI POSITION
; ===============================
SysGet, MonitorWorkArea, MonitorWorkArea
GuiWidth := 200
GuiHeight := 80
GuiX := MonitorWorkAreaLeft
GuiY := MonitorWorkAreaBottom - GuiHeight

; ===============================
; GUI
; ===============================
Gui, +AlwaysOnTop -Caption +ToolWindow
Gui, Color, 0D0D0D
Gui, Margin, 0, 0

; Title text (top, smaller, gray)
Gui, Font, s8 c888888 Normal, Segoe UI
Gui, Add, Text, x0 y8 w%GuiWidth% Center BackgroundTrans, Logitech G HUB

; Status indicator (red for OFF, green for ON - using Progress)
Gui, Add, Progress, x12 y30 w10 h10 Background1A1A1A cFF4444 vstatusIndicatorOff, 100
Gui, Add, Progress, x12 y30 w10 h10 Background1A1A1A c00FF44 vstatusIndicatorOn Hidden, 100

; Status text (main, bold, white)
Gui, Font, s11 Bold cFFFFFF, Segoe UI
Gui, Add, Text, x28 y26 w%GuiWidth% BackgroundTrans vstatusText, STATUS: OFF

; Accent line at bottom (cyan/blue using Progress)
Gui, Add, Progress, x0 y%GuiHeight% w%GuiWidth% h2 BackgroundTrans c00D4FF, 100

Gui, Show, x%GuiX% y%GuiY% w%GuiWidth% h%GuiHeight% NoActivate

; ===============================
; SOUND NOTIFICATIONS
; ===============================
PlayToggleSound(isOn) {
    if (isOn) {
        ; Higher pitch for ON
        SoundBeep, 800, 100
        Sleep, 50
        SoundBeep, 1000, 80
    } else {
        ; Lower pitch for OFF
        SoundBeep, 600, 100
        Sleep, 50
        SoundBeep, 400, 80
    }
}

; ===============================
; MASTER TOGGLE
; ===============================
*LAlt::
lbuttonDown := false
StopMacro()
SendInput, {LCtrl Up}{RCtrl Up}

shiftEnabled := !shiftEnabled
if (shiftEnabled)
{
    SendInput, {LShift Down}
    GuiControl,, statusText, STATUS: ON
    GuiControl, Hide, statusIndicatorOff
    GuiControl, Show, statusIndicatorOn
    PlayToggleSound(true)
    SetTimer, EnforceShift, %ShiftCheckTick%
}
else
{
    SendInput, {LShift Up}
    GuiControl,, statusText, STATUS: OFF
    GuiControl, Show, statusIndicatorOff
    GuiControl, Hide, statusIndicatorOn
    PlayToggleSound(false)
    SetTimer, EnforceShift, Off
}
return

; ===============================
; EMERGENCY RESET (XBUTTON2 x5)
; ===============================
*XButton2::
resetCount++
if (resetCount = 1)
    SetTimer, ResetCounter, -%resetWindow%
if (resetCount >= 5)
{
    resetCount := 0
    lbuttonDown := false
    shiftEnabled := false

    SendInput, {LShift Up}{LCtrl Up}{RCtrl Up}
    StopMacro()
    GuiControl,, statusText, STATUS: OFF
    GuiControl, Show, statusIndicatorOff
    GuiControl, Hide, statusIndicatorOn

    SendInput, {Esc}
    Sleep, 20
    SendInput, r
    Sleep, 20
    SendInput, {Enter}
}
return

ResetCounter:
resetCount := 0
return

; ===============================
; C = CROUCH
; ===============================
$*c::
if (suppressC)
{
    SendInput, {Blind}c
    return
}
if (shiftEnabled)
    SendInput, {LShift Up}
SendInput, {Blind}c
if (shiftEnabled)
    SendInput, {LShift Down}
return

; ===============================
; SAFE EXIT
; ===============================
F10::
if (!shiftEnabled)
    ExitApp
return

; ===============================
; LMB CONTROL
; ===============================
*~$LButton::
if (!shiftEnabled || isRunning)
    return
lbuttonDown := true
StartMacro()
return

*~$LButton Up::
lbuttonDown := false
StopMacro()
return

; ===============================
; RELOAD
; ===============================
*r::
if (!shiftEnabled)
{
    SendInput, r
    return
}

StopMacro()
lbuttonDown := false

SendInput, r
Sleep, %ReloadDelay%
SendInput, 1
Sleep, %ReloadDelay%
SendInput, r
Sleep, %ReloadDelay%

SendInput, r
Sleep, %ReloadDelay%
SendInput, 2
Sleep, %ReloadDelay%
SendInput, r
Sleep, %ReloadDelay%

SendInput, 2
return

; ===============================
; SHIFT ENFORCER
; ===============================
EnforceShift:
if (shiftEnabled && !duckRunning && !GetKeyState("LShift", "P"))
    SendInput, {LShift Down}
return

; ===============================
; MACRO CONTROL
; ===============================
StartMacro() {
    global isRunning
    isRunning := true
    SetTimer, RunSequence, -1
}

StopMacro() {
    global isRunning
    isRunning := false
}

; ===============================
; MAIN SEQUENCE (2 → 1)
; ===============================
RunSequence:
while (isRunning)
{
    if (!lbuttonDown)
        break

    SendInput, {Blind}2
    Sleep, 60

    Click, {Blind Down}
    Sleep, %Slot2ClickHold%
    Click, {Blind Up}

    if (!isRunning || !lbuttonDown)
        break

    SendInput, {Blind}1
    Sleep, 25

    Click, {Blind Down}

    elapsed := 0
    while (elapsed < CooldownMS)
    {
        if (!isRunning || !lbuttonDown)
            break 2
        Sleep, CooldownTick
        elapsed += CooldownTick
    }

    Click, {Blind Up}
    Sleep, 40
}
StopMacro()
return

; ===============================
; DUCK / AVOID
; ===============================
*XButton1::
if (!shiftEnabled || duckRunning)
    return

Critical, On
duckRunning := true
suppressC := true

; stop shift-enforcer during duck so it can't re-hold shift mid-combo
SetTimer, EnforceShift, Off

resumeAfterDuck := lbuttonDown
StopMacro()
lbuttonDown := false

; make sure shift is really up during the duck taps
SendInput, {LShift Up}{RShift Up}
Sleep, %DUCK_PREWAIT_MS%

; --- SPACE TAP ---
SendInput, {Space Down}
Sleep, %DUCK_SPACE_HOLD_MS%
SendInput, {Space Up}

; --- FIRST C TAP ---
SendInput, {c Down}
Sleep, %DUCK_C_TAP_MS%
SendInput, {c Up}

Sleep, %DUCK_C_GAP1_MS%

; --- SECOND C TAP ---
SendInput, {c Down}
Sleep, %DUCK_C_TAP_MS%
SendInput, {c Up}

Sleep, %DUCK_SHIFT_REHOLD_MS%

; re-hold shift + re-enable enforcer (only if still armed)
if (shiftEnabled)
{
    SendInput, {LShift Down}
    SetTimer, EnforceShift, %ShiftCheckTick%
}

suppressC := false
duckRunning := false
Critical, Off

; resume shooting if you were holding before + still physically holding now
if (resumeAfterDuck && GetKeyState("LButton", "P"))
{
    lbuttonDown := true
    StartMacro()
}
return
