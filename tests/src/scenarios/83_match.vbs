'At the end of a game the match mode compares the last two digits of the score with a
'drawn number and posts the result. The result is a queue event: a listener that waits
'holds the end of the game until it is done.
'Covers feat/match.
TB_Scenario "match"

'A listener that makes the match result wait for tb_match_go, like a show that blocks the queue
Function TB_MatchWait(args)
    args(1).Add "wait_for", "tb_match_go"
    Set TB_MatchWait = args(1)
End Function

'Plays one ball of a one player game to its end. Returns the wait for the stage.
Function TB_MatchPlayBall(last_ball)
    TB_MatchPlayBall = 0
    TB_DrainBall
    If last_ball Then
        TB_WaitUntil "game ends", "glf_gameStarted = False", 15000
    Else
        TB_WaitUntil "next ball reaches the plunger lane", "TB_Dev(""plunger"").Count() = 1", 10000
    End If
End Function

Function Scenario_match(stage)
    Scenario_match = 0
    If stage = 0 Then
        If Not TB_Require("match") Then
            Scenario_match = TB_DONE
            Exit Function
        End If
        TB_Watch "match_has_match"
        TB_Watch "match_no_match"
    End If
    If stage < TB_PRELUDE_STEPS Then
        Scenario_match = TB_OneBallInPlay(stage)
        Exit Function
    End If
    Select Case stage - TB_PRELUDE_STEPS
        Case 0
            Scenario_match = TB_MatchPlayBall(False)
        Case 1
            TB_Plunge
            TB_WaitUntil "ball 2 is in play", "TB_PenCount() = 1", 5000
        Case 2
            Scenario_match = TB_MatchPlayBall(False)
        Case 3
            TB_Plunge
            TB_WaitUntil "ball 3 is in play", "TB_PenCount() = 1", 5000
        Case 4
            SetPlayerState GLF_SCORE, 123440
            'A roll of 0 is always inside the match percentage
            glf_match.ForceRoll = 0
            Scenario_match = TB_MatchPlayBall(True)
        Case 5
            Scenario_match = 500
        Case 6
            TB_Eq "match posted", TB_Seen("match_has_match"), 1
            TB_Eq "no no-match", TB_Seen("match_no_match"), 0
            TB_Eq "player's number is the last two digits of the score", TB_Kwarg("match_has_match", "match_number0"), 40
            TB_Eq "winning number is the player's", TB_Kwarg("match_has_match", "winner_number"), 40
            TB_Eq "one winner", TB_Kwarg("match_has_match", "winners"), 1
            TB_Eq "player 1 won", TB_Kwarg("match_has_match", "match_number0_won"), True
            TB_Eq "machine variable holds the winning number", glf_machine_vars("match_number").Value, 40
            'Second game: a roll of 99 never matches
            TB_StartGame
            TB_WaitUntil "second game: first ball reaches the plunger lane", "TB_Dev(""plunger"").Count = 1", 8000
        Case 7
            TB_Plunge
            TB_WaitUntil "ball 1 is in play", "TB_PenCount() = 1", 5000
        Case 8
            Scenario_match = TB_MatchPlayBall(False)
        Case 9
            TB_Plunge
            TB_WaitUntil "ball 2 is in play", "TB_PenCount() = 1", 5000
        Case 10
            Scenario_match = TB_MatchPlayBall(False)
        Case 11
            TB_Plunge
            TB_WaitUntil "ball 3 is in play", "TB_PenCount() = 1", 5000
        Case 12
            SetPlayerState GLF_SCORE, 5570
            glf_match.ForceRoll = 99
            AddPinEventListener "match_no_match", "tb_match_wait", "TB_MatchWait", 500, Null
            TB_DrainBall
            TB_WaitUntil "match mode starts", "glf_modes(""match"").GetValue(""active"") = True", 15000
        Case 13
            'Far longer than the display time
            Scenario_match = 2000
        Case 14
            TB_Eq "match mode stays up while a listener waits", glf_modes("match").GetValue("active"), True
            TB_Eq "the game has not ended yet", glf_gameStarted, True
            TB_Post "tb_match_go"
            TB_WaitUntil "game ends once the listener is done", "glf_gameStarted = False", 5000
        Case 15
            RemovePinEventListener "match_no_match", "tb_match_wait"
            Scenario_match = 300
        Case 16
            TB_Eq "no match posted", TB_Seen("match_no_match"), 1
            TB_Eq "still only one match", TB_Seen("match_has_match"), 1
            TB_Eq "no winners", TB_Kwarg("match_no_match", "winners"), 0
            TB_True "winning number is not the player's", TB_Kwarg("match_no_match", "winner_number") <> 70
            TB_Eq "winning number is a multiple of ten", TB_Kwarg("match_no_match", "winner_number") Mod 10, 0
        Case Else
            Scenario_match = TB_DONE
    End Select
End Function
