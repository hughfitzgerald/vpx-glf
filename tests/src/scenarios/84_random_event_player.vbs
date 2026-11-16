'Random event players: force_all plays every valid event once per round,
'force_different never repeats the last event unless it is the only one,
'disable_random plays the events in order, and the fallback event is posted
'only when no event's condition passes.
'Covers fix/random-event-player.
TB_Scenario "random_event_player"

Dim tb_rnd_log : Set tb_rnd_log = CreateObject("Scripting.Dictionary")   'trigger -> picks so far, as "a,b,c"

'Record which event each trigger posts. The picks are the last letter of the posted event.
Sub TB_RndListen(trigger, picks)
    Dim i, posted
    If Not tb_rnd_log.Exists(trigger) Then
        tb_rnd_log.Add trigger, ""
        For i = 0 To UBound(picks)
            posted = trigger & "_" & picks(i)
            AddPinEventListener posted, "tb_rnd_" & posted, "TB_RndHandler", 1, Array(trigger, picks(i))
        Next
    End If
    tb_rnd_log(trigger) = ""
End Sub

Function TB_RndHandler(args)
    Dim trigger : trigger = args(0)(0)
    If tb_rnd_log(trigger) = "" Then
        tb_rnd_log(trigger) = args(0)(1)
    Else
        tb_rnd_log(trigger) = tb_rnd_log(trigger) & "," & args(0)(1)
    End If
    If IsObject(args(1)) Then
        Set TB_RndHandler = args(1)
    Else
        TB_RndHandler = args(1)
    End If
End Function

Sub TB_RndFire(trigger, times)
    Dim i
    For i = 1 To times
        TB_Post trigger
    Next
End Sub

Function TB_RndPicks(trigger)
    If tb_rnd_log(trigger) = "" Then
        TB_RndPicks = Array()
    Else
        TB_RndPicks = Split(tb_rnd_log(trigger), ",")
    End If
End Function

'True when no pick is the same as the one before it
Function TB_RndNoRepeats(picks)
    Dim i
    TB_RndNoRepeats = True
    For i = 1 To UBound(picks)
        If picks(i) = picks(i - 1) Then
            TB_RndNoRepeats = False
        End If
    Next
End Function

'True when every round of round_size picks holds each of the letters exactly once
Function TB_RndFullRounds(picks, letters)
    Dim round_size, start, i, j, found
    round_size = UBound(letters) + 1
    TB_RndFullRounds = ((UBound(picks) + 1) Mod round_size = 0)
    For start = 0 To UBound(picks) - round_size + 1 Step round_size
        For j = 0 To UBound(letters)
            found = 0
            For i = start To start + round_size - 1
                If picks(i) = letters(j) Then
                    found = found + 1
                End If
            Next
            If found <> 1 Then
                TB_RndFullRounds = False
            End If
        Next
    Next
End Function

Function Scenario_random_event_player(stage)
    Scenario_random_event_player = 0
    If stage < TB_PRELUDE_STEPS Then
        Scenario_random_event_player = TB_OneBallInPlay(stage)
        Exit Function
    End If
    Dim picks
    Select Case stage - TB_PRELUDE_STEPS
        Case 0
            TB_RndListen "tb_rnd_all", Array("a", "b", "c")
            TB_RndListen "tb_rnd_cond", Array("a", "b", "c")
            TB_RndListen "tb_rnd_diff", Array("a", "b")
            TB_RndListen "tb_rnd_one", Array("a")
            TB_RndListen "tb_rnd_order", Array("a", "b", "c")
            TB_RndListen "tb_rnd_fallback", Array("a")
            TB_Watch "tb_rnd_fallback_none"
            TB_Post "tb_start_random"
            Scenario_random_event_player = 300
        Case 1
            TB_RndFire "tb_rnd_all", 30
            TB_RndFire "tb_rnd_cond", 10
            TB_RndFire "tb_rnd_diff", 10
            TB_RndFire "tb_rnd_one", 3
            TB_RndFire "tb_rnd_order", 6
            TB_RndFire "tb_rnd_fallback", 2
            'GLF dispatches a limited number of queued events each frame
            TB_WaitUntil "every trigger and pick dispatched", "glf_dispatch_await.Count = 0", 5000
        Case 2
            picks = TB_RndPicks("tb_rnd_all")
            TB_Eq "force_all: an event every time", UBound(picks) + 1, 30
            TB_True "force_all: each round plays every event once (" & tb_rnd_log("tb_rnd_all") & ")", TB_RndFullRounds(picks, Array("a", "b", "c"))
            TB_True "force_all: no event twice in a row, even across rounds", TB_RndNoRepeats(picks)

            picks = TB_RndPicks("tb_rnd_cond")
            TB_Eq "force_all with a failing condition: an event every time (" & tb_rnd_log("tb_rnd_cond") & ")", UBound(picks) + 1, 10
            TB_True "force_all with a failing condition: rounds of the two valid events", TB_RndFullRounds(picks, Array("a", "b"))

            picks = TB_RndPicks("tb_rnd_diff")
            TB_Eq "force_different alone: an event every time", UBound(picks) + 1, 10
            TB_True "force_different alone: alternates (" & tb_rnd_log("tb_rnd_diff") & ")", TB_RndNoRepeats(picks)
            TB_Eq "force_different with one event: still plays", tb_rnd_log("tb_rnd_one"), "a,a,a"
            TB_Eq "disable_random: in order, round after round", tb_rnd_log("tb_rnd_order"), "a,b,c,a,b,c"

            TB_Eq "fallback: no event can play", tb_rnd_log("tb_rnd_fallback"), ""
            TB_Eq "fallback: posted each time", TB_Seen("tb_rnd_fallback_none"), 2
            TB_Post "tb_stop_random"
            Scenario_random_event_player = 300
        Case Else
            Scenario_random_event_player = TB_DONE
    End Select
End Function
