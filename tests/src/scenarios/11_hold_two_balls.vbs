'A hold with room for two balls in one device takes the second ball without an error.
'Covers fix/ball-hold-queue-duplicate-key: before it, the second ball raised a
'duplicate-key error part-way through the device's ball-enter handling, so the
'device never posted its second ball_entered event.
TB_Scenario "hold_two_balls"

Function Scenario_hold_two_balls(stage)
    Scenario_hold_two_balls = 0
    If stage < TB_PRELUDE_STEPS Then
        Scenario_hold_two_balls = TB_OneBallInPlay(stage)
        Exit Function
    End If
    Select Case stage - TB_PRELUDE_STEPS
        Case 0
            'A two-ball multiball puts the second ball in play
            TB_Post "tb_enable_mb"
            Scenario_hold_two_balls = 300
        Case 1
            TB_Post "tb_start_mb"
            TB_WaitUntil "second ball is in play", "TB_PenCount() = 2", 8000
        Case 2
            Scenario_hold_two_balls = TB_EJECT_TIMEOUT + 400
        Case 3
            TB_CheckCounts "two balls in play", 2
            TB_Watch "balldevice_lock_ball_entered"
            TB_Post "tb_start_hold2"
            Scenario_hold_two_balls = 300
        Case 4
            TB_Shoot "lock"
            TB_WaitUntil "hold takes the first ball", "glf_ball_holds(""lock_hold"").GetValue(""balls_held"") = 1", 3000
        Case 5
            TB_Shoot "lock"
            TB_WaitUntil "hold takes the second ball", "glf_ball_holds(""lock_hold"").GetValue(""balls_held"") = 2", 3000
        Case 6
            Scenario_hold_two_balls = 1500
        Case 7
            TB_Eq "device finished handling both balls", TB_Seen("balldevice_lock_ball_entered"), 2
            TB_Eq "both balls are in the lock device", TB_Dev("lock").Count(), 2
            TB_Eq "lock device has not ejected", TB_Dev("lock").EjectCount, 0
            TB_CheckCounts "two held balls count as in play", 2
        Case Else
            Scenario_hold_two_balls = TB_DONE
    End Select
End Function
