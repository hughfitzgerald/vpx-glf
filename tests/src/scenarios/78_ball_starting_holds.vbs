'ball_starting is a queue event: a mode that starts on it with UseWaitQueue holds the
'ball back until the mode stops.
'Covers feat/game-players.
TB_Scenario "ball_starting_holds"

Function Scenario_ball_starting_holds(stage)
    Scenario_ball_starting_holds = 0
    If stage = 0 Then
        If Not TB_Require("game_players") Then
            Scenario_ball_starting_holds = TB_DONE
            Exit Function
        End If
    End If
    If stage < TB_PRELUDE_STEPS Then
        Scenario_ball_starting_holds = TB_OneBallInPlay(stage)
        Exit Function
    End If
    Select Case stage - TB_PRELUDE_STEPS
        Case 0
            SetPlayerState "tb_intro", 1
            TB_DrainBall
            TB_WaitUntil "the intro mode starts on ball_starting", "glf_modes(""tb_ball_intro"").GetValue(""active"") = True", 8000
        Case 1
            Scenario_ball_starting_holds = 1500
        Case 2
            TB_Eq "no ball served while the mode runs", TB_Dev("plunger").Count(), 0
            TB_Eq "trough still full", TB_HomeCount(), tnob
            TB_Post "tb_intro_done"
            TB_WaitUntil "ball is served once the mode stops", "TB_Dev(""plunger"").Count() = 1", 4000
        Case 3
            'Let GLF count the ball into the plunger lane
            Scenario_ball_starting_holds = 800
        Case 4
            SetPlayerState "tb_intro", 0
            TB_Eq "player is on ball 2", GetPlayerState(GLF_CURRENT_BALL), 2
            TB_CheckCounts "ball 2", 1
        Case Else
            Scenario_ball_starting_holds = TB_DONE
    End Select
End Function
