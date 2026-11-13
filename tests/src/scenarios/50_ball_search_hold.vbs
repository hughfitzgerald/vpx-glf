'Ball search leaves a held ball where it is.
'Covers fix/ball-search-claimed-balls: before it, the second search phase kicked the
'held ball out without the hold knowing.
TB_Scenario "ball_search_hold"

Function Scenario_ball_search_hold(stage)
    Scenario_ball_search_hold = 0
    If stage < TB_PRELUDE_STEPS Then
        Scenario_ball_search_hold = TB_OneBallInPlay(stage)
        Exit Function
    End If
    Select Case stage - TB_PRELUDE_STEPS
        Case 0
            'Two balls: one will be held, the other stays on the playfield so a search can run
            TB_Post "tb_enable_mb"
            Scenario_ball_search_hold = 300
        Case 1
            TB_Post "tb_start_mb"
            TB_WaitUntil "second ball is in play", "TB_PenCount() = 2", 8000
        Case 2
            Scenario_ball_search_hold = TB_EJECT_TIMEOUT + 400
        Case 3
            TB_Post "tb_start_hold"
            Scenario_ball_search_hold = 300
        Case 4
            TB_Shoot "scoop"
            TB_WaitUntil "hold takes the ball", "glf_ball_holds(""scoop_hold"").GetValue(""balls_held"") = 1", 3000
        Case 5
            Scenario_ball_search_hold = 1000
        Case 6
            TB_Watch "ball_search_started"
            glf_ballsearch.Start 1
            'Three phases over eight devices
            Scenario_ball_search_hold = 6000
        Case 7
            TB_Eq "search ran all three phases", TB_Seen("ball_search_started"), 3
            TB_Eq "held ball is still in the scoop", TB_Dev("scoop").Count(), 1
            TB_Eq "scoop was not kicked", TB_Dev("scoop").EjectCount, 0
            TB_Eq "hold still has its ball", glf_ball_holds("scoop_hold").GetValue("balls_held"), 1
            TB_CheckCounts "after the search", 2
        Case Else
            Scenario_ball_search_hold = TB_DONE
    End Select
End Function
