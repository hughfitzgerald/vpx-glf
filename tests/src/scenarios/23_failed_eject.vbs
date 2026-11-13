'A kicked ball that falls back in before the eject is confirmed leaves the device usable.
'Covers fix/ball-device-failed-eject: before it, the device stayed in its ejecting state
'for good and HasBall never returned True again.
TB_Scenario "failed_eject"

Function Scenario_failed_eject(stage)
    Scenario_failed_eject = 0
    If stage < TB_PRELUDE_STEPS Then
        Scenario_failed_eject = TB_OneBallInPlay(stage)
        Exit Function
    End If
    Select Case stage - TB_PRELUDE_STEPS
        Case 0
            TB_Watch "balldevice_saucer_ball_eject_failed"
            TB_Watch "balldevice_saucer_ball_eject_success"
            TB_Shoot "saucer"
            TB_WaitUntil "GLF counts the ball in the saucer", "glf_ball_devices(""saucer"").Balls = 1", 3000
        Case 1
            'The next kick fails: the ball falls straight back in
            TB_RouteOnce "saucer", "self"
            TB_Post "tb_eject_saucer"
            TB_WaitUntil "saucer kicks the ball", "TB_Dev(""saucer"").EjectCount = 1", 3000
        Case 2
            Scenario_failed_eject = 1500
        Case 3
            TB_Eq "ball is back in the saucer", TB_Dev("saucer").Count(), 1
            TB_Eq "device reports it has a ball", glf_ball_devices("saucer").HasBall(), True
            TB_Eq "failed eject was reported", TB_Seen("balldevice_saucer_ball_eject_failed"), 1
            TB_Eq "no successful eject was reported", TB_Seen("balldevice_saucer_ball_eject_success"), 0
            TB_CheckCounts "after the failed eject", 1
            'A second kick works
            TB_Post "tb_eject_saucer"
            TB_WaitUntil "ball is back in play", "TB_PenCount() = 1", 3000
        Case 4
            Scenario_failed_eject = TB_EJECT_TIMEOUT + 400
        Case 5
            TB_Eq "saucer kicked twice in all", TB_Dev("saucer").EjectCount, 2
            TB_Eq "one successful eject was reported", TB_Seen("balldevice_saucer_ball_eject_success"), 1
            TB_CheckCounts "after the second eject", 1
        Case Else
            Scenario_failed_eject = TB_DONE
    End Select
End Function
