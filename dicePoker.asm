
;  DICE POKER



.MODEL SMALL
.STACK 256

PRINTSTR MACRO lbl
    PUSH DX
    PUSH AX
    LEA  DX, lbl
    MOV  AH, 09h
    INT  21h
    POP  AX
    POP  DX
ENDM

SETCUR MACRO col_val, row_val
    PUSH AX
    PUSH BX
    PUSH DX
    MOV  AH, 02h
    MOV  BH, 00h
    MOV  DH, row_val
    MOV  DL, col_val
    INT  10h
    POP  DX
    POP  BX
    POP  AX
ENDM


.DATA
dice        DB  5 DUP(1)

; --- Feature 5: Match History Log Variables
history     DB  25 DUP(0)   
histCount   DB  0           
histHead    DB  0           

; --- Feature 2: Score Tracker Variables 
totalScore  DW  0
targetScore DW  0
rollScore   DW  0
turns       DB  3

; --- Feature 6: Reroll Option Variables
rerolls     DB  3

; --- Feature 4: Combo Evaluator Variables
comboIdx    DB  0           
comboMult   DB  1, 2, 4, 5, 6, 7, 8, 10
CNAME_SZ    EQU 17
comboNames  DB  'High Die        $'   
            DB  'One Pair        $'   
            DB  'Two Pair        $'   
            DB  'Three of a Kind $'   
            DB  'Straight        $'   
            DB  'Full House      $'   
            DB  'Four of a Kind  $'   
            DB  'Five of a Kind  $'   

; --- Feature 1: Dice Roller Variables 
rndSeed     DW  1

; --- UI Strings
sBorder  DB '+=========================+', 0Dh, 0Ah, '$'
sTitle   DB '|    *** DICE POKER *** |', 0Dh, 0Ah, '$'
sDLbl    DB '| Dice   : $'
sCLbl    DB '| Combo  : $'
sRSLbl   DB '| Roll $ : $'
sTSLbl   DB '| Total  : $'
sTGLbl   DB '| Target : $'
sTNLbl   DB '| Turns  : $'
sRRLbl   DB '| Rerolls: $'
sHdrHist DB '| ----- ROLL HISTORY ---- |', 0Dh, 0Ah, '$'
sRollPfx DB '| Roll $'     
sRowClose DB '        |', 0Dh, 0Ah, '$'
sDiceClose DB '   |', 0Dh, 0Ah, '$'
sCtrl    DB '| R=Reroll  P=Play  Q=Quit|', 0Dh, 0Ah, '$'
sSpace   DB  ' $'
sNL      DB  0Dh, 0Ah, '$'
sColon   DB  ': $'
sWin     DB  0Dh, 0Ah
         DB  '+=========================+', 0Dh, 0Ah
         DB  '|    *** YOU  WIN! *** |', 0Dh, 0Ah
         DB  '+=========================+', 0Dh, 0Ah, '$'
sLose    DB  0Dh, 0Ah
         DB  '+=========================+', 0Dh, 0Ah
         DB  '|   *** GAME  OVER! *** |', 0Dh, 0Ah
         DB  '|  Score < Target. Lose.  |', 0Dh, 0Ah
         DB  '+=========================+', 0Dh, 0Ah, '$'
sNoRR    DB  '| No rerolls remaining!  |', 0Dh, 0Ah, '$'
sEmpty   DB  '| (no history yet)       |', 0Dh, 0Ah, '$'
sBlank   DB  '|                        |', 0Dh, 0Ah, '$'
sPrompt  DB  'Press any key to exit...', '$'

.CODE

START:
    MOV  AX, @DATA
    MOV  DS, AX
    MOV  ES, AX

    ; Seed RNG for Feature 1 (Dice Roller)
    MOV  AH, 00h
    INT  1Ah
    MOV  [rndSeed], DX
    
    MOV  AX, [rndSeed]
    OR   AX, 1
    MOV  [rndSeed], AX

    ; Generate target score for Feature 2 (Score Tracker)
    CALL RandByte               
    MOV  AH, 0
    MOV  BL, 171                
    DIV  BL                     
    MOV  AL, AH
    MOV  AH, 0
    ADD  AX, 80                 
    MOV  [targetScore], AX

    ; Initial game setup calling all features
    CALL RollDice
    CALL SortDice
    CALL EvaluateCombo
    CALL UpdateHistory
    CALL DisplayUI

GameLoop:
    CALL HandleInput
    CMP  AX, 0FFFFh
    JE   DoQuit
    CMP  AX, 1
    JNE  GameLoop           

    ; Feature 2: Score Tracker - Win condition check
    MOV  AX, [totalScore]
    CMP  AX, [targetScore]
    JAE  DoWin

    ; Feature 2: Score Tracker - Lose condition check
    MOV  AL, [turns]
    CMP  AL, 0
    JE   DoLose

    JMP  GameLoop

DoWin:
    CALL DisplayUI
    PRINTSTR sWin
    JMP  ExitGame

DoLose:
    CALL DisplayUI
    PRINTSTR sLose
    JMP  ExitGame

DoQuit:
    MOV  AX, 4C00h          
    INT  21h

ExitGame:
    PRINTSTR sPrompt
    MOV  AH, 00h
    INT  16h                
    MOV  AX, 4C00h
    INT  21h                


; FEATURE 1: DICE ROLLER
; Generates random values (1-6) for the 5 dice array slots
; using the custom RandByte logic.

RollDice PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH SI
    MOV  CX, 5
    MOV  SI, 0
RD_Loop:
    CALL RandByte       
    MOV  AH, 0
    MOV  BL, 6
    DIV  BL             
    INC  AH             
    MOV  [dice + SI], AH
    INC  SI
    LOOP RD_Loop
    POP  SI
    POP  CX
    POP  BX
    POP  AX
    RET
RollDice ENDP

; Feature 1 Pseudo-Random Number Generator (LCG + Timer)
RandByte PROC NEAR
    PUSH BX
    PUSH CX
    PUSH DX
    MOV  AX, [rndSeed]
    MOV  BX, 25173
    MUL  BX             
    ADD  AX, 13849      
    PUSH AX
    MOV  AH, 00h
    INT  1Ah            
    POP  AX
    XOR  AL, DL
    MOV  [rndSeed], AX
    POP  DX
    POP  CX
    POP  BX
    RET
RandByte ENDP
                                                               
; FEATURE 3: DICE SORTER
; Implements a Bubble Sort algorithm to organize the dice
; in ascending order

SortDice PROC NEAR
    PUSH AX
    PUSH CX
    PUSH DX
    PUSH SI
    MOV  DX, 4          
SD_Outer:
    MOV  SI, 0
    MOV  CX, DX         
SD_Inner:
    MOV  AL, [dice + SI]
    MOV  AH, [dice + SI + 1]
    CMP  AL, AH
    JLE  SD_NoSwap
    MOV  [dice + SI],     AH   
    MOV  [dice + SI + 1], AL
SD_NoSwap:
    INC  SI
    LOOP SD_Inner
    DEC  DX
    JNZ  SD_Outer
    POP  SI
    POP  DX
    POP  CX
    POP  AX
    RET
SortDice ENDP


; FEATURE 4: COMBO EVALUATOR


EvaluateCombo PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    ; Initialize counters for pairs, triples, quads
    MOV  BL, 1      
    MOV  BH, 0      
    MOV  CL, 0      
    MOV  CH, 0      
    MOV  DL, 0      
    MOV  DH, 1      
    MOV  SI, 1      

EC_RunLoop:
    CMP  SI, 5
    JGE  EC_FlushLast
    MOV  AL, [dice + SI - 1]
    MOV  AH, [dice + SI]
    CMP  AL, AH
    JNE  EC_NewRun
    INC  DH             
    JMP  EC_Next
EC_NewRun:
    CALL EC_Flush       
    MOV  DH, 1          
EC_Next:
    INC  SI
    JMP  EC_RunLoop
EC_FlushLast:
    CALL EC_Flush       

    ; Evaluate from highest priority combo to lowest
    MOV  AL, [dice + 4]
    SUB  AL, [dice]
    CMP  AL, 4
    JNE  EC_NoStr
    CMP  BL, 1
    JNE  EC_NoStr
    MOV  AL, 4
    MOV  [comboIdx], AL
    JMP  EC_Score

EC_NoStr:
    CMP  DL, 1              
    JNE  EC_NoQuint
    MOV  AL, 7
    MOV  [comboIdx], AL
    JMP  EC_Score

EC_NoQuint:
    CMP  CH, 1              
    JNE  EC_NoQuad
    MOV  AL, 6
    MOV  [comboIdx], AL
    JMP  EC_Score

EC_NoQuad:
    CMP  CL, 1              
    JNE  EC_NoTrip
    CMP  BH, 1              
    JNE  EC_NoFH
    MOV  AL, 5
    MOV  [comboIdx], AL
    JMP  EC_Score
EC_NoFH:
    MOV  AL, 3
    MOV  [comboIdx], AL
    JMP  EC_Score

EC_NoTrip:
    CMP  BH, 2              
    JNE  EC_NoTwoPair
    MOV  AL, 2
    MOV  [comboIdx], AL
    JMP  EC_Score

EC_NoTwoPair:
    CMP  BH, 1              
    JNE  EC_HighDie
    MOV  AL, 1
    MOV  [comboIdx], AL
    JMP  EC_Score

EC_HighDie:
    MOV  AL, 0
    MOV  [comboIdx], AL

EC_Score:
    MOV  AX, 0
    MOV  [rollScore], AX
    MOV  SI, 0
EC_SumLoop:
    CMP  SI, 5
    JGE  EC_SumDone
    MOV  BL, [dice + SI]
    MOV  BH, 0
    ADD  [rollScore], BX
    INC  SI
    JMP  EC_SumLoop

EC_SumDone:
    MOV  BL, [comboIdx]
    MOV  BH, 0
    MOV  BL, [comboMult + BX]   
    MOV  BH, 0
    MOV  AX, [rollScore]
    MUL  BX                     
    MOV  [rollScore], AX

    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
EvaluateCombo ENDP

; Feature 4 Helper: Commits the current run counter to registers
EC_Flush PROC NEAR
    CMP  DH, BL
    JBE  EF_MaxDone
    MOV  BL, DH
EF_MaxDone:
    CMP  DH, 2
    JNE  EF_Not2
    INC  BH             
EF_Not2:
    CMP  DH, 3
    JNE  EF_Not3
    INC  CL             
EF_Not3:
    CMP  DH, 4
    JNE  EF_Not4
    INC  CH             
EF_Not4:
    CMP  DH, 5
    JNE  EF_Not5
    INC  DL             
EF_Not5:
    RET
EC_Flush ENDP


; FEATURE 5: MATCH HISTORY LOG


UpdateHistory PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DI
    PUSH SI

    MOV  AL, [histHead]
    MOV  AH, 0
    MOV  BX, 5
    MUL  BX             
    MOV  DI, AX

    MOV  CX, 5
    MOV  SI, 0
UH_Copy:
    MOV  AL, [dice + SI]
    MOV  [history + DI], AL
    INC  SI
    INC  DI
    LOOP UH_Copy

    MOV  AL, [histHead]
    INC  AL
    CMP  AL, 5
    JB   UH_NoWrap
    MOV  AL, 0
UH_NoWrap:
    MOV  [histHead], AL

    MOV  AL, [histCount]
    CMP  AL, 5
    JAE  UH_Full
    INC  AL
    MOV  [histCount], AL
UH_Full:

    POP  SI
    POP  DI
    POP  CX
    POP  BX
    POP  AX
    RET
UpdateHistory ENDP


; FEATURE 2: SCORE TRACKER
; decrements available turns, and refreshes rerolls.

UpdateScore PROC NEAR
    PUSH AX
    MOV  AX, [rollScore]
    ADD  [totalScore], AX
    
    MOV  AL, [turns]
    DEC  AL
    MOV  [turns], AL
    
    MOV  AL, 3
    MOV  [rerolls], AL

    POP  AX
    RET
UpdateScore ENDP

; --- Main UI Display 
DisplayUI PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    MOV  AX, 0600h
    MOV  BH, 07h        
    MOV  CX, 0000h      
    MOV  DX, 184Fh      
    INT  10h
    SETCUR 0, 0

    PRINTSTR sBorder
    PRINTSTR sTitle
    PRINTSTR sBorder
    PRINTSTR sDLbl
    CALL PrintDiceRow
    PRINTSTR sDiceClose

    PRINTSTR sCLbl
    MOV  AL, [comboIdx]
    MOV  AH, 0
    MOV  BX, CNAME_SZ
    MUL  BX             
    PUSH DX
    LEA  DX, comboNames
    ADD  DX, AX
    MOV  AH, 09h
    INT  21h
    POP  DX
    PRINTSTR sNL

    PRINTSTR sRSLbl
    MOV  AX, [rollScore]
    CALL PrintDec
    PRINTSTR sNL

    PRINTSTR sTSLbl
    MOV  AX, [totalScore]
    CALL PrintDec
    PRINTSTR sNL

    PRINTSTR sTGLbl
    MOV  AX, [targetScore]
    CALL PrintDec
    PRINTSTR sNL

    PRINTSTR sTNLbl
    MOV  AL, [turns]
    MOV  AH, 0
    CALL PrintDec
    PRINTSTR sNL

    PRINTSTR sRRLbl
    MOV  AL, [rerolls]
    MOV  AH, 0
    CALL PrintDec
    PRINTSTR sNL

    PRINTSTR sBorder
    PRINTSTR sHdrHist

    ; Feature 5 Display 
    MOV  CL, [histCount]
    MOV  CH, 0              

    CMP  CX, 0
    JNE  DU_HasHistory
    PRINTSTR sEmpty
    MOV  CX, 4              
DU_FillBlank:
    PRINTSTR sBlank
    LOOP DU_FillBlank
    JMP  DU_HistDone

DU_HasHistory:
    MOV  AL, 0
    MOV  AH, [histCount] 
    CMP  AH, 5
    JB   DU_SlotSet
    MOV  AL, [histHead]     
DU_SlotSet:
    MOV  BX, 1              

DU_HistLoop:
    CMP  CX, 0
    JE   DU_HistLoopDone

    PUSH AX
    PUSH CX
    PUSH BX

    LEA  DX, sRollPfx
    MOV  AH, 09h
    INT  21h

    MOV  AX, BX
    CALL PrintDec
    PRINTSTR sColon

    POP  BX     
    POP  CX     
    POP  AX     

    PUSH AX
    PUSH BX
    PUSH CX

    MOV  BL, AL
    MOV  BH, 0
    MOV  AX, BX
    MOV  BX, 5
    MUL  BX             
    MOV  SI, AX

    MOV  BX, 5          
DU_DicePrint:
    MOV  AL, [history + SI]
    MOV  AH, 0
    CALL PrintDec
    MOV  AH, 02h
    MOV  DL, ' '
    INT  21h
    INC  SI
    DEC  BX
    JNZ  DU_DicePrint

    PRINTSTR sRowClose

    POP  CX
    POP  BX
    POP  AX

    INC  AL
    CMP  AL, 5
    JB   DU_NoWrap
    MOV  AL, 0
DU_NoWrap:
    INC  BX             
    DEC  CX
    JMP  DU_HistLoop

DU_HistLoopDone:
    MOV  AL, [histCount]
    MOV  AH, 0
    MOV  CX, 5
    SUB  CX, AX         
DU_Blanks:
    CMP  CX, 0
    JE   DU_HistDone
    PRINTSTR sBlank
    DEC  CX
    JMP  DU_Blanks

DU_HistDone:
    PRINTSTR sBorder
    PRINTSTR sCtrl
    PRINTSTR sBorder

    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
DisplayUI ENDP

PrintDiceRow PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    MOV  CX, 5
    MOV  BX, 0
PDR_Loop:
    MOV  AL, [dice + BX]
    MOV  AH, 0
    CALL PrintDec
    MOV  AH, 02h
    MOV  DL, ' '
    INT  21h
    INC  BX
    LOOP PDR_Loop
    POP  CX
    POP  BX
    POP  AX
    RET
PrintDiceRow ENDP

PrintDec PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    MOV  BX, 10
    MOV  CX, 0          
    CMP  AX, 0
    JNE  PD_Divide
    MOV  DL, '0'
    MOV  AH, 02h
    INT  21h
    JMP  PD_Done
PD_Divide:
    CMP  AX, 0
    JE   PD_Print
    MOV  DX, 0
    DIV  BX             
    PUSH DX             
    INC  CX
    JMP  PD_Divide
PD_Print:
    CMP  CX, 0
    JE   PD_Done
    POP  DX
    ADD  DL, '0'
    MOV  AH, 02h
    INT  21h
    DEC  CX
    JMP  PD_Print
PD_Done:
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
PrintDec ENDP

DisplayDice PROC NEAR
    CALL PrintDiceRow
    RET
DisplayDice ENDP

; --- Key Input Handler
HandleInput PROC NEAR
HI_Wait:
    MOV  AH, 00h
    INT  16h            
    CMP  AL, 'a'
    JB   HI_Dispatch
    CMP  AL, 'z'
    JA   HI_Dispatch
    SUB  AL, 20h
HI_Dispatch:
    CMP  AL, 'R'
    JE   HI_Reroll
    CMP  AL, 'P'
    JE   HI_Play
    CMP  AL, 'Q'
    JE   HI_Quit
    JMP  HI_Wait        


; FEATURE 6: REROLL OPTION
; Checks for available reroll tokens

HI_Reroll:
    MOV  AL, [rerolls]
    CMP  AL, 0
    JE   HI_NoRerolls
    DEC  AL
    MOV  [rerolls], AL

    CALL RollDice
    CALL SortDice
    CALL EvaluateCombo
    CALL UpdateHistory
    CALL DisplayUI
    MOV  AX, 0
    RET

HI_NoRerolls:
    PRINTSTR sNoRR
    JMP  HI_Wait        

HI_Play:
    CALL UpdateScore
    MOV  AL, [turns]
    CMP  AL, 0
    JE   HI_PlayDone
    CALL RollDice
    CALL SortDice
    CALL EvaluateCombo
    CALL UpdateHistory
    CALL DisplayUI
HI_PlayDone:
    MOV  AX, 1
    RET

HI_Quit:
    MOV  AX, 0FFFFh
    RET
HandleInput ENDP

MainGameLoop PROC NEAR
    RET
MainGameLoop ENDP

END START

