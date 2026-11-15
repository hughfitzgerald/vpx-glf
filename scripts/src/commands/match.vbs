' Match: the end-of-game number match, after MPF's built-in match mode.
'
' EnableGlfMatch creates a mode called "match" that starts on game_ending and holds
' the end of the game. Each player's match number is the last two digits of their
' score. The mode draws a winning number, posts match_has_match or match_no_match
' with every player's number, and ends after the display time.
'
' Awarding something for a match is left to the table: the credits mode can give a
' credit on match_has_match.

Dim glf_match : glf_match = Null

Function EnableGlfMatch()
    If Not IsNull(glf_match) Then
        Set EnableGlfMatch = glf_match
        Exit Function
    End If
    Dim match_mode : Set match_mode = CreateGlfMode("match", 1000)
    match_mode.StartEvents = Array("game_ending")
    match_mode.GameMode = False
    match_mode.UseWaitQueue = True
    Set glf_match = (new GlfMatch)(match_mode)
    match_mode.AddModeSettings "match", glf_match
    Set EnableGlfMatch = glf_match
End Function

Class GlfMatch

    Private m_name
    Private m_priority
    Private m_base_device
    Private m_debug

    Private m_match_percentage
    Private m_non_match_number_step
    Private m_display_time_ms
    Private m_end_match_event

    Private m_running
    Private m_winner_number
    Private m_winners
    Private m_forced_roll

    Public Property Get Name() : Name = m_name : End Property
    Public Property Get Mode() : Set Mode = m_base_device.Mode : End Property
    Public Property Get WinnerNumber() : WinnerNumber = m_winner_number : End Property
    Public Property Get Winners() : Winners = m_winners : End Property

    ' Chance, in percent, that the winning number is one of the players' numbers
    Public Property Let MatchPercentage(value) : m_match_percentage = value : End Property
    ' Losing numbers are drawn from 0, step, 2 x step ... Scores usually end in 0, so the default is 10
    Public Property Let NonMatchNumberStep(value) : m_non_match_number_step = value : End Property
    Public Property Let DisplayTimeMs(value) : m_display_time_ms = value : End Property
    Public Property Let EndMatchEvent(value)
        If IsEmpty(value) Or IsNull(value) Then
            m_end_match_event = Null
        Else
            Set m_end_match_event = (new GlfEvent)(value)
        End If
    End Property
    ' For tests: a number from 0 to 99 used in place of the random roll for the next match
    Public Property Let ForceRoll(value) : m_forced_roll = value : End Property

    Public Property Let Debug(value)
        m_debug = value
        m_base_device.Debug = value
    End Property
    Public Property Get IsDebug()
        If m_debug Then : IsDebug = 1 : Else : IsDebug = 0 : End If
    End Property

	Public default Function init(mode)
        m_name = "match"
        m_priority = mode.Priority
        m_debug = False
        m_match_percentage = 10
        m_non_match_number_step = 10
        m_display_time_ms = 2000
        m_end_match_event = Null
        m_running = False
        m_winner_number = Empty
        m_winners = 0
        m_forced_roll = Empty
        If Not glf_machine_vars.Exists("match_number") Then
            With CreateMachineVar("match_number")
                .InitialValue = 0
                .ValueType = "int"
                .Persist = False
            End With
        End If
        Set m_base_device = (new GlfBaseModeDevice)(mode, "match", Me)
        Set Init = Me
	End Function

    ' Called by the base mode device when the match mode starts
    Public Sub Activate()
        m_running = False
        Dim player_count : player_count = UBound(glf_playerState.Keys()) + 1
        If player_count = 0 Then
            Log "No players. Skipping match."
            m_base_device.Mode.StopMode
            Exit Sub
        End If
        m_running = True

        Dim match_numbers(), i, score
        ReDim match_numbers(player_count - 1)
        For i = 0 To player_count - 1
            score = glf_playerState("PLAYER " & (i + 1))(GLF_SCORE)
            match_numbers(i) = CLng(score - (100 * Int(score / 100)))
        Next

        ' Draw the winning number
        Dim roll
        If IsEmpty(m_forced_roll) Then
            roll = Int(Rnd() * 100)
        Else
            roll = m_forced_roll
            m_forced_roll = Empty
        End If
        If roll < m_match_percentage Then
            m_winner_number = match_numbers(Int(Rnd() * player_count))
        Else
            m_winner_number = LosingNumber(match_numbers)
        End If

        m_winners = 0
        Dim kwargs : Set kwargs = GlfKwargs()
        Dim slots : slots = 4
        If player_count > slots Then
            slots = player_count
        End If
        For i = 0 To slots - 1
            If i < player_count Then
                kwargs.Add "match_number" & i, match_numbers(i)
                kwargs.Add "match_number" & i & "_won", (match_numbers(i) = m_winner_number)
                If match_numbers(i) = m_winner_number Then
                    m_winners = m_winners + 1
                End If
            Else
                kwargs.Add "match_number" & i, ""
                kwargs.Add "match_number" & i & "_won", False
            End If
        Next
        kwargs.Add "winner_number", m_winner_number
        kwargs.Add "winners", m_winners

        Dim previous : previous = glf_machine_vars("match_number").Value
        glf_machine_vars("match_number").Value = m_winner_number
        Glf_BcpSendMachineVar "match_number", m_winner_number, previous

        If Not IsNull(m_end_match_event) Then
            AddPinEventListener m_end_match_event.EventName, m_name & "_end_match", "MatchEventHandler", m_priority+m_end_match_event.Priority, Array("end_match", Me, m_end_match_event)
        End If

        If m_winners = 0 Then
            Log "No match. Winning number: " & m_winner_number
            Glf_BcpSendEvent "match_no_match", kwargs
            DispatchPinEvent "match_no_match", kwargs
        Else
            Log "Match. Winning number: " & m_winner_number & ", winners: " & m_winners
            Glf_BcpSendEvent "match_has_match", kwargs
            DispatchPinEvent "match_has_match", kwargs
        End If
        SetDelay m_name & "_end", "MatchEventHandler", Array(Array("end", Me), Null), m_display_time_ms
    End Sub

    ' A number nobody has, from 0, step, 2 x step ...
    Private Function LosingNumber(match_numbers)
        Dim candidates, n, i, taken, step_size
        step_size = m_non_match_number_step
        If step_size < 1 Then
            step_size = 1
        End If
        candidates = Array()
        For n = 0 To 99 Step step_size
            taken = False
            For i = 0 To UBound(match_numbers)
                If match_numbers(i) = n Then
                    taken = True
                End If
            Next
            If Not taken Then
                ReDim Preserve candidates(UBound(candidates) + 1)
                candidates(UBound(candidates)) = n
            End If
        Next
        If UBound(candidates) = -1 Then
            ' The players hold every number on offer. Fall back to any number nobody has.
            For n = 0 To 99
                taken = False
                For i = 0 To UBound(match_numbers)
                    If match_numbers(i) = n Then
                        taken = True
                    End If
                Next
                If Not taken Then
                    ReDim Preserve candidates(UBound(candidates) + 1)
                    candidates(UBound(candidates)) = n
                End If
            Next
        End If
        If UBound(candidates) = -1 Then
            LosingNumber = match_numbers(0)
        Else
            LosingNumber = candidates(Int(Rnd() * (UBound(candidates) + 1)))
        End If
    End Function

    Public Sub EndMatch()
        If Not m_running Then
            Exit Sub
        End If
        m_running = False
        m_base_device.Mode.StopMode
    End Sub

    ' Called by the base mode device when the match mode stops
    Public Sub Deactivate()
        RemoveDelay m_name & "_end"
        If Not IsNull(m_end_match_event) Then
            RemovePinEventListener m_end_match_event.EventName, m_name & "_end_match"
        End If
        m_running = False
    End Sub

    Public Sub Enable()
    End Sub

    Public Sub Disable()
    End Sub

    Private Sub Log(message)
        If m_debug = True Then
            glf_debugLog.WriteToLog m_name, message
        End If
    End Sub

    ' Lines for the mode_settings section of the exported match mode
    Public Function ModeSettingsYaml()
        ModeSettingsYaml = "  non_match_number_step: " & m_non_match_number_step & vbCrLf
    End Function
End Class

Function MatchEventHandler(args)
    Dim ownProps, kwargs : ownProps = args(0)
    If IsObject(args(1)) Then
        Set kwargs = args(1)
    Else
        kwargs = args(1)
    End If
    Dim evt : evt = ownProps(0)
    Dim match_device : Set match_device = ownProps(1)
    Select Case evt
        Case "end"
            match_device.EndMatch
        Case "end_match"
            If ownProps(2).Evaluate() Then
                match_device.EndMatch
            End If
    End Select
    If IsObject(args(1)) Then
        Set MatchEventHandler = kwargs
    Else
        MatchEventHandler = kwargs
    End If
End Function
