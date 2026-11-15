' The game settings. A table sets them in its device configuration, before Glf_Init,
' so the settings object is created once and kept.
Function GlfGameSettings()
    If Not IsObject(glf_game) Then
        Set glf_game = (new GlfGame)()
    End If
	Set GlfGameSettings = glf_game
End Function

Class GlfGame

    Private m_balls_per_game
    Private m_max_players

    Public Property Get BallsPerGame()
        BallsPerGame = m_balls_per_game.Value()
    End Property
    Public Property Let BallsPerGame(input)
        Set m_balls_per_game = CreateGlfInput(input)
    End Property

    ' The most players one game can have. MPF's default is 4.
    Public Property Get MaxPlayers()
        MaxPlayers = m_max_players.Value()
    End Property
    Public Property Let MaxPlayers(input)
        Set m_max_players = CreateGlfInput(input)
    End Property

	Public default Function init()

        Set m_balls_per_game = CreateGlfInput(3)
        Set m_max_players = CreateGlfInput(4)
       
        Set Init = Me
	End Function

    Public Function ToYaml()
        Dim yaml : yaml = ""
        yaml = yaml & "game:" & vbCrLf
        yaml = yaml & "  balls_per_game: " & m_balls_per_game.Raw & vbCrLf
        yaml = yaml & "  max_players: " & m_max_players.Raw & vbCrLf
        ToYaml = yaml
    End Function

End Class