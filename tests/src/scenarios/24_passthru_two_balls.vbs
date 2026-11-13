'Two balls reaching a pass-through kicker in quick succession both come back out.
'The second ball lands while the first is still being confirmed, so its eject request
'joins one already in flight. Guards fix/ball-device-overlapping-ejects.
TB_Scenario "passthru_two_balls"

Function Scenario_passthru_two_balls(stage)
    Scenario_passthru_two_balls = 0
    If stage < TB_PRELUDE_STEPS Then
        Scenario_passthru_two_balls = TB_OneBallInPlay(stage)
        Exit Function
    End If
    Select Case stage - TB_PRELUDE_STEPS
        Case 0
            TB_Post "tb_enable_mb"
            Scenario_passthru_two_balls = 300
        Case 1
            TB_Post "tb_start_mb"
            TB_WaitUntil "second ball is in play", "TB_PenCount() = 2", 8000
        Case 2
            Scenario_passthru_two_balls = TB_EJECT_TIMEOUT + 400
        Case 3
            TB_Shoot "passthru"
            TB_WaitUntil "first ball is kicked out", "TB_Dev(""passthru"").EjectCount = 1", 4000
        Case 4
            'The second ball arrives while the first eject is still unconfirmed
            TB_Shoot "passthru"
            TB_WaitUntil "both balls are back in play", "TB_Dev(""passthru"").EjectCount = 2 And TB_PenCount() = 2", 6000
        Case 5
            Scenario_passthru_two_balls = TB_EJECT_TIMEOUT + 3600
        Case 6
            TB_Eq "kicker ejected exactly twice", TB_Dev("passthru").EjectCount, 2
            TB_CheckCounts "after both balls passed through", 2
        Case Else
            Scenario_passthru_two_balls = TB_DONE
    End Select
End Function
