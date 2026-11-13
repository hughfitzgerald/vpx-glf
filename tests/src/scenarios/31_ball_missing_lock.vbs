'A locked ball that gets back onto the playfield is counted as in play again.
'Covers fix/ball-device-ball-missing: before it, glf_BIP stayed one short, so the
'ball's eventual drain ended the ball in play early.
TB_Scenario "ball_missing_lock"

Function Scenario_ball_missing_lock(stage)
    Scenario_ball_missing_lock = 0
    If stage < TB_PRELUDE_STEPS Then
        Scenario_ball_missing_lock = TB_OneBallInPlay(stage)
        Exit Function
    End If
    Select Case stage - TB_PRELUDE_STEPS
        Case 0
            TB_Post "tb_start_lock"
            Scenario_ball_missing_lock = 300
        Case 1
            TB_Shoot "lock"
            TB_WaitUntil "replacement ball is in play", "glf_ball_devices(""lock"").Balls = 1 And TB_PenCount() = 1", 8000
        Case 2
            Scenario_ball_missing_lock = TB_EJECT_TIMEOUT + 400
        Case 3
            TB_Eq "one ball is locked", GetPlayerState("mbl_locked_balls"), 1
            TB_CheckCounts "one locked, one in play", 1
            'The locked ball gets out on its own
            TB_Escape "lock"
            TB_WaitUntil "both balls are on the playfield", "TB_PenCount() = 2", 3000
        Case 4
            Scenario_ball_missing_lock = 4000
        Case 5
            TB_CheckCounts "escaped ball counts as in play", 2
        Case Else
            Scenario_ball_missing_lock = TB_DONE
    End Select
End Function
