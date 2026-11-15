'The hurry-up event makes the bonus move on at once and use the short delay.
'Covers feat/bonus-mode.
TB_Scenario "bonus_hurry_up"

Function Scenario_bonus_hurry_up(stage)
    Scenario_bonus_hurry_up = 0
    If stage = 0 Then
        If Not TB_Require("bonus") Then
            Scenario_bonus_hurry_up = TB_DONE
            Exit Function
        End If
    End If
    If stage < TB_PRELUDE_STEPS Then
        Scenario_bonus_hurry_up = TB_OneBallInPlay(stage)
        Exit Function
    End If
    Select Case stage - TB_PRELUDE_STEPS
        Case 0
            SetPlayerState "tb_ramps", 1
            SetPlayerState "tb_loops", 1
            SetPlayerState "bonus_multiplier", 3
            TB_Watch "bonus_start"
            TB_Watch "bonus_entry"
            TB_DrainBall
            TB_WaitUntil "bonus starts", "TB_Seen(""bonus_start"") = 1", 3000
        Case 1
            TB_Eq "nothing counted yet", TB_Seen("bonus_entry"), 0
            TB_Post "tb_bonus_hurry"
            'Five steps at the normal delay would take two seconds
            TB_WaitUntil "all five steps are done quickly", "TB_Seen(""bonus_entry"") = 5", 600
        Case 2
            TB_Eq "total is (1000 + 250) x 3", TB_Kwarg("bonus_entry", "score"), 3750
            TB_WaitUntil "next ball reaches the plunger lane", "TB_Dev(""plunger"").Count() = 1", 6000
        Case Else
            Scenario_bonus_hurry_up = TB_DONE
    End Select
End Function
