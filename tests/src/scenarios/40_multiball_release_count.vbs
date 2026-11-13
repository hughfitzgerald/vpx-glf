'A multiball takes only the locked balls it needs.
'Covers fix/multiball-lock-release-count: with two balls locked and a two-ball multiball
'starting from one ball in play, only one locked ball is released. Before the fix both
'were, putting three balls in play while glf_BIP said two.
TB_Scenario "multiball_release_count"

Function Scenario_multiball_release_count(stage)
    Scenario_multiball_release_count = 0
    If stage < TB_PRELUDE_STEPS Then
        Scenario_multiball_release_count = TB_OneBallInPlay(stage)
        Exit Function
    End If
    Select Case stage - TB_PRELUDE_STEPS
        Case 0
            TB_Post "tb_start_lock"
            Scenario_multiball_release_count = 300
        Case 1
            TB_Shoot "lock"
            TB_WaitUntil "first ball locked and replaced", "glf_ball_devices(""lock"").Balls = 1 And TB_PenCount() = 1", 8000
        Case 2
            Scenario_multiball_release_count = TB_EJECT_TIMEOUT + 400
        Case 3
            TB_Shoot "lock"
            TB_WaitUntil "second ball locked and replaced", "glf_ball_devices(""lock"").Balls = 2 And TB_PenCount() = 1", 8000
        Case 4
            Scenario_multiball_release_count = TB_EJECT_TIMEOUT + 400
        Case 5
            TB_Eq "two balls are locked", GetPlayerState("mbl_locked_balls"), 2
            TB_CheckCounts "two locked, one in play", 1
            TB_Post "tb_enable_mb"
            Scenario_multiball_release_count = 300
        Case 6
            TB_Post "tb_start_mb"
            TB_WaitUntil "second ball is in play", "TB_PenCount() = 2", 8000
        Case 7
            Scenario_multiball_release_count = 2500
        Case 8
            TB_Eq "one ball was released from the lock", TB_Dev("lock").EjectCount, 1
            TB_Eq "one ball stays in the lock", TB_Dev("lock").Count(), 1
            TB_Eq "two balls are on the playfield", TB_PenCount(), 2
            TB_CheckCounts "two in play, one still locked", 2
        Case Else
            Scenario_multiball_release_count = TB_DONE
    End Select
End Function
