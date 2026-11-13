'*******************************************
'  Virtual table: balls, trough, devices and the ball router
'*******************************************
' GLF talks to the table in three ways, and each is replaced here by script:
'
'   1. Trough kickers. GLF calls swTrough1..N and Drain by name (.BallCntOver,
'      .Kick, .CreateSizedballWithMass). Those names are TbKicker objects.
'   2. Switches. GLF ball devices listen for <switch>_active / _inactive
'      events. TbDevice posts them when a ball arrives or leaves.
'   3. Eject callbacks. GLF calls TB_Eject_<device>(ball). The router takes the
'      ball and delivers it wherever the test has routed that device.
'
' A ball is always in exactly one place, held in its .Where:
'   a kicker name, a device name, "pen" (in play on the playfield),
'   "transit" (in play, on its way somewhere), "trough_transit", or "void".

Dim tb_balls    : Set tb_balls    = CreateObject("Scripting.Dictionary")   'id -> TbBall
Dim tb_kickers  : Set tb_kickers  = CreateObject("Scripting.Dictionary")   'name -> TbKicker
Dim tb_devices  : Set tb_devices  = CreateObject("Scripting.Dictionary")   'GLF device name -> TbDevice
Dim tb_routes   : Set tb_routes   = CreateObject("Scripting.Dictionary")   'device name -> destination
Dim tb_routes_once : Set tb_routes_once = CreateObject("Scripting.Dictionary")
Dim tb_sched    : Set tb_sched    = CreateObject("Scripting.Dictionary")   'seq -> Array(due, action, arg1, arg2)
Dim tb_sched_seq : tb_sched_seq = 0
Dim tb_ball_seq  : tb_ball_seq = 0


'----- Scheduler (independent of GLF's own delay queue) -----

Sub TB_After(ms, action, arg1, arg2)
    tb_sched_seq = tb_sched_seq + 1
    tb_sched.Add tb_sched_seq, Array(gametime + ms, action, arg1, arg2)
End Sub

Sub TB_SchedTick()
    Dim key, item, action
    For Each key In tb_sched.Keys()
        If tb_sched.Exists(key) Then
            item = tb_sched(key)
            If item(0) <= gametime Then
                tb_sched.Remove key
                Set action = GetRef(item(1))
                action item(2), item(3)
            End If
        End If
    Next
End Sub


'----- Balls -----

Class TbBall
    Public ID
    Public Where
    'GLF only passes balls around, but give them the usual properties in case
    Public X, Y, Z, VelX, VelY, VelZ, Radius, Mass
End Class

Function TB_NewBall(where)
    Dim ball : Set ball = New TbBall
    tb_ball_seq = tb_ball_seq + 1
    ball.ID = tb_ball_seq
    ball.Where = where
    ball.X = 0 : ball.Y = 0 : ball.Z = 25
    ball.VelX = 0 : ball.VelY = 0 : ball.VelZ = 0
    ball.Radius = BallSize / 2 : ball.Mass = BallMass
    tb_balls.Add ball.ID, ball
    Set TB_NewBall = ball
End Function

'Number of balls whose .Where is the given place
Function TB_CountWhere(where)
    Dim ball, total
    total = 0
    For Each ball In tb_balls.Items()
        If ball.Where = where Then
            total = total + 1
        End If
    Next
    TB_CountWhere = total
End Function

Function TB_PenCount()
    TB_PenCount = TB_CountWhere("pen")
End Function

'One ball that is in play on the playfield, or Nothing
Function TB_PenTake()
    Dim ball
    Set TB_PenTake = Nothing
    For Each ball In tb_balls.Items()
        If ball.Where = "pen" Then
            Set TB_PenTake = ball
            Exit Function
        End If
    Next
End Function

Function TB_TroughCount()
    Dim kicker, total
    total = 0
    For Each kicker In tb_kickers.Items()
        If kicker.Name <> "Drain" Then
            total = total + kicker.BallCntOver
        End If
    Next
    TB_TroughCount = total
End Function

'Balls that are in the trough, in the drain, or rolling between them
Function TB_HomeCount()
    TB_HomeCount = TB_TroughCount() + Drain.BallCntOver + TB_CountWhere("trough_transit")
End Function


'----- Trough kickers -----

Class TbKicker
    Public Name
    Private m_ball

    Public Default Function init(kicker_name)
        Name = kicker_name
        m_ball = Null
        tb_kickers.Add kicker_name, Me
        Set init = Me
    End Function

    Public Property Get BallCntOver()
        If IsNull(m_ball) Then
            BallCntOver = 0
        Else
            BallCntOver = 1
        End If
    End Property

    Public Property Get X() : X = 0 : End Property
    Public Property Get Y() : Y = 0 : End Property

    'GLF calls these two at start-up to fill the trough
    Public Sub DestroyBall()
        If Not IsNull(m_ball) Then
            tb_balls.Remove m_ball.ID
        End If
        m_ball = Null
    End Sub

    Public Function CreateSizedballWithMass(radius, mass)
        Set m_ball = TB_NewBall(Name)
        Set CreateSizedballWithMass = m_ball
    End Function

    Public Sub Kick(angle, speed)
        If IsNull(m_ball) Then
            Exit Sub
        End If
        Dim ball : Set ball = m_ball
        m_ball = Null
        TB_CallIfExists Name & "_UnHit"
        TB_KickerKicked Name, ball
    End Sub

    'A ball rolls in. Returns False if the kicker is occupied.
    Public Function Receive(ball)
        If Not IsNull(m_ball) Then
            Receive = False
            Exit Function
        End If
        Set m_ball = ball
        ball.Where = Name
        TB_CallIfExists Name & "_Hit"
        Receive = True
    End Function

    'Test reset only: place or remove a ball without telling GLF
    Public Sub ForceBall(ball)
        Set m_ball = ball
        ball.Where = Name
    End Sub
    Public Sub ForceEmpty()
        m_ball = Null
    End Sub
End Class

Dim swTrough1, swTrough2, swTrough3, swTrough4, swTrough5, Drain
Set swTrough1 = (New TbKicker)("swTrough1")
Set swTrough2 = (New TbKicker)("swTrough2")
Set swTrough3 = (New TbKicker)("swTrough3")
Set swTrough4 = (New TbKicker)("swTrough4")
Set swTrough5 = (New TbKicker)("swTrough5")
Set Drain     = (New TbKicker)("Drain")

'Calls a Sub by name if the script has one (GLF defines swTroughN_Hit, Drain_Hit and so on)
Sub TB_CallIfExists(sub_name)
    Dim handler, found
    found = False
    On Error Resume Next
    Set handler = GetRef(sub_name)
    If Err.Number = 0 Then
        found = True
    End If
    Err.Clear
    On Error Goto 0
    If found = True Then
        Call handler()
    End If
End Sub

'Where a ball kicked out of a trough kicker rolls to
Sub TB_KickerKicked(kicker_name, ball)
    Dim dest
    If kicker_name = "Drain" Then
        dest = "swTrough" & tnob
        ball.Where = "trough_transit"
    ElseIf kicker_name = "swTrough1" Then
        dest = "@plunger"
        ball.Where = "transit"
    Else
        dest = "swTrough" & (CInt(Mid(kicker_name, 9)) - 1)
        ball.Where = "trough_transit"
    End If
    TB_After TB_TROUGH_TRANSIT_MS, "TB_Arrive", dest, ball
End Sub


'----- Switches -----

'The same thing GLF's generated <switch>_Hit and _UnHit subs do
Sub TB_SwitchActive(switch_name, ball)
    If Not glf_gameTilted Then
        DispatchPinEvent switch_name & "_active", ball
        glf_last_switch_hit_time = gametime
        glf_last_switch_hit = switch_name
    End If
End Sub

Sub TB_SwitchInactive(switch_name, ball)
    If Not glf_gameTilted Then
        DispatchPinEvent switch_name & "_inactive", ball
    End If
End Sub


'----- Ball devices -----

'The physical side of one GLF ball device: one ball position per switch.
'Position 0 is the exit, and balls stack up from there.
Class TbDevice
    Public Name
    Public Switches
    Public EjectCount       'times GLF's eject callback took a ball out
    Public NullEjectCount   'times GLF's eject callback was called without a ball
    Private m_balls

    Public Default Function init(device_name, switch_names)
        Dim i
        Name = device_name
        Switches = switch_names
        ReDim m_balls(UBound(switch_names))
        For i = 0 To UBound(m_balls)
            m_balls(i) = Null
        Next
        EjectCount = 0
        NullEjectCount = 0
        tb_devices.Add device_name, Me
        Set init = Me
    End Function

    Public Function Capacity()
        Capacity = UBound(m_balls) + 1
    End Function

    Public Function Count()
        Dim i, total
        total = 0
        For i = 0 To UBound(m_balls)
            If Not IsNull(m_balls(i)) Then
                total = total + 1
            End If
        Next
        Count = total
    End Function

    'A ball arrives. Returns False if the device is full.
    Public Function Receive(ball)
        Dim i
        For i = 0 To UBound(m_balls)
            If IsNull(m_balls(i)) Then
                Set m_balls(i) = ball
                ball.Where = Name
                TB_SwitchActive Switches(i), ball
                Receive = True
                Exit Function
            End If
        Next
        Receive = False
    End Function

    'GLF's eject callback asks for this ball to leave. Returns False if it is not here.
    Public Function Eject(ball)
        Dim i
        For i = 0 To UBound(m_balls)
            If Not IsNull(m_balls(i)) Then
                If m_balls(i).ID = ball.ID Then
                    m_balls(i) = Null
                    EjectCount = EjectCount + 1
                    TB_SwitchInactive Switches(i), ball
                    Eject = True
                    Exit Function
                End If
            End If
        Next
        Eject = False
    End Function

    'The ball nearest the exit leaves without GLF asking. Returns the ball, or Nothing.
    Public Function Escape()
        Dim i, ball
        Set Escape = Nothing
        For i = 0 To UBound(m_balls)
            If Not IsNull(m_balls(i)) Then
                Set ball = m_balls(i)
                m_balls(i) = Null
                TB_SwitchInactive Switches(i), ball
                Set Escape = ball
                Exit Function
            End If
        Next
    End Function

    'Balls behind an empty position roll down one place
    Public Sub Settle()
        Dim i, ball
        For i = 1 To UBound(m_balls)
            If Not IsNull(m_balls(i)) Then
                If IsNull(m_balls(i - 1)) Then
                    Set ball = m_balls(i)
                    m_balls(i) = Null
                    TB_SwitchInactive Switches(i), ball
                    Set m_balls(i - 1) = ball
                    TB_SwitchActive Switches(i - 1), ball
                End If
            End If
        Next
    End Sub

    'Test reset only: empty the device without telling GLF
    Public Sub ForceEmpty()
        Dim i
        For i = 0 To UBound(m_balls)
            m_balls(i) = Null
        Next
    End Sub

    Public Sub ResetCounters()
        EjectCount = 0
        NullEjectCount = 0
    End Sub
End Class

'Creates the physical device and the eject callback GLF will call for it
Sub TB_AddDevice(device_name, switch_names)
    Dim device : Set device = (New TbDevice)(device_name, switch_names)
    ExecuteGlobal "Sub TB_Eject_" & device_name & "(ball) : TB_DeviceEjectCallback """ & device_name & """, ball : End Sub"
End Sub

Function TB_Dev(device_name)
    Set TB_Dev = tb_devices(device_name)
End Function

Sub TB_DeviceEjectCallback(device_name, ball)
    Dim device : Set device = tb_devices(device_name)
    If Not IsObject(ball) Then
        device.NullEjectCount = device.NullEjectCount + 1
        Exit Sub
    End If
    If device.Eject(ball) = False Then
        TB_Note "GLF ejected a ball that was not in " & device_name
        Exit Sub
    End If
    ball.Where = "transit"
    TB_After TB_EJECT_TRANSIT_MS, "TB_Arrive", TB_RouteFor(device_name), ball
    If device.Capacity() > 1 Then
        TB_After TB_SETTLE_MS, "TB_DeviceSettle", device_name, Null
    End If
End Sub

Sub TB_DeviceSettle(device_name, unused)
    tb_devices(device_name).Settle
End Sub


'----- Router -----

'Destinations: "pen" (back in play), "drain", "@<device>", "self" (falls back in), "void" (never seen again)
Sub TB_Route(device_name, dest)
    If tb_routes.Exists(device_name) Then
        tb_routes.Remove device_name
    End If
    tb_routes.Add device_name, dest
End Sub

'Applies to the next eject from that device only
Sub TB_RouteOnce(device_name, dest)
    If tb_routes_once.Exists(device_name) Then
        tb_routes_once.Remove device_name
    End If
    tb_routes_once.Add device_name, dest
End Sub

Function TB_RouteFor(device_name)
    Dim dest
    If tb_routes_once.Exists(device_name) Then
        dest = tb_routes_once(device_name)
        tb_routes_once.Remove device_name
    ElseIf tb_routes.Exists(device_name) Then
        dest = tb_routes(device_name)
    Else
        dest = "pen"
    End If
    If dest = "self" Then
        dest = "@" & device_name
    End If
    TB_RouteFor = dest
End Function

Sub TB_Arrive(dest, ball)
    If dest = "pen" Then
        ball.Where = "pen"
    ElseIf dest = "void" Then
        ball.Where = "void"
    ElseIf dest = "drain" Then
        If Drain.Receive(ball) = False Then
            TB_After 100, "TB_Arrive", dest, ball
        End If
    ElseIf Left(dest, 1) = "@" Then
        If tb_devices(Mid(dest, 2)).Receive(ball) = False Then
            TB_Note Mid(dest, 2) & " was full; the ball stayed in play"
            ball.Where = "pen"
        End If
    Else
        If tb_kickers(dest).Receive(ball) = False Then
            TB_After 100, "TB_Arrive", dest, ball
        End If
    End If
End Sub


'----- Things a test can make happen -----

'A ball in play is shot into a device
Sub TB_Shoot(device_name)
    Dim ball : Set ball = TB_PenTake()
    If ball Is Nothing Then
        TB_Fail "shoot " & device_name, "no ball in play to shoot"
        Exit Sub
    End If
    ball.Where = "transit"
    TB_After TB_SHOT_TRANSIT_MS, "TB_Arrive", "@" & device_name, ball
End Sub

'A ball in play drains
Sub TB_DrainBall()
    Dim ball : Set ball = TB_PenTake()
    If ball Is Nothing Then
        TB_Fail "drain", "no ball in play to drain"
        Exit Sub
    End If
    ball.Where = "transit"
    TB_After TB_SHOT_TRANSIT_MS, "TB_Arrive", "drain", ball
End Sub

'A ball leaves a device without GLF ejecting it, and ends up in play
Sub TB_Escape(device_name)
    Dim ball : Set ball = tb_devices(device_name).Escape()
    If ball Is Nothing Then
        TB_Fail "escape " & device_name, "no ball in " & device_name
        Exit Sub
    End If
    ball.Where = "transit"
    TB_After TB_EJECT_TRANSIT_MS, "TB_Arrive", "pen", ball
End Sub

'The player plunges the ball
Sub TB_Plunge()
    TB_Escape "plunger"
End Sub
