'The bonus mode counts its entries, multiplies them and adds the total to the score
'before the next ball starts.
'Covers feat/bonus-mode.
TB_Scenario "bonus"

Dim tb_bonus_score_before

Function Scenario_bonus(stage)
    Scenario_bonus = 0
    If stage = 0 Then
        If Not TB_Require("bonus") Then
            Scenario_bonus = TB_DONE
            Exit Function
        End If
    End If
    If stage < TB_PRELUDE_STEPS Then
        Scenario_bonus = TB_OneBallInPlay(stage)
        Exit Function
    End If
    Select Case stage - TB_PRELUDE_STEPS
        Case 0
            SetPlayerState "tb_ramps", 3
            SetPlayerState "tb_loops", 2
            SetPlayerState "bonus_multiplier", 2
            tb_bonus_score_before = GetPlayerState(GLF_SCORE)
            TB_Watch "bonus_start"
            TB_Watch "bonus_entry"
            TB_DrainBall
            TB_WaitUntil "bonus starts", "TB_Seen(""bonus_start"") = 1", 3000
        Case 1
            TB_Eq "ball end waits for the bonus", TB_Dev("plunger").Count(), 0
            TB_WaitUntil "next ball reaches the plunger lane", "TB_Dev(""plunger"").Count() = 1", 10000
        Case 2
            Scenario_bonus = 300
        Case 3
            TB_Eq "two entries, subtotal, multiplier and total", TB_Seen("bonus_entry"), 5
            TB_Eq "last step is the total", TB_Kwarg("bonus_entry", "entry"), "total"
            TB_Eq "total is (3 x 1000 + 2 x 250) x 2", TB_Kwarg("bonus_entry", "score"), 7000
            TB_Eq "total added to the score", GetPlayerState(GLF_SCORE) - tb_bonus_score_before, 7000
            TB_Eq "entry set to reset is back at 0", GetPlayerState("tb_ramps"), 0
            TB_Eq "entry not set to reset keeps its count", GetPlayerState("tb_loops"), 2
            TB_Eq "multiplier is back at 1", GetPlayerState("bonus_multiplier"), 1
            TB_Eq "player is on ball 2", GetPlayerState(GLF_CURRENT_BALL), 2
        Case Else
            Scenario_bonus = TB_DONE
    End Select
End Function
