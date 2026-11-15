' End-of-ball bonus, after MPF's built-in bonus mode.
'
' EnableGlfBonus creates a mode called "bonus" that starts on ball_ending and holds
' the end of the ball until the bonus has been counted. It walks through the bonus
' entries one at a time, posting bonus_entry for each, then the subtotal, the
' multiplier and the total, and adds the total to the player's score.

Dim glf_bonus : glf_bonus = Null

Function EnableGlfBonus()
    If Not IsNull(glf_bonus) Then
        Set EnableGlfBonus = glf_bonus
        Exit Function
    End If
    Dim bonus_mode : Set bonus_mode = CreateGlfMode("bonus", 500)
    bonus_mode.StartEvents = Array("ball_ending")
    bonus_mode.UseWaitQueue = True
    Set glf_bonus = (new GlfBonus)(bonus_mode)
    bonus_mode.AddModeSettings "bonus", glf_bonus
    Set EnableGlfBonus = glf_bonus
End Function

Class GlfBonusEntry

    Private m_entry
    Private m_text
    Private m_score
    Private m_player_score_entry
    Private m_reset_player_score_entry
    Private m_skip_if_zero
    Private m_skip_if_negative

    Public Property Get Entry() : Entry = m_entry : End Property
    Public Property Get Text() : Text = m_text : End Property
    Public Property Let Text(value) : m_text = value : End Property
    Public Property Get Score() : Score = m_score.Value : End Property
    Public Property Get ScoreRaw() : ScoreRaw = m_score.Raw : End Property
    Public Property Let Score(value) : Set m_score = CreateGlfInput(value) : End Property
    Public Property Get PlayerScoreEntry() : PlayerScoreEntry = m_player_score_entry : End Property
    Public Property Let PlayerScoreEntry(value) : m_player_score_entry = value : End Property
    Public Property Get ResetPlayerScoreEntry() : ResetPlayerScoreEntry = m_reset_player_score_entry : End Property
    Public Property Let ResetPlayerScoreEntry(value) : m_reset_player_score_entry = value : End Property
    Public Property Get SkipIfZero() : SkipIfZero = m_skip_if_zero : End Property
    Public Property Let SkipIfZero(value) : m_skip_if_zero = value : End Property
    Public Property Get SkipIfNegative() : SkipIfNegative = m_skip_if_negative : End Property
    Public Property Let SkipIfNegative(value) : m_skip_if_negative = value : End Property

	Public default Function init(entry_name)
        m_entry = entry_name
        m_text = Empty
        Set m_score = CreateGlfInput(0)
        m_player_score_entry = Empty
        m_reset_player_score_entry = False
        m_skip_if_zero = True
        m_skip_if_negative = False
        Set Init = Me
	End Function

    Public Function ToYaml()
        Dim yaml
        yaml = "    - entry: " & m_entry & vbCrLf
        yaml = yaml & "      score: " & m_score.Raw & vbCrLf
        If Not IsEmpty(m_text) Then
            yaml = yaml & "      text: " & m_text & vbCrLf
        End If
        If Not IsEmpty(m_player_score_entry) Then
            yaml = yaml & "      player_score_entry: " & m_player_score_entry & vbCrLf
        End If
        If m_reset_player_score_entry = True Then
            yaml = yaml & "      reset_player_score_entry: true" & vbCrLf
        End If
        If m_skip_if_zero = False Then
            yaml = yaml & "      skip_if_zero: false" & vbCrLf
        End If
        If m_skip_if_negative = True Then
            yaml = yaml & "      skip_if_negative: true" & vbCrLf
        End If
        ToYaml = yaml
    End Function
End Class

Class GlfBonus

    Private m_name
    Private m_priority
    Private m_base_device
    Private m_debug

    Private m_entries
    Private m_display_delay_ms
    Private m_hurry_up_delay_ms
    Private m_hurry_up_event
    Private m_end_bonus_event
    Private m_keep_multiplier
    Private m_rounding_value
    Private m_rounding_direction

    Private m_running
    Private m_bonus_score
    Private m_current_delay
    Private m_next_entry
    Private m_next_step

    Public Property Get Name() : Name = m_name : End Property
    Public Property Get Mode() : Set Mode = m_base_device.Mode : End Property
    Public Property Get BonusScore() : BonusScore = m_bonus_score : End Property
    Public Property Get Running() : Running = m_running : End Property

    ' Entries are counted in the order they are first named
    Public Property Get Entries(entry_name)
        If entry_name = "subtotal" Or entry_name = "multiplier" Or entry_name = "total" Then
            Err.Raise vbObjectError + 1, "GlfBonus", "Bonus entry cannot be the reserved word '" & entry_name & "'"
        End If
        If Not m_entries.Exists(entry_name) Then
            m_entries.Add entry_name, (new GlfBonusEntry)(entry_name)
        End If
        Set Entries = m_entries(entry_name)
    End Property

    Public Property Let DisplayDelayMs(value) : m_display_delay_ms = value : End Property
    Public Property Let HurryUpDelayMs(value) : m_hurry_up_delay_ms = value : End Property
    Public Property Let HurryUpEvent(value)
        If IsEmpty(value) Or IsNull(value) Then
            m_hurry_up_event = Null
        Else
            Set m_hurry_up_event = (new GlfEvent)(value)
        End If
    End Property
    Public Property Let EndBonusEvent(value)
        If IsEmpty(value) Or IsNull(value) Then
            m_end_bonus_event = Null
        Else
            Set m_end_bonus_event = (new GlfEvent)(value)
        End If
    End Property
    Public Property Let KeepMultiplier(value) : m_keep_multiplier = value : End Property
    Public Property Let RoundingValue(value) : m_rounding_value = value : End Property
    Public Property Let RoundingDirection(value) : m_rounding_direction = LCase(value) : End Property

    Public Property Let Debug(value)
        m_debug = value
        m_base_device.Debug = value
    End Property
    Public Property Get IsDebug()
        If m_debug Then : IsDebug = 1 : Else : IsDebug = 0 : End If
    End Property

	Public default Function init(mode)
        m_name = "bonus"
        m_priority = mode.Priority
        m_debug = False
        Set m_entries = CreateObject("Scripting.Dictionary")
        m_display_delay_ms = 2000
        m_hurry_up_delay_ms = 500
        Set m_hurry_up_event = (new GlfEvent)("flipper_cancel")
        m_end_bonus_event = Null
        m_keep_multiplier = False
        m_rounding_value = 0
        m_rounding_direction = "up"
        m_running = False
        m_bonus_score = 0
        m_current_delay = 0
        m_next_entry = 0
        m_next_step = ""
        Set m_base_device = (new GlfBaseModeDevice)(mode, "bonus", Me)
        Set Init = Me
	End Function

    ' Called by the base mode device when the bonus mode starts
    Public Sub Activate()
        m_running = False
        If glf_gameStarted = False Or IsNull(glf_currentPlayer) Then
            Log "No game is running. Skipping bonus."
            m_base_device.Mode.StopMode
            Exit Sub
        End If
        If glf_gameTilted = True Then
            Log "The game is tilted. Skipping bonus."
            ResetAllScores()
            m_base_device.Mode.StopMode
            Exit Sub
        End If

        m_running = True
        m_bonus_score = 0
        m_next_entry = 0
        m_current_delay = m_display_delay_ms

        If Not IsNull(m_hurry_up_event) Then
            AddPinEventListener m_hurry_up_event.EventName, m_name & "_hurry_up", "BonusEventHandler", m_priority+m_hurry_up_event.Priority, Array("hurry_up", Me, m_hurry_up_event)
        End If
        If Not IsNull(m_end_bonus_event) Then
            AddPinEventListener m_end_bonus_event.EventName, m_name & "_end_bonus", "BonusEventHandler", m_priority+m_end_bonus_event.Priority, Array("end_bonus", Me, m_end_bonus_event)
        End If

        Glf_BcpSendEvent "bonus_start", Null
        DispatchPinEvent "bonus_start", Null
        Schedule "next_item"
    End Sub

    ' Called by the base mode device when the bonus mode stops
    Public Sub Deactivate()
        RemoveDelay m_name & "_step"
        If Not IsNull(m_hurry_up_event) Then
            RemovePinEventListener m_hurry_up_event.EventName, m_name & "_hurry_up"
        End If
        If Not IsNull(m_end_bonus_event) Then
            RemovePinEventListener m_end_bonus_event.EventName, m_name & "_end_bonus"
        End If
        m_running = False
        m_next_step = ""
    End Sub

    Public Sub Enable()
    End Sub

    Public Sub Disable()
    End Sub

    Private Sub Schedule(next_step)
        m_next_step = next_step
        SetDelay m_name & "_step", "BonusEventHandler", Array(Array("step", Me), Null), m_current_delay
    End Sub

    ' Runs whichever step is waiting
    Public Sub RunStep()
        Dim next_step : next_step = m_next_step
        m_next_step = ""
        Select Case next_step
            Case "next_item"
                NextItem()
            Case "multiplier"
                DoMultiplier()
            Case "total"
                TotalBonus()
            Case "end"
                EndBonus()
        End Select
    End Sub

    ' Switch to the shorter delay and move on at once
    Public Sub HurryUp()
        If Not m_running Then
            Exit Sub
        End If
        Log "Hurry up"
        m_current_delay = m_hurry_up_delay_ms
        If m_next_step <> "" Then
            RemoveDelay m_name & "_step"
            RunStep()
        End If
    End Sub

    ' Entries that reset are cleared without being scored, as after a tilt
    Private Sub ResetAllScores()
        If IsNull(glf_currentPlayer) Then
            Exit Sub
        End If
        Dim bonus_entry
        For Each bonus_entry in m_entries.Items()
            If bonus_entry.ResetPlayerScoreEntry = True And Not IsEmpty(bonus_entry.PlayerScoreEntry) Then
                SetPlayerState bonus_entry.PlayerScoreEntry, 0
            End If
        Next
    End Sub

    Private Function PlayerNumber(var_name, default_value)
        Dim value : value = GetPlayerState(var_name)
        If IsEmpty(value) Or IsNull(value) Or VarType(value) = vbBoolean Or VarType(value) = vbString Then
            If VarType(value) = vbString Then
                If IsNumeric(value) Then
                    PlayerNumber = CDbl(value)
                    Exit Function
                End If
            End If
            PlayerNumber = default_value
        Else
            PlayerNumber = value
        End If
    End Function

    Private Sub NextItem()
        Dim items : items = m_entries.Items()
        Do While m_next_entry <= UBound(items)
            Dim bonus_entry : Set bonus_entry = items(m_next_entry)
            m_next_entry = m_next_entry + 1

            Dim hits : hits = 1
            If Not IsEmpty(bonus_entry.PlayerScoreEntry) Then
                hits = PlayerNumber(bonus_entry.PlayerScoreEntry, 0)
            End If
            Dim score : score = bonus_entry.Score * hits

            If (score = 0 And bonus_entry.SkipIfZero) Or (score < 0 And bonus_entry.SkipIfNegative) Then
                Log "Skipping bonus entry '" & bonus_entry.Entry & "'"
            Else
                If m_rounding_value > 0 Then
                    Dim remainder : remainder = score - (m_rounding_value * Int(score / m_rounding_value))
                    If remainder <> 0 Then
                        If m_rounding_direction = "down" Then
                            score = score - remainder
                        Else
                            score = score + m_rounding_value - remainder
                        End If
                    End If
                End If
                m_bonus_score = m_bonus_score + score
                Log "Bonus entry '" & bonus_entry.Entry & "': score " & score & ", hits " & hits

                Dim kwargs : Set kwargs = GlfKwargs()
                kwargs.Add "entry", bonus_entry.Entry
                kwargs.Add "score", score
                kwargs.Add "text", bonus_entry.Text
                kwargs.Add "bonus_score", m_bonus_score
                kwargs.Add "hits", hits
                Glf_BcpSendEvent "bonus_entry", kwargs
                DispatchPinEvent "bonus_entry", kwargs

                If bonus_entry.ResetPlayerScoreEntry = True And Not IsEmpty(bonus_entry.PlayerScoreEntry) Then
                    SetPlayerState bonus_entry.PlayerScoreEntry, 0
                End If
                Schedule "next_item"
                Exit Sub
            End If
        Loop
        Subtotal()
    End Sub

    Private Sub PostSummary(entry_name, text, score)
        Dim kwargs : Set kwargs = GlfKwargs()
        kwargs.Add "entry", entry_name
        kwargs.Add "text", text
        kwargs.Add "score", score
        Glf_BcpSendEvent "bonus_entry", kwargs
        DispatchPinEvent "bonus_entry", kwargs
    End Sub

    Private Sub Subtotal()
        If PlayerNumber("bonus_multiplier", 1) = 1 Then
            ' Nothing to multiply: go straight to the total
            TotalBonus()
        Else
            Log "Bonus subtotal: " & m_bonus_score
            PostSummary "subtotal", "Subtotal", m_bonus_score
            Schedule "multiplier"
        End If
    End Sub

    Private Sub DoMultiplier()
        Dim multiplier : multiplier = PlayerNumber("bonus_multiplier", 1)
        Log "Bonus multiplier: " & multiplier
        PostSummary "multiplier", "Multiplier", multiplier
        m_bonus_score = m_bonus_score * multiplier
        Schedule "total"
    End Sub

    Private Sub TotalBonus()
        SetPlayerState GLF_SCORE, GetPlayerState(GLF_SCORE) + m_bonus_score
        Log "Bonus total: " & m_bonus_score
        PostSummary "total", "Total Bonus", m_bonus_score
        If IsNull(m_end_bonus_event) Then
            Schedule "end"
        End If
    End Sub

    Public Sub EndBonus()
        If Not m_running Then
            Exit Sub
        End If
        Log "Bonus done"
        m_running = False
        If m_keep_multiplier = False Then
            SetPlayerState "bonus_multiplier", 1
        End If
        m_base_device.Mode.StopMode
    End Sub

    Private Sub Log(message)
        If m_debug = True Then
            glf_debugLog.WriteToLog m_name, message
        End If
    End Sub

    ' Lines for the mode_settings section of the exported bonus mode
    Public Function ModeSettingsYaml()
        Dim yaml, bonus_entry
        yaml = "  display_delay_ms: " & m_display_delay_ms & vbCrLf
        yaml = yaml & "  hurry_up_delay_ms: " & m_hurry_up_delay_ms & vbCrLf
        If Not IsNull(m_hurry_up_event) Then
            yaml = yaml & "  hurry_up_event: " & m_hurry_up_event.Raw & vbCrLf
        End If
        If Not IsNull(m_end_bonus_event) Then
            yaml = yaml & "  end_bonus_event: " & m_end_bonus_event.Raw & vbCrLf
        End If
        yaml = yaml & "  keep_multiplier: " & LCase(CStr(m_keep_multiplier)) & vbCrLf
        If m_rounding_value > 0 Then
            yaml = yaml & "  rounding_value: " & m_rounding_value & vbCrLf
            yaml = yaml & "  rounding_direction: " & m_rounding_direction & vbCrLf
        End If
        yaml = yaml & "  bonus_entries:" & vbCrLf
        For Each bonus_entry in m_entries.Items()
            yaml = yaml & bonus_entry.ToYaml()
        Next
        ModeSettingsYaml = yaml
    End Function
End Class

Function BonusEventHandler(args)
    Dim ownProps, kwargs : ownProps = args(0)
    If IsObject(args(1)) Then
        Set kwargs = args(1)
    Else
        kwargs = args(1)
    End If
    Dim evt : evt = ownProps(0)
    Dim bonus : Set bonus = ownProps(1)
    Select Case evt
        Case "step"
            bonus.RunStep
        Case "hurry_up"
            If ownProps(2).Evaluate() Then
                bonus.HurryUp
            End If
        Case "end_bonus"
            If ownProps(2).Evaluate() Then
                bonus.EndBonus
            End If
    End Select
    If IsObject(args(1)) Then
        Set BonusEventHandler = kwargs
    Else
        BonusEventHandler = kwargs
    End If
End Function
