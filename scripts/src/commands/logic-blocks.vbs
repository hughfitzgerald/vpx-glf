' Accruals and sequences: the two step-based logic blocks from MPF.
'
' Both track a list of steps. Each step is one event, or several alternative events.
'   Accrual:  the steps may be completed in any order.
'   Sequence: the steps must be completed in order.
' The counter, MPF's third logic block, lives in counter.vbs.

Dim glf_accruals : Set glf_accruals = CreateObject("Scripting.Dictionary")
Dim glf_sequences : Set glf_sequences = CreateObject("Scripting.Dictionary")

Class GlfStepLogicBlock

    Private m_name
    Private m_block_name
    Private m_kind
    Private m_ordered
    Private m_priority
    Private m_mode
    Private m_base_device
    Private m_debug

    Private m_steps
    Private m_reset_events
    Private m_restart_events
    Private m_advance_random_events
    Private m_events_when_complete
    Private m_events_when_hit
    Private m_disable_on_complete
    Private m_reset_on_complete
    Private m_persist_state
    Private m_start_enabled
    Private m_timeout

    Private m_value
    Private m_enabled
    Private m_completed

    Public Property Get Name() : Name = m_name : End Property
    Public Property Get Kind() : Kind = m_kind : End Property
    Public Property Get Enabled() : Enabled = m_enabled : End Property
    Public Property Get Completed() : Completed = m_completed : End Property

    ' Accrual: an array of True/False, one per step. Sequence: the number of steps done.
    Public Property Get Value() : Value = m_value : End Property

    Public Property Get GetValue(value)
        Select Case value
            Case "value"
                GetValue = m_value
            Case "completed_steps"
                GetValue = CompletedSteps()
            Case "enabled"
                GetValue = m_enabled
            Case "completed"
                GetValue = m_completed
        End Select
    End Property

    ' Each entry is one step: an event name, several names separated by commas,
    ' or an array of names. Any one of a step's events completes that step.
    Public Property Let Events(value)
        Dim x, y, step_events, parts
        m_steps = Array()
        For x = 0 To UBound(value)
            Set step_events = CreateObject("Scripting.Dictionary")
            If IsArray(value(x)) Then
                parts = value(x)
            Else
                parts = Split(value(x), ",")
            End If
            For y = 0 To UBound(parts)
                If Trim(parts(y)) <> "" Then
                    Dim newEvent : Set newEvent = (new GlfEvent)(Trim(parts(y)))
                    If Not step_events.Exists(newEvent.Raw) Then
                        step_events.Add newEvent.Raw, newEvent
                    End If
                End If
            Next
            ReDim Preserve m_steps(x)
            Set m_steps(x) = step_events
        Next
    End Property

    Public Property Let EnableEvents(value) : m_base_device.EnableEvents = value : End Property
    Public Property Let DisableEvents(value) : m_base_device.DisableEvents = value : End Property
    Public Property Let ResetEvents(value) : AddGlfEvents m_reset_events, value : End Property
    Public Property Let RestartEvents(value) : AddGlfEvents m_restart_events, value : End Property
    Public Property Let AdvanceRandomEvents(value) : AddGlfEvents m_advance_random_events, value : End Property
    Public Property Let EventsWhenComplete(value) : AddGlfEvents m_events_when_complete, value : End Property
    Public Property Let EventsWhenHit(value) : AddGlfEvents m_events_when_hit, value : End Property
    Public Property Let DisableOnComplete(value) : m_disable_on_complete = value : End Property
    Public Property Let ResetOnComplete(value) : m_reset_on_complete = value : End Property
    Public Property Let PersistState(value) : m_persist_state = value : End Property
    Public Property Let StartEnabled(value) : m_start_enabled = value : End Property
    Public Property Let LogicBlockTimeout(value)
        If VarType(value) = vbString Then
            value = Replace(LCase(value), "ms", "")
        End If
        m_timeout = CLng(value)
    End Property

    Public Property Let Debug(value)
        m_debug = value
        m_base_device.Debug = value
    End Property
    Public Property Get IsDebug()
        If m_debug Then : IsDebug = 1 : Else : IsDebug = 0 : End If
    End Property

	Public default Function init(name, mode, kind)
        m_block_name = name
        m_kind = kind
        m_ordered = (kind = "sequence")
        m_name = kind & "_" & name
        m_mode = mode.Name
        m_priority = mode.Priority
        m_debug = False

        m_steps = Array()
        Set m_reset_events = CreateObject("Scripting.Dictionary")
        Set m_restart_events = CreateObject("Scripting.Dictionary")
        Set m_advance_random_events = CreateObject("Scripting.Dictionary")
        Set m_events_when_complete = CreateObject("Scripting.Dictionary")
        Set m_events_when_hit = CreateObject("Scripting.Dictionary")
        m_disable_on_complete = True
        m_reset_on_complete = True
        m_persist_state = False
        m_start_enabled = Empty
        m_timeout = 0

        m_value = StartValue()
        m_enabled = False
        m_completed = False

        Set m_base_device = (new GlfBaseModeDevice)(mode, kind, Me)
        If m_ordered Then
            Set glf_sequences(name) = Me
        Else
            Set glf_accruals(name) = Me
        End If
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

    Private Function StartValue()
        If m_ordered Then
            StartValue = 0
        Else
            Dim x, steps
            steps = Array()
            If UBound(m_steps) > -1 Then
                ReDim steps(UBound(m_steps))
                For x = 0 To UBound(m_steps)
                    steps(x) = False
                Next
            End If
            StartValue = steps
        End If
    End Function

    Public Function CompletedSteps()
        If m_ordered Then
            CompletedSteps = m_value
        Else
            Dim x, done : done = 0
            For x = 0 To UBound(m_value)
                If m_value(x) = True Then
                    done = done + 1
                End If
            Next
            CompletedSteps = done
        End If
    End Function

    ' Called by the base mode device when the mode starts
    Public Sub Activate()
        Dim evt, x
        For x = 0 To UBound(m_steps)
            For Each evt in m_steps(x).Keys
                ' A later step gets a higher priority, as in MPF, so one event shared by
                ' two steps of a sequence cannot advance it twice.
                AddPinEventListener m_steps(x)(evt).EventName, m_name & "_step" & x & "_" & evt & "_hit", "StepLogicBlockEventHandler", m_priority+m_steps(x)(evt).Priority+x, Array("hit", Me, m_steps(x)(evt), x)
            Next
        Next
        For Each evt in m_reset_events.Keys
            AddPinEventListener m_reset_events(evt).EventName, m_name & "_" & evt & "_reset", "StepLogicBlockEventHandler", m_priority+m_reset_events(evt).Priority, Array("reset", Me, m_reset_events(evt))
        Next
        For Each evt in m_restart_events.Keys
            AddPinEventListener m_restart_events(evt).EventName, m_name & "_" & evt & "_restart", "StepLogicBlockEventHandler", m_priority+m_restart_events(evt).Priority, Array("restart", Me, m_restart_events(evt))
        Next
        For Each evt in m_advance_random_events.Keys
            AddPinEventListener m_advance_random_events(evt).EventName, m_name & "_" & evt & "_advance_random", "StepLogicBlockEventHandler", m_priority+m_advance_random_events(evt).Priority, Array("advance_random", Me, m_advance_random_events(evt))
        Next

        Dim start_enabled : start_enabled = m_start_enabled
        If IsEmpty(start_enabled) Then
            start_enabled = (UBound(m_base_device.EnableEvents.Keys) = -1)
        End If

        If m_persist_state And HasPersistedState() Then
            ' A block that persists keeps its progress and its enabled state per player
            RestoreState()
            Log "Restored. Completed steps: " & CompletedSteps() & ", Enabled: " & m_enabled & ", Completed: " & m_completed
            PostUpdateEvent()
            If m_enabled Then
                StartTimeout()
            End If
        Else
            m_completed = False
            m_enabled = False
            m_value = StartValue()
            SaveState()
            If start_enabled Then
                Enable()
            Else
                PostUpdateEvent()
            End If
        End If
    End Sub

    ' Called by the base mode device when the mode stops
    Public Sub Deactivate()
        Dim evt, x
        For x = 0 To UBound(m_steps)
            For Each evt in m_steps(x).Keys
                RemovePinEventListener m_steps(x)(evt).EventName, m_name & "_step" & x & "_" & evt & "_hit"
            Next
        Next
        For Each evt in m_reset_events.Keys
            RemovePinEventListener m_reset_events(evt).EventName, m_name & "_" & evt & "_reset"
        Next
        For Each evt in m_restart_events.Keys
            RemovePinEventListener m_restart_events(evt).EventName, m_name & "_" & evt & "_restart"
        Next
        For Each evt in m_advance_random_events.Keys
            RemovePinEventListener m_advance_random_events(evt).EventName, m_name & "_" & evt & "_advance_random"
        Next
        RemoveDelay m_name & "_timeout"
        ' The saved state keeps the enabled flag; only the running copy is switched off
        m_enabled = False
    End Sub

    Public Sub Enable()
        Log "Enabling"
        m_enabled = True
        SaveState()
        PostUpdateEvent()
        StartTimeout()
    End Sub

    Public Sub Disable()
        Log "Disabling"
        m_enabled = False
        SaveState()
        PostUpdateEvent()
        RemoveDelay m_name & "_timeout"
    End Sub

    Public Sub Reset()
        Log "Resetting"
        m_completed = False
        m_value = StartValue()
        SaveState()
        PostUpdateEvent()
        StartTimeout()
    End Sub

    Public Sub Restart()
        Log "Restarting"
        Reset()
        Enable()
    End Sub

    Public Sub Timeout()
        Log "Timed out"
        DispatchPinEvent m_block_name & "_timeout", Null
        Reset()
    End Sub

    Private Sub StartTimeout()
        If m_timeout > 0 Then
            SetDelay m_name & "_timeout", "StepLogicBlockEventHandler", Array(Array("timeout", Me), Null), m_timeout
        End If
    End Sub

    ' step is zero based
    Public Sub Hit(step_index)
        If Not m_enabled Then
            Exit Sub
        End If
        Dim kwargs : Set kwargs = GlfKwargs()
        If m_ordered Then
            If step_index <> m_value Then
                ' An event for another step of the sequence
                Exit Sub
            End If
            m_value = m_value + 1
            Log "Step " & step_index & " hit. Steps done: " & m_value
            SaveState()
            kwargs.Add "step", m_value
            PostHitEvents kwargs
            If m_value >= UBound(m_steps) + 1 Then
                Complete()
            End If
        Else
            If m_value(step_index) = False Then
                m_value(step_index) = True
                Log "Step " & step_index & " hit. Steps done: " & CompletedSteps()
                SaveState()
                kwargs.Add "step", step_index
                PostHitEvents kwargs
            End If
            If CompletedSteps() = UBound(m_steps) + 1 Then
                Complete()
            End If
        End If
    End Sub

    ' Accruals only: complete one of the steps that is still open, picked at random
    Public Sub AdvanceRandom()
        If Not m_enabled Or m_ordered Then
            Exit Sub
        End If
        Dim x, open_steps : open_steps = Array()
        For x = 0 To UBound(m_value)
            If m_value(x) = False Then
                ReDim Preserve open_steps(UBound(open_steps) + 1)
                open_steps(UBound(open_steps)) = x
            End If
        Next
        If UBound(open_steps) = -1 Then
            Exit Sub
        End If
        Hit open_steps(Int(Rnd() * (UBound(open_steps) + 1)))
    End Sub

    Private Sub Complete()
        If m_completed Then
            Exit Sub
        End If
        Log "Complete"
        m_completed = True
        RemoveDelay m_name & "_timeout"
        SaveState()
        If UBound(m_events_when_complete.Keys) > -1 Then
            Dim evt
            For Each evt in m_events_when_complete.Items()
                If evt.Evaluate() Then
                    Glf_BcpSendEvent evt.EventName, Null
                    DispatchPinEvent evt.EventName, Null
                End If
            Next
        Else
            Glf_BcpSendEvent "logicblock_" & m_block_name & "_complete", Null
            DispatchPinEvent "logicblock_" & m_block_name & "_complete", Null
        End If
        If m_reset_on_complete Then
            Reset()
        End If
        If m_disable_on_complete Then
            Disable()
        End If
    End Sub

    Private Sub PostHitEvents(kwargs)
        PostUpdateEvent()
        If UBound(m_events_when_hit.Keys) > -1 Then
            Dim evt
            For Each evt in m_events_when_hit.Items()
                If evt.Evaluate() Then
                    Glf_BcpSendEvent evt.EventName, kwargs
                    DispatchPinEvent evt.EventName, kwargs
                End If
            Next
        Else
            Glf_BcpSendEvent "logicblock_" & m_block_name & "_hit", kwargs
            DispatchPinEvent "logicblock_" & m_block_name & "_hit", kwargs
        End If
    End Sub

    Private Sub PostUpdateEvent()
        Dim kwargs : Set kwargs = GlfKwargs()
        kwargs.Add "value", m_value
        kwargs.Add "enabled", m_enabled
        Glf_BcpSendEvent "logicblock_" & m_block_name & "_updated", kwargs
        DispatchPinEvent "logicblock_" & m_block_name & "_updated", kwargs
    End Sub

    ' ----- Per-player state, used when PersistState is True -----

    Private Function HasPersistedState()
        HasPersistedState = False
        If IsNull(glf_currentPlayer) Then
            Exit Function
        End If
        HasPersistedState = glf_playerState(glf_currentPlayer).Exists(m_name & "_state_value")
    End Function

    Private Sub SaveState()
        If Not m_persist_state Then
            Exit Sub
        End If
        If m_ordered Then
            SetPlayerState m_name & "_state_value", m_value
        Else
            Dim x, text : text = ""
            For x = 0 To UBound(m_value)
                If m_value(x) = True Then
                    text = text & "1"
                Else
                    text = text & "0"
                End If
            Next
            SetPlayerState m_name & "_state_value", text
        End If
        SetPlayerState m_name & "_state_enabled", m_enabled
        SetPlayerState m_name & "_state_completed", m_completed
    End Sub

    Private Sub RestoreState()
        Dim saved : saved = GetPlayerState(m_name & "_state_value")
        If m_ordered Then
            m_value = saved
        Else
            Dim x
            m_value = StartValue()
            For x = 0 To UBound(m_value)
                If x < Len(saved) Then
                    m_value(x) = (Mid(saved, x + 1, 1) = "1")
                End If
            Next
        End If
        m_enabled = (GetPlayerState(m_name & "_state_enabled") = True)
        m_completed = (GetPlayerState(m_name & "_state_completed") = True)
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
        Dim yaml, x
        yaml = "  " & m_block_name & ":" & vbCrLf
        yaml = yaml & "    events:" & vbCrLf
        For x = 0 To UBound(m_steps)
            yaml = yaml & "      - " & EventsYaml(m_steps(x)) & vbCrLf
        Next
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
        If UBound(m_advance_random_events.Keys) > -1 Then
            yaml = yaml & "    advance_random_events: " & EventsYaml(m_advance_random_events) & vbCrLf
        End If
        If UBound(m_events_when_hit.Keys) > -1 Then
            yaml = yaml & "    events_when_hit: " & EventsYaml(m_events_when_hit) & vbCrLf
        End If
        If UBound(m_events_when_complete.Keys) > -1 Then
            yaml = yaml & "    events_when_complete: " & EventsYaml(m_events_when_complete) & vbCrLf
        End If
        If m_reset_on_complete = False Then
            yaml = yaml & "    reset_on_complete: false" & vbCrLf
        End If
        If m_disable_on_complete = False Then
            yaml = yaml & "    disable_on_complete: false" & vbCrLf
        End If
        If m_persist_state = True Then
            yaml = yaml & "    persist_state: true" & vbCrLf
        End If
        If Not IsEmpty(m_start_enabled) Then
            yaml = yaml & "    start_enabled: " & LCase(CStr(m_start_enabled)) & vbCrLf
        End If
        If m_timeout > 0 Then
            yaml = yaml & "    logic_block_timeout: " & m_timeout & "ms" & vbCrLf
        End If
        ToYaml = yaml
    End Function
End Class

Function StepLogicBlockEventHandler(args)
    Dim ownProps, kwargs : ownProps = args(0)
    If IsObject(args(1)) Then
        Set kwargs = args(1)
    Else
        kwargs = args(1)
    End If
    Dim evt : evt = ownProps(0)
    Dim block : Set block = ownProps(1)
    Dim run : run = True
    If evt <> "timeout" Then
        run = ownProps(2).Evaluate()
    End If
    If run Then
        Select Case evt
            Case "hit"
                block.Hit ownProps(3)
            Case "reset"
                block.Reset
            Case "restart"
                block.Restart
            Case "advance_random"
                block.AdvanceRandom
            Case "timeout"
                block.Timeout
        End Select
    End If
    If IsObject(args(1)) Then
        Set StepLogicBlockEventHandler = kwargs
    Else
        StepLogicBlockEventHandler = kwargs
    End If
End Function
