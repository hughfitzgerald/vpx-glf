'Ball search leaves a locked ball where it is.
'Covers fix/ball-search-claimed-balls.
TB_Scenario "ball_search_lock"

Function Scenario_ball_search_lock(stage)
    Scenario_ball_search_lock = 0
    If stage < TB_PRELUDE_STEPS Then
        Scenario_ball_search_lock = TB_OneBallInPlay(stage)
        Exit Function
    End If
    Select Case stage - TB_PRELUDE_STEPS
        Case 0
            TB_Post "tb_start_lock"
            Scenario_ball_search_lock = 300
        Case 1
            TB_Shoot "lock"
            TB_WaitUntil "ball locked and replaced", "glf_ball_devices(""lock"").Balls = 1 And TB_PenCount() = 1", 8000
        Case 2
            Scenario_ball_search_lock = TB_EJECT_TIMEOUT + 400
        Case 3
            TB_Watch "ball_search_started"
            glf_ballsearch.Start 1
            Scenario_ball_search_lock = 6000
        Case 4
            TB_Eq "search ran all three phases", TB_Seen("ball_search_started"), 3
            TB_Eq "locked ball is still in the lock", TB_Dev("lock").Count(), 1
            TB_Eq "lock was not kicked", TB_Dev("lock").EjectCount, 0
            TB_CheckCounts "after the search", 1
        Case Else
            Scenario_ball_search_lock = TB_DONE
    End Select
End Function
