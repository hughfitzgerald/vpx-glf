'The ball number goes up when the next turn starts, as in MPF, and a 3-ball game ends
'after ball 3 without the ball number ever reaching 4.
'Covers fix/ball-number-at-turn-start: before it, GLF added 1 to the ball as soon as the
'ball ended, so the turn-end events and the pause before the next ball saw the next
'ball, and the game ended by checking for ball 4.
TB_Scenario "ball_number"

Dim tb_ball_at_turn_end, tb_ball_at_game_end, tb_ball_highest

Function TB_BallAtTurnEnd(args)
    tb_ball_at_turn_end = GetPlayerState(GLF_CURRENT_BALL)
    If IsObject(args(1)) Then
        Set TB_BallAtTurnEnd = args(1)
    Else
        TB_BallAtTurnEnd = args(1)
    End If
End Function

Function TB_BallAtGameEnd(args)
    tb_ball_at_game_end = GetPlayerState(GLF_CURRENT_BALL)
    If IsObject(args(1)) Then
        Set TB_BallAtGameEnd = args(1)
    Else
        TB_BallAtGameEnd = args(1)
    End If
End Function

Function TB_BallHighest(args)
    If GetPlayerState(GLF_CURRENT_BALL) > tb_ball_highest Then
        tb_ball_highest = GetPlayerState(GLF_CURRENT_BALL)
    End If
    If IsObject(args(1)) Then
        Set TB_BallHighest = args(1)
    Else
        TB_BallHighest = args(1)
    End If
End Function

'Drains the ball and waits for the turn to end
Function TB_BallNumberDrain(turns)
    TB_BallNumberDrain = 0
    TB_DrainBall
    TB_WaitUntil "turn ends", "TB_Seen(""player_turn_ended"") = " & turns, 10000
End Function

Function Scenario_ball_number(stage)
    Scenario_ball_number = 0
    If stage = 0 Then
        If Not TB_Require("game_players") Then
            Scenario_ball_number = TB_DONE
            Exit Function
        End If
        tb_ball_at_turn_end = Empty
        tb_ball_at_game_end = Empty
        tb_ball_highest = 0
        TB_Watch "player_turn_ended"
        TB_Watch "player_turn_started"
        TB_Watch "ball_starting"
        AddPinEventListener "player_turn_ended", "tb_ball_at_turn_end", "TB_BallAtTurnEnd", 100, Null
        AddPinEventListener "game_will_end", "tb_ball_at_game_end", "TB_BallAtGameEnd", 100, Null
        AddPinEventListener "player_turn_ended", "tb_ball_highest_te", "TB_BallHighest", 100, Null
        AddPinEventListener "ball_started", "tb_ball_highest_bs", "TB_BallHighest", 100, Null
        AddPinEventListener "game_will_end", "tb_ball_highest_ge", "TB_BallHighest", 100, Null
    End If
    If stage < TB_PRELUDE_STEPS Then
        Scenario_ball_number = TB_OneBallInPlay(stage)
        Exit Function
    End If
    Select Case stage - TB_PRELUDE_STEPS
        Case 0
            TB_Eq "player is on ball 1", GetPlayerState(GLF_CURRENT_BALL), 1
            TB_Eq "ball_starting said ball 1", TB_Kwarg("ball_starting", "ball"), 1
            Scenario_ball_number = TB_BallNumberDrain(1)
        Case 1
            'Inside the 1s pause before the next ball
            Scenario_ball_number = 300
        Case 2
            TB_Eq "player_turn_ended saw the ball that finished", tb_ball_at_turn_end, 1
            TB_Eq "the pause still shows ball 1", GetPlayerState(GLF_CURRENT_BALL), 1
            TB_Eq "next turn has not started yet", TB_Seen("player_turn_started"), 1
            'Play has gone back round to player 1, so nobody can join any more
            Glf_AddPlayer
            Scenario_ball_number = 100
        Case 3
            TB_Eq "no player joins in the pause after ball 1", Glf_PlayerCount(), 1
            TB_WaitUntil "ball 2 reaches the plunger lane", "TB_Dev(""plunger"").Count() = 1", 10000
        Case 4
            TB_Eq "player is on ball 2 once the turn starts", GetPlayerState(GLF_CURRENT_BALL), 2
            TB_Eq "ball_starting said ball 2", TB_Kwarg("ball_starting", "ball"), 2
            TB_Eq "ball_starting said one ball remaining", TB_Kwarg("ball_starting", "balls_remaining"), 1
            TB_Plunge
            TB_WaitUntil "ball 2 is in play", "TB_PenCount() = 1", 5000
        Case 5
            Scenario_ball_number = TB_EJECT_TIMEOUT + 400
        Case 6
            Scenario_ball_number = TB_BallNumberDrain(2)
        Case 7
            TB_WaitUntil "ball 3 reaches the plunger lane", "TB_Dev(""plunger"").Count() = 1", 10000
        Case 8
            TB_Eq "player is on ball 3", GetPlayerState(GLF_CURRENT_BALL), 3
            TB_Plunge
            TB_WaitUntil "ball 3 is in play", "TB_PenCount() = 1", 5000
        Case 9
            Scenario_ball_number = TB_EJECT_TIMEOUT + 400
        Case 10
            TB_DrainBall
            TB_WaitUntil "game ends after ball 3", "glf_gameStarted = False", 15000
        Case 11
            TB_Eq "player_turn_ended saw ball 3", tb_ball_at_turn_end, 3
            TB_Eq "game_will_end saw ball 3", tb_ball_at_game_end, 3
            TB_Eq "the ball number never reached 4", tb_ball_highest, 3
            TB_Eq "three turns ended", TB_Seen("player_turn_ended"), 3
            TB_Eq "three turns started", TB_Seen("player_turn_started"), 3
            RemovePinEventListener "player_turn_ended", "tb_ball_at_turn_end"
            RemovePinEventListener "game_will_end", "tb_ball_at_game_end"
            RemovePinEventListener "player_turn_ended", "tb_ball_highest_te"
            RemovePinEventListener "ball_started", "tb_ball_highest_bs"
            RemovePinEventListener "game_will_end", "tb_ball_highest_ge"
        Case Else
            Scenario_ball_number = TB_DONE
    End Select
End Function
