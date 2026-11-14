'An accrual completes when all its steps are done, in any order.
'Covers feat/logic-blocks.
TB_Scenario "accrual"

Function Scenario_accrual(stage)
    Scenario_accrual = 0
    If stage = 0 Then
        If Not TB_Require("logic_blocks") Then
            Scenario_accrual = TB_DONE
            Exit Function
        End If
    End If
    If stage < TB_PRELUDE_STEPS Then
        Scenario_accrual = TB_OneBallInPlay(stage)
        Exit Function
    End If
    Select Case stage - TB_PRELUDE_STEPS
        Case 0
            TB_Watch "logicblock_acc_hit"
            TB_Watch "logicblock_acc_complete"
            TB_Post "tb_start_logic"
            Scenario_accrual = 300
        Case 1
            TB_Eq "starts enabled", glf_accruals("acc").GetValue("enabled"), True
            TB_Post "tb_acc_c"
            TB_Post "tb_acc_a"
            Scenario_accrual = 300
        Case 2
            TB_Eq "two steps done, out of order", glf_accruals("acc").GetValue("completed_steps"), 2
            TB_Eq "two hit events", TB_Seen("logicblock_acc_hit"), 2
            TB_Eq "last hit names step 0", TB_Kwarg("logicblock_acc_hit", "step"), 0
            TB_Eq "not complete yet", TB_Seen("logicblock_acc_complete"), 0
            'A step that is already done does not count again
            TB_Post "tb_acc_a"
            Scenario_accrual = 300
        Case 3
            TB_Eq "repeat of a done step is ignored", TB_Seen("logicblock_acc_hit"), 2
            'The second of two alternative events for the middle step
            TB_Post "tb_acc_b2"
            Scenario_accrual = 300
        Case 4
            TB_Eq "third hit event", TB_Seen("logicblock_acc_hit"), 3
            TB_Eq "complete event posted once", TB_Seen("logicblock_acc_complete"), 1
            TB_Eq "reset after completing", glf_accruals("acc").GetValue("completed_steps"), 0
            TB_Eq "disabled after completing", glf_accruals("acc").GetValue("enabled"), False
            TB_Post "tb_acc_a"
            Scenario_accrual = 300
        Case 5
            TB_Eq "a disabled accrual ignores its events", TB_Seen("logicblock_acc_hit"), 3
        Case Else
            Scenario_accrual = TB_DONE
    End Select
End Function
