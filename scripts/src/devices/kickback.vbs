' Kickback: fires a ball back into play when its switch is hit, while it is enabled.
' After MPF's kickback device, which is an autofire coil that also posts an event
' each time it fires.

Dim glf_kickbacks : Set glf_kickbacks = CreateObject("Scripting.Dictionary")

Function CreateGlfKickback(name)
	Dim kickback : Set kickback = (new GlfKickback)(name)
	Set CreateGlfKickback = kickback
End Function

Class GlfKickback

    Private m_name
    Private m_device_name
    Private m_enable_events
    Private m_disable_events
    Private m_enabled
    Private m_switch
    Private m_action_cb
    Private m_disabled_cb
    Private m_enabled_cb
    Private m_debug

    Public Property Get Name() : Name = m_name : End Property
    Public Property Get Enabled() : Enabled = m_enabled : End Property
    Public Property Get GetValue(value)
        Select Case value
            Case "enabled"
                GetValue = m_enabled
        End Select
    End Property

    Public Property Let Switch(value)
        If m_enabled = True Then
            RemoveSwitchListeners()
        End If
        m_switch = value
        If m_enabled = True Then
            AddSwitchListeners()
        End If
    End Property
    ' Called with Array(1, ball) when the kickback fires and Array(0, ball) when the ball has left
    Public Property Let ActionCallback(value) : m_action_cb = value : End Property
    Public Property Let DisabledCallback(value) : m_disabled_cb = value : End Property
    Public Property Let EnabledCallback(value) : m_enabled_cb = value : End Property
    Public Property Let EnableEvents(value)
        Dim evt
        If IsArray(m_enable_events) Then
            For Each evt in m_enable_events
                RemovePinEventListener evt, m_name & "_enable"
            Next
        End If
        m_enable_events = value
        For Each evt in m_enable_events
            AddPinEventListener evt, m_name & "_enable", "KickbackEventHandler", 1000, Array("enable", Me)
        Next
    End Property
    Public Property Let DisableEvents(value)
        Dim evt
        If IsArray(m_disable_events) Then
            For Each evt in m_disable_events
                RemovePinEventListener evt, m_name & "_disable"
            Next
        End If
        m_disable_events = value
        For Each evt in m_disable_events
            AddPinEventListener evt, m_name & "_disable", "KickbackEventHandler", 1000, Array("disable", Me)
        Next
    End Property
    Public Property Let Debug(value) : m_debug = value : End Property

	Public default Function init(name)
        m_name = "kickback_" & name
        m_device_name = name
        m_enabled = False
        m_action_cb = Empty
        m_disabled_cb = Empty
        m_enabled_cb = Empty
        m_switch = Empty
        m_debug = False
        m_enable_events = Empty
        m_disable_events = Empty
        ' A kickback is switched on by the table's rules, so it has no enable events until given some
        DisableEvents = Array("ball_will_end", "service_mode_entered")
        glf_kickbacks.Add name, Me
        Set Init = Me
	End Function

    Private Sub AddSwitchListeners()
        If Not IsEmpty(m_switch) Then
            AddPinEventListener m_switch & "_active", m_name & "_active", "KickbackEventHandler", 1000, Array("activate", Me)
            AddPinEventListener m_switch & "_inactive", m_name & "_inactive", "KickbackEventHandler", 1000, Array("deactivate", Me)
        End If
    End Sub

    Private Sub RemoveSwitchListeners()
        If Not IsEmpty(m_switch) Then
            RemovePinEventListener m_switch & "_active", m_name & "_active"
            RemovePinEventListener m_switch & "_inactive", m_name & "_inactive"
        End If
    End Sub

    Public Sub Enable()
        If m_enabled = True Then
            Exit Sub
        End If
        Log "Enabling"
        m_enabled = True
        If Not IsEmpty(m_enabled_cb) Then
            GetRef(m_enabled_cb)(Null)
        End If
        AddSwitchListeners()
        DispatchPinEvent m_name & "_enabled", Null
    End Sub

    Public Sub Disable()
        If m_enabled = False Then
            Exit Sub
        End If
        Log "Disabling"
        m_enabled = False
        If Not IsEmpty(m_disabled_cb) Then
            GetRef(m_disabled_cb)(Null)
        End If
        RemoveSwitchListeners()
        DispatchPinEvent m_name & "_disabled", Null
    End Sub

    ' The switch was hit while the kickback is enabled
    Public Sub Activate(active_ball)
        Log "Firing"
        If Not IsEmpty(m_action_cb) Then
            GetRef(m_action_cb)(Array(1, active_ball))
        End If
        Glf_BcpSendEvent m_name & "_fired", Null
        DispatchPinEvent m_name & "_fired", Null
    End Sub

    Public Sub Deactivate(active_ball)
        If Not IsEmpty(m_action_cb) Then
            GetRef(m_action_cb)(Array(0, active_ball))
        End If
    End Sub

    Private Sub Log(message)
        If m_debug = True Then
            glf_debugLog.WriteToLog m_name, message
        End If
    End Sub

    Public Function ToYaml()
        Dim yaml
        yaml = "  " & m_device_name & ":" & vbCrLf
        yaml = yaml & "    coil: c_" & m_name & vbCrLf
        yaml = yaml & "    switch: " & m_switch & vbCrLf
        If IsArray(m_enable_events) Then
            yaml = yaml & "    enable_events: " & Join(m_enable_events, ", ") & vbCrLf
        End If
        If IsArray(m_disable_events) Then
            yaml = yaml & "    disable_events: " & Join(m_disable_events, ", ") & vbCrLf
        End If
        ToYaml = yaml
    End Function
End Class

Function KickbackEventHandler(args)
    Dim ownProps, kwargs : ownProps = args(0)
    If IsObject(args(1)) Then
        Set kwargs = args(1)
    Else
        kwargs = args(1)
    End If
    Dim evt : evt = ownProps(0)
    Dim kickback : Set kickback = ownProps(1)
    Select Case evt
        Case "enable"
            kickback.Enable
        Case "disable"
            kickback.Disable
        Case "activate"
            kickback.Activate kwargs
        Case "deactivate"
            kickback.Deactivate kwargs
    End Select
    If IsObject(args(1)) Then
        Set KickbackEventHandler = kwargs
    Else
        KickbackEventHandler = kwargs
    End If
End Function
