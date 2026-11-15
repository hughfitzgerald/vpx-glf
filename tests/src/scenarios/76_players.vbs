'Players are added up to the maximum, a listener can refuse one, and turns pass from
'player to player with the turn events posted around them.
'Covers feat/game-players.
TB_Scenario "players"

Function Scenario_players(stage)
    Scenario_players = 0
    If stage = 0 Then
        If Not TB_Require("game_players") Then
            Scenario_players = TB_DONE
            Exit Function
        End If
        TB_Watch "player_added"
        TB_Watch "multiplayer_game"
        TB_Watch "player_turn_started"
        TB_Watch "player_turn_ended"
        TB_Watch "ball_starting"
    End If
    If stage < TB_PRELUDE_STEPS Then
        Scenario_players = TB_OneBallInPlay(stage)
        Exit Function
    End If
    Select Case stage - TB_PRELUDE_STEPS
        Case 0
            TB_Eq "one player", Glf_PlayerCount(), 1
            TB_Eq "first turn started for player 1", TB_Kwarg("player_turn_started", "number"), 1
            TB_Eq "ball_starting posted for the first ball", TB_Seen("ball_starting"), 1
            'A listener on player_add_request can refuse a player
            AddPinEventListener "player_add_request", "tb_refuse_player", "TB_Refuse", 100, Null
            Glf_AddPlayer
            Scenario_players = 300
        Case 1
            TB_Eq "refused player is not added", Glf_PlayerCount(), 1
            RemovePinEventListener "player_add_request", "tb_refuse_player"
            Glf_AddPlayer
            Scenario_players = 300
        Case 2
            TB_Eq "second player added", Glf_PlayerCount(), 2
            TB_Eq "multiplayer_game posted", TB_Seen("multiplayer_game"), 1
            Glf_AddPlayer
            Scenario_players = 300
        Case 3
            TB_Eq "third player added", Glf_PlayerCount(), 3
            Glf_AddPlayer
            Scenario_players = 300
        Case 4
            TB_Eq "fourth player refused: the maximum is three", Glf_PlayerCount(), 3
            TB_Eq "player_added posted three times", TB_Seen("player_added"), 3
            TB_Eq "still player 1's turn", Getglf_currentPlayerNumber(), 0
            TB_DrainBall
            TB_WaitUntil "player 2's ball reaches the plunger lane", "Getglf_currentPlayerNumber() = 1 And TB_Dev(""plunger"").Count() = 1", 10000
        Case 5
            TB_Eq "turn ended for player 1", TB_Kwarg("player_turn_ended", "number"), 1
            TB_Eq "turn started for player 2", TB_Kwarg("player_turn_started", "number"), 2
            TB_Eq "player 2 is on ball 1", GetPlayerState(GLF_CURRENT_BALL), 1
            TB_Plunge
            TB_WaitUntil "ball is in play", "TB_PenCount() = 1", 5000
        Case 6
            TB_DrainBall
            TB_WaitUntil "player 3's ball reaches the plunger lane", "Getglf_currentPlayerNumber() = 2 And TB_Dev(""plunger"").Count() = 1", 10000
        Case 7
            TB_Plunge
            TB_WaitUntil "ball is in play", "TB_PenCount() = 1", 5000
        Case 8
            TB_DrainBall
            TB_WaitUntil "back to player 1", "Getglf_currentPlayerNumber() = 0 And TB_Dev(""plunger"").Count() = 1", 10000
        Case 9
            TB_Eq "player 1 is on ball 2", GetPlayerState(GLF_CURRENT_BALL), 2
            TB_Eq "three turns ended", TB_Seen("player_turn_ended"), 3
            TB_Eq "four turns started", TB_Seen("player_turn_started"), 4
            'Nobody can join after ball 1
            Glf_AddPlayer
            Scenario_players = 300
        Case 10
            TB_Eq "no player added after ball 1", Glf_PlayerCount(), 3
            TB_CheckCounts "player 1 ball 2", 1
        Case Else
            Scenario_players = TB_DONE
    End Select
End Function
