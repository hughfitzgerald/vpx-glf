'A held ball that leaves its device without being released is written off by the hold.
'Covers fix/ball-device-ball-missing: before it, the hold kept counting the ball.
TB_Scenario "ball_missing_hold"

Function Scenario_ball_missing_hold(stage)
    Scenario_ball_missing_hold = 0
    If stage < TB_PRELUDE_STEPS Then
        Scenario_ball_missing_hold = TB_OneBallInPlay(stage)
        Exit Function
    End If
    Select Case stage - TB_PRELUDE_STEPS
        Case 0
            TB_Watch "balldevice_scoop_ball_missing"
            TB_Post "tb_start_hold"
            Scenario_ball_missing_hold = 300
        Case 1
            TB_Shoot "scoop"
            TB_WaitUntil "hold takes the ball", "glf_ball_holds(""scoop_hold"").GetValue(""balls_held"") = 1", 3000
        Case 2
            Scenario_ball_missing_hold = 1000
        Case 3
            'The ball gets out on its own
            TB_Escape "scoop"
            TB_WaitUntil "ball is back in play", "TB_PenCount() = 1", 3000
        Case 4
            'GLF waits three seconds for a ball that left unexpectedly to come back
            Scenario_ball_missing_hold = 4000
        Case 5
            TB_Eq "device reported the ball missing", TB_Seen("balldevice_scoop_ball_missing"), 1
            TB_Eq "hold no longer counts the ball", glf_ball_holds("scoop_hold").GetValue("balls_held"), 0
            TB_CheckCounts "after the ball escaped", 1
        Case Else
            Scenario_ball_missing_hold = TB_DONE
    End Select
End Function
