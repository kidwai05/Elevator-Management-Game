; Elevator Maintenance Game
INCLUDE Irvine32.inc
INCLUDELIB Irvine32.lib

; -------------------------
; CONSTANTS
; -------------------------
NUM_ELEVATORS   EQU 3
MAX_FLOOR       EQU 10
MIN_FLOOR       EQU 1

STATUS_IDLE     EQU 0
STATUS_MOVING   EQU 1
STATUS_BROKEN   EQU 2
STATUS_REPAIR   EQU 3

DIR_UP          EQU 1
DIR_DOWN        EQU -1
DIR_NONE        EQU 0

MAX_REQUESTS    EQU 20
MAX_REPAIR_TIME EQU 3

; Game ending conditions
MAX_TURNS       EQU 20        ; Win if you survive 20 turns
ALL_BROKEN_LIMIT EQU 5        ; Lose if all elevators broken for 5+ turns
WIN_SCORE       EQU 100       ; Alternative win: reach 100 points (10 requests)

; Breakdown probability (used in RandomBreakdowns)
BREAKDOWN_CHANCE EQU 30       ; 1 in 30 chance = ~3.3% per elevator per turn

; -------------------------
; DATA
; -------------------------
.data
elevatorFloor   DWORD NUM_ELEVATORS DUP (MIN_FLOOR)
elevatorDir     DWORD NUM_ELEVATORS DUP (DIR_NONE)
elevatorStatus  DWORD NUM_ELEVATORS DUP (STATUS_IDLE)
elevatorTarget  DWORD NUM_ELEVATORS DUP (0)
repairTimer     DWORD NUM_ELEVATORS DUP (0)

requestsQueue   DWORD MAX_REQUESTS DUP (0)
requestsCount   DWORD 0

turnCount       DWORD 0
score           DWORD 0
requestsServed  DWORD 0

breakdownsOccurred  DWORD 0
repairsCompleted    DWORD 0

allBrokenCounter    DWORD 0   ; Tracks consecutive turns with all elevators broken

; Messages
msgFloor        BYTE "Floor: ",0
msgElevator     BYTE " Elevator ",0
msgIdle         BYTE "[I] Idle",0
msgMoving       BYTE "[M] Moving",0
msgBroken       BYTE "[X] Broken",0
msgRepair       BYTE "[R] Repairing",0
msgDirUp        BYTE " ^",0
msgDirDown      BYTE " v",0
msgDirNone      BYTE " -",0
newline         BYTE 13,10,0
msgWaitKey      BYTE "Press any key to continue...",0
msgRequest      BYTE "Enter requested floor (1-10): ",0
msgInvalid      BYTE "Invalid floor! Try again.",0
msgBreakdown      BYTE "Oh no! Elevator ",0
msgBrokenAt       BYTE " broke down!",0
msgChooseAction   BYTE "Choose action: (1) Call Elevator  (2) Repair Elevator  (3) Skip Turn",13,10,0
msgPromptChoice   BYTE "Enter choice (1-3): ",0
msgNotBroken      BYTE "That elevator is not broken! Try again.",13,10,0
msgRepairStarted  BYTE "Repair started.",13,10,0
msgRepairDone     BYTE "Elevator repaired!",13,10,0

; Random floor request messages
msgRandomFloor    BYTE "A person is waiting at floor: ",0
msgChooseElev     BYTE "Choose an elevator to send (1-3): ",0
msgInvalidElev    BYTE "Invalid elevator! Choose again.",0

; Repair menu messages
msgRepairing      BYTE "Repairing elevator ",0
msgSkipRepair     BYTE "Skipping repair for now.",0
msgMenuRepair     BYTE "Do you want to repair a broken elevator? (1=Yes, 2=No): ",0

; Display messages for headers
msgRoundHeader     BYTE "================= TURN ",0
msgRoundTail       BYTE " =================",0
msgSeparator       BYTE "--------------------------------------------",0

msgStatsTitle BYTE "===== Live Stats =====",0
msgTurns      BYTE "Turns: ",0
msgReqServed  BYTE "Requests Served: ",0
msgBreaks     BYTE "Breakdowns: ",0
msgRepairs    BYTE "Repairs Completed: ",0
msgScore      BYTE "Score: ",0

msgEndSummary      BYTE "=========== GAME SUMMARY ===========",0
msgEndScore        BYTE "Final Score: ",0
msgEndReqServed    BYTE "Requests Served: ",0
msgEndBreaks       BYTE "Breakdowns: ",0
msgEndRepairs      BYTE "Repairs Completed: ",0
msgEndTurns        BYTE "Total Turns: ",0

msgFinalEff BYTE "===== FINAL EFFICIENCY REPORT =====",0
msgEffScore BYTE "Efficiency Score: ",0

; Title Page
borderTop    BYTE "============================================================",0
borderMid    BYTE "------------------------- GAME GUIDE ------------------------",0
borderBottom BYTE "============================================================",0
titleLine1   BYTE "                   ELEVATOR MANAGEMENT GAME                 ",0
instrHeader  BYTE "HOW TO PLAY:",0
instr1       BYTE "1. There are 3 elevators operating between floors 1–10.",0
instr2       BYTE "2. Elevators may break down — repair them on your turn.",0
instr3       BYTE "3. Assign elevators to calls efficiently.",0
instr4       BYTE "4. Avoid leaving passengers waiting too long.",0
instr5       BYTE "5. Survive breakdowns and keep the system running!",0


; Win/Loss messages
msgWinSurvive     BYTE 13,10,"*** CONGRATULATIONS! ***",13,10,"You survived 20 turns and kept the building operational!",13,10,0
msgWinScore       BYTE 13,10,"*** OUTSTANDING! ***",13,10,"You reached the target score of 100 points!",13,10,0
msgLoseAllBroken  BYTE 13,10,"*** GAME OVER ***",13,10,"All elevators have been broken for too long. Building shut down!",13,10,0
msgAllBrokenWarn  BYTE "WARNING: All elevators are broken! Repair one immediately!",13,10,0

; Table display strings
headerLine BYTE "Elev | Floor | Dir | Status",0
colSep     BYTE " | ",0

; -------------------------
; CODE
; -------------------------
.code

; -------------------------
; Clear screen procedure
; -------------------------
ClearScreen PROC
    call Clrscr
    ret
ClearScreen ENDP

; -------------------------
; Center text procedure
; -------------------------
CenterText PROC
    push eax
    push ebx
    push ecx
    push edx

    mov esi, edx
    xor ecx, ecx
CountLen:
    mov al, [esi+ecx]
    cmp al, 0
    je DoneCountLen
    inc ecx
    jmp CountLen
DoneCountLen:

    mov eax, 80
    sub eax, ecx
    shr eax, 1
    mov ebx, eax
PrintSpaces:
    cmp ebx, 0
    je PrintString
    mov dl, ' '
    call WriteChar
    dec ebx
    jmp PrintSpaces

PrintString:
    mov edx, esi
    call WriteString

    pop edx
    pop ecx
    pop ebx
    pop eax
    ret
CenterText ENDP

;-------------------------------
;       MAIN
;-------------------------------
main PROC
    call Randomize        ; Initialize random number generator once
    call InitializeSystem
    call ShowIntroScreen

MainLoop:
    call ClearScreen
    call DisplayRoundHeader
    call DisplayElevatorTable

    ; Check for loss condition: all elevators broken
    call CheckAllBroken
    cmp eax, 1
    je GameLost

    call PlayerMenu        ; ask 1) call 2) repair 3) skip

    call MoveElevators
    call ProcessRequests

    call UpdateRepairs     ; decrement repair timers, mark repaired
    call RandomBreakdowns  ; possibly trigger new breakdowns

    call DisplayStats      ; show live stats

    inc turnCount

    ; Check win conditions
    call CheckWinConditions
    cmp eax, 1
    je GameWon

    call WaitForKey
    jmp MainLoop

GameWon:
    call ClearScreen
    call DisplayEndSummary
    call DisplayFinalEfficiency
    call WaitForKey
    exit

GameLost:
    call ClearScreen
    call DisplayEndSummary
    call DisplayFinalEfficiency
    call WaitForKey
    exit

main ENDP

ShowIntroScreen PROC
    call Clrscr

    ; ============================
    ; TOP BORDER
    ; ============================
    mov edx, OFFSET borderTop
    call WriteString
    call Crlf

    ; ============================
    ; TITLE
    ; ============================
    mov edx, OFFSET titleLine1
    call WriteString
    call Crlf

    mov edx, OFFSET borderMid
    call WriteString
    call Crlf
    call Crlf

    ; ============================
    ; INSTRUCTIONS BLOCK
    ; ============================
    mov edx, OFFSET instrHeader
    call WriteString
    call Crlf

    mov edx, OFFSET instr1
    call WriteString
    call Crlf

    mov edx, OFFSET instr2
    call WriteString
    call Crlf

    mov edx, OFFSET instr3
    call WriteString
    call Crlf

    mov edx, OFFSET instr4
    call WriteString
    call Crlf

    mov edx, OFFSET instr5
    call WriteString
    call Crlf
    call Crlf

    ; ============================
    ; PRESS ANY KEY
    ; ============================
    
    call WaitForKey
    mov edx, OFFSET borderBottom
    call WriteString
    call Crlf

    ret
ShowIntroScreen ENDP

; -------------------------
; Check if all elevators are broken (loss condition)
; Returns: EAX = 1 if game lost, 0 otherwise
; -------------------------
CheckAllBroken PROC
    push ebx
    push ecx
    push esi

    xor esi, esi
    mov ecx, 0              ; count broken/repairing elevators

CountBroken:
    cmp esi, NUM_ELEVATORS
    jge DoneCount

    mov ebx, esi
    shl ebx, 2
    mov eax, [elevatorStatus + ebx]
    
    cmp eax, STATUS_BROKEN
    je IncBroken
    cmp eax, STATUS_REPAIR
    je IncBroken
    jmp NextElevCheck

IncBroken:
    inc ecx

NextElevCheck:
    inc esi
    jmp CountBroken

DoneCount:
    ; If all elevators are broken/repairing
    cmp ecx, NUM_ELEVATORS
    jl NotAllBroken

    ; Increment counter
    mov eax, allBrokenCounter
    inc eax
    mov allBrokenCounter, eax

    ; Display warning
    mov edx, OFFSET msgAllBrokenWarn
    call WriteString

    ; Check if exceeded limit
    cmp eax, ALL_BROKEN_LIMIT
    jge AllBrokenTooLong

    ; Not lost yet
    mov eax, 0
    jmp CheckDone

AllBrokenTooLong:
    mov edx, OFFSET msgLoseAllBroken
    call WriteString
    mov eax, 1
    jmp CheckDone

NotAllBroken:
    ; Reset counter if at least one working
    mov allBrokenCounter, 0
    mov eax, 0

CheckDone:
    pop esi
    pop ecx
    pop ebx
    ret
CheckAllBroken ENDP

; -------------------------
; Check win conditions
; Returns: EAX = 1 if won, 0 otherwise
; -------------------------
CheckWinConditions PROC
    push ebx

    ; Check if reached target score
    mov eax, score
    cmp eax, WIN_SCORE
    jge WonByScore

    ; Check if survived max turns
    mov eax, turnCount
    cmp eax, MAX_TURNS
    jge WonBySurvival

    ; Not won yet
    mov eax, 0
    jmp WinCheckDone

WonByScore:
    mov edx, OFFSET msgWinScore
    call WriteString
    mov eax, 1
    jmp WinCheckDone

WonBySurvival:
    mov edx, OFFSET msgWinSurvive
    call WriteString
    mov eax, 1

WinCheckDone:
    pop ebx
    ret
CheckWinConditions ENDP

; -------------------------
; Initialize elevators
; -------------------------
InitializeSystem PROC
    xor esi, esi
InitLoop:
    cmp esi, NUM_ELEVATORS
    jge DoneInit

    mov edi, esi
    shl edi, 2
    mov [elevatorFloor + edi], MIN_FLOOR
    mov [elevatorDir + edi], DIR_NONE
    mov [elevatorStatus + edi], STATUS_IDLE
    mov [elevatorTarget + edi], 0
    mov [repairTimer + edi], 0
    inc esi
    jmp InitLoop

DoneInit:
    mov turnCount, 0
    mov score, 0
    mov requestsServed, 0
    mov requestsCount, 0
    mov breakdownsOccurred, 0
    mov repairsCompleted, 0
    mov allBrokenCounter, 0
    ret
InitializeSystem ENDP

; -------------------------
; Player menu (Call / Repair / Skip)
; -------------------------
PlayerMenu PROC
MenuStart:
    mov edx, OFFSET msgChooseAction
    call WriteString

    mov edx, OFFSET msgPromptChoice
    call WriteString
    call ReadInt        ; eax = choice

    cmp eax, 1
    je DoCall
    cmp eax, 2
    je DoRepair
    cmp eax, 3
    je DoSkip

    ; invalid
    mov edx, OFFSET msgInvalid
    call WriteString
    call Crlf
    jmp MenuStart

DoCall:
    call GetPlayerRequest
    ret

DoRepair:
    call PlayerRepairMenu
    ret

DoSkip:
    ret
PlayerMenu ENDP

; -------------------------
; Player input for floor request NOW WITH RANDOM FLOOR
; -------------------------
GetPlayerRequest PROC
    ; Generate random floor (1-10)
    call Random32
    mov ebx, 10
    xor edx, edx
    div ebx               ; EDX = remainder (0-9)
    mov eax, edx          ; Use remainder
    inc eax               ; scale to 1-10

    push eax              ; save requested floor on stack

    ; Show random floor to player
    mov edx, OFFSET msgRandomFloor
    call WriteString
    mov eax, [esp]
    call WriteDec
    call Crlf

ChooseElev:
    ; Ask player which elevator to send
    mov edx, OFFSET msgChooseElev
    call WriteString
    call ReadInt
    mov ebx, eax          ; chosen elevator number
    cmp ebx, 1
    jl InvalidElev
    cmp ebx, NUM_ELEVATORS
    jg InvalidElev

    dec ebx
    shl ebx, 2

    ; Check if elevator is available
    mov eax, [elevatorStatus + ebx]
    cmp eax, STATUS_IDLE
    je AssignElev
    cmp eax, STATUS_MOVING
    je AssignElev
    ; Elevator broken or repairing
InvalidElev:
    mov edx, OFFSET msgInvalidElev
    call WriteString
    call Crlf
    jmp ChooseElev

AssignElev:
    pop esi               ; retrieve requested floor
    push esi              ; keep it on stack for safety

    ; Assign target floor
    mov [elevatorTarget + ebx], esi
    
    ; Set direction
    mov eax, [elevatorFloor + ebx]
    cmp eax, esi
    jl SetUp
    cmp eax, esi
    jg SetDown
    mov [elevatorDir + ebx], DIR_NONE
    mov [elevatorStatus + ebx], STATUS_IDLE
    pop esi               ; clean stack
    ret

SetUp:
    mov [elevatorDir + ebx], DIR_UP
    mov [elevatorStatus + ebx], STATUS_MOVING
    pop esi               ; clean stack
    ret

SetDown:
    mov [elevatorDir + ebx], DIR_DOWN
    mov [elevatorStatus + ebx], STATUS_MOVING
    pop esi               ; clean stack
    ret
GetPlayerRequest ENDP

; -------------------------
; Assign nearest elevator
; -------------------------
AssignNearestAvailableElevator PROC
    push ebp
    mov ebp, esp
    mov eax, [ebp+8]         ; requested floor

    mov esi, 0
    mov edi, -1               ; nearestElevator = -1
    mov ecx, MAX_FLOOR+1      ; minDistance

NextElevator:
    cmp esi, NUM_ELEVATORS
    jge DoneAssign

    mov ebx, esi
    shl ebx, 2
    mov edx, [elevatorStatus + ebx]
    ; only consider IDLE or MOVING (broken/repair ignored)
    cmp edx, STATUS_IDLE
    je CheckDistance
    cmp edx, STATUS_MOVING
    jne NextElevIndex

CheckDistance:
    mov edx, esi
    shl edx, 2
    mov ebx, [elevatorFloor + edx]
    mov edx, eax
    sub edx, ebx
    cmp edx, 0
    jge SkipNeg
    neg edx
SkipNeg:
    cmp edx, ecx
    jge NextElevIndex
    mov ecx, edx
    mov edi, esi
NextElevIndex:
    inc esi
    jmp NextElevator

DoneAssign:
    cmp edi, -1
    je DoneAssignProc

    mov edx, edi
    shl edx, 2
    mov [elevatorTarget + edx], eax
    mov ebx, [elevatorFloor + edx]
    cmp ebx, eax
    jl SetDirUp
    cmp ebx, eax
    jg SetDirDown
    jmp DoneAssignProc

SetDirUp:
    mov [elevatorDir + edx], DIR_UP
    mov [elevatorStatus + edx], STATUS_MOVING
    jmp DoneAssignProc

SetDirDown:
    mov [elevatorDir + edx], DIR_DOWN
    mov [elevatorStatus + edx], STATUS_MOVING

DoneAssignProc:
    pop ebp
    ret
AssignNearestAvailableElevator ENDP

; -------------------------
; Move elevators toward target
; -------------------------
MoveElevators PROC
    xor esi, esi
NextElev:
    cmp esi, NUM_ELEVATORS
    jge DoneMove

    mov edi, esi
    shl edi, 2
    mov eax, [elevatorStatus + edi]
    cmp eax, STATUS_IDLE
    je CheckTarget
    cmp eax, STATUS_MOVING
    jne SkipElev
CheckTarget:
    mov eax, [elevatorTarget + edi]
    cmp eax, 0
    je SkipElev
    mov ebx, [elevatorFloor + edi]
    cmp ebx, eax
    je ReachedTarget
    jl MoveUp
MoveDown:
    dec ebx
    mov [elevatorFloor + edi], ebx
    mov [elevatorDir + edi], DIR_DOWN
    jmp NextElevIndex
MoveUp:
    inc ebx
    mov [elevatorFloor + edi], ebx
    mov [elevatorDir + edi], DIR_UP
    jmp NextElevIndex
ReachedTarget:
    mov [elevatorDir + edi], DIR_NONE
    mov [elevatorTarget + edi], 0
    mov [elevatorStatus + edi], STATUS_IDLE
    
    ; Increment requestsServed
    mov eax, requestsServed
    inc eax
    mov requestsServed, eax
    
    ; Add score (10 points per request)
    mov eax, score
    add eax, 10
    mov score, eax
    
    jmp NextElevIndex

NextElevIndex:
    inc esi
    jmp NextElev
SkipElev:
    inc esi
    jmp NextElev
DoneMove:
    ret
MoveElevators ENDP

; -------------------------
; Process served requests
; -------------------------
ProcessRequests PROC
    ret
ProcessRequests ENDP

; -------------------------
; Display: Round header
; -------------------------
DisplayRoundHeader PROC
    mov edx, OFFSET msgRoundHeader
    call WriteString

    mov eax, turnCount
    call WriteDec

    mov edx, OFFSET msgRoundTail
    call WriteString
    call Crlf

    mov edx, OFFSET msgSeparator
    call WriteString
    call Crlf
    ret
DisplayRoundHeader ENDP

; -------------------------
; Display: Elevator table
; -------------------------
DisplayElevatorTable PROC
    call Crlf

    mov edx, OFFSET msgSeparator
    call WriteString
    call Crlf

    mov edx, OFFSET headerLine
    call WriteString
    call Crlf

    mov edx, OFFSET msgSeparator
    call WriteString
    call Crlf

    xor esi, esi
NextElevDisp:
    cmp esi, NUM_ELEVATORS
    jge DoneDisp

    ; Print elevator number
    mov eax, esi
    inc eax
    call WriteDec
    mov edx, OFFSET colSep
    call WriteString

    ; Floor
    mov edi, esi
    shl edi, 2
    mov eax, [elevatorFloor + edi]
    call WriteDec
    mov edx, OFFSET colSep
    call WriteString

    ; Direction symbol
    mov eax, [elevatorDir + edi]
    cmp eax, DIR_UP
    je PrintUp
    cmp eax, DIR_DOWN
    je PrintDown
    jmp PrintNone

PrintUp:
    mov edx, OFFSET msgDirUp
    call WriteString
    jmp AfterDir

PrintDown:
    mov edx, OFFSET msgDirDown
    call WriteString
    jmp AfterDir

PrintNone:
    mov edx, OFFSET msgDirNone
    call WriteString

AfterDir:
    mov edx, OFFSET colSep
    call WriteString

    ; Status
    mov eax, [elevatorStatus + edi]
    cmp eax, STATUS_IDLE
    je SIdle
    cmp eax, STATUS_MOVING
    je SMoving
    cmp eax, STATUS_BROKEN
    je SBroken
    cmp eax, STATUS_REPAIR
    je SRepair

SIdle:
    mov edx, OFFSET msgIdle
    call WriteString
    jmp FinishRow

SMoving:
    mov edx, OFFSET msgMoving
    call WriteString
    jmp FinishRow

SBroken:
    mov edx, OFFSET msgBroken
    call WriteString
    jmp FinishRow

SRepair:
    mov edx, OFFSET msgRepair
    call WriteString

FinishRow:
    call Crlf
    inc esi
    jmp NextElevDisp

DoneDisp:
    mov edx, OFFSET msgSeparator
    call WriteString
    call Crlf
    ret
DisplayElevatorTable ENDP

; -------------------------
; Player Repair Menu
; -------------------------
PlayerRepairMenu PROC
    xor esi, esi
NextBroken:
    cmp esi, NUM_ELEVATORS
    jge DoneRepairMenu
    
    mov edi, esi
    shl edi, 2
    mov eax, [elevatorStatus + edi]
    cmp eax, STATUS_BROKEN
    jne NotBrokenInMenu

    ; Ask player if they want to repair this elevator
    mov edx, OFFSET msgMenuRepair
    call WriteString
    call ReadInt
    cmp eax, 1
    jne SkipRepairAction

    ; Start repair
    mov [elevatorStatus + edi], STATUS_REPAIR
    mov [repairTimer + edi], MAX_REPAIR_TIME
    
    mov edx, OFFSET msgRepairing
    call WriteString
    mov eax, esi
    inc eax
    call WriteDec
    call Crlf
    jmp DoneRepairMenu    ; Only repair one at a time

SkipRepairAction:
    mov edx, OFFSET msgSkipRepair
    call WriteString
    call Crlf

NotBrokenInMenu:
    inc esi
    jmp NextBroken

DoneRepairMenu:
    ret
PlayerRepairMenu ENDP

; -------------------------
; Repair elevator routine
; -------------------------
RepairElevator PROC
AskAgain:
    mov edx, OFFSET msgElevator
    call WriteString
    mov edx, OFFSET msgPromptChoice
    call WriteString
    call ReadInt              ; eax = elevator choice (1..NUM_ELEVATORS)

    mov ebx, eax
    cmp ebx, 1
    jl AskAgain
    cmp ebx, NUM_ELEVATORS
    jg AskAgain

    dec ebx                   ; 0-based index
    mov esi, ebx
    shl esi, 2

    mov eax, [elevatorStatus + esi]
    cmp eax, STATUS_BROKEN
    jne NotBrokenErr

    ; Start repair
    mov [elevatorStatus + esi], STATUS_REPAIR
    mov [repairTimer + esi], MAX_REPAIR_TIME

    mov edx, OFFSET msgRepairStarted
    call WriteString
    call Crlf
    ret

NotBrokenErr:
    mov edx, OFFSET msgNotBroken
    call WriteString
    jmp AskAgain
RepairElevator ENDP

; -------------------------
; Update repair timers
; complete repairs
; -------------------------
UpdateRepairs PROC
    xor esi, esi
NextRepair:
    cmp esi, NUM_ELEVATORS
    jge DoneRepairs

    mov edi, esi
    shl edi, 2

    mov eax, [elevatorStatus + edi]
    cmp eax, STATUS_REPAIR
    jne SkipRepair

    ; Decrement timer
    mov ebx, [repairTimer + edi]
    dec ebx
    mov [repairTimer + edi], ebx

    cmp ebx, 0
    jg SkipRepair

    ; Repair complete: set to idle
    mov [elevatorStatus + edi], STATUS_IDLE
    mov [repairTimer + edi], 0

    ; Count repair
    mov eax, repairsCompleted
    inc eax
    mov repairsCompleted, eax

    mov edx, OFFSET msgRepairDone
    call WriteString
    call Crlf

SkipRepair:
    inc esi
    jmp NextRepair

DoneRepairs:
    ret
UpdateRepairs ENDP

; -------------------------
; Random breakdown generator
; -------------------------
RandomBreakdowns PROC
    xor esi, esi
NextElevBreak:
    cmp esi, NUM_ELEVATORS
    jge DoneBreak
    
    ; Generate random number for each elevator
    call Random32
    mov ebx, BREAKDOWN_CHANCE    ; Use constant for breakdown chance
    xor edx, edx
    div ebx                      ; remainder in EDX
    cmp edx, 0
    jne SkipBreak

    ; Check if elevator is not already broken/repairing
    mov edi, esi
    shl edi, 2
    mov eax, [elevatorStatus + edi]
    cmp eax, STATUS_BROKEN
    je SkipBreak
    cmp eax, STATUS_REPAIR
    je SkipBreak

    ; Break elevator
    mov [elevatorStatus + edi], STATUS_BROKEN
    mov [elevatorDir + edi], DIR_NONE
    mov [elevatorTarget + edi], 0
    ; Don't set repair timer here - only when player starts repair

    ; Count breakdown
    mov eax, breakdownsOccurred
    inc eax
    mov breakdownsOccurred, eax

    ; Show message
    mov edx, OFFSET msgBreakdown
    call WriteString
    mov eax, esi
    inc eax
    call WriteDec
    mov edx, OFFSET msgBrokenAt
    call WriteString
    call Crlf

SkipBreak:
    inc esi
    jmp NextElevBreak

DoneBreak:
    ret
RandomBreakdowns ENDP

; -------------------------
; Display live stats
; -------------------------
DisplayStats PROC
    call Crlf

    mov edx, OFFSET msgStatsTitle
    call WriteString
    call Crlf

    mov edx, OFFSET msgTurns
    call WriteString
    mov eax, turnCount
    call WriteDec
    call Crlf

    mov edx, OFFSET msgReqServed
    call WriteString
    mov eax, requestsServed
    call WriteDec
    call Crlf

    mov edx, OFFSET msgBreaks
    call WriteString
    mov eax, breakdownsOccurred
    call WriteDec
    call Crlf

    mov edx, OFFSET msgRepairs
    call WriteString
    mov eax, repairsCompleted
    call WriteDec
    call Crlf

    mov edx, OFFSET msgScore
    call WriteString
    mov eax, score
    call WriteDec
    call Crlf

    mov edx, OFFSET msgSeparator
    call WriteString
    call Crlf
    ret
DisplayStats ENDP

; -------------------------
; Wait for key
; -------------------------
WaitForKey PROC
    mov edx, OFFSET msgWaitKey
    call WriteString
    call ReadChar
    ret
WaitForKey ENDP

; -------------------------
; Final summary & efficiency (call when you want game to end)
; -------------------------
DisplayEndSummary PROC
    call Crlf
    mov edx, OFFSET msgEndSummary
    call WriteString
    call Crlf

    mov edx, OFFSET msgEndReqServed
    call WriteString
    mov eax, requestsServed
    call WriteDec
    call Crlf

    mov edx, OFFSET msgEndBreaks
    call WriteString
    mov eax, breakdownsOccurred
    call WriteDec
    call Crlf

    mov edx, OFFSET msgEndRepairs
    call WriteString
    mov eax, repairsCompleted
    call WriteDec
    call Crlf

    mov edx, OFFSET msgEndTurns
    call WriteString
    mov eax, turnCount
    call WriteDec
    call Crlf

    mov edx, OFFSET msgEndScore
    call WriteString
    mov eax, score
    call WriteDec
    call Crlf

    ret
DisplayEndSummary ENDP

DisplayFinalEfficiency PROC
    call Crlf
    mov edx, OFFSET msgFinalEff
    call WriteString
    call Crlf

    ; efficiency = (requestsServed*10) + (repairsCompleted*5) - (breakdownsOccurred*3) - (turnCount / 2)
    ; compute requestsServed*10
    mov eax, requestsServed
    mov ebx, 10
    imul eax, ebx         ; EAX = requestsServed*10

    ; compute repairsCompleted*5 into EBX and add
    mov ebx, repairsCompleted
    imul ebx, 5
    add eax, ebx

    ; subtract breakdownsOccurred*3
    mov ebx, breakdownsOccurred
    imul ebx, 3
    sub eax, ebx

    ; subtract (turnCount/2)
    mov ebx, turnCount
    shr ebx, 1
    sub eax, ebx

    mov edx, OFFSET msgEffScore
    call WriteString
    call WriteDec
    call Crlf
    ret
DisplayFinalEfficiency ENDP

END main