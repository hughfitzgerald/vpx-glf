'The attract mode runs whenever no game does, and is started once after a cancelled game.
'Covers feat/attract.
TB_Scenario "attract"

Function Scenario_attract(stage)
    Scenario_attract = 0
    Select Case stage
        Case 0
            If Not TB_Require("attract") Then
                Scenario_attract = TB_DONE
                Exit Function
            End If
            TB_Eq "attract runs before a game", glf_modes("attract").GetValue("active"), True
            TB_StartGame
            TB_WaitUntil "first ball reaches the plunger lane", "TB_Dev(""plunger"").Count = 1", 5000
        Case 1
            TB_Eq "attract stops when a game starts", glf_modes("attract").GetValue("active"), False
            TB_Watch "mode_attract_started"
            TB_Post "glf_game_cancel"
            Scenario_attract = 1500
        Case 2
            TB_Eq "attract runs again after the game", glf_modes("attract").GetValue("active"), True
            TB_Eq "and was started once, not twice", TB_Seen("mode_attract_started"), 1
        Case Else
            Scenario_attract = TB_DONE
    End Select
End Function
