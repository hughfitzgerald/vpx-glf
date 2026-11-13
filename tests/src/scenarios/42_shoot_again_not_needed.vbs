'Shoot again does not replace a ball when the multiball already has more balls than it asked for.
'Covers fix/multiball-shoot-again: a two-ball multiball is running with three balls in play
'(a second multiball added one). When one drains, two remain, which is what it wants, so
'nothing is saved. Before the fix it saved the ball anyway.
TB_Scenario "shoot_again_not_needed"

Function Scenario_shoot_again_not_needed(stage)
    Scenario_shoot_again_not_needed = 0
    If stage < TB_PRELUDE_STEPS Then
        Scenario_shoot_again_not_needed = TB_OneBallInPlay(stage)
        Exit Function
    End If
    Select Case stage - TB_PRELUDE_STEPS
        Case 0
            TB_Post "tb_enable_mb_sa"
            TB_Post "tb_enable_mb3"
            Scenario_shoot_again_not_needed = 300
        Case 1
            TB_Watch "multiball_mb_sa_shoot_again"
            TB_Post "tb_start_mb_sa"
            TB_WaitUntil "second ball is in play", "TB_PenCount() = 2", 8000
        Case 2
            Scenario_shoot_again_not_needed = TB_EJECT_TIMEOUT + 400
        Case 3
            TB_Post "tb_start_mb3"
            TB_WaitUntil "third ball is in play", "TB_PenCount() = 3", 8000
        Case 4
            Scenario_shoot_again_not_needed = TB_EJECT_TIMEOUT + 400
        Case 5
            TB_CheckCounts "three balls in play", 3
            TB_DrainBall
            Scenario_shoot_again_not_needed = 4000
        Case 6
            TB_Eq "no ball was saved", TB_Seen("multiball_mb_sa_shoot_again"), 0
            TB_Eq "two balls are on the playfield", TB_PenCount(), 2
            TB_CheckCounts "two balls in play", 2
        Case Else
            Scenario_shoot_again_not_needed = TB_DONE
    End Select
End Function
