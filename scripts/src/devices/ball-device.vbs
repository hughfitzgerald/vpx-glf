Function CreateGlfBallDevice(name)
	Dim device : Set device = (new GlfBallDevice)(name)
	Set CreateGlfBallDevice = device
End Function

Class GlfBallDevice

    Private m_name
    Private m_ball_switches
    Private m_player_controlled_eject_event
    Private m_eject_timeout
    Private m_eject_enable_time
    Private m_balls
    Private m_balls_in_device
    Private m_default_device
    Private m_eject_callback
    Private m_eject_all_events
    Private m_eject_events
    Private m_balls_to_eject
    Private m_ejecting_all
    Private m_ejecting
    Private m_mechanical_eject
    Private m_eject_targets
    Private m_entrance_count_delay
    Private m_incoming_balls
    Private m_entering
    Private m_empty_eject_retries
    Private m_lost_balls
    Private m_claimed_balls
    Private m_eject_requested
    Private m_exclude_from_ball_search
    Private m_auto_fire_on_unexpected_ball
    Private m_debug

    Public Property Get Name(): Name = m_name : End Property
    Public Property Get GetValue(value)
        Select Case value
            Case "balls":
                GetValue = m_balls_in_device
        End Select
    End Property
    Public Property Let DefaultDevice(value)
        m_default_device = value
        If m_default_device = True Then
            Set glf_plunger = Me
        End If
    End Property
	Public Property Get HasBall()
        HasBall = (Not IsNull(m_balls(0)) And m_ejecting = False)
    End Property
    
    Public Property Get Balls(): Balls = m_balls_in_device : End Property
    Public Property Get Capacity(): Capacity = UBound(m_ball_switches) + 1 : End Property

    Public Property Let AddIncomingBalls(value) : m_incoming_balls = m_incoming_balls + value : End Property
    Public Property Get IncomingBalls() : IncomingBalls = m_incoming_balls : End Property

    Public Property Let EjectCallback(value) : m_eject_callback = value : End Property
    Public Property Let EjectEnableTime(value) : m_eject_enable_time = value : End Property
        
    Public Property Let EjectTimeout(value) : m_eject_timeout = value : End Property
    Public Property Let EntranceCountDelay(value) : m_entrance_count_delay = value : End Property
    Public Property Let EjectAllEvents(value)
        m_eject_all_events = value
        Dim evt
        For Each evt in m_eject_all_events
            AddPinEventListener evt, m_name & "_eject_all", "BallDeviceEventHandler", 1000, Array("ball_eject_all", Me)
        Next
    End Property
    Public Property Let EjectEvents(value)
        m_eject_events = value
        Dim evt
        For Each evt in m_eject_events
            AddPinEventListener evt, m_name & "_eject_one", "BallDeviceEventHandler", 1000, Array("ball_eject", Me)
        Next
    End Property
    Public Property Let EjectTargets(value)
        m_eject_targets = value
        Dim evt
        For Each evt in m_eject_targets
            AddPinEventListener evt & "_active", m_name & "_eject_target", "BallDeviceEventHandler", 1000, Array("eject_target", Me)
        Next
    End Property
    Public Property Let PlayerControlledEjectEvent(value)
        m_player_controlled_eject_event = value
        AddPinEventListener m_player_controlled_eject_event, m_name & "_eject_attempt", "BallDeviceEventHandler", 1000, Array("ball_eject", Me)
    End Property
    Public Property Let BallSwitches(value)
        m_ball_switches = value
        ReDim m_balls(Ubound(m_ball_switches))
        ReDim m_entering(Ubound(m_ball_switches))
        Dim x
        For x=0 to UBound(m_ball_switches)
            m_balls(x) = Null
            m_entering(x) = False
            AddPinEventListener m_ball_switches(x)&"_active", m_name & "_ball_enter", "BallDeviceEventHandler", 1000, Array("ball_entering", Me, x)
            AddPinEventListener m_ball_switches(x)&"_inactive", m_name & "_ball_exiting", "BallDeviceEventHandler", 1000, Array("ball_exiting", Me, x)
        Next
    End Property
    Public Property Let MechanicalEject(value) : m_mechanical_eject = value : End Property
    Public Property Let ExcludeFromBallSearch(value) : m_exclude_from_ball_search = value : End Property
    Public Property Let AutoFireOnUnexpectedBall(value) : m_auto_fire_on_unexpected_ball = value : End Property
    Public Property Get AutoFireOnUnexpectedBall(): AutoFireOnUnexpectedBall = m_auto_fire_on_unexpected_ball : End Property

    Public Property Let Debug(value) : m_debug = value : End Property
        
	Public default Function init(name)
        m_name = "balldevice_" & name
        m_ball_switches = Array()
        m_eject_all_events = Array()
        m_eject_events = Array()
        m_eject_targets = Array()
        m_balls = Array()
        m_debug = False
        m_default_device = False
        m_ejecting = False
        m_eject_callback = Null
        m_ejecting_all = False
        m_balls_to_eject = 0
        m_balls_in_device = 0
        m_lost_balls = 0
        m_claimed_balls = 0
        m_eject_requested = False
        m_mechanical_eject = False
        m_eject_timeout = 1000
        m_eject_enable_time = 0
        m_entrance_count_delay = 500
        m_incoming_balls = 0
        m_entering = Array()
        m_empty_eject_retries = 0
        m_exclude_from_ball_search = False
        m_auto_fire_on_unexpected_ball = True
        glf_ball_devices.Add name, Me
	    Set Init = Me
	End Function

    Public Sub BallEntering(ball, switch)
        Log "Ball Entering" 
        If m_default_device = False Then
            m_entering(switch) = True
            SetDelay m_name & "_" & switch & "_ball_enter", "BallDeviceEventHandler", Array(Array("ball_enter", Me, switch), ball), m_entrance_count_delay
        Else
            BallEnter ball, switch
        End If
    End Sub

    Public Sub BallEnterCancelled(switch)
        'The ball left again before the entrance count delay ran out
        m_entering(switch) = False
    End Sub

    Private Function BallsEntering()
        Dim x : BallsEntering = 0
        For x = 0 to UBound(m_entering)
            If m_entering(x) = True Then
                BallsEntering = BallsEntering + 1
            End If
        Next
    End Function

    Public Sub BallEnter(ball, switch)
        m_entering(switch) = False
        RemoveDelay m_name & "_switch" & switch & "_eject_timeout"
        If m_ejecting = True And switch = 0 Then
            'A ball is back on the eject switch before the eject was confirmed, so that eject is over.
            'Without this the device stays in its ejecting state and HasBall never returns True again.
            m_ejecting = False
            Log "Eject failed, ball returned"
            DispatchPinEvent m_name & "_ball_eject_failed", Null
        End If
        If switch = 0 Then
            'Any eject from this switch is over once a ball is back on it
            m_eject_requested = False
        End If
        Set m_balls(switch) = ball
        m_balls_in_device = m_balls_in_device + 1
        Log "Ball Entered"
        If m_lost_balls > 0 Then
            m_lost_balls = m_lost_balls - 1
            Log "Lost Ball Found"
            If m_lost_balls = 0 Then
                RemoveDelay m_name & "_clear_lost_balls"
            End If
            Exit Sub
        End If

        Dim unclaimed_balls: unclaimed_balls = 1
        If m_incoming_balls > 0 Then
            unclaimed_balls = 0
        End If
        If unclaimed_balls > 0 Then
            unclaimed_balls = DispatchRelayPinEvent(m_name & "_ball_enter", 1)
            If unclaimed_balls < 1 Then
                'A ball hold or multiball lock is keeping this ball
                m_claimed_balls = m_claimed_balls + 1
                If m_claimed_balls > m_balls_in_device Then
                    m_claimed_balls = m_balls_in_device
                End If
            End If
        End If        
        Log "Unclaimed Balls: " & unclaimed_balls
        DispatchPinEvent m_name & "_ball_entered", Null
        If unclaimed_balls > 0 And m_auto_fire_on_unexpected_ball = True Then
            SetDelay m_name & "_eject_attempt", "BallDeviceEventHandler", Array(Array("ball_eject", Me), ball), 500
        End If
    End Sub

    Public Sub BallExiting(ball, switch)
        RemoveDelay m_name & "_" & switch & "_ball_enter"
        If m_ejecting = False And m_mechanical_eject = False Then
            Log "Ball Lost, Wasn't Ejecting"
            m_lost_balls = m_lost_balls + 1
            SetDelay m_name & "_clear_lost_balls", "BallDeviceEventHandler", Array(Array("clear_lost_balls", Me), Null), 3000
        End If
        m_balls(switch) = Null
        m_balls_in_device = m_balls_in_device - 1
        DispatchPinEvent m_name & "_ball_exiting", Null
        If m_mechanical_eject = True And m_eject_timeout > 0 Then
            SetDelay m_name & "_switch" & switch & "_eject_timeout", "BallDeviceEventHandler", Array(Array("eject_timeout", Me), ball), m_eject_timeout
        End If
        Log "Ball Exiting"
    End Sub

    Public Sub BallExitSuccess(ball)
        m_ejecting = False
        If m_eject_requested = False Then
            'A ball left that GLF did not eject. If it was one a hold or lock was keeping, report it.
            Dim claimed_lost : claimed_lost = LostClaimedBalls()
            If claimed_lost > 0 Then
                PostBallMissing claimed_lost, claimed_lost
            End If
        Else
            'GLF ejected the ball, so nothing is missing. Just keep the claimed count in step.
            LostClaimedBalls
        End If
        m_eject_requested = False

        If m_incoming_balls > 0 Then
            m_incoming_balls = m_incoming_balls - 1
        End If
        DispatchPinEvent m_name & "_ball_eject_success", Null
        Log "Ball successfully exited"
        RemoveDelay m_name & "_eject_attempt"
        If m_ejecting_all = True Then
            If m_balls_to_eject <= 0 Then
                m_ejecting_all = False
                m_balls_to_eject = 0
                Exit Sub
            End If
            If Not IsNull(m_balls(0)) Then
                m_balls_to_eject = m_balls_to_eject - 1
                Eject()
            Else
                SetDelay m_name & "_eject_attempt", "BallDeviceEventHandler", Array(Array("ball_eject", Me), ball), 600
            End If
        End If
    End Sub

    Public Sub EjectTargetHit(ball)
        'An eject target switch confirms an eject early. Ignore it unless a ball is on its way out,
        'and cancel the pending timeout so the same eject is not confirmed twice.
        Dim x, pending : pending = False
        For x = 0 to UBound(m_ball_switches)
            If RemoveDelay(m_name & "_switch" & x & "_eject_timeout") = True Then
                pending = True
            End If
        Next
        If m_ejecting = True Or pending = True Then
            BallExitSuccess ball
        End If
    End Sub

    Public Sub Eject
        m_empty_eject_retries = 0
        DoEject
    End Sub

    'Called 600ms after an eject request found no ball on the eject switch.
    Public Sub EjectRetry
        If m_balls_in_device = 0 And BallsEntering() = 0 And m_incoming_balls = 0 Then
            'Nothing here and nothing on its way. Allow a few seconds for a ball that is
            'about to arrive, then drop the request so it cannot eject some later ball.
            m_empty_eject_retries = m_empty_eject_retries + 1
            If m_empty_eject_retries >= 5 Then
                Log "Eject request dropped, device is empty"
                m_empty_eject_retries = 0
                m_ejecting_all = False
                m_balls_to_eject = 0
                Exit Sub
            End If
        Else
            m_empty_eject_retries = 0
        End If
        DoEject
    End Sub

    Private Sub DoEject
        If Not IsNull(m_eject_callback) Then
            If Not IsNull(m_balls(0)) Then
                Log "Ejecting."
                m_empty_eject_retries = 0
                DispatchPinEvent m_name & "_ejecting_ball", Null
                DispatchQueuePinEvent m_name & "_ball_eject_attempt", Null
                SetDelay m_name & "_switch0_eject_timeout", "BallDeviceEventHandler", Array(Array("eject_timeout", Me), m_balls(0)), m_eject_timeout
                m_ejecting = True
                m_eject_requested = True
                If m_claimed_balls > 0 Then
                    m_claimed_balls = m_claimed_balls - 1
                End If
            
                GetRef(m_eject_callback)(m_balls(0))
                If m_eject_enable_time > 0 Then
                    SetDelay m_name & "_eject_enable_time", "BallDeviceEventHandler", Array(Array("eject_enable_complete", Me), m_balls(0)), m_eject_enable_time
                End If
            Else
                SetDelay m_name & "_eject_attempt", "BallDeviceEventHandler", Array(Array("ball_eject_retry", Me), Null), 600
            End If
        End If
    End Sub

    Public Sub EjectEnableComplete
        If Not IsNull(m_eject_callback) Then
            GetRef(m_eject_callback)(Null)
        End If
    End Sub

    Public Sub EjectBalls(balls)
        Log "Ejecting "&balls&" Balls."
        If balls <= 0 Then
            Exit Sub
        End If
        m_ejecting_all = True
        m_balls_to_eject = balls - 1
        Eject()
    End Sub

    Public Sub EjectAll
        Log "Ejecting All." 
        m_ejecting_all = True
        'Count a ball that has hit the switch but is still inside its entrance count delay
        m_balls_to_eject = m_balls_in_device + BallsEntering() - 1
        If m_balls_to_eject < 0 Then
            m_balls_to_eject = 0
        End If
        Eject()
    End Sub

    Public Sub ClearLostBalls()
        'The balls that left without being ejected did not come back
        Dim lost : lost = m_lost_balls
        m_lost_balls = 0
        If lost > 0 Then
            PostBallMissing lost, LostClaimedBalls()
        End If
    End Sub

    'Number of balls a hold or lock was keeping that are no longer in the device
    Private Function LostClaimedBalls()
        LostClaimedBalls = 0
        If m_claimed_balls > m_balls_in_device Then
            LostClaimedBalls = m_claimed_balls - m_balls_in_device
            m_claimed_balls = m_balls_in_device
        End If
    End Function

    Private Sub PostBallMissing(balls, claimed_balls)
        Log "Ball missing: " & balls & ", claimed: " & claimed_balls
        Dim kwargs : Set kwargs = GlfKwargs()
        With kwargs
            .Add "balls", balls
            .Add "claimed_balls", claimed_balls
        End With
        DispatchPinEvent m_name & "_ball_missing", kwargs
        If claimed_balls > 0 Then
            Glf_ClaimedBallMissing Replace(m_name, "balldevice_", "", 1, 1), claimed_balls
        End If
    End Sub

    Public Sub BallSearch(phase)
        If m_exclude_from_ball_search = True Then
            Exit Sub
        End If
        Log "Ball Search, phase " & phase
        If m_default_device = True Then
            Exit Sub
        End If
        If phase = 1 And HasBall() Then
            Exit Sub
        End If
        If m_balls_in_device > 0 Then
            If Glf_BallDeviceKeepsBalls(Replace(m_name, "balldevice_", "", 1, 1)) = True Then
                'A held or locked ball is not the missing one. Kicking it out would only put the counts wrong.
                Log "Ball Search skipped, device is holding or locking a ball"
                Exit Sub
            End If
        End If
        If Not IsNull(m_eject_callback) Then
            If Not IsNull(m_balls(0)) Then
                'Use a normal eject so the device knows the ball is leaving
                Eject()
            Else
                GetRef(m_eject_callback)(Null)
            End If
        End If
    End Sub

    Public Function ToYaml
        Dim yaml
        yaml = "  " & m_name & ":" & vbCrLf
        yaml = yaml + "    ball_switches: " & Join(m_ball_switches, ",") & vbCrLf
        yaml = yaml + "    mechanical_eject: " & m_mechanical_eject & vbCrLf
        
        ToYaml = yaml
    End Function

    Private Sub Log(message)
        If m_debug = True Then
            glf_debugLog.WriteToLog m_name, message
        End If
    End Sub
End Class

'A ball that a ball hold or multiball lock was keeping has left its device without being ejected.
'Held balls are still counted in glf_BIP, so the hold only lowers its own count. Locked balls are
'not counted in glf_BIP, so a locked ball that is back on the playfield is added to it.
Sub Glf_ClaimedBallMissing(device_name, balls)
    Dim ball_hold, multiball_lock, lock_device, is_lock_device
    For Each ball_hold in glf_ball_holds.Items()
        balls = balls - ball_hold.BallMissing(device_name)
    Next
    If balls <= 0 Then
        Exit Sub
    End If
    is_lock_device = False
    For Each multiball_lock in glf_multiball_locks.Items()
        For Each lock_device in multiball_lock.LockDevices
            If lock_device = device_name Then
                is_lock_device = True
            End If
        Next
    Next
    If is_lock_device = True And glf_gameStarted = True And glf_gameTilted = False And glf_BIP > 0 Then
        glf_BIP = glf_BIP + balls
        glf_debugLog.WriteToLog "Ball Device", "Locked ball left " & device_name & " without being ejected. BIP: " & glf_BIP
    End If
End Sub

'True if the named device belongs to a ball hold that is holding balls, or to a multiball lock.
Function Glf_BallDeviceKeepsBalls(device_name)
    Glf_BallDeviceKeepsBalls = False
    Dim ball_hold, multiball_lock, device
    For Each ball_hold in glf_ball_holds.Items()
        If ball_hold.GetValue("balls_held") > 0 Then
            For Each device in ball_hold.HoldDevices
                If device = device_name Then
                    Glf_BallDeviceKeepsBalls = True
                    Exit Function
                End If
            Next
        End If
    Next
    For Each multiball_lock in glf_multiball_locks.Items()
        For Each device in multiball_lock.LockDevices
            If device = device_name Then
                Glf_BallDeviceKeepsBalls = True
                Exit Function
            End If
        Next
    Next
End Function

Function BallDeviceEventHandler(args)
    Dim ownProps, ball
    ownProps = args(0)
    Dim evt : evt = ownProps(0)
    Dim ballDevice : Set ballDevice = ownProps(1)
    Dim switch
    'debug.print "Ball Device: " & ballDevice.Name & ". Event: " & evt
    Select Case evt
        Case "ball_entering"
            Set ball = args(1)
            switch = ownProps(2)
            ballDevice.BallEntering ball, switch
        Case "ball_enter"
            Set ball = args(1)
            switch = ownProps(2)
            ballDevice.BallEnter ball, switch
        Case "ball_eject"
            ballDevice.Eject
        Case "ball_eject_retry"
            ballDevice.EjectRetry
        Case "ball_eject_all"
            ballDevice.EjectAll
        Case "ball_exiting"
            switch = ownProps(2)
            If RemoveDelay(ballDevice.Name & "_" & switch & "_ball_enter") = False Then
                Set ball = args(1)
                ballDevice.BallExiting ball, switch
            Else
                ballDevice.BallEnterCancelled switch
            End If
        Case "eject_timeout"
            Set ball = args(1)
            ballDevice.BallExitSuccess ball
        Case "eject_target"
            Set ball = args(1)
            ballDevice.EjectTargetHit ball
        Case "eject_enable_complete"
            ballDevice.EjectEnableComplete
        Case "clear_lost_balls"
            ballDevice.ClearLostBalls
    End Select
End Function