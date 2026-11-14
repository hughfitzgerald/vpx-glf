'*******************************************
'  Configuration for optional GLF features
'*******************************************
' Each block configures one feature that not every GLF build has. A block that
' fails (the build has no such setting) is skipped, and scenarios for it fail at
' TB_Require instead of stopping the whole run.

Dim tb_features : Set tb_features = CreateObject("Scripting.Dictionary")   'feature name -> True

Sub TB_ConfigureFeatures()
    TB_Feature "logic_blocks", "TB_ConfigLogicBlocks"
End Sub

Sub TB_Feature(feature, config_sub)
    Dim failed
    On Error Resume Next
    Err.Clear
    Dim handler : Set handler = GetRef(config_sub)
    handler
    failed = (Err.Number <> 0)
    Err.Clear
    On Error Goto 0
    If Not failed Then
        tb_features.Add feature, True
    End If
End Sub

'Accruals and sequences
Sub TB_ConfigLogicBlocks()
    With CreateGlfMode("tb_logic", 600)
        .StartEvents = Array("tb_start_logic")
        .StopEvents = Array("tb_stop_logic")
        With .Accruals("acc")
            .Events = Array("tb_acc_a", "tb_acc_b, tb_acc_b2", "tb_acc_c")
        End With
        With .Sequences("seq")
            .Events = Array("tb_seq_1", "tb_seq_2", "tb_seq_3")
        End With
        'Keeps its progress per player and stays usable after it completes
        With .Accruals("acc_keep")
            .Events = Array("tb_keep_a", "tb_keep_b")
            .PersistState = True
            .ResetOnComplete = False
            .DisableOnComplete = False
            .ResetEvents = Array("tb_keep_reset")
        End With
        'Only counts once it is enabled
        With .Sequences("seq_gated")
            .Events = Array("tb_gated_1", "tb_gated_2")
            .EnableEvents = Array("tb_gated_enable")
            .EventsWhenComplete = Array("tb_gated_done")
        End With
    End With
End Sub
