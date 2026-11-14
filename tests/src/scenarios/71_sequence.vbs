'A sequence only advances on the event for its next step, and can wait to be enabled.
'Covers feat/logic-blocks.
TB_Scenario "sequence"

Function Scenario_sequence(stage)
    Scenario_sequence = 0
    If stage = 0 Then
        If Not TB_Require("logic_blocks") Then
            Scenario_sequence = TB_DONE
            Exit Function
        End If
    End If
    If stage < TB_PRELUDE_STEPS Then
        Scenario_sequence = TB_OneBallInPlay(stage)
        Exit Function
    End If
    Select Case stage - TB_PRELUDE_STEPS
        Case 0
            TB_Watch "logicblock_seq_hit"
            TB_Watch "logicblock_seq_complete"
            TB_Watch "tb_gated_done"
            TB_Post "tb_start_logic"
            Scenario_sequence = 300
        Case 1
            TB_Post "tb_seq_2"
            TB_Post "tb_seq_3"
            Scenario_sequence = 300
        Case 2
            TB_Eq "later steps do nothing before step 1", glf_sequences("seq").GetValue("value"), 0
            TB_Post "tb_seq_1"
            Scenario_sequence = 300
        Case 3
            TB_Eq "step 1 done", glf_sequences("seq").GetValue("value"), 1
            TB_Post "tb_seq_3"
            Scenario_sequence = 300
        Case 4
            TB_Eq "step 3 does nothing before step 2", glf_sequences("seq").GetValue("value"), 1
            TB_Post "tb_seq_2"
            Scenario_sequence = 300
        Case 5
            TB_Post "tb_seq_3"
            Scenario_sequence = 300
        Case 6
            TB_Eq "three hit events", TB_Seen("logicblock_seq_hit"), 3
            TB_Eq "complete event posted once", TB_Seen("logicblock_seq_complete"), 1
            'A sequence with enable events starts disabled
            TB_Eq "gated sequence starts disabled", glf_sequences("seq_gated").GetValue("enabled"), False
            TB_Post "tb_gated_1"
            Scenario_sequence = 300
        Case 7
            TB_Eq "disabled sequence ignores its events", glf_sequences("seq_gated").GetValue("value"), 0
            TB_Post "tb_gated_enable"
            Scenario_sequence = 300
        Case 8
            TB_Post "tb_gated_1"
            Scenario_sequence = 300
        Case 9
            TB_Post "tb_gated_2"
            Scenario_sequence = 300
        Case 10
            TB_Eq "its own complete event is posted", TB_Seen("tb_gated_done"), 1
        Case Else
            Scenario_sequence = TB_DONE
    End Select
End Function
