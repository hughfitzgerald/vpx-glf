'A game starts, serves a ball, the ball drains and the next ball is served.
'This is the test that the test bed itself works.
TB_Scenario "smoke_game"

Function Scenario_smoke_game(stage)
    Scenario_smoke_game = 0
    Select Case stage
        Case 0
            TB_Eq "trough is full before the game", TB_TroughCount(), tnob
            TB_Eq "no game running", glf_gameStarted, False
            TB_StartGame
            TB_WaitUntil "first ball reaches the plunger lane", "TB_Dev(""plunger"").Count = 1", 5000
        Case 1
            Scenario_smoke_game = 400
        Case 2
            TB_Eq "game started", glf_gameStarted, True
            TB_CheckCounts "ball in plunger lane", 1
            TB_Plunge
            TB_WaitUntil "ball is in play", "TB_PenCount() = 1", 3000
        Case 3
            Scenario_smoke_game = TB_EJECT_TIMEOUT + 400
        Case 4
            TB_CheckCounts "ball in play", 1
            TB_DrainBall
            TB_WaitUntil "next ball is served", "TB_Dev(""plunger"").Count = 1", 8000
        Case 5
            Scenario_smoke_game = 400
        Case 6
            TB_CheckCounts "second ball in plunger lane", 1
            TB_Eq "player is on ball 2", GetPlayerState("ball"), 2
            TB_Eq "four balls left in the trough", TB_TroughCount(), tnob - 1
        Case Else
            Scenario_smoke_game = TB_DONE
    End Select
End Function
