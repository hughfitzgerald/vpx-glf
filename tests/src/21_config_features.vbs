'*******************************************
'  Configuration for optional GLF features
'*******************************************
' Each block configures one feature that not every GLF build has. A block that
' fails (the build has no such setting) is skipped, and scenarios for it fail at
' TB_Require instead of stopping the whole run.

Dim tb_features : Set tb_features = CreateObject("Scripting.Dictionary")   'feature name -> True

Sub TB_ConfigureFeatures()
    TB_Feature "logic_blocks", "TB_ConfigLogicBlocks"
    TB_Feature "bonus", "TB_ConfigBonus"
    TB_Feature "game_players", "TB_ConfigGamePlayers"
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

'End-of-ball bonus. It runs at the end of every ball in every scenario, so the delays are short.
'With no hits to count it only posts the total.
Sub TB_ConfigBonus()
    With EnableGlfBonus()
        .DisplayDelayMs = 400
        .HurryUpDelayMs = 20
        .HurryUpEvent = "tb_bonus_hurry"
        With .Entries("ramps")
            .Score = 1000
            .PlayerScoreEntry = "tb_ramps"
            .ResetPlayerScoreEntry = True
        End With
        With .Entries("loops")
            .Score = 250
            .PlayerScoreEntry = "tb_loops"
        End With
        With .Entries("never")
            .Score = 100
            .PlayerScoreEntry = "tb_never_set"
        End With
    End With
End Sub

'Up to three players, so a fourth is refused
Sub TB_ConfigGamePlayers()
    GlfGameSettings().MaxPlayers = 3
End Sub

'A relay listener that refuses whatever is asked. Scenarios add and remove it.
Function TB_Refuse(args)
    TB_Refuse = False
End Function
