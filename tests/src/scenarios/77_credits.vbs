'On credit play a game and each extra player cost a credit. Coins become credits
'through the pricing tiers, up to the maximum.
'Covers feat/credits.
TB_Scenario "credits"

Function Scenario_credits(stage)
    Scenario_credits = 0
    Select Case stage
        Case 0
            If Not TB_Require("credits") Then
                Scenario_credits = TB_DONE
                Exit Function
            End If
            TB_Watch "not_enough_credits"
            TB_Watch "credits_added"
            TB_Watch "max_credits_reached"
            TB_Eq "starts on free play", glf_machine_vars("credits_string").Value, "FREE PLAY"
            TB_Post "enable_credit_play"
            Scenario_credits = 300
        Case 1
            TB_Eq "credit play shows no credits", glf_machine_vars("credits_string").Value, "CREDITS 0"
            TB_StartGame
            Scenario_credits = 500
        Case 2
            TB_Eq "no game without a credit", glf_gameStarted, False
            TB_Eq "not_enough_credits posted", TB_Seen("not_enough_credits"), 1
            TB_Post "s_tb_coin_quarter_active"
            Scenario_credits = 300
        Case 3
            TB_Eq "one quarter is half a credit", glf_machine_vars("credits_value").Value, "1/2"
            TB_StartGame
            Scenario_credits = 500
        Case 4
            TB_Eq "no game on half a credit", glf_gameStarted, False
            TB_Post "s_tb_coin_quarter_active"
            Scenario_credits = 300
        Case 5
            TB_Eq "two quarters are one credit", glf_machine_vars("credits_value").Value, "1"
            TB_Eq "credits_added posted for each coin", TB_Seen("credits_added"), 2
            TB_StartGame
            TB_WaitUntil "game starts and the ball reaches the plunger lane", "glf_gameStarted = True And TB_Dev(""plunger"").Count() = 1", 5000
        Case 6
            TB_Eq "the credit was taken", glf_machine_vars("credits_value").Value, "0"
            Glf_AddPlayer
            Scenario_credits = 300
        Case 7
            TB_Eq "no second player without a credit", Glf_PlayerCount(), 1
            TB_Post "s_tb_service_active"
            Scenario_credits = 300
        Case 8
            TB_Eq "service switch adds a credit", glf_machine_vars("credits_value").Value, "1"
            Glf_AddPlayer
            Scenario_credits = 300
        Case 9
            TB_Eq "second player joins", Glf_PlayerCount(), 2
            TB_Eq "and pays a credit", glf_machine_vars("credits_value").Value, "0"
            TB_Post "s_tb_coin_dollar_active"
            Scenario_credits = 300
        Case 10
            TB_Eq "one dollar is two credits", glf_machine_vars("credits_value").Value, "2"
            TB_Post "s_tb_coin_dollar_active"
            Scenario_credits = 300
        Case 11
            'Two dollars buys five credits, but the machine only holds four
            TB_Eq "capped at the maximum", glf_machine_vars("credits_value").Value, "4"
            TB_Eq "max_credits_reached posted", TB_Seen("max_credits_reached"), 1
            TB_Post "credits_reset"
            Scenario_credits = 300
        Case 12
            TB_Eq "reset clears the credits", glf_machine_vars("credits_value").Value, "0"
            TB_Post "tb_award_credit"
            Scenario_credits = 300
        Case 13
            TB_Eq "an event can award a credit", glf_machine_vars("credits_value").Value, "1"
            TB_Post "enable_free_play"
            Scenario_credits = 300
        Case 14
            TB_Eq "back on free play", glf_machine_vars("credits_string").Value, "FREE PLAY"
        Case Else
            Scenario_credits = TB_DONE
    End Select
End Function
