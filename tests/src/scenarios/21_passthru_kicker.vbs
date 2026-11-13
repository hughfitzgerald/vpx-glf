'A kicker that ejects from its own switch-active event passes the ball straight through.
'The eject request arrives before the ball has been counted in, so the device has to
'wait for it. Guards the eject-empty fix against breaking this common setup.
TB_Scenario "passthru_kicker"

Function Scenario_passthru_kicker(stage)
    Scenario_passthru_kicker = 0
    If stage < TB_PRELUDE_STEPS Then
        Scenario_passthru_kicker = TB_OneBallInPlay(stage)
        Exit Function
    End If
    Select Case stage - TB_PRELUDE_STEPS
        Case 0
            TB_Shoot "passthru"
            TB_WaitUntil "ball is kicked back into play", "TB_Dev(""passthru"").EjectCount = 1 And TB_PenCount() = 1", 4000
        Case 1
            Scenario_passthru_kicker = TB_EJECT_TIMEOUT + 400
        Case 2
            TB_Eq "kicker ejected exactly once", TB_Dev("passthru").EjectCount, 1
            TB_CheckCounts "after the first pass", 1
            'And again, to check nothing was left over from the first ball
            TB_Shoot "passthru"
            TB_WaitUntil "ball is kicked back into play again", "TB_Dev(""passthru"").EjectCount = 2 And TB_PenCount() = 1", 4000
        Case 3
            Scenario_passthru_kicker = TB_EJECT_TIMEOUT + 400
        Case 4
            TB_Eq "kicker ejected exactly twice", TB_Dev("passthru").EjectCount, 2
            TB_CheckCounts "after the second pass", 1
        Case Else
            Scenario_passthru_kicker = TB_DONE
    End Select
End Function
