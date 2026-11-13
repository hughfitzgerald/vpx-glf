'An eject request made while a device is empty must not eject a ball that arrives later.
'Covers fix/ball-device-eject-empty: before it, the request waited without limit and
'ejected the next ball to arrive.
TB_Scenario "eject_empty_stale"

Function Scenario_eject_empty_stale(stage)
    Scenario_eject_empty_stale = 0
    If stage < TB_PRELUDE_STEPS Then
        Scenario_eject_empty_stale = TB_OneBallInPlay(stage)
        Exit Function
    End If
    Select Case stage - TB_PRELUDE_STEPS
        Case 0
            TB_Eq "saucer starts empty", TB_Dev("saucer").Count(), 0
            TB_Post "tb_eject_saucer"
            'Longer than the three seconds an empty device keeps a request alive
            Scenario_eject_empty_stale = 4500
        Case 1
            TB_Shoot "saucer"
            TB_WaitUntil "GLF counts the ball in the saucer", "glf_ball_devices(""saucer"").Balls = 1", 3000
        Case 2
            Scenario_eject_empty_stale = 2000
        Case 3
            TB_Eq "ball is still in the saucer", TB_Dev("saucer").Count(), 1
            TB_Eq "saucer has not ejected", TB_Dev("saucer").EjectCount, 0
            TB_CheckCounts "ball waiting in the saucer", 1
            'A request made now, with a ball present, must still work
            TB_Post "tb_eject_saucer"
            TB_WaitUntil "ball is ejected on request", "TB_PenCount() = 1", 3000
        Case 4
            Scenario_eject_empty_stale = TB_EJECT_TIMEOUT + 400
        Case 5
            TB_Eq "saucer ejected once", TB_Dev("saucer").EjectCount, 1
            TB_CheckCounts "after the eject", 1
        Case Else
            Scenario_eject_empty_stale = TB_DONE
    End Select
End Function
