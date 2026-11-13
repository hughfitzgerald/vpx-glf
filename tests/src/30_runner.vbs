'*******************************************
'  Scenario runner
'*******************************************
' A scenario is a function called once per step:
'
'   TB_Scenario "my_test"
'   Function Scenario_my_test(stage)
'       Scenario_my_test = 0                  'ms to wait before the next step
'       Select Case stage
'           Case 0 : TB_StartGame
'                    TB_WaitUntil "ball served", "TB_Dev(""plunger"").Count = 1", 5000
'           Case 1 : TB_CheckCounts "ball in lane", 1
'           Case Else : Scenario_my_test = TB_DONE
'       End Select
'   End Function
'
' After each scenario the runner cancels the game, sends every ball home and
' waits for GLF to go quiet before starting the next one.
'
' Results go to the file named by TB_RESULTS_FILE, one line per event:
'   TB|START|scenario
'   TB|PASS|scenario|label
'   TB|FAIL|scenario|label|detail
'   TB|NOTE|scenario|text
'   TB|END|scenario|passed or failed or known|passes|fails|ms
'   TB|DONE|scenarios run|scenarios failed

Const TB_DONE = -1
Const TB_BOOT_MS = 2500             'time given to GLF to initialise before the first scenario
Const TB_QUIET_MS = 3500            'quiet time after cleanup; longer than GLF's 3s lost-ball window
Const TB_PRELUDE_STEPS = 4          'steps used by TB_OneBallInPlay

Dim tb_scenarios : Set tb_scenarios = CreateObject("Scripting.Dictionary")   'name -> known issue text, or ""
Dim tb_watch     : Set tb_watch     = CreateObject("Scripting.Dictionary")   'event name -> times seen
Dim tb_phase : tb_phase = "boot"
Dim tb_index : tb_index = -1
Dim tb_current : tb_current = ""
Dim tb_step : tb_step = 0
Dim tb_wait_until : tb_wait_until = 0
Dim tb_cond : tb_cond = ""
Dim tb_cond_label : tb_cond_label = ""
Dim tb_cond_deadline : tb_cond_deadline = 0
Dim tb_pass : tb_pass = 0
Dim tb_fail : tb_fail = 0
Dim tb_started_at : tb_started_at = 0
Dim tb_scenarios_run : tb_scenarios_run = 0
Dim tb_scenarios_failed : tb_scenarios_failed = 0
Dim tb_cleanup_step : tb_cleanup_step = 0
Dim tb_cleanup_until : tb_cleanup_until = 0
Dim tb_done_at : tb_done_at = 0
Dim tb_pump_checked : tb_pump_checked = False
Dim tb_pump : tb_pump = False
Dim tb_results_path : tb_results_path = ""


'----- Registering and writing scenarios -----

Sub TB_Scenario(scenario_name)
    tb_scenarios.Add scenario_name, ""
End Sub

'A scenario that documents a bug nobody has fixed yet. Its failures are reported but do not fail the run.
Sub TB_KnownIssueScenario(scenario_name, issue)
    tb_scenarios.Add scenario_name, issue
End Sub

Sub TB_StartGame()
    DispatchRelayPinEvent "request_to_start_game", True
End Sub

Sub TB_Post(event_name)
    DispatchPinEvent event_name, Null
End Sub

'Pause the scenario until the expression is True. Ends the scenario as failed on timeout.
Sub TB_WaitUntil(label, condition, timeout_ms)
    tb_cond = condition
    tb_cond_label = label
    tb_cond_deadline = gametime + timeout_ms
End Sub

'Count how many times GLF posts an event. Read the count with TB_Seen.
Sub TB_Watch(event_name)
    If tb_watch.Exists(event_name) Then
        tb_watch(event_name) = 0
    Else
        tb_watch.Add event_name, 0
        AddPinEventListener event_name, "tb_watch_" & event_name, "TB_WatchHandler", 1, event_name
    End If
End Sub

Function TB_Seen(event_name)
    If tb_watch.Exists(event_name) Then
        TB_Seen = tb_watch(event_name)
    Else
        TB_Seen = 0
    End If
End Function

Function TB_WatchHandler(args)
    Dim event_name : event_name = args(0)
    tb_watch(event_name) = tb_watch(event_name) + 1
    If IsObject(args(1)) Then
        Set TB_WatchHandler = args(1)
    Else
        TB_WatchHandler = args(1)
    End If
End Function

'The first four steps of most scenarios: start a game and plunge the ball.
'Use as:  If stage < TB_PRELUDE_STEPS Then Scenario_x = TB_OneBallInPlay(stage) : Exit Function
Function TB_OneBallInPlay(stage)
    Dim wait_ms : wait_ms = 0
    Select Case stage
        Case 0
            TB_StartGame
            TB_WaitUntil "first ball reaches the plunger lane", "TB_Dev(""plunger"").Count = 1", 5000
        Case 1
            wait_ms = 400
        Case 2
            TB_Plunge
            TB_WaitUntil "ball is in play", "TB_PenCount() = 1", 3000
        Case 3
            'Let GLF confirm the plunger eject
            wait_ms = TB_EJECT_TIMEOUT + 400
    End Select
    TB_OneBallInPlay = wait_ms
End Function


'----- Assertions -----

Function TB_Str(value)
    If IsObject(value) Then
        TB_Str = "[object]"
    ElseIf IsNull(value) Then
        TB_Str = "Null"
    ElseIf IsEmpty(value) Then
        TB_Str = "Empty"
    Else
        TB_Str = CStr(value)
    End If
End Function

Sub TB_Eq(label, actual, expected)
    Dim same : same = False
    If Not IsObject(actual) And Not IsNull(actual) And Not IsEmpty(actual) Then
        If actual = expected Then
            same = True
        End If
    End If
    If same = True Then
        TB_Pass label
    Else
        TB_Fail label, "expected " & TB_Str(expected) & ", got " & TB_Str(actual)
    End If
End Sub

Sub TB_True(label, condition)
    If condition = True Then
        TB_Pass label
    Else
        TB_Fail label, "was not true"
    End If
End Sub

'Checks that GLF's picture of the table matches where the balls really are:
'  - every ball device reports the number of balls physically in it
'  - glf_BIP equals expected_in_play
'  - no ball has gone missing from the test bed itself
Sub TB_CheckCounts(label, expected_in_play)
    Dim device_name, problems, accounted
    problems = ""
    accounted = TB_HomeCount() + TB_CountWhere("pen") + TB_CountWhere("transit") + TB_CountWhere("void")
    For Each device_name In tb_devices.Keys()
        accounted = accounted + tb_devices(device_name).Count()
        If glf_ball_devices(device_name).Balls <> tb_devices(device_name).Count() Then
            problems = problems & " " & device_name & ": GLF counts " & glf_ball_devices(device_name).Balls & ", holds " & tb_devices(device_name).Count() & "."
        End If
    Next
    If glf_BIP <> expected_in_play Then
        problems = problems & " glf_BIP is " & glf_BIP & ", expected " & expected_in_play & "."
    End If
    If accounted <> tnob Then
        problems = problems & " Test bed accounts for " & accounted & " of " & tnob & " balls."
    End If
    If problems = "" Then
        TB_Pass label & " (counts)"
    Else
        TB_Fail label & " (counts)", Trim(problems) & " " & TB_StateLine()
    End If
End Sub

'One line describing where everything is, for failure messages
Function TB_StateLine()
    Dim device_name, text
    text = "State: glf_BIP=" & glf_BIP & " in play=" & TB_CountWhere("pen") & " transit=" & TB_CountWhere("transit") & _
        " trough=" & TB_TroughCount() & " drain=" & Drain.BallCntOver & " |"
    For Each device_name In tb_devices.Keys()
        text = text & " " & device_name & "=" & tb_devices(device_name).Count() & "/" & glf_ball_devices(device_name).Balls
    Next
    TB_StateLine = text & " (physical/GLF)"
End Function

Sub TB_Pass(label)
    tb_pass = tb_pass + 1
    TB_Log "TB|PASS|" & tb_current & "|" & TB_Clean(label)
End Sub

Sub TB_Fail(label, detail)
    tb_fail = tb_fail + 1
    TB_Log "TB|FAIL|" & tb_current & "|" & TB_Clean(label) & "|" & TB_Clean(detail)
End Sub

Sub TB_Note(text)
    TB_Log "TB|NOTE|" & tb_current & "|" & TB_Clean(text)
End Sub

Function TB_Clean(text)
    Dim cleaned : cleaned = TB_Str(text)
    cleaned = Replace(cleaned, "|", "/")
    cleaned = Replace(cleaned, vbCr, " ")
    cleaned = Replace(cleaned, vbLf, " ")
    TB_Clean = cleaned
End Function


'----- Results file -----

Sub TB_Log(line)
    Dim fso, file, opened
    opened = False
    On Error Resume Next
    Debug.Print line
    Err.Clear
    Set fso = CreateObject("Scripting.FileSystemObject")
    If tb_results_path = "" Then
        'First line: use the path the launcher asked for, or fall back to the working folder
        Set file = fso.OpenTextFile(TB_RESULTS_FILE, 8, True)
        If Err.Number = 0 Then
            tb_results_path = TB_RESULTS_FILE
            opened = True
        Else
            Err.Clear
            Set file = fso.OpenTextFile("glftest_results.txt", 8, True)
            If Err.Number = 0 Then
                tb_results_path = "glftest_results.txt"
                opened = True
            End If
        End If
    Else
        Set file = fso.OpenTextFile(tb_results_path, 8, True)
        If Err.Number = 0 Then
            opened = True
        End If
    End If
    If opened = True Then
        file.WriteLine line
        file.Close
    End If
    Err.Clear
    On Error Goto 0
End Sub


'----- The loop -----

'Called every frame by the TB_Timer table timer
Sub TB_Tick()
    'If the table's Glf_GameTimer never fires, drive GLF from here instead
    If tb_pump_checked = False And gametime > 2000 Then
        tb_pump_checked = True
        If glf_lastEventExecutionTime = 0 Then
            tb_pump = True
        End If
    End If
    If tb_pump = True Then
        Glf_GameTimer_Timer
    End If

    TB_SchedTick

    Select Case tb_phase
        Case "boot"
            If gametime >= TB_BOOT_MS Then
                If tb_pump = True Then
                    TB_Note "Glf_GameTimer did not fire; the test bed is driving GLF"
                End If
                tb_phase = "next"
            End If
        Case "next"
            TB_NextScenario
        Case "run"
            TB_RunStep
        Case "cleanup"
            TB_CleanupStep
        Case "finishing"
            If gametime >= tb_done_at Then
                tb_phase = "off"
                TB_Quit
            End If
    End Select
End Sub

Function TB_Wanted(scenario_name)
    Dim wanted
    If TB_ONLY = "" Then
        TB_Wanted = True
        Exit Function
    End If
    TB_Wanted = False
    For Each wanted In Split(TB_ONLY, ",")
        If LCase(Trim(wanted)) = LCase(scenario_name) Then
            TB_Wanted = True
        End If
    Next
End Function

Sub TB_NextScenario()
    Dim names, device_name
    names = tb_scenarios.Keys()
    Do
        tb_index = tb_index + 1
        If tb_index > UBound(names) Then
            tb_current = ""
            TB_Log "TB|DONE|" & tb_scenarios_run & "|" & tb_scenarios_failed
            tb_done_at = gametime + 500
            tb_phase = "finishing"
            Exit Sub
        End If
    Loop Until TB_Wanted(names(tb_index)) = True

    tb_current = names(tb_index)
    tb_step = 0
    tb_pass = 0
    tb_fail = 0
    tb_cond = ""
    tb_wait_until = gametime
    tb_started_at = gametime
    tb_routes.RemoveAll
    tb_routes_once.RemoveAll
    For Each device_name In tb_devices.Keys()
        tb_devices(device_name).ResetCounters
    Next
    TB_Log "TB|START|" & tb_current
    If tb_scenarios(tb_current) <> "" Then
        TB_Note "Known issue: " & tb_scenarios(tb_current)
    End If
    tb_phase = "run"
End Sub

Sub TB_RunStep()
    Dim met, result, scenario_fn, error_text
    error_text = ""

    If tb_cond <> "" Then
        met = False
        On Error Resume Next
        met = Eval(tb_cond)
        If Err.Number <> 0 Then
            error_text = Err.Description
        End If
        Err.Clear
        On Error Goto 0
        If error_text <> "" Then
            TB_Fail tb_cond_label, "could not evaluate " & tb_cond & ": " & error_text
            TB_EndScenario
            Exit Sub
        End If
        If met = True Then
            TB_Pass tb_cond_label
            tb_cond = ""
        ElseIf gametime > tb_cond_deadline Then
            TB_Fail tb_cond_label, "timed out waiting for " & tb_cond & ". " & TB_StateLine()
            TB_EndScenario
            Exit Sub
        Else
            Exit Sub
        End If
    End If

    If gametime < tb_wait_until Then
        Exit Sub
    End If

    Set scenario_fn = GetRef("Scenario_" & tb_current)
    tb_step = tb_step + 1
    result = TB_DONE
    On Error Resume Next
    result = scenario_fn(tb_step - 1)
    If Err.Number <> 0 Then
        error_text = "step " & (tb_step - 1) & ": " & Err.Description
    End If
    Err.Clear
    On Error Goto 0
    If error_text <> "" Then
        TB_Fail "script error", error_text
        TB_EndScenario
        Exit Sub
    End If

    If IsEmpty(result) Then
        result = 0
    End If
    If result < 0 Then
        TB_EndScenario
    Else
        tb_wait_until = gametime + result
    End If
End Sub

Sub TB_EndScenario()
    tb_cond = ""
    tb_cleanup_step = 0
    tb_cleanup_until = gametime
    tb_phase = "cleanup"
End Sub

'Sends every ball home through GLF, so that GLF's own counts return to zero
Sub TB_CleanupStep()
    Dim device_name, ball, device, stagger, verdict

    If gametime < tb_cleanup_until Then
        Exit Sub
    End If

    Select Case tb_cleanup_step
        Case 0
            'Anything GLF ejects from now on goes straight to the drain
            tb_routes.RemoveAll
            tb_routes_once.RemoveAll
            For Each device_name In tb_devices.Keys()
                TB_Route device_name, "drain"
            Next
            If glf_gameStarted = True Then
                DispatchPinEvent "glf_game_cancel", Null
            End If
            tb_cleanup_step = 1
            tb_cleanup_until = gametime + 1500

        Case 1
            'Whatever is still on the playfield or in a device leaves now
            stagger = 0
            For Each ball In tb_balls.Items()
                If ball.Where = "pen" Or ball.Where = "void" Then
                    ball.Where = "transit"
                    TB_After stagger, "TB_Arrive", "drain", ball
                    stagger = stagger + 200
                End If
            Next
            For Each device_name In tb_devices.Keys()
                Set device = tb_devices(device_name)
                Do While device.Count() > 0
                    Set ball = device.Escape()
                    ball.Where = "transit"
                    TB_After stagger, "TB_Arrive", "drain", ball
                    stagger = stagger + 200
                Loop
            Next
            tb_cleanup_step = 2
            tb_cleanup_until = gametime
            tb_cond_deadline = gametime + 10000

        Case 2
            If TB_TroughCount() = tnob Then
                tb_cleanup_step = 3
                tb_cleanup_until = gametime + TB_QUIET_MS
            ElseIf gametime > tb_cond_deadline Then
                TB_Note "Balls did not return to the trough; forcing them back. " & TB_StateLine()
                TB_ForceHome
                tb_cleanup_step = 3
                tb_cleanup_until = gametime + TB_QUIET_MS
            End If

        Case 3
            For Each device_name In tb_devices.Keys()
                If glf_ball_devices(device_name).Balls <> 0 Then
                    TB_Note "After cleanup GLF still counts " & glf_ball_devices(device_name).Balls & " balls in " & device_name & ". Later scenarios may be affected; rerun them alone with --only."
                End If
            Next
            If tb_fail = 0 Then
                verdict = "passed"
            ElseIf tb_scenarios(tb_current) <> "" Then
                verdict = "known"
            Else
                verdict = "failed"
                tb_scenarios_failed = tb_scenarios_failed + 1
            End If
            tb_scenarios_run = tb_scenarios_run + 1
            TB_Log "TB|END|" & tb_current & "|" & verdict & "|" & tb_pass & "|" & tb_fail & "|" & (gametime - tb_started_at)
            tb_phase = "next"
    End Select
End Sub

'Last resort: put every ball back in the trough without telling GLF
Sub TB_ForceHome()
    Dim kicker, device_name, ball, position
    tb_sched.RemoveAll
    For Each kicker In tb_kickers.Items()
        kicker.ForceEmpty
    Next
    For Each device_name In tb_devices.Keys()
        tb_devices(device_name).ForceEmpty
    Next
    position = 0
    For Each ball In tb_balls.Items()
        position = position + 1
        If position <= tnob Then
            tb_kickers("swTrough" & position).ForceBall ball
        End If
    Next
End Sub

Sub TB_Quit()
    If TB_QUIT_WHEN_DONE = True Then
        On Error Resume Next
        QuitPlayer 2
        Err.Clear
        On Error Goto 0
    End If
End Sub
