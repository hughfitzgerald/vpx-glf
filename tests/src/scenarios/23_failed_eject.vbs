'A kicked ball that falls back in before the eject is confirmed is kicked again.
'The device recognises the returning ball, reports one failed eject and retries the same
'request after EjectRetryDelay.
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
            'The device sees the ball come back, reports the failure and kicks again by itself
            TB_WaitUntil "saucer retries and the ball is back in play", "TB_Dev(""saucer"").EjectCount = 2 And TB_PenCount() = 1", 4000
        Case 3
            TB_Eq "failed eject was reported once", TB_Seen("balldevice_saucer_ball_eject_failed"), 1
            TB_Eq "eject not yet reported as a success", TB_Seen("balldevice_saucer_ball_eject_success"), 0
            Scenario_failed_eject = TB_EJECT_TIMEOUT + 1000
        Case 4
            TB_Eq "saucer kicked twice in all", TB_Dev("saucer").EjectCount, 2
            TB_Eq "one successful eject was reported", TB_Seen("balldevice_saucer_ball_eject_success"), 1
            TB_Eq "device is empty", glf_ball_devices("saucer").HasBall(), False
            TB_CheckCounts "after the retry", 1
        Case Else
            Scenario_failed_eject = TB_DONE
    End Select
End Function
