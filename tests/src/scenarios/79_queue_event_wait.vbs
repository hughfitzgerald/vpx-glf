'When one handler of a queue event waits, the handlers after it all run once the wait is over.
'Covers fix/queue-event-wait: before it, the wait was handed on to the next handler, which
'waited again for an event already posted, so any handler after that one never ran.
TB_Scenario "queue_event_wait"

Dim tb_q_second : tb_q_second = 0
Dim tb_q_third : tb_q_third = 0

Function TB_QueueFirst(args)
    args(1).Add "wait_for", "tb_q_go"
    Set TB_QueueFirst = args(1)
End Function

Function TB_QueueSecond(args)
    tb_q_second = tb_q_second + 1
    Set TB_QueueSecond = args(1)
End Function

Function TB_QueueThird(args)
    tb_q_third = tb_q_third + 1
    Set TB_QueueThird = args(1)
End Function

Function Scenario_queue_event_wait(stage)
    Scenario_queue_event_wait = 0
    Select Case stage
        Case 0
            tb_q_second = 0
            tb_q_third = 0
            AddPinEventListener "tb_q_event", "tb_q_first", "TB_QueueFirst", 300, Null
            AddPinEventListener "tb_q_event", "tb_q_second", "TB_QueueSecond", 200, Null
            AddPinEventListener "tb_q_event", "tb_q_third", "TB_QueueThird", 100, Null
            Dim kwargs : Set kwargs = GlfKwargs()
            kwargs.Add "x", 1
            DispatchQueuePinEvent "tb_q_event", kwargs
            Scenario_queue_event_wait = 400
        Case 1
            TB_Eq "second handler waits", tb_q_second, 0
            TB_Eq "third handler waits", tb_q_third, 0
            TB_Post "tb_q_go"
            Scenario_queue_event_wait = 400
        Case 2
            TB_Eq "second handler ran", tb_q_second, 1
            TB_Eq "third handler ran", tb_q_third, 1
            RemovePinEventListener "tb_q_event", "tb_q_first"
            RemovePinEventListener "tb_q_event", "tb_q_second"
            RemovePinEventListener "tb_q_event", "tb_q_third"
        Case Else
            Scenario_queue_event_wait = TB_DONE
    End Select
End Function
