Class GlfCounter

    Private m_name
    Private m_counter_name
    Private m_player_var_name
    Private m_priority
    Private m_mode
    Private m_base_device
    Private m_debug

    Private m_count_events
    Private m_control_events
    Private m_reset_events
    Private m_restart_events
    Private m_events_when_complete
    Private m_events_when_hit
    Private m_count_complete_value
    Private m_starting_count
    Private m_count_interval
    Private m_direction
    Private m_multiple_hit_window
    Private m_disable_on_complete
    Private m_reset_on_complete
    Private m_persist_state
    Private m_start_enabled

    Private m_value
    Private m_enabled
    Private m_completed
    Private m_last_hit_time

    Public Property Get Name() : Name = m_name : End Property
    Public Property Get Value() : Value = m_value : End Property
    Public Property Get Enabled() : Enabled = m_enabled : End Property
    Public Property Get Completed() : Completed = m_completed : End Property

    Public Property Get GetValue(value)
        Select Case value
            Case "value"
                GetValue = m_value
            Case "enabled"
                GetValue = m_enabled
            Case "completed"
                GetValue = m_completed
        End Select
    End Property

    Public Property Let EnableEvents(value) : m_base_device.EnableEvents = value : End Property
    Public Property Let DisableEvents(value) : m_base_device.DisableEvents = value : End Property
    Public Property Let CountEvents(value) : AddGlfEvents m_count_events, value : End Property
    Public Property Let ResetEvents(value) : AddGlfEvents m_reset_events, value : End Property
    Public Property Let RestartEvents(value) : AddGlfEvents m_restart_events, value : End Property
    Public Property Let EventsWhenComplete(value) : AddGlfEvents m_events_when_complete, value : End Property
    Public Property Let EventsWhenHit(value) : AddGlfEvents m_events_when_hit, value : End Property
    Public Property Let CountCompleteValue(value) : Set m_count_complete_value = CreateGlfInput(value) : End Property
    Public Property Let StartingCount(value) : Set m_starting_count = CreateGlfInput(value) : End Property
    Public Property Let CountInterval(value) : m_count_interval = value : End Property
    Public Property Let Direction(value) : m_direction = value : End Property
    Public Property Let MultipleHitWindow(value)
        If VarType(value) = vbString Then
            value = Replace(LCase(value), "ms", "")
        End If
        m_multiple_hit_window = CLng(value)
    End Property
    Public Property Let DisableOnComplete(value) : m_disable_on_complete = value : End Property
    Public Property Let ResetOnComplete(value) : m_reset_on_complete = value : End Property
    Public Property Let PersistState(value) : m_persist_state = value : End Property
    Public Property Let StartEnabled(value) : m_start_enabled = value : End Property

    Public Property Get ControlEvents()
        Dim count : count = UBound(m_control_events.Keys)
        Dim newEvent : Set newEvent = (new GlfCounterControlEvent)()
        m_control_events.Add CStr(count), newEvent
        Set ControlEvents = newEvent
    End Property

    Public Property Let Debug(value)
        m_debug = value
        m_base_device.Debug = value
    End Property
    Public Property Get IsDebug()
        If m_debug Then : IsDebug = 1 : Else : IsDebug = 0 : End If
    End Property

	Public default Function init(name, mode)
        m_counter_name = name
        m_name = "counter_" & name
        m_player_var_name = "counter_" & name
        m_mode = mode.Name
        m_priority = mode.Priority
        m_debug = False

        Set m_count_events = CreateObject("Scripting.Dictionary")
        Set m_control_events = CreateObject("Scripting.Dictionary")
        Set m_reset_events = CreateObject("Scripting.Dictionary")
        Set m_restart_events = CreateObject("Scripting.Dictionary")
        Set m_events_when_complete = CreateObject("Scripting.Dictionary")
        Set m_events_when_hit = CreateObject("Scripting.Dictionary")
        m_count_complete_value = Null
        Set m_starting_count = CreateGlfInput(0)
        m_count_interval = 1
        m_direction = "up"
        m_multiple_hit_window = 0
        m_disable_on_complete = True
        m_reset_on_complete = True
        m_persist_state = False
        m_start_enabled = Empty

        m_value = 0
        m_enabled = False
        m_completed = False
        m_last_hit_time = Empty

        Set m_base_device = (new GlfBaseModeDevice)(mode, "counter", Me)
        Set glf_counters(name) = Me
        Set Init = Me
	End Function

    Private Sub AddGlfEvents(dict, value)
        Dim x
        For x=0 to UBound(value)
            Dim newEvent : Set newEvent = (new GlfEvent)(value(x))
            If Not dict.Exists(newEvent.Raw) Then
                dict.Add newEvent.Raw, newEvent
            End If
        Next
    End Sub

    ' Called by the base mode device when the mode starts
    Public Sub Activate()
        Dim evt
        For Each evt in m_count_events.Keys
            AddPinEventListener m_count_events(evt).EventName, m_name & "_" & evt & "_count", "CounterEventHandler", m_priority+m_count_events(evt).Priority, Array("count", Me, m_count_events(evt))
        Next
        For Each evt in m_reset_events.Keys
            AddPinEventListener m_reset_events(evt).EventName, m_name & "_" & evt & "_reset", "CounterEventHandler", m_priority+m_reset_events(evt).Priority, Array("reset", Me, m_reset_events(evt))
        Next
        For Each evt in m_restart_events.Keys
            AddPinEventListener m_restart_events(evt).EventName, m_name & "_" & evt & "_restart", "CounterEventHandler", m_priority+m_restart_events(evt).Priority, Array("restart", Me, m_restart_events(evt))
        Next
        For Each evt in m_control_events.Keys
            AddPinEventListener m_control_events(evt).EventName.EventName, m_name & "_" & evt & "_control", "CounterEventHandler", m_priority+m_control_events(evt).EventName.Priority, Array("control", Me, m_control_events(evt))
        Next

        m_last_hit_time = Empty
        m_enabled = False
        If m_persist_state And HasPersistedState() Then
            ' Only the value is persisted (like shots and state machines). A restored
            ' value already at the complete value is treated as completed, without
            ' re-posting the complete events.
            m_value = GetPlayerState(m_player_var_name)
            m_completed = IsAtCompleteValue()
            Log "Restored persisted value: " & m_value & ", Completed: " & m_completed
        Else
            m_completed = False
            SetValue m_starting_count.Value
        End If

        Dim start_enabled : start_enabled = m_start_enabled
        If IsEmpty(start_enabled) Then
            start_enabled = (UBound(m_base_device.EnableEvents.Keys) = -1)
        End If
        If m_completed And m_disable_on_complete Then
            start_enabled = False
        End If
        If start_enabled Then
            Enable()
        End If
    End Sub

    ' Called by the base mode device when the mode stops
    Public Sub Deactivate()
        Dim evt
        For Each evt in m_count_events.Keys
            RemovePinEventListener m_count_events(evt).EventName, m_name & "_" & evt & "_count"
        Next
        For Each evt in m_reset_events.Keys
            RemovePinEventListener m_reset_events(evt).EventName, m_name & "_" & evt & "_reset"
        Next
        For Each evt in m_restart_events.Keys
            RemovePinEventListener m_restart_events(evt).EventName, m_name & "_" & evt & "_restart"
        Next
        For Each evt in m_control_events.Keys
            RemovePinEventListener m_control_events(evt).EventName.EventName, m_name & "_" & evt & "_control"
        Next
        m_enabled = False
    End Sub

    Public Sub Enable()
        Log "Enabling"
        m_enabled = True
    End Sub

    Public Sub Disable()
        Log "Disabling"
        m_enabled = False
    End Sub

    Public Sub Reset()
        Log "Resetting"
        m_completed = False
        SetValue m_starting_count.Value
    End Sub

    Public Sub Restart()
        Log "Restarting"
        Reset()
        Enable()
    End Sub

    Public Sub Count()
        If Not m_enabled Then
            Log "Count event ignored, counter is disabled"
            Exit Sub
        End If

        If m_multiple_hit_window > 0 And Not IsEmpty(m_last_hit_time) Then
            If (gametime - m_last_hit_time) < m_multiple_hit_window Then
                Log "Count event ignored, inside multiple hit window"
                Exit Sub
            End If
        End If
        m_last_hit_time = gametime

        Dim new_value
        If m_direction = "down" Then
            new_value = m_value - m_count_interval
        Else
            new_value = m_value + m_count_interval
        End If
        Log "Counting. Old value: " & m_value & ", new value: " & new_value
        SetValue new_value
        PostHitEvents()
        CheckComplete()
    End Sub

    Public Sub Action(controlEvent)
        Dim value : value = controlEvent.Value
        Log "Control event action: " & controlEvent.Action & ", value: " & value
        Select Case controlEvent.Action
            Case "add"
                SetValue m_value + value
            Case "subtract"
                SetValue m_value - value
            Case "jump"
                SetValue value
            Case Else
                Exit Sub
        End Select
        CheckComplete()
    End Sub

    Private Function IsAtCompleteValue()
        IsAtCompleteValue = False
        If IsNull(m_count_complete_value) Then
            Exit Function
        End If
        Dim complete_value : complete_value = m_count_complete_value.Value
        If m_direction = "down" Then
            IsAtCompleteValue = (m_value <= complete_value)
        Else
            IsAtCompleteValue = (m_value >= complete_value)
        End If
    End Function

    Private Sub CheckComplete()
        If IsAtCompleteValue() Then
            Complete()
        End If
    End Sub

    Private Sub Complete()
        If m_completed Then
            Exit Sub
        End If
        Log "Complete"
        m_completed = True
        If UBound(m_events_when_complete.Keys) > -1 Then
            Dim evt
            For Each evt in m_events_when_complete.Items()
                If evt.Evaluate() Then
                    Glf_BcpSendEvent evt.EventName, Null
                    DispatchPinEvent evt.EventName, Null
                End If
            Next
        Else
            Glf_BcpSendEvent "logicblock_" & m_counter_name & "_complete", Null
            DispatchPinEvent "logicblock_" & m_counter_name & "_complete", Null
        End If
        If m_reset_on_complete Then
            Reset()
        End If
        If m_disable_on_complete Then
            Disable()
        End If
    End Sub

    Private Sub PostHitEvents()
        Dim kwargs : Set kwargs = GlfKwargs()
        kwargs.Add "count", m_value
        If Not IsNull(m_count_complete_value) Then
            kwargs.Add "remaining", Abs(m_count_complete_value.Value - m_value)
        End If
        If UBound(m_events_when_hit.Keys) > -1 Then
            Dim evt
            For Each evt in m_events_when_hit.Items()
                If evt.Evaluate() Then
                    Glf_BcpSendEvent evt.EventName, kwargs
                    DispatchPinEvent evt.EventName, kwargs
                End If
            Next
        Else
            Glf_BcpSendEvent "logicblock_" & m_counter_name & "_hit", kwargs
            DispatchPinEvent "logicblock_" & m_counter_name & "_hit", kwargs
        End If
    End Sub

    Private Sub SetValue(value)
        If IsEmpty(value) Or IsNull(value) Then
            value = 0
        ElseIf VarType(value) = vbString Then
            If value = "" Then value = 0 Else value = CDbl(value)
        End If
        Dim changed : changed = (m_value <> value)
        m_value = value
        SaveState()
        If changed Then
            Dim kwargs : Set kwargs = GlfKwargs()
            kwargs.Add "value", m_value
            Glf_BcpSendEvent "logicblock_" & m_counter_name & "_updated", kwargs
            DispatchPinEvent "logicblock_" & m_counter_name & "_updated", kwargs
        End If
    End Sub

    Private Function HasPersistedState()
        HasPersistedState = False
        If IsNull(glf_currentPlayer) Then
            Exit Function
        End If
        HasPersistedState = glf_playerState(glf_currentPlayer).Exists(m_player_var_name)
    End Function

    Private Sub SaveState()
        If m_persist_state Then
            SetPlayerState m_player_var_name, m_value
        End If
    End Sub

    Private Sub Log(message)
        If m_debug = True Then
            glf_debugLog.WriteToLog m_name, message
        End If
    End Sub

    Private Function EventsYaml(dict)
        Dim yaml, key, y : y = 0
        For Each key in dict.Keys
            yaml = yaml & Replace(Replace(key, "&&", "and"), "||", "or")
            If y <> UBound(dict.Keys) Then
                yaml = yaml & ", "
            End If
            y = y + 1
        Next
        EventsYaml = yaml
    End Function

    Public Function ToYaml
        Dim yaml, key
        yaml = "  " & m_counter_name & ":" & vbCrLf
        yaml = yaml & "    count_events: " & EventsYaml(m_count_events) & vbCrLf
        If UBound(m_base_device.EnableEvents.Keys) > -1 Then
            yaml = yaml & "    enable_events: " & EventsYaml(m_base_device.EnableEvents) & vbCrLf
        End If
        If UBound(m_base_device.DisableEvents.Keys) > -1 Then
            yaml = yaml & "    disable_events: " & EventsYaml(m_base_device.DisableEvents) & vbCrLf
        End If
        If UBound(m_reset_events.Keys) > -1 Then
            yaml = yaml & "    reset_events: " & EventsYaml(m_reset_events) & vbCrLf
        End If
        If UBound(m_restart_events.Keys) > -1 Then
            yaml = yaml & "    restart_events: " & EventsYaml(m_restart_events) & vbCrLf
        End If
        If UBound(m_events_when_hit.Keys) > -1 Then
            yaml = yaml & "    events_when_hit: " & EventsYaml(m_events_when_hit) & vbCrLf
        End If
        If UBound(m_events_when_complete.Keys) > -1 Then
            yaml = yaml & "    events_when_complete: " & EventsYaml(m_events_when_complete) & vbCrLf
        End If
        If UBound(m_control_events.Keys) > -1 Then
            yaml = yaml & "    control_events: " & vbCrLf
            For Each key in m_control_events.Keys
                yaml = yaml & m_control_events(key).ToYaml()
            Next
        End If
        If Not IsNull(m_count_complete_value) Then
            yaml = yaml & "    count_complete_value: " & m_count_complete_value.Raw & vbCrLf
        End If
        yaml = yaml & "    starting_count: " & m_starting_count.Raw & vbCrLf
        yaml = yaml & "    count_interval: " & m_count_interval & vbCrLf
        yaml = yaml & "    direction: " & m_direction & vbCrLf
        If m_multiple_hit_window > 0 Then
            yaml = yaml & "    multiple_hit_window: " & m_multiple_hit_window & "ms" & vbCrLf
        End If
        yaml = yaml & "    disable_on_complete: " & LCase(m_disable_on_complete) & vbCrLf
        yaml = yaml & "    reset_on_complete: " & LCase(m_reset_on_complete) & vbCrLf
        yaml = yaml & "    persist_state: " & LCase(m_persist_state) & vbCrLf
        If Not IsEmpty(m_start_enabled) Then
            yaml = yaml & "    start_enabled: " & LCase(m_start_enabled) & vbCrLf
        End If
        ToYaml = yaml
    End Function
End Class

Function CounterEventHandler(args)
    Dim ownProps, kwargs : ownProps = args(0)
    If IsObject(args(1)) Then
        Set kwargs = args(1)
    Else
        kwargs = args(1)
    End If
    Dim evt : evt = ownProps(0)
    Dim counter : Set counter = ownProps(1)
    Dim glfEvent
    Select Case evt
        Case "count"
            Set glfEvent = ownProps(2)
            If glfEvent.Evaluate() Then counter.Count
        Case "reset"
            Set glfEvent = ownProps(2)
            If glfEvent.Evaluate() Then counter.Reset
        Case "restart"
            Set glfEvent = ownProps(2)
            If glfEvent.Evaluate() Then counter.Restart
        Case "control"
            Dim controlEvent : Set controlEvent = ownProps(2)
            If controlEvent.EventName.Evaluate() Then counter.Action controlEvent
    End Select
    If IsObject(args(1)) Then
        Set CounterEventHandler = kwargs
    Else
        CounterEventHandler = kwargs
    End If
End Function

Class GlfCounterControlEvent
	Private m_event, m_action, m_value

	Public Property Get EventName(): Set EventName = m_event: End Property
    Public Property Let EventName(input)
        Set m_event = (new GlfEvent)(input)
    End Property

    Public Property Get Action(): Action = m_action : End Property
    Public Property Let Action(input): m_action = input : End Property

    Public Property Get Value()
        If Not IsNull(m_value) Then
            Value = m_value.Value
        Else
            Value = 0
        End If
    End Property
    Public Property Let Value(input)
        Set m_value = CreateGlfInput(input)
    End Property

	Public default Function init()
        m_event = Null
        m_action = Empty
        m_value = Null
	    Set Init = Me
	End Function

    Public Function ToYaml
        Dim yaml
        yaml = yaml & "      - event: " & m_event.Raw & vbCrLf
        yaml = yaml & "        action: " & m_action & vbCrLf
        If Not IsNull(m_value) Then
            yaml = yaml & "        value: " & m_value.Raw & vbCrLf
        End If
        ToYaml = yaml
    End Function

End Class