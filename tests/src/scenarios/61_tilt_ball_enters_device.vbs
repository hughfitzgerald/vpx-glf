'A ball that rolls into a device after a tilt is kicked back out, so the tilt can finish.
'Covers fix/ball-device-tilt: before it, GLF posted no switch events while tilted, so the
'device never knew the ball was there, nothing ejected it and the game waited for ever.
TB_Scenario "tilt_ball_enters_device"

Function Scenario_tilt_ball_enters_device(stage)
    Scenario_tilt_ball_enters_device = 0
    If stage < TB_PRELUDE_STEPS Then
        Scenario_tilt_ball_enters_device = TB_OneBallInPlay(stage)
        Exit Function
    End If
    Select Case stage - TB_PRELUDE_STEPS
        Case 0
            'A hold that stays enabled through the tilt, like one in an always-on mode
            TB_Post "tb_start_hold"
            Scenario_tilt_ball_enters_device = 300
        Case 1
            TB_Post "s_tilt_warning_active"
            TB_WaitUntil "game is tilted", "glf_gameTilted = True", 2000
        Case 2
            TB_Route "scoop", "drain"
            TB_Shoot "scoop"
            TB_WaitUntil "scoop kicks the ball out and it drains", "TB_Dev(""scoop"").Count() = 0 And TB_HomeCount() = tnob", 6000
        Case 3
            TB_WaitUntil "tilt clears and the next ball is served", "glf_gameTilted = False And TB_Dev(""plunger"").Count() = 1", 8000
        Case 4
            Scenario_tilt_ball_enters_device = 1000
        Case 5
            TB_Eq "hold did not keep the ball", glf_ball_holds("scoop_hold").GetValue("balls_held"), 0
            TB_Eq "player is on ball 2", GetPlayerState(GLF_CURRENT_BALL), 2
            TB_CheckCounts "next ball", 1
        Case Else
            Scenario_tilt_ball_enters_device = TB_DONE
    End Select
End Function
