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
    TB_Feature "credits", "TB_ConfigCredits"
    TB_Feature "kickbacks", "TB_ConfigKickbacks"
    TB_Feature "carousel", "TB_ConfigCarousel"
    TB_Feature "attract", "TB_ConfigAttract"
    TB_Feature "match", "TB_ConfigMatch"
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
    'Holds the start of a ball, for a player who has tb_intro set
    With CreateGlfMode("tb_ball_intro", 700)
        .StartEvents = Array("ball_starting{current_player.tb_intro==1}")
        .StopEvents = Array("tb_intro_done")
        .UseWaitQueue = True
    End With
End Sub

'A relay listener that refuses whatever is asked. Scenarios add and remove it.
Function TB_Refuse(args)
    TB_Refuse = False
End Function

'Coin play. Starts on free play so other scenarios can start games; the credits
'scenario switches to credit play, and the runner switches back after every scenario.
'A game costs 0.50 and 2.00 buys five, so a credit is two units of 0.25.
Sub TB_ConfigCredits()
    With EnableGlfCredits()
        .MaxCredits = 4
        .PersistCredits = False
        .ServiceCreditsSwitch = "s_tb_service"
        With .Switches("s_tb_coin_quarter")
            .Value = 0.25
        End With
        With .Switches("s_tb_coin_dollar")
            .Value = 1
        End With
        .AddPricingTier 0.5, 1
        .AddPricingTier 2, 5
        With .Events("tb_award_credit")
            .Credits = 1
        End With
    End With
End Sub

'A kickback that goes out once it has fired
Dim tb_kick_actions : tb_kick_actions = 0

Sub TB_ConfigKickbacks()
    With CreateGlfKickback("tb_kick")
        .Switch = "s_tb_kick"
        .ActionCallback = "TB_KickAction"
        .EnableEvents = Array("tb_kick_on")
        .DisableEvents = Array("kickback_tb_kick_fired", "ball_will_end")
    End With
End Sub

Sub TB_KickAction(args)
    If args(0) = 1 Then
        tb_kick_actions = tb_kick_actions + 1
    End If
End Sub

'A carousel of three items plus one whose condition is never true, and a carousel with nothing to offer
Sub TB_ConfigCarousel()
    With CreateGlfMode("tb_carousel", 650)
        .StartEvents = Array("tb_start_carousel")
        .StopEvents = Array("tb_stop_carousel")
        With .Carousel()
            .SelectableItems = Array("one", "two", "never{game.balls_in_play==99}", "three")
            .NextItemEvents = Array("tb_car_next")
            .PreviousItemEvents = Array("tb_car_prev")
            .SelectItemEvents = Array("tb_car_select")
            .BlockEvents = Array("tb_car_block")
            .ReleaseEvents = Array("tb_car_release")
        End With
    End With
    With CreateGlfMode("tb_carousel_empty", 651)
        .StartEvents = Array("tb_start_carousel_empty")
        .StopEvents = Array("tb_stop_carousel_empty")
        With .Carousel()
            .SelectableItems = Array("never{game.balls_in_play==99}")
        End With
    End With
End Sub

Sub TB_ConfigAttract()
    EnableGlfAttract()
End Sub

'End-of-game match with a short display time
Sub TB_ConfigMatch()
    With EnableGlfMatch()
        .MatchPercentage = 50
        .DisplayTimeMs = 300
    End With
End Sub
