'A logic block with PersistState keeps its progress when its mode stops and starts again.
'Covers feat/logic-blocks.
TB_Scenario "logic_block_persist"

Function Scenario_logic_block_persist(stage)
    Scenario_logic_block_persist = 0
    If stage = 0 Then
        If Not TB_Require("logic_blocks") Then
            Scenario_logic_block_persist = TB_DONE
            Exit Function
        End If
    End If
    If stage < TB_PRELUDE_STEPS Then
        Scenario_logic_block_persist = TB_OneBallInPlay(stage)
        Exit Function
    End If
    Select Case stage - TB_PRELUDE_STEPS
        Case 0
            TB_Post "tb_start_logic"
            Scenario_logic_block_persist = 300
        Case 1
            TB_Post "tb_keep_a"
            TB_Post "tb_acc_a"
            Scenario_logic_block_persist = 300
        Case 2
            TB_Eq "persisting accrual has one step", glf_accruals("acc_keep").GetValue("completed_steps"), 1
            TB_Eq "plain accrual has one step", glf_accruals("acc").GetValue("completed_steps"), 1
            TB_Post "tb_stop_logic"
            Scenario_logic_block_persist = 300
        Case 3
            TB_Post "tb_start_logic"
            Scenario_logic_block_persist = 300
        Case 4
            TB_Eq "persisting accrual kept its step", glf_accruals("acc_keep").GetValue("completed_steps"), 1
            TB_Eq "persisting accrual is still enabled", glf_accruals("acc_keep").GetValue("enabled"), True
            TB_Eq "plain accrual started again", glf_accruals("acc").GetValue("completed_steps"), 0
            TB_Post "tb_keep_b"
            Scenario_logic_block_persist = 300
        Case 5
            TB_Eq "completed", glf_accruals("acc_keep").GetValue("completed"), True
            TB_Eq "kept its steps, because ResetOnComplete is off", glf_accruals("acc_keep").GetValue("completed_steps"), 2
            TB_Post "tb_keep_reset"
            Scenario_logic_block_persist = 300
        Case 6
            TB_Eq "reset event clears the steps", glf_accruals("acc_keep").GetValue("completed_steps"), 0
            TB_Eq "reset event clears completed", glf_accruals("acc_keep").GetValue("completed"), False
        Case Else
            Scenario_logic_block_persist = TB_DONE
    End Select
End Function
