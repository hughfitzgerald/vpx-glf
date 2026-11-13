'Releasing a two-ball hold puts both balls back in play.
'Known to fail: when the first ball leaves a multi-switch device, the second ball
'rolls onto the exit switch while the eject is still unconfirmed, and GLF treats
'it as a new ball. The hold, which is still enabled, takes it again.
TB_KnownIssueScenario "hold_release_two_balls", "a ball shifting between switches inside a device is relayed as a new ball"

Function Scenario_hold_release_two_balls(stage)
    Scenario_hold_release_two_balls = 0
    If stage < TB_PRELUDE_STEPS Then
        Scenario_hold_release_two_balls = TB_OneBallInPlay(stage)
        Exit Function
    End If
    Select Case stage - TB_PRELUDE_STEPS
        Case 0
            TB_Post "tb_enable_mb"
            Scenario_hold_release_two_balls = 300
        Case 1
            TB_Post "tb_start_mb"
            TB_WaitUntil "second ball is in play", "TB_PenCount() = 2", 8000
        Case 2
            Scenario_hold_release_two_balls = TB_EJECT_TIMEOUT + 400
        Case 3
            TB_Post "tb_start_hold2"
            Scenario_hold_release_two_balls = 300
        Case 4
            TB_Shoot "lock"
            TB_WaitUntil "hold takes the first ball", "glf_ball_holds(""lock_hold"").GetValue(""balls_held"") = 1", 3000
        Case 5
            TB_Shoot "lock"
            TB_WaitUntil "hold takes the second ball", "glf_ball_holds(""lock_hold"").GetValue(""balls_held"") = 2", 3000
        Case 6
            Scenario_hold_release_two_balls = 1000
        Case 7
            TB_Post "tb_release_hold2"
            TB_WaitUntil "both balls are back in play", "TB_PenCount() = 2", 6000
        Case 8
            Scenario_hold_release_two_balls = TB_EJECT_TIMEOUT + 400
        Case 9
            TB_Eq "hold is empty", glf_ball_holds("lock_hold").GetValue("balls_held"), 0
            TB_Eq "lock device ejected twice", TB_Dev("lock").EjectCount, 2
            TB_CheckCounts "after release", 2
        Case Else
            Scenario_hold_release_two_balls = TB_DONE
    End Select
End Function
