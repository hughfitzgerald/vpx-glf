'A kickback only fires while it is enabled, and posts an event each time it fires.
'Covers feat/kickbacks.
TB_Scenario "kickback"

Function Scenario_kickback(stage)
    Scenario_kickback = 0
    If stage = 0 Then
        If Not TB_Require("kickbacks") Then
            Scenario_kickback = TB_DONE
            Exit Function
        End If
    End If
    If stage < TB_PRELUDE_STEPS Then
        Scenario_kickback = TB_OneBallInPlay(stage)
        Exit Function
    End If
    Select Case stage - TB_PRELUDE_STEPS
        Case 0
            tb_kick_actions = 0
            TB_Watch "kickback_tb_kick_fired"
            TB_Eq "starts disabled", glf_kickbacks("tb_kick").Enabled, False
            TB_Post "s_tb_kick_active"
            Scenario_kickback = 300
        Case 1
            TB_Eq "a disabled kickback does not fire", tb_kick_actions, 0
            TB_Post "tb_kick_on"
            Scenario_kickback = 300
        Case 2
            TB_Eq "enabled by its event", glf_kickbacks("tb_kick").Enabled, True
            TB_Post "s_tb_kick_active"
            Scenario_kickback = 300
        Case 3
            TB_Eq "fires once", tb_kick_actions, 1
            TB_Eq "fired event posted", TB_Seen("kickback_tb_kick_fired"), 1
            TB_Eq "its own fired event disables it", glf_kickbacks("tb_kick").Enabled, False
            TB_Post "s_tb_kick_active"
            Scenario_kickback = 300
        Case 4
            TB_Eq "does not fire again", tb_kick_actions, 1
            TB_Post "tb_kick_on"
            Scenario_kickback = 300
        Case 5
            TB_DrainBall
            TB_WaitUntil "next ball reaches the plunger lane", "TB_Dev(""plunger"").Count() = 1", 10000
        Case 6
            TB_Eq "disabled at the end of the ball", glf_kickbacks("tb_kick").Enabled, False
        Case Else
            Scenario_kickback = TB_DONE
    End Select
End Function
