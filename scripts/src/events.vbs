
Class GlfEvent
	Private m_raw, m_name, m_event, m_condition, m_delay, m_priority, has_condition
  
    Public Property Get Name() : Name = m_name : End Property
    Public Property Get EventName() : EventName = m_event : End Property
    Public Property Get Condition() : Condition = m_condition : End Property
    Public Property Get Delay() : Delay = m_delay : End Property
    Public Property Get Raw() : Raw = m_raw : End Property
    Public Property Get Priority() : Priority = m_priority : End Property

    Public Function Evaluate()
        If has_condition = True Then
            Evaluate = GetRef(m_condition)(Null)
        Else
            Evaluate = True
        End If
    End Function

	Public default Function init(evt)
        m_raw = evt
        Dim parsedEvent : parsedEvent = Glf_ParseEventInput(evt)
        m_name = parsedEvent(0)
        m_event = parsedEvent(1)
        m_condition = parsedEvent(2)
        If Not IsNull(m_condition) Then
            has_condition = True
        Else
            has_condition = False
        End If
        m_delay = parsedEvent(3)
        m_priority = parsedEvent(4)
	    Set Init = Me
	End Function

End Class

Class GlfEventDispatch
	Private m_raw, m_event, m_kwargs_ref
  
    Public Property Get EventName() : EventName = m_event : End Property
    Public Property Get Kwargs()
        If IsEmpty(m_kwargs_ref) Then
            Kwargs = Null
        Else
            Set Kwargs = GetRef(m_kwargs_ref)(Null)
        End If
    End Property
    Public Property Get Raw() : Raw = m_raw : End Property

	Public default Function init(evt)
        m_raw = evt
        Dim parsedDispatchEvent : parsedDispatchEvent = Glf_ParseDispatchEventInput(evt)
        m_event = parsedDispatchEvent(0)
        m_kwargs_ref = parsedDispatchEvent(1)
	    Set Init = Me
	End Function

End Class

Class GlfRandomEvent
	
    Private m_parent_key
    Private m_key
    Private m_mode
    Private m_events
    Private m_weights
    Private m_fallback_event
    Private m_force_all
    Private m_force_different
    Private m_disable_random
    Private m_total_weights
    Private m_scope

    Public Property Let Scope(value) : m_scope = value : End Property

    Public Property Let FallbackEvent(value) : m_fallback_event = value : End Property
    Public Property Let ForceAll(value) : m_force_all = value : End Property
    Public Property Let ForceDifferent(value) : m_force_different = value : End Property
    Public Property Let DisableRandom(value) : m_disable_random = value : End Property

	Public default Function init(evt, mode, key)
        m_parent_key = evt
        m_key = key
        m_mode = mode
        m_fallback_event = Empty
        m_force_all = True
        m_force_different = True
        m_scope = "player"
        m_disable_random = False
        m_total_weights = 0
        Set m_events = CreateObject("Scripting.Dictionary")
        Set m_weights = CreateObject("Scripting.Dictionary")
        Randomize
	    Set Init = Me
	End Function

    Public Sub Add(evt, weight)
        Dim newEvent : Set newEvent = (new GlfEvent)(evt)
        m_events.Add newEvent.Raw, newEvent
        m_weights.Add newEvent.Raw, weight
        m_total_weights = m_total_weights + weight
    End Sub

    'Picks the event to post, following MPF's random_event_player:
    '  - only events whose conditions pass can be picked; if none pass, the fallback event is posted
    '  - force_all: every valid event plays once before any plays again
    '  - force_different: the same event is never picked twice in a row, unless it is the only one
    '  - disable_random: the first remaining event in the order they were added is picked
    Public Function GetNextRandomEvent()
        GetNextRandomEvent = Empty

        Dim valid_events, candidates, key, chosenKey
        Set valid_events = CreateObject("Scripting.Dictionary")
        For Each key In m_events.Keys
            If m_events(key).Evaluate() Then
                valid_events.Add key, m_events(key)
            End If
        Next
        If valid_events.Count = 0 Then
            GetNextRandomEvent = m_fallback_event
            Exit Function
        End If

        Set candidates = CopyEvents(valid_events)

        If m_force_all = True Then
            For Each key In valid_events.Keys
                If GetPlayerState(PlayedKey(key)) = True Then
                    candidates.Remove key
                End If
            Next
            If candidates.Count = 0 Then
                'Every valid event has played, so a new round starts
                For Each key In m_events.Keys
                    If GetPlayerState(PlayedKey(key)) = True Then
                        SetPlayerState PlayedKey(key), False
                    End If
                Next
                Set candidates = CopyEvents(valid_events)
            End If
        End If

        If m_force_different = True And candidates.Count > 1 Then
            Dim last_event : last_event = GetPlayerState(LastKey())
            If candidates.Exists(last_event) Then
                candidates.Remove last_event
            End If
        End If

        If m_disable_random = True Then
            chosenKey = candidates.Keys()(0)
        Else
            chosenKey = WeightedChoice(candidates)
        End If

        SetPlayerState LastKey(), chosenKey
        If m_force_all = True Then
            SetPlayerState PlayedKey(chosenKey), True
        End If

        GetNextRandomEvent = m_events(chosenKey).EventName
    End Function

    Private Function WeightedChoice(candidates)
        Dim key, total_weight, cumulative_weight, rand_val
        total_weight = 0
        For Each key In candidates.Keys
            total_weight = total_weight + m_weights(key)
        Next
        If total_weight <= 0 Then
            WeightedChoice = candidates.Keys()(Int(Rnd() * candidates.Count))
            Exit Function
        End If

        rand_val = Rnd() * total_weight
        cumulative_weight = 0
        For Each key In candidates.Keys
            cumulative_weight = cumulative_weight + m_weights(key)
            WeightedChoice = key
            If rand_val < cumulative_weight Then
                Exit Function
            End If
        Next
    End Function

    Private Function CopyEvents(events)
        Dim copy, key : Set copy = CreateObject("Scripting.Dictionary")
        For Each key In events.Keys
            copy.Add key, events(key)
        Next
        Set CopyEvents = copy
    End Function

    Private Function LastKey()
        LastKey = "random_" & m_mode & "_" & m_key & "_last"
    End Function

    Private Function PlayedKey(event_key)
        PlayedKey = "random_" & m_mode & "_" & m_key & "_played_" & event_key
    End Function

    Public Function ToYaml
        Dim yaml,evt
        yaml = yaml & "    events:" & vbCrLf
        For Each evt in m_events.Keys
            yaml = yaml & "      " & evt & ": " & m_weights(evt) & vbCrLf
        Next
        yaml = yaml & "    scope: " & m_scope & vbCrLf
        ToYaml = yaml

    End Function

End Class