'A ball hold keeps one ball in the scoop, counts it as in play, and releases it on request.
TB_Scenario "hold_basic"

Function Scenario_hold_basic(stage)
    Scenario_hold_basic = 0
    If stage < TB_PRELUDE_STEPS Then
        Scenario_hold_basic = TB_OneBallInPlay(stage)
        Exit Function
    End If
    Select Case stage - TB_PRELUDE_STEPS
        Case 0
            TB_Post "tb_start_hold"
            Scenario_hold_basic = 300
        Case 1
            TB_Shoot "scoop"
            TB_WaitUntil "hold takes the ball", "glf_ball_holds(""scoop_hold"").GetValue(""balls_held"") = 1", 3000
        Case 2
            'Longer than the auto-eject delay and the eject timeout, to prove the ball stays put
            Scenario_hold_basic = 1500
        Case 3
            TB_Eq "ball is still in the scoop", TB_Dev("scoop").Count(), 1
            TB_Eq "scoop has not ejected", TB_Dev("scoop").EjectCount, 0
            TB_CheckCounts "held ball counts as in play", 1
            TB_Post "tb_release_hold"
            TB_WaitUntil "released ball is back in play", "TB_PenCount() = 1", 3000
        Case 4
            Scenario_hold_basic = TB_EJECT_TIMEOUT + 400
        Case 5
            TB_Eq "hold is empty", glf_ball_holds("scoop_hold").GetValue("balls_held"), 0
            TB_Eq "scoop ejected once", TB_Dev("scoop").EjectCount, 1
            TB_CheckCounts "after release", 1
        Case Else
            Scenario_hold_basic = TB_DONE
    End Select
End Function
