' Carousel: a mode that lets the player step through a list of items and select one.
' After MPF's carousel mode. Used for mode select screens, attract screens and menus.
'
' Any mode becomes a carousel by configuring its .Carousel(). While the mode runs,
' one item is highlighted. Events move the highlight forwards and backwards, and an
' event selects the highlighted item. What an item means is up to the table: start a
' mode on carousel_item_selected, show a slide on carousel_item_highlighted.

Class GlfCarousel

    Private m_name
    Private m_carousel_name
    Private m_priority
    Private m_base_device
    Private m_debug

    Private m_all_items
    Private m_select_item_events
    Private m_next_item_events
    Private m_previous_item_events
    Private m_block_events
    Private m_release_events
    Private m_wrap_items

    Private m_items
    Private m_highlighted_item_index
    Private m_done
    Private m_is_blocking
    Private m_running

    Public Property Get Name() : Name = m_name : End Property
    Public Property Get Mode() : Set Mode = m_base_device.Mode : End Property

    ' The name of the highlighted item, or "" when the carousel is not running
    Public Property Get HighlightedItem()
        HighlightedItem = ""
        If m_running Then
            HighlightedItem = m_items(m_highlighted_item_index)
        End If
    End Property

    Public Property Get GetValue(value)
        Select Case value
            Case "highlighted_item"
                GetValue = HighlightedItem
            Case "done"
                GetValue = m_done
        End Select
    End Property

    ' Item names. An item may carry a condition, "bonus_round{current_player.level>2}",
    ' and is then only offered when the condition is true as the mode starts.
    Public Property Let SelectableItems(value)
        Dim x
        m_all_items = Array()
        For x = 0 To UBound(value)
            ReDim Preserve m_all_items(x)
            Set m_all_items(x) = (new GlfEvent)(value(x))
        Next
    End Property
    Public Property Let SelectItemEvents(value) : AddGlfEvents m_select_item_events, value : End Property
    Public Property Let NextItemEvents(value) : AddGlfEvents m_next_item_events, value : End Property
    Public Property Let PreviousItemEvents(value) : AddGlfEvents m_previous_item_events, value : End Property
    Public Property Let BlockEvents(value) : AddGlfEvents m_block_events, value : End Property
    Public Property Let ReleaseEvents(value) : AddGlfEvents m_release_events, value : End Property
    Public Property Let WrapItems(value) : m_wrap_items = value : End Property

    Public Property Let Debug(value)
        m_debug = value
        m_base_device.Debug = value
    End Property
    Public Property Get IsDebug()
        If m_debug Then : IsDebug = 1 : Else : IsDebug = 0 : End If
    End Property

	Public default Function init(mode)
        m_carousel_name = mode.ModeName
        m_name = "carousel_" & mode.ModeName
        m_priority = mode.Priority
        m_debug = False
        m_all_items = Array()
        Set m_select_item_events = CreateObject("Scripting.Dictionary")
        Set m_next_item_events = CreateObject("Scripting.Dictionary")
        Set m_previous_item_events = CreateObject("Scripting.Dictionary")
        Set m_block_events = CreateObject("Scripting.Dictionary")
        Set m_release_events = CreateObject("Scripting.Dictionary")
        m_wrap_items = True
        m_items = Array()
        m_highlighted_item_index = 0
        m_done = False
        m_is_blocking = False
        m_running = False
        Set m_base_device = (new GlfBaseModeDevice)(mode, "carousel", Me)
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

    Private Sub AddHandlers(dict, action, priority_bump)
        Dim evt
        For Each evt in dict.Keys
            AddPinEventListener dict(evt).EventName, m_name & "_" & evt & "_" & action, "CarouselEventHandler", m_priority+dict(evt).Priority+priority_bump, Array(action, Me, dict(evt))
        Next
    End Sub

    Private Sub RemoveHandlers(dict, action)
        Dim evt
        For Each evt in dict.Keys
            RemovePinEventListener dict(evt).EventName, m_name & "_" & evt & "_" & action
        Next
    End Sub

    ' Called by the base mode device when the mode starts
    Public Sub Activate()
        Dim x
        m_running = False
        m_items = Array()
        For x = 0 To UBound(m_all_items)
            If m_all_items(x).Evaluate() Then
                ReDim Preserve m_items(UBound(m_items) + 1)
                m_items(UBound(m_items)) = m_all_items(x).EventName
            End If
        Next
        If UBound(m_all_items) = -1 Then
            ' Nothing to choose from: the mode runs as a plain mode
            Exit Sub
        End If
        If UBound(m_items) = -1 Then
            Log "Every item's condition is false. Stopping."
            Dim kwargs : Set kwargs = GlfKwargs()
            kwargs.Add "carousel", m_carousel_name
            Glf_BcpSendEvent "carousel_items_empty", kwargs
            DispatchPinEvent "carousel_items_empty", kwargs
            m_base_device.Mode.StopMode
            Exit Sub
        End If

        m_running = True
        m_done = False
        m_is_blocking = False
        AddHandlers m_next_item_events, "next", 0
        AddHandlers m_previous_item_events, "previous", 0
        AddHandlers m_select_item_events, "select", 0
        AddHandlers m_block_events, "block", 100
        AddHandlers m_release_events, "release", 100
        m_highlighted_item_index = 0
        UpdateHighlightedItem Null
    End Sub

    ' Called by the base mode device when the mode stops
    Public Sub Deactivate()
        RemoveHandlers m_next_item_events, "next"
        RemoveHandlers m_previous_item_events, "previous"
        RemoveHandlers m_select_item_events, "select"
        RemoveHandlers m_block_events, "block"
        RemoveHandlers m_release_events, "release"
        m_running = False
    End Sub

    Public Sub Enable()
    End Sub

    Public Sub Disable()
    End Sub

    Private Sub UpdateHighlightedItem(direction)
        Dim item : item = m_items(m_highlighted_item_index)
        Log "Highlighted item: " & item
        Dim kwargs : Set kwargs = GlfKwargs()
        kwargs.Add "carousel", m_carousel_name
        kwargs.Add "direction", direction
        kwargs.Add "item", item
        Glf_BcpSendEvent "carousel_item_highlighted", kwargs
        DispatchPinEvent "carousel_item_highlighted", kwargs
        ' The same thing with the names in the event, which is easier to hang a player on
        DispatchPinEvent m_carousel_name & "_" & item & "_highlighted", kwargs
    End Sub

    Public Sub NextItem()
        If Not m_running Or m_done Or m_is_blocking Then
            Exit Sub
        End If
        m_highlighted_item_index = m_highlighted_item_index + 1
        If m_highlighted_item_index > UBound(m_items) Then
            If Not m_wrap_items Then
                m_highlighted_item_index = m_highlighted_item_index - 1
                Exit Sub
            End If
            m_highlighted_item_index = 0
        End If
        UpdateHighlightedItem "forwards"
    End Sub

    Public Sub PreviousItem()
        If Not m_running Or m_done Or m_is_blocking Then
            Exit Sub
        End If
        m_highlighted_item_index = m_highlighted_item_index - 1
        If m_highlighted_item_index < 0 Then
            If Not m_wrap_items Then
                m_highlighted_item_index = 0
                Exit Sub
            End If
            m_highlighted_item_index = UBound(m_items)
        End If
        UpdateHighlightedItem "backwards"
    End Sub

    Public Sub SelectItem()
        If Not m_running Or m_done Then
            Exit Sub
        End If
        Dim item : item = m_items(m_highlighted_item_index)
        Log "Selected item: " & item
        m_done = True
        Dim kwargs : Set kwargs = GlfKwargs()
        kwargs.Add "carousel", m_carousel_name
        kwargs.Add "item", item
        Glf_BcpSendEvent "carousel_item_selected", kwargs
        DispatchPinEvent "carousel_item_selected", kwargs
        DispatchPinEvent m_carousel_name & "_" & item & "_selected", kwargs
    End Sub

    ' While blocked the highlight does not move. Selecting still works.
    Public Sub Block()
        m_is_blocking = True
    End Sub

    Public Sub Release()
        m_is_blocking = False
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

    ' Lines for the mode_settings section of the exported mode
    Public Function ModeSettingsYaml()
        Dim yaml, x
        yaml = ""
        If UBound(m_all_items) > -1 Then
            yaml = yaml & "  selectable_items: "
            For x = 0 To UBound(m_all_items)
                yaml = yaml & Replace(Replace(m_all_items(x).Raw, "&&", "and"), "||", "or")
                If x <> UBound(m_all_items) Then
                    yaml = yaml & ", "
                End If
            Next
            yaml = yaml & vbCrLf
        End If
        If UBound(m_select_item_events.Keys) > -1 Then
            yaml = yaml & "  select_item_events: " & EventsYaml(m_select_item_events) & vbCrLf
        End If
        If UBound(m_next_item_events.Keys) > -1 Then
            yaml = yaml & "  next_item_events: " & EventsYaml(m_next_item_events) & vbCrLf
        End If
        If UBound(m_previous_item_events.Keys) > -1 Then
            yaml = yaml & "  previous_item_events: " & EventsYaml(m_previous_item_events) & vbCrLf
        End If
        If UBound(m_block_events.Keys) > -1 Then
            yaml = yaml & "  block_events: " & EventsYaml(m_block_events) & vbCrLf
        End If
        If UBound(m_release_events.Keys) > -1 Then
            yaml = yaml & "  release_events: " & EventsYaml(m_release_events) & vbCrLf
        End If
        If m_wrap_items = False Then
            yaml = yaml & "  wrap_items: false" & vbCrLf
        End If
        ModeSettingsYaml = yaml
    End Function
End Class

Function CarouselEventHandler(args)
    Dim ownProps, kwargs : ownProps = args(0)
    If IsObject(args(1)) Then
        Set kwargs = args(1)
    Else
        kwargs = args(1)
    End If
    Dim evt : evt = ownProps(0)
    Dim carousel : Set carousel = ownProps(1)
    If ownProps(2).Evaluate() Then
        Select Case evt
            Case "next"
                carousel.NextItem
            Case "previous"
                carousel.PreviousItem
            Case "select"
                carousel.SelectItem
            Case "block"
                carousel.Block
            Case "release"
                carousel.Release
        End Select
    End If
    If IsObject(args(1)) Then
        Set CarouselEventHandler = kwargs
    Else
        CarouselEventHandler = kwargs
    End If
End Function
