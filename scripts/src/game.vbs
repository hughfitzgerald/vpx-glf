

'******************************************************
'*****  Player Setup                               ****
'******************************************************

' Adds a player to the game, if the game has room and it is still ball 1.
' player_add_request is a relay: any listener that returns False refuses the player
' (the credits mode does, when there are not enough credits).
Sub Glf_AddPlayer()
    Dim player_count : player_count = Glf_PlayerCount()
    If player_count >= glf_game.MaxPlayers() Then
        glf_canAddPlayers = False
        Exit Sub
    End If
    If player_count > 0 Then
        If GetPlayerState(GLF_CURRENT_BALL) <> 1 Then
            Exit Sub
        End If
        ' Turned off once play has gone back round to player 1, which can be before
        ' player 1's ball number goes up (that happens when the next turn starts).
        If glf_canAddPlayers = False Then
            Exit Sub
        End If
    End If

    If DispatchRelayPinEvent("player_add_request", True) = False Then
        glf_debugLog.WriteToLog "Game", "Request to add a player was refused"
        Exit Sub
    End If

    Dim new_number : new_number = player_count + 1
    Dim kwargs : Set kwargs = GlfKwargs()
    kwargs.Add "num", new_number
    kwargs.Add "number", new_number
    DispatchPinEvent "player_will_add", kwargs
    DispatchPinEvent "player_added", kwargs
    glf_playerState.Add "PLAYER " & new_number, Glf_InitNewPlayer()
    SetPlayerStateByPlayer GLF_SCORE, 0, player_count
    SetPlayerStateByPlayer "number", new_number, player_count
    Glf_BcpAddPlayer new_number
    If new_number = 1 Then
        glf_currentPlayer = "PLAYER 1"
    End If
    Glf_BcpSendMachineVar "last_game_players", new_number, player_count
    glf_machine_vars("last_game_players").Value = new_number
    If new_number = 2 Then
        DispatchPinEvent "multiplayer_game", Null
    End If
    If new_number >= glf_game.MaxPlayers() Then
        glf_canAddPlayers = False
    End If
End Sub

Function Glf_InitNewPlayer()
    Dim state : Set state = CreateObject("Scripting.Dictionary")
    state.Add GLF_SCORE, 0
    Glf_MonitorPlayerStateUpdate GLF_SCORE, 0
    state.Add GLF_INITIALS, ""
    Glf_MonitorPlayerStateUpdate GLF_INITIALS, ""
    state.Add GLF_CURRENT_BALL, 1
    Glf_MonitorPlayerStateUpdate GLF_CURRENT_BALL, 1
    state.Add "extra_balls", 0
    Glf_MonitorPlayerStateUpdate "extra_balls", 0
    Dim i
    Dim init_var_keys : init_var_keys = glf_initialVars.Keys()
    Dim init_var_items : init_var_items = glf_initialVars.Items()
    For i=0 To UBound(init_var_keys)
        state.Add init_var_keys(i), init_var_items(i)
        Glf_MonitorPlayerStateUpdate init_var_keys(i), init_var_items(i)
    Next
    Set Glf_InitNewPlayer = state
End Function


'****************************
' Setup Player
' Event Listeners:  
    AddPinEventListener GLF_GAME_STARTED,   "start_game_setup",   "Glf_SetupPlayer", 1000, Null
    AddPinEventListener GLF_NEXT_PLAYER,    "next_player_setup",  "Glf_SetupPlayer", 1000, Null
'
'*****************************
Function Glf_SetupPlayer(args)
    EmitAllglf_playerEvents()
End Function

'****************************
' StartGame
'
'*****************************

AddPinEventListener "request_to_start_game", "request_to_start_game_ball_controller", "Glf_BallController", 30, Null
Function Glf_BallController(args)
    Dim balls_in_trough : balls_in_trough = 0
    Dim i, switch_count
    ' An eight ball trough of the default style keeps its eighth ball in the drain
    switch_count = glf_troughSize
    If glf_troughSize = 8 And glf_troughStyle = "Default" Then
        switch_count = 7
        If Drain.BallCntOver = 1 Then balls_in_trough = balls_in_trough + 1
    End If
    For i = 1 To switch_count
        If Eval("swTrough" & i).BallCntOver = 1 Then balls_in_trough = balls_in_trough + 1
    Next

    If glf_troughSize <> balls_in_trough Then
        Glf_BallController = False
        Exit Function
    End If

    Glf_BallController = True
End Function

AddPinEventListener "request_to_start_game", "request_to_start_game_result", "Glf_StartGame", 20, Null

Function Glf_StartGame(args)
    If args(1) = True And glf_gameStarted = False Then
        Glf_AddPlayer()
        glf_gameStarted = True
        glf_canAddPlayers = True
        DispatchPinEvent GLF_GAME_START, Null
        SetDelay GLF_GAME_STARTED, "Glf_DispatchGameStarted", Null, 50
    End If
End Function

Sub Glf_EndBall()

    glf_BIP = 0
    DispatchPinEvent GLF_BALL_WILL_END, Null
    DispatchQueuePinEvent GLF_BALL_ENDING, Null
    Dim device
    For Each device in glf_flippers.Items()
        device.Disable()
    Next
    For Each device in glf_autofiredevices.Items()
        device.Disable()
    Next

End Sub

Public Function Glf_DispatchGameStarted(args)
    DispatchPinEvent GLF_GAME_STARTED, Null
    Glf_PostPlayerTurnStart 1
End Function

' player_turn_will_start, player_turn_starting (a queue event) and player_turn_started,
' as in MPF. Posted when a player's turn begins, not for an extra ball.
' ball is the ball number this turn is for. As in MPF, the player's ball number goes up
' between player_turn_starting and player_turn_started, so until then the player still
' shows the ball they last played.
Sub Glf_PostPlayerTurnStart(ball)
    Dim kwargs : Set kwargs = Glf_PlayerTurnKwargs()
    DispatchPinEvent "player_turn_will_start", kwargs
    DispatchQueuePinEvent "player_turn_starting", kwargs
    If GetPlayerState(GLF_CURRENT_BALL) < ball Then
        SetPlayerState GLF_CURRENT_BALL, ball
    End If
    DispatchPinEvent "player_turn_started", kwargs
End Sub

Function Glf_PlayerTurnKwargs()
    Dim kwargs : Set kwargs = GlfKwargs()
    kwargs.Add "number", Getglf_currentPlayerNumber() + 1
    kwargs.Add "player", Getglf_currentPlayerNumber() + 1
    Set Glf_PlayerTurnKwargs = kwargs
End Function


'******************************************************
'*****   Ball Release                              ****
'******************************************************

'****************************
' Release Ball
' Event Listeners:  
AddPinEventListener GLF_GAME_STARTED, "start_game_release_ball",   "Glf_ReleaseBall", 20, True
AddPinEventListener GLF_NEXT_PLAYER, "next_player_release_ball",   "Glf_ReleaseBall", 20, True
'
'*****************************
Function Glf_ReleaseBall(args)
    Dim kwargs
    Set kwargs = GlfKwargs()
    If Not IsNull(args) Then
        If args(0) = True Then
            ' A new ball for the current player, as against a ball added to one in play.
            ' ball_starting is a queue event: the ball is served by its last listener,
            ' Glf_BallStartingDone, so a listener that waits holds the ball back.
            Dim ball_kwargs : Set ball_kwargs = GlfKwargs()
            ball_kwargs.Add "ball", GetPlayerState(GLF_CURRENT_BALL)
            ball_kwargs.Add "player", Getglf_currentPlayerNumber() + 1
            ball_kwargs.Add "balls_remaining", glf_game.BallsPerGame() - GetPlayerState(GLF_CURRENT_BALL)
            DispatchPinEvent "ball_will_start", ball_kwargs
            DispatchQueuePinEvent "ball_starting", ball_kwargs
            Exit Function
        End If
    End If
    DispatchQueuePinEvent "balldevice_trough_ball_eject_attempt", kwargs
End Function


'****************************
' Serve the new ball once every ball_starting listener is done
' Event Listeners:
AddPinEventListener "ball_starting", "glf_ball_starting_done", "Glf_BallStartingDone", -1000, Null
'
'*****************************
Function Glf_BallStartingDone(args)
    If glf_gameStarted = True Then
        Dim kwargs : Set kwargs = GlfKwargs()
        kwargs.Add "new_ball", True
        DispatchQueuePinEvent "balldevice_trough_ball_eject_attempt", kwargs
    End If
    If IsObject(args(1)) Then
        Set Glf_BallStartingDone = args(1)
    Else
        Glf_BallStartingDone = args(1)
    End If
End Function

'****************************
' Release Ball
' Event Listeners:  
AddPinEventListener "balldevice_trough_ball_eject_attempt", "trough_eject",  "Glf_TroughReleaseBall", 20, Null
'
'*****************************
Function Glf_TroughReleaseBall(args)

    If Not IsNull(args) Then
        If IsObject(args(1)) Then
            If args(1)("new_ball") = True Then
                glf_BIP = glf_BIP + 1
                DispatchPinEvent GLF_BALL_STARTED, Null
                If Glf_PlayerCount() = 1 Then
                    DispatchPinEvent "single_player_ball_started", Null
                Else
                    DispatchPinEvent "multi_player_ball_started", Null
                    DispatchPinEvent "player_" & (Getglf_currentPlayerNumber() + 1) & "_ball_started", Null
                End If
                If useBcp Then
                    bcpController.SendPlayerVariable GLF_CURRENT_BALL, GetPlayerState(GLF_CURRENT_BALL), GetPlayerState(GLF_CURRENT_BALL)-1
                    bcpController.SendPlayerVariable GLF_SCORE, GetPlayerState(GLF_SCORE), GetPlayerState(GLF_SCORE)
                End If
            End If
        End If
    End If
    Glf_WriteDebugLog "Release Ball", "swTrough1: " & swTrough1.BallCntOver
    glf_plunger.AddIncomingBalls = 1
    swTrough1.kick 90, 10
    DispatchPinEvent "trough_eject", Null
    Glf_WriteDebugLog "Release Ball", "Just Kicked"
    If Not IsNull(args) Then
		If IsObject(args(1)) Then
			Set Glf_TroughReleaseBall = args(1)
		Else
			Glf_TroughReleaseBall = args(1)
		End If
	Else
		Glf_TroughReleaseBall = Null
	End If
End Function

'****************************
' Ball Drain
' Event Listeners:      
    AddPinEventListener GLF_BALL_DRAIN, "ball_drain", "Glf_Drain", 20, Null
'
'*****************************
Function Glf_Drain(args)
    
    If Not glf_gameTilted And glf_gameStarted = True Then
        Dim ballsToSave : ballsToSave = args(1) 
        Glf_WriteDebugLog "end_of_ball, unclaimed balls", CStr(ballsToSave)
        Glf_WriteDebugLog "end_of_ball, balls in play", CStr(glf_BIP)
        If ballsToSave <= 0 Then
            Exit Function
        End If

        If glf_BIP <= 0 Then
            'The last ball in play has already drained and the ball is ending.
            'A ball that reaches the drain after that must not end the ball a second time.
            glf_debugLog.WriteToLog "Trough", "Ball drained with no balls in play, ignored"
            Exit Function
        End If

        glf_BIP = glf_BIP - 1
        glf_debugLog.WriteToLog "Trough", "Ball Drained: BIP: " & glf_BIP

        If glf_BIP > 0 Then
            Exit Function
        End If
        
        DispatchPinEvent GLF_BALL_WILL_END, Null
        DispatchQueuePinEvent GLF_BALL_ENDING, Null
    End If
    
End Function

'****************************
' End Of Ball
' Event Listeners:      
AddPinEventListener GLF_BALL_ENDING, "ball_will_end", "Glf_BallWillEnd", 10, Null
'
'*****************************
Function Glf_BallWillEnd(args)
    DispatchPinEvent GLF_BALL_ENDED, Null
    If Not IsNull(args) Then
		If IsObject(args(1)) Then
			Set Glf_BallWillEnd = args(1)
		Else
			Glf_BallWillEnd = args(1)
		End If
	Else
		Glf_BallWillEnd = Null
	End If
End Function

'****************************
' End Of Ball
' Event Listeners:      
AddPinEventListener GLF_BALL_ENDED, "end_of_ball", "Glf_EndOfBall", 20, Null
'
'*****************************
Function Glf_EndOfBall(args)

    If GetPlayerState("extra_balls") > 0 Then
        'self.debug_log("Awarded extra ball to Player %s. Shoot Again", self.player.index + 1)
        'self.player.extra_balls -= 1
        SetPlayerState "extra_balls", GetPlayerState("extra_balls") - 1
        SetDelay "end_of_ball_delay", "EndOfBallNextPlayer", Null, 1000
        Exit Function
    End If

    ' The turn is over. The player only changes once these events have been handled,
    ' so their listeners still see the player whose turn it was.
    Dim kwargs : Set kwargs = Glf_PlayerTurnKwargs()
    DispatchPinEvent "player_turn_will_end", kwargs
    DispatchQueuePinEvent "player_turn_ending", kwargs
    DispatchPinEvent "player_turn_ended", kwargs
    DispatchPinEvent "glf_player_turn_complete", Null

End Function

'****************************
' Next Player
' Event Listeners:
AddPinEventListener "glf_player_turn_complete", "glf_rotate_players", "Glf_RotatePlayers", 20, Null
'
'*****************************
Function Glf_RotatePlayers(args)
    If glf_gameStarted = False Or IsNull(glf_currentPlayer) Then
        Exit Function
    End If
    ' As in MPF: the game is over when the last player has played the last ball.
    ' The ball number still holds the ball that just finished.
    Dim this_player : this_player = Getglf_currentPlayerNumber()
    Dim this_ball : this_ball = GetPlayerState(GLF_CURRENT_BALL)
    If this_player + 1 >= Glf_PlayerCount() And this_ball >= glf_game.BallsPerGame() Then
        Dim device
        For Each device in glf_ball_devices.Items()
            If device.HasBall() Then
                device.EjectAll()
            End If
        Next
        DispatchPinEvent "game_will_end", Null
        DispatchQueuePinEvent "game_ending", Null
        Exit Function
    End If

    ' The next player plays the same ball, or the next ball once play goes back round
    ' to player 1. The ball number changes when that turn starts, not now.
    Dim next_player : next_player = this_player + 1
    Dim next_ball : next_ball = this_ball
    If next_player >= Glf_PlayerCount() Then
        next_player = 0
        next_ball = this_ball + 1
        ' Ball 1 is over for everyone, so no more players can join.
        glf_canAddPlayers = False
    End If
    glf_currentPlayer = Getglf_PlayerName(next_player)
    SetDelay "end_of_ball_delay", "Glf_StartPlayerTurn", next_ball, 1000
End Function

' The next player's turn: the turn events, then the ball. args is the ball number.
Public Function Glf_StartPlayerTurn(args)
    If glf_gameStarted = False Or IsNull(glf_currentPlayer) Then
        Exit Function
    End If
    Glf_PostPlayerTurnStart args
    DispatchPinEvent GLF_NEXT_PLAYER, Null
End Function

'****************************
' Game Over
' Event Listeners:      
AddPinEventListener "game_ending", "glf_game_over", "Glf_EndGame", 20, Null
'
'*****************************
Function Glf_EndGame(args)
    If GetPlayerStateForPlayer("0", "score") = False Then
        glf_machine_vars("player1_score").Value = 0
    Else
        glf_machine_vars("player1_score").Value = GetPlayerStateForPlayer("0", "score")
    End If
    If GetPlayerStateForPlayer("1", "score") = False Then
        glf_machine_vars("player2_score").Value = 0
    Else
        glf_machine_vars("player2_score").Value = GetPlayerStateForPlayer("1", "score")
    End If
    If GetPlayerStateForPlayer("2", "score") = False Then
        glf_machine_vars("player3_score").Value = 0
    Else
        glf_machine_vars("player3_score").Value = GetPlayerStateForPlayer("2", "score")
    End If
    If GetPlayerStateForPlayer("3", "score") = False Then
        glf_machine_vars("player4_score").Value = 0
    Else
        glf_machine_vars("player4_score").Value = GetPlayerStateForPlayer("3", "score")
    End If

    Glf_BcpSendMachineVar "player1_score", glf_machine_vars("player1_score").Value, 0
    Glf_BcpSendMachineVar "player2_score", glf_machine_vars("player2_score").Value, 0
    Glf_BcpSendMachineVar "player3_score", glf_machine_vars("player3_score").Value, 0
    Glf_BcpSendMachineVar "player4_score", glf_machine_vars("player4_score").Value, 0

    glf_gameStarted = False
    glf_currentPlayer = Null
    glf_playerState.RemoveAll()

    DispatchPinEvent "game_ended", Null
    If Not IsNull(args) Then
		If IsObject(args(1)) Then
			Set Glf_EndGame = args(1)
		Else
			Glf_EndGame = args(1)
		End If
	Else
		Glf_EndGame = Null
	End If
End Function

AddPinEventListener "glf_game_cancel", "glf_game_cancel", "Glf_GameCancel", 20, Null

Function Glf_GameCancel(args)
    Dim device
    For Each device in glf_ball_devices.Items()
        If device.HasBall() Then
            device.EjectAll()
        End If
    Next
    Dim mode
    For Each mode in glf_modes.Items()
        mode.StopMode()
    Next
    Dim flipper
    For Each flipper in glf_flippers.Items()
        flipper.Disable()
    Next
    Dim auto_fire_device
    For Each auto_fire_device in glf_autofiredevices.Items()
        auto_fire_device.Disable()
    Next
    glf_bip = 0
    Glf_EndGame Null
    Glf_Reset(Null)
End Function

Public Function EndOfBallNextPlayer(args)
    DispatchPinEvent GLF_NEXT_PLAYER, Null
End Function
