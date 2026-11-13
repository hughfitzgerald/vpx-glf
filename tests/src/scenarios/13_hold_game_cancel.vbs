'Cancelling a game while a hold has two balls leaves the hold empty.
'Covers fix/ball-hold-release-count: before it, the hold stayed one ball over after the
'game ejected its device, and reported itself full in the next game.
TB_Scenario "hold_game_cancel"

Function Scenario_hold_game_cancel(stage)
    Scenario_hold_game_cancel = 0
    If stage < TB_PRELUDE_STEPS Then
        Scenario_hold_game_cancel = TB_OneBallInPlay(stage)
        Exit Function
    End If
    Select Case stage - TB_PRELUDE_STEPS
        Case 0
            TB_Post "tb_enable_mb"
            Scenario_hold_game_cancel = 300
        Case 1
            TB_Post "tb_start_mb"
            TB_WaitUntil "second ball is in play", "TB_PenCount() = 2", 8000
        Case 2
            Scenario_hold_game_cancel = TB_EJECT_TIMEOUT + 400
        Case 3
            TB_Post "tb_start_hold2"
            Scenario_hold_game_cancel = 300
        Case 4
            TB_Shoot "lock"
            TB_WaitUntil "hold takes the first ball", "glf_ball_holds(""lock_hold"").GetValue(""balls_held"") = 1", 3000
        Case 5
            TB_Shoot "lock"
            TB_WaitUntil "hold takes the second ball", "glf_ball_holds(""lock_hold"").GetValue(""balls_held"") = 2", 3000
        Case 6
            Scenario_hold_game_cancel = 1000
        Case 7
            TB_Route "lock", "drain"
            TB_Post "glf_game_cancel"
            TB_WaitUntil "both balls are back in the trough", "TB_TroughCount() = tnob", 10000
        Case 8
            Scenario_hold_game_cancel = 1500
        Case 9
            TB_Eq "game is over", glf_gameStarted, False
            TB_Eq "hold is empty", glf_ball_holds("lock_hold").GetValue("balls_held"), 0
            TB_Eq "GLF counts no balls in the lock device", glf_ball_devices("lock").Balls, 0
        Case Else
            Scenario_hold_game_cancel = TB_DONE
    End Select
End Function
