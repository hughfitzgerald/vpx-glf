' Attract mode, after MPF's built-in attract mode.
'
' EnableGlfAttract creates a mode called "attract" that runs whenever no game is in
' progress: it starts on reset_complete and game_ended and stops on game_start.
' It is an ordinary mode, so shows, sounds and slides are added to it in the usual
' way, and like MPF's it can be a carousel, to step through attract screens.
'
' GLF's start button already posts request_to_start_game by itself, so unlike MPF's
' attract mode this one has no part in starting a game.

Dim glf_attract : glf_attract = Null

Function EnableGlfAttract()
    If IsNull(glf_attract) Then
        Set glf_attract = CreateGlfMode("attract", 10)
        ' The conditions keep the mode from being started a second time while it runs,
        ' which happens after a cancelled game: game_ended is followed by reset_complete.
        glf_attract.StartEvents = Array("reset_complete{modes.attract.active==False}", "game_ended{modes.attract.active==False}")
        glf_attract.StopEvents = Array("game_start", "service_mode_entered")
        glf_attract.GameMode = False
    End If
    Set EnableGlfAttract = glf_attract
End Function
