'A held ball released by a tilt is seen leaving its device.
'Covers fix/ball-device-tilt: before it, the device missed the ball leaving and went on
'counting it, so it reported a ball it did not have for the rest of the game.
TB_Scenario "tilt_releases_held_ball"

Function Scenario_tilt_releases_held_ball(stage)
    Scenario_tilt_releases_held_ball = 0
    If stage < TB_PRELUDE_STEPS Then
        Scenario_tilt_releases_held_ball = TB_OneBallInPlay(stage)
        Exit Function
    End If
    Select Case stage - TB_PRELUDE_STEPS
        Case 0
            TB_Post "tb_start_hold"
            Scenario_tilt_releases_held_ball = 300
        Case 1
            TB_Shoot "scoop"
            TB_WaitUntil "hold takes the ball", "glf_ball_holds(""scoop_hold"").GetValue(""balls_held"") = 1", 3000
        Case 2
            TB_Route "scoop", "drain"
            TB_Post "s_tilt_warning_active"
            TB_WaitUntil "tilt releases the ball and it drains", "TB_Dev(""scoop"").Count() = 0 And TB_HomeCount() = tnob", 6000
        Case 3
            TB_WaitUntil "tilt clears and the next ball is served", "glf_gameTilted = False And TB_Dev(""plunger"").Count() = 1", 8000
        Case 4
            Scenario_tilt_releases_held_ball = 1000
        Case 5
            TB_Eq "GLF counts no ball in the scoop", glf_ball_devices("scoop").Balls, 0
            TB_Eq "scoop is not reported as having a ball", glf_ball_devices("scoop").HasBall(), False
            TB_CheckCounts "next ball", 1
        Case Else
            Scenario_tilt_releases_held_ball = TB_DONE
    End Select
End Function
