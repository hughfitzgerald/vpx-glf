'A ball that drains during a multiball's shoot-again window is put back in play.
TB_Scenario "shoot_again_saves"

Function Scenario_shoot_again_saves(stage)
    Scenario_shoot_again_saves = 0
    If stage < TB_PRELUDE_STEPS Then
        Scenario_shoot_again_saves = TB_OneBallInPlay(stage)
        Exit Function
    End If
    Select Case stage - TB_PRELUDE_STEPS
        Case 0
            TB_Post "tb_enable_mb_sa"
            Scenario_shoot_again_saves = 300
        Case 1
            TB_Watch "multiball_mb_sa_shoot_again"
            TB_Post "tb_start_mb_sa"
            TB_WaitUntil "second ball is in play", "TB_PenCount() = 2", 8000
        Case 2
            Scenario_shoot_again_saves = TB_EJECT_TIMEOUT + 400
        Case 3
            TB_CheckCounts "two balls in play", 2
            TB_DrainBall
            TB_WaitUntil "drained ball is replaced", "TB_Seen(""multiball_mb_sa_shoot_again"") = 1 And TB_PenCount() = 2", 8000
        Case 4
            Scenario_shoot_again_saves = TB_EJECT_TIMEOUT + 400
        Case 5
            TB_Eq "one ball was saved", TB_Seen("multiball_mb_sa_shoot_again"), 1
            TB_CheckCounts "still two balls in play", 2
        Case Else
            Scenario_shoot_again_saves = TB_DONE
    End Select
End Function
