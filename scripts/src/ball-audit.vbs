
'*******************************************
'  Ball Audit (debug only)
'*******************************************
' While glf_debugEnabled is True and a game is running, this checks every two
' seconds that glf_BIP agrees with where the balls physically are:
'
'   glf_BIP should equal  total balls - balls in the trough - ball in the drain
'                         - balls sitting in multiball lock devices
'
' Balls in the plunger lane, on the playfield and in ball holds all count as in
' play. A mismatch is written to the debug log once the ball positions have been
' the same for two checks in a row, so balls in transit do not raise false alarms.
' The audit never changes game state.

Dim glf_ball_audit_last : glf_ball_audit_last = ""
Dim glf_ball_audit_reported : glf_ball_audit_reported = ""
Dim glf_ball_audit_expected : glf_ball_audit_expected = 0

AddPinEventListener "reset_complete", "glf_ball_audit_start", "Glf_BallAuditStart", 10, Null

Function Glf_BallAuditStart(args)
	SetDelay "glf_ball_audit", "Glf_BallAuditTick", Null, 2000
	If Not IsNull(args) Then
		If IsObject(args(1)) Then
			Set Glf_BallAuditStart = args(1)
		Else
			Glf_BallAuditStart = args(1)
		End If
	Else
		Glf_BallAuditStart = Null
	End If
End Function

Function Glf_BallAuditTick(args)
	SetDelay "glf_ball_audit", "Glf_BallAuditTick", Null, 2000
	If glf_debugEnabled = False Or glf_gameStarted = False Or glf_gameTilted = True Then
		glf_ball_audit_last = ""
		glf_ball_audit_reported = ""
		Exit Function
	End If

	Dim snapshot : snapshot = Glf_BallAuditSnapshot()
	If snapshot <> glf_ball_audit_last Then
		'Something moved since the last check. Wait for it to settle.
		glf_ball_audit_last = snapshot
		Exit Function
	End If

	If glf_ball_audit_expected = glf_BIP Then
		If glf_ball_audit_reported <> "" Then
			glf_debugLog.WriteToLog "Ball Audit", "OK again. " & snapshot
			glf_ball_audit_reported = ""
		End If
		Exit Function
	End If

	If snapshot <> glf_ball_audit_reported Then
		glf_ball_audit_reported = snapshot
		glf_debugLog.WriteToLog "Ball Audit", "MISMATCH. " & snapshot
	End If
End Function

'Returns a one-line description of where every ball is, and sets glf_ball_audit_expected.
Function Glf_BallAuditSnapshot()
	Dim i, trough_balls, drain_balls, locked_balls, held_balls
	trough_balls = 0
	For i = 1 To glf_troughSize
		If i < 8 Or glf_troughStyle = "P3" Then
			trough_balls = trough_balls + Glf_BallAuditKickerBalls("swTrough" & i)
		End If
	Next
	drain_balls = Glf_BallAuditKickerBalls("Drain")

	'Balls sitting in any device that a multiball lock uses
	Dim lock_devices : Set lock_devices = CreateObject("Scripting.Dictionary")
	Dim multiball_lock, device_name
	For Each multiball_lock in glf_multiball_locks.Items()
		For Each device_name in multiball_lock.LockDevices
			If Not lock_devices.Exists(device_name) Then
				lock_devices.Add device_name, True
			End If
		Next
	Next
	locked_balls = 0
	For Each device_name in lock_devices.Keys
		If glf_ball_devices.Exists(device_name) Then
			locked_balls = locked_balls + glf_ball_devices(device_name).Balls
		End If
	Next

	held_balls = 0
	Dim ball_hold
	For Each ball_hold in glf_ball_holds.Items()
		held_balls = held_balls + ball_hold.GetValue("balls_held")
	Next

	Dim devices : devices = ""
	For Each device_name in glf_ball_devices.Keys
		devices = devices & " " & device_name & "=" & glf_ball_devices(device_name).Balls
		If lock_devices.Exists(device_name) Then
			devices = devices & "(lock)"
		End If
	Next

	glf_ball_audit_expected = glf_troughSize - trough_balls - drain_balls - locked_balls
	Glf_BallAuditSnapshot = "glf_BIP=" & glf_BIP & ", expected=" & glf_ball_audit_expected & _
		" (total=" & glf_troughSize & ", trough=" & trough_balls & ", drain=" & drain_balls & _
		", in lock devices=" & locked_balls & "). Held=" & held_balls & ". Devices:" & devices
End Function

'Number of balls over a named kicker, or 0 if the table has no such object.
Function Glf_BallAuditKickerBalls(kicker_name)
	Glf_BallAuditKickerBalls = 0
	On Error Resume Next
	Glf_BallAuditKickerBalls = Eval(kicker_name).BallCntOver
	On Error Goto 0
End Function
