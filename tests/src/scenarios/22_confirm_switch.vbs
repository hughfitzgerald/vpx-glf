'An eject target switch confirms an eject only while that eject is in progress, and only once.
'Covers fix/ball-device-confirm-switch: before it, every ball that closed chain_b's switch
'made chain_a report a successful eject, and a real eject was confirmed twice.
TB_Scenario "confirm_switch"

Function Scenario_confirm_switch(stage)
    Scenario_confirm_switch = 0
    If stage < TB_PRELUDE_STEPS Then
        Scenario_confirm_switch = TB_OneBallInPlay(stage)
        Exit Function
    End If
    Select Case stage - TB_PRELUDE_STEPS
        Case 0
            'A ball arrives in chain_b from the playfield. chain_a is empty and has ejected nothing.
            TB_Watch "balldevice_chain_a_ball_eject_success"
            TB_Shoot "chain_b"
            TB_WaitUntil "GLF counts the ball in chain_b", "glf_ball_devices(""chain_b"").Balls = 1", 3000
        Case 1
            Scenario_confirm_switch = TB_EJECT_TIMEOUT + 400
        Case 2
            TB_Eq "chain_a reported no eject", TB_Seen("balldevice_chain_a_ball_eject_success"), 0
            TB_Post "tb_eject_chain_b"
            TB_WaitUntil "ball is back in play", "TB_PenCount() = 1", 3000
        Case 3
            Scenario_confirm_switch = TB_EJECT_TIMEOUT + 400
        Case 4
            'Now a real eject from chain_a into chain_b
            TB_Route "chain_a", "@chain_b"
            TB_Shoot "chain_a"
            TB_WaitUntil "GLF counts the ball in chain_a", "glf_ball_devices(""chain_a"").Balls = 1", 3000
        Case 5
            TB_Post "tb_eject_chain_a"
            TB_WaitUntil "ball arrives in chain_b", "glf_ball_devices(""chain_b"").Balls = 1", 4000
        Case 6
            Scenario_confirm_switch = TB_EJECT_TIMEOUT + 400
        Case 7
            TB_Eq "chain_a reported one eject", TB_Seen("balldevice_chain_a_ball_eject_success"), 1
            TB_Eq "chain_a ejected once", TB_Dev("chain_a").EjectCount, 1
            TB_CheckCounts "ball waiting in chain_b", 1
        Case Else
            Scenario_confirm_switch = TB_DONE
    End Select
End Function
