'A ball that drains after the last ball in play has already drained does not end the ball twice.
'Covers fix/drain-after-ball-end: before it, the second drain took glf_BIP below zero and
'posted ball_ending again, so the player lost two balls instead of one.
TB_Scenario "drain_after_ball_end"

Function Scenario_drain_after_ball_end(stage)
    Scenario_drain_after_ball_end = 0
    If stage < TB_PRELUDE_STEPS Then
        Scenario_drain_after_ball_end = TB_OneBallInPlay(stage)
        Exit Function
    End If
    Select Case stage - TB_PRELUDE_STEPS
        Case 0
            TB_Post "tb_start_lock"
            Scenario_drain_after_ball_end = 300
        Case 1
            TB_Shoot "lock"
            TB_WaitUntil "replacement ball is in play", "glf_ball_devices(""lock"").Balls = 1 And TB_PenCount() = 1", 8000
        Case 2
            Scenario_drain_after_ball_end = TB_EJECT_TIMEOUT + 400
        Case 3
            'GLF ejects the locked ball outside a multiball, so it is on the playfield but not in glf_BIP
            glf_ball_devices("lock").EjectAll
            TB_WaitUntil "both balls are on the playfield", "TB_PenCount() = 2", 3000
        Case 4
            Scenario_drain_after_ball_end = TB_EJECT_TIMEOUT + 400
        Case 5
            TB_Eq "one ball counted in play", glf_BIP, 1
            TB_Eq "player is on ball 1", GetPlayerState(GLF_CURRENT_BALL), 1
            TB_DrainBall
            TB_DrainBall
            TB_WaitUntil "both balls are back in the trough", "TB_HomeCount() + TB_Dev(""plunger"").Count() = tnob", 6000
        Case 6
            TB_WaitUntil "next ball reaches the plunger lane", "TB_Dev(""plunger"").Count() = 1", 6000
        Case 7
            Scenario_drain_after_ball_end = 1500
        Case 8
            TB_Eq "player is on ball 2, not ball 3", GetPlayerState(GLF_CURRENT_BALL), 2
            TB_Eq "one ball counted in play", glf_BIP, 1
        Case Else
            Scenario_drain_after_ball_end = TB_DONE
    End Select
End Function
