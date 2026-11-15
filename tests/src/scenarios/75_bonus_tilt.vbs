'A tilted ball gets no bonus, and entries that reset are cleared without being scored.
'Covers feat/bonus-mode.
TB_Scenario "bonus_tilt"

Dim tb_bonus_tilt_score_before

Function Scenario_bonus_tilt(stage)
    Scenario_bonus_tilt = 0
    If stage = 0 Then
        If Not TB_Require("bonus") Then
            Scenario_bonus_tilt = TB_DONE
            Exit Function
        End If
    End If
    If stage < TB_PRELUDE_STEPS Then
        Scenario_bonus_tilt = TB_OneBallInPlay(stage)
        Exit Function
    End If
    Select Case stage - TB_PRELUDE_STEPS
        Case 0
            SetPlayerState "tb_ramps", 4
            SetPlayerState "tb_loops", 2
            tb_bonus_tilt_score_before = GetPlayerState(GLF_SCORE)
            TB_Watch "bonus_start"
            TB_Watch "bonus_entry"
            TB_Post "s_tilt_warning_active"
            TB_WaitUntil "game is tilted", "glf_gameTilted = True", 2000
        Case 1
            TB_DrainBall
            TB_WaitUntil "tilt clears and the next ball is served", "glf_gameTilted = False And TB_Dev(""plunger"").Count() = 1", 10000
        Case 2
            Scenario_bonus_tilt = 300
        Case 3
            TB_Eq "no bonus start", TB_Seen("bonus_start"), 0
            TB_Eq "no bonus steps", TB_Seen("bonus_entry"), 0
            TB_Eq "score unchanged", GetPlayerState(GLF_SCORE) - tb_bonus_tilt_score_before, 0
            TB_Eq "entry set to reset is cleared", GetPlayerState("tb_ramps"), 0
            TB_Eq "entry not set to reset is kept", GetPlayerState("tb_loops"), 2
        Case Else
            Scenario_bonus_tilt = TB_DONE
    End Select
End Function
