' Credits (coin play), after MPF's built-in credits mode.
'
' EnableGlfCredits creates a mode called "credits" that runs from reset_complete. On
' free play it only keeps the credit strings up to date. On credit play it counts money
' from the coin switches, turns it into credits through the pricing tiers, refuses to
' start a game or add a player without a credit, and takes one credit per player.
'
' Not carried over from MPF: the earnings audits and the coin inhibit output.

Dim glf_credits : glf_credits = Null

Function EnableGlfCredits()
    If Not IsNull(glf_credits) Then
        Set EnableGlfCredits = glf_credits
        Exit Function
    End If
    Dim credits_mode : Set credits_mode = CreateGlfMode("credits", 1000010)
    credits_mode.StartEvents = Array("reset_complete")
    credits_mode.GameMode = False
    Set glf_credits = (new GlfCredits)(credits_mode)
    Set EnableGlfCredits = glf_credits
End Function

' A coin switch: each closure is worth Value in money
Class GlfCreditsSwitch
    Private m_switch, m_value, m_type, m_label
    Public Property Get Switch() : Switch = m_switch : End Property
    Public Property Get Value() : Value = m_value : End Property
    Public Property Let Value(input) : m_value = input : End Property
    Public Property Get SwitchType() : SwitchType = m_type : End Property
    Public Property Let SwitchType(input) : m_type = input : End Property
    Public Property Get Label() : Label = m_label : End Property
    Public Property Let Label(input) : m_label = input : End Property
	Public default Function init(switch_name)
        m_switch = switch_name
        m_value = 0.25
        m_type = "money"
        m_label = Empty
        Set Init = Me
	End Function
End Class

' An event that awards credits directly, such as a replay or a match
Class GlfCreditsEvent
    Private m_event, m_credits, m_type
    Public Property Get EventObject() : Set EventObject = m_event : End Property
    Public Property Get Credits() : Credits = m_credits : End Property
    Public Property Let Credits(input) : m_credits = input : End Property
    Public Property Get EventType() : EventType = m_type : End Property
    Public Property Let EventType(input) : m_type = input : End Property
	Public default Function init(event_name)
        Set m_event = (new GlfEvent)(event_name)
        m_credits = 0.25
        m_type = "replay"
        Set Init = Me
	End Function
End Class

Class GlfCredits

    Private m_name
    Private m_priority
    Private m_base_device
    Private m_debug

    Private m_max_credits
    Private m_free_play
    Private m_service_credits_switches
    Private m_fractional_credit_expiration_time
    Private m_credit_expiration_time
    Private m_persist_credits
    Private m_free_play_string
    Private m_credits_string
    Private m_price_tier_template
    Private m_switches
    Private m_events
    Private m_tier_prices
    Private m_tier_credits
    Private m_reset_credits_events

    Private m_active
    Private m_credit_play_active
    Private m_credit_unit
    Private m_credit_units_per_game
    Private m_pricing_table
    Private m_pricing_tiers_wrap_around
    Private m_credit_units_for_pricing_tiers
    Private m_reset_pricing_tier_count_this_game

    Public Property Get Name() : Name = m_name : End Property
    Public Property Get Mode() : Set Mode = m_base_device.Mode : End Property
    Public Property Get FreePlay() : FreePlay = m_free_play : End Property
    Public Property Get CreditUnits() : CreditUnits = GetCreditUnits() : End Property
    Public Property Get CreditUnitsPerGame() : CreditUnitsPerGame = m_credit_units_per_game : End Property

    Public Property Get GetValue(value)
        Select Case value
            Case "free_play"
                GetValue = m_free_play
            Case "credit_units"
                GetValue = GetCreditUnits()
            Case "credits"
                GetValue = glf_machine_vars("credits_whole_num").Value
        End Select
    End Property

    Public Property Let MaxCredits(value) : m_max_credits = value : End Property
    Public Property Let FreePlay(value) : m_free_play = value : End Property
    Public Property Let ServiceCreditsSwitch(value)
        If IsArray(value) Then
            m_service_credits_switches = value
        Else
            m_service_credits_switches = Array(value)
        End If
    End Property
    Public Property Let FractionalCreditExpirationTime(value) : m_fractional_credit_expiration_time = value : End Property
    Public Property Let CreditExpirationTime(value) : m_credit_expiration_time = value : End Property
    ' Keep the credits on the machine when the table is closed
    Public Property Let PersistCredits(value)
        m_persist_credits = value
        glf_machine_vars("credit_units").Persist = value
    End Property
    Public Property Let FreePlayString(value) : m_free_play_string = value : End Property
    Public Property Let CreditsString(value) : m_credits_string = value : End Property
    Public Property Let PriceTierTemplate(value) : m_price_tier_template = value : End Property
    Public Property Let ResetCreditsEvents(value) : m_reset_credits_events = value : End Property

    Public Property Get Switches(switch_name)
        If Not m_switches.Exists(switch_name) Then
            m_switches.Add switch_name, (new GlfCreditsSwitch)(switch_name)
        End If
        Set Switches = m_switches(switch_name)
    End Property

    Public Property Get Events(event_name)
        If Not m_events.Exists(event_name) Then
            m_events.Add event_name, (new GlfCreditsEvent)(event_name)
        End If
        Set Events = m_events(event_name)
    End Property

    ' Tiers must be added from the cheapest up, and the first must buy exactly one credit
    Public Sub AddPricingTier(price, credits_for_price)
        ReDim Preserve m_tier_prices(UBound(m_tier_prices) + 1)
        ReDim Preserve m_tier_credits(UBound(m_tier_credits) + 1)
        m_tier_prices(UBound(m_tier_prices)) = price
        m_tier_credits(UBound(m_tier_credits)) = credits_for_price
    End Sub

    Public Property Let Debug(value)
        m_debug = value
        m_base_device.Debug = value
    End Property
    Public Property Get IsDebug()
        If m_debug Then : IsDebug = 1 : Else : IsDebug = 0 : End If
    End Property

	Public default Function init(mode)
        m_name = "credits"
        m_priority = mode.Priority
        m_debug = False

        m_max_credits = 0
        m_free_play = True
        m_service_credits_switches = Array()
        m_fractional_credit_expiration_time = 0
        m_credit_expiration_time = 0
        m_persist_credits = True
        m_free_play_string = "FREE PLAY"
        m_credits_string = "CREDITS"
        m_price_tier_template = "{credits} CREDITS ${price}"
        Set m_switches = CreateObject("Scripting.Dictionary")
        Set m_events = CreateObject("Scripting.Dictionary")
        m_tier_prices = Array()
        m_tier_credits = Array()
        m_reset_credits_events = Array("credits_reset", "factory_reset")

        m_active = False
        m_credit_play_active = False
        m_credit_unit = 1
        m_credit_units_per_game = 1
        Set m_pricing_table = CreateObject("Scripting.Dictionary")
        m_pricing_tiers_wrap_around = 1
        m_credit_units_for_pricing_tiers = 0
        m_reset_pricing_tier_count_this_game = False

        NewMachineVar "credit_units", 0, "int", True
        NewMachineVar "credits_string", " ", "string", False
        NewMachineVar "credits_value", "0", "string", False
        NewMachineVar "credits_whole_num", 0, "int", False
        NewMachineVar "credits_numerator", 0, "int", False
        NewMachineVar "credits_denominator", 0, "int", False
        NewMachineVar "free_play", 1, "int", False

        Set m_base_device = (new GlfBaseModeDevice)(mode, "credits", Me)
        Set Init = Me
	End Function

    Private Sub NewMachineVar(var_name, initial_value, value_type, persist_value)
        If glf_machine_vars.Exists(var_name) Then
            Exit Sub
        End If
        With CreateMachineVar(var_name)
            .InitialValue = initial_value
            .ValueType = value_type
            .Persist = persist_value
        End With
    End Sub

    Private Sub SetMachineVar(var_name, value)
        Dim previous : previous = glf_machine_vars(var_name).Value
        glf_machine_vars(var_name).Value = value
        Glf_BcpSendMachineVar var_name, value, previous
    End Sub

    ' ----- Mode start and stop -----

    Public Sub Activate()
        m_active = True
        Dim evt
        AddPinEventListener "enable_free_play", m_name & "_enable_free_play", "CreditsEventHandler", m_priority, Array("enable_free_play", Me)
        AddPinEventListener "enable_credit_play", m_name & "_enable_credit_play", "CreditsEventHandler", m_priority, Array("enable_credit_play", Me)
        AddPinEventListener "toggle_credit_play", m_name & "_toggle_credit_play", "CreditsEventHandler", m_priority, Array("toggle_credit_play", Me)
        AddPinEventListener "slam_tilt", m_name & "_slam_tilt", "CreditsEventHandler", m_priority, Array("clear_all_credits", Me)
        For Each evt in m_reset_credits_events
            AddPinEventListener evt, m_name & "_reset_credits", "CreditsEventHandler", m_priority, Array("clear_all_credits", Me)
        Next
        If m_free_play Then
            EnableFreePlay False
        Else
            EnableCreditPlay False
        End If
    End Sub

    Public Sub Deactivate()
        Dim evt
        RemovePinEventListener "enable_free_play", m_name & "_enable_free_play"
        RemovePinEventListener "enable_credit_play", m_name & "_enable_credit_play"
        RemovePinEventListener "toggle_credit_play", m_name & "_toggle_credit_play"
        RemovePinEventListener "slam_tilt", m_name & "_slam_tilt"
        For Each evt in m_reset_credits_events
            RemovePinEventListener evt, m_name & "_reset_credits"
        Next
        RemoveGameHandlers()
        DisableCreditHandlers()
        SetMachineVar "credits_string", m_free_play_string
        m_active = False
    End Sub

    Public Sub Enable()
    End Sub

    Public Sub Disable()
    End Sub

    ' ----- Credit units -----
    ' Money is counted in credit units: the largest unit that both the smallest coin
    ' and the price of a game are whole multiples of. Half credits and the like are
    ' whole numbers of units.

    Private Function AsWhole(value)
        AsWhole = CLng(Round(value, 6))
    End Function

    Private Sub CalculateCreditUnits()
        Dim min_currency_value, price_per_game, coin_switch, first
        If UBound(m_switches.Keys) > -1 Then
            first = True
            For Each coin_switch in m_switches.Items()
                If first Or coin_switch.Value < min_currency_value Then
                    min_currency_value = coin_switch.Value
                End If
                first = False
            Next
        ElseIf UBound(m_tier_prices) > -1 Then
            min_currency_value = m_tier_prices(0)
        Else
            min_currency_value = 1
        End If

        If UBound(m_tier_prices) > -1 Then
            price_per_game = m_tier_prices(0)
            If m_tier_credits(0) <> 1 Then
                Err.Raise vbObjectError + 2, "GlfCredits", "The first pricing tier has to give exactly one credit."
            End If
        Else
            price_per_game = 1
        End If

        If min_currency_value = price_per_game Then
            m_credit_unit = min_currency_value
        ElseIf min_currency_value < price_per_game Then
            m_credit_unit = price_per_game - min_currency_value
            If m_credit_unit > min_currency_value Then
                m_credit_unit = min_currency_value
            End If
        Else
            m_credit_unit = min_currency_value - price_per_game
            If m_credit_unit > price_per_game Then
                m_credit_unit = price_per_game
            End If
        End If
        m_credit_units_per_game = AsWhole(price_per_game / m_credit_unit)
        Log "Credit unit: " & m_credit_unit & ", credit units per game: " & m_credit_units_per_game
    End Sub

    ' Builds the table of bonus credit units: how many extra units the Nth unit paid
    ' in brings, so that a higher tier gives its discount.
    Private Sub CalculatePricingTiers()
        m_pricing_table.RemoveAll
        If UBound(m_tier_prices) = -1 Then
            m_pricing_tiers_wrap_around = 1
            m_pricing_table.Add "1", 0
            Exit Sub
        End If

        m_pricing_tiers_wrap_around = 0
        Dim tier_units, tier_bonus, index, credit_units, actual_credit_units
        tier_units = Array()
        tier_bonus = Array()
        For index = 0 To UBound(m_tier_prices)
            credit_units = AsWhole(m_tier_prices(index) / m_credit_unit)
            actual_credit_units = m_credit_units_per_game * m_tier_credits(index)
            If m_pricing_tiers_wrap_around > credit_units Then
                Log "Pricing tier " & index & " has to cost more than the one before it. Skipping it."
            Else
                m_pricing_tiers_wrap_around = credit_units
                ReDim Preserve tier_units(UBound(tier_units) + 1)
                ReDim Preserve tier_bonus(UBound(tier_bonus) + 1)
                tier_units(UBound(tier_units)) = credit_units
                tier_bonus(UBound(tier_bonus)) = actual_credit_units - credit_units
                NewMachineVar "price_per_game_raw_" & index, 0, "string", False
                NewMachineVar "price_per_game_string_" & index, "", "string", False
                SetMachineVar "price_per_game_raw_" & index, m_tier_prices(index)
                SetMachineVar "price_per_game_string_" & index, Replace(Replace(m_price_tier_template, "{price}", CStr(m_tier_prices(index))), "{credits}", CStr(m_tier_credits(index)))
            End If
        Next

        Dim units, accounted_units, bonus, old_bonus, t
        old_bonus = 0
        For units = 0 To m_pricing_tiers_wrap_around
            accounted_units = 0
            bonus = 0
            For t = UBound(tier_units) To 0 Step -1
                Do While units - accounted_units >= tier_units(t)
                    accounted_units = accounted_units + tier_units(t)
                    bonus = bonus + tier_bonus(t)
                Loop
            Next
            m_pricing_table.Add CStr(units), bonus - old_bonus
            old_bonus = bonus
        Next
    End Sub

    Private Function GetCreditUnits()
        Dim units : units = glf_machine_vars("credit_units").Value
        If IsEmpty(units) Or IsNull(units) Then
            units = 0
        ElseIf VarType(units) = vbString Then
            If IsNumeric(units) Then units = CLng(units) Else units = 0
        End If
        GetCreditUnits = units
    End Function

    ' ----- Free play and credit play -----

    Public Sub EnableCreditPlay(post_event)
        m_free_play = False
        SetMachineVar "free_play", 0
        If m_credit_play_active = False Then
            CalculateCreditUnits()
            CalculatePricingTiers()
        End If
        SetMachineVar "credit_units", GetCreditUnits()
        UpdateCreditStrings()
        EnableCreditHandlers()
        RemoveGameHandlers()
        AddPinEventListener "player_add_request", m_name & "_player_add_request", "CreditsEventHandler", 25, Array("player_add_request", Me)
        AddPinEventListener "request_to_start_game", m_name & "_request_to_start_game", "CreditsEventHandler", 25, Array("request_to_start_game", Me)
        AddPinEventListener "player_added", m_name & "_player_added", "CreditsEventHandler", m_priority, Array("player_added", Me)
        AddPinEventListener "game_started", m_name & "_game_started", "CreditsEventHandler", m_priority, Array("game_started", Me)
        AddPinEventListener "ball_starting", m_name & "_ball_starting", "CreditsEventHandler", m_priority, Array("ball_starting", Me)
        m_credit_play_active = True
        If post_event Then
            Glf_BcpSendEvent "enabling_credit_play", Null
            DispatchPinEvent "enabling_credit_play", Null
        End If
    End Sub

    Public Sub EnableFreePlay(post_event)
        m_free_play = True
        SetMachineVar "free_play", 1
        RemoveGameHandlers()
        DisableCreditHandlers()
        m_credit_play_active = False
        UpdateCreditStrings()
        If post_event Then
            Glf_BcpSendEvent "enabling_free_play", Null
            DispatchPinEvent "enabling_free_play", Null
        End If
    End Sub

    Public Sub ToggleCreditPlay()
        If m_free_play Then
            EnableCreditPlay True
        Else
            EnableFreePlay True
        End If
    End Sub

    Private Sub RemoveGameHandlers()
        RemovePinEventListener "player_add_request", m_name & "_player_add_request"
        RemovePinEventListener "request_to_start_game", m_name & "_request_to_start_game"
        RemovePinEventListener "player_added", m_name & "_player_added"
        RemovePinEventListener "game_started", m_name & "_game_started"
        RemovePinEventListener "ball_starting", m_name & "_ball_starting"
    End Sub

    Private Sub EnableCreditHandlers()
        Dim coin_switch, service_switch, credit_event
        For Each coin_switch in m_switches.Items()
            AddPinEventListener coin_switch.Switch & "_active", m_name & "_coin_" & coin_switch.Switch, "CreditsEventHandler", m_priority, Array("coin", Me, coin_switch)
        Next
        For Each service_switch in m_service_credits_switches
            AddPinEventListener service_switch & "_active", m_name & "_service_" & service_switch, "CreditsEventHandler", m_priority, Array("service_credit", Me)
        Next
        For Each credit_event in m_events.Items()
            AddPinEventListener credit_event.EventObject.EventName, m_name & "_event_" & credit_event.EventObject.Name, "CreditsEventHandler", m_priority, Array("credit_event", Me, credit_event)
        Next
    End Sub

    Private Sub DisableCreditHandlers()
        Dim coin_switch, service_switch, credit_event
        For Each coin_switch in m_switches.Items()
            RemovePinEventListener coin_switch.Switch & "_active", m_name & "_coin_" & coin_switch.Switch
        Next
        For Each service_switch in m_service_credits_switches
            RemovePinEventListener service_switch & "_active", m_name & "_service_" & service_switch
        Next
        For Each credit_event in m_events.Items()
            RemovePinEventListener credit_event.EventObject.EventName, m_name & "_event_" & credit_event.EventObject.Name
        Next
    End Sub

    ' ----- Game hooks -----

    ' Both requests are relays. Returns True when there is a credit to pay with.
    Public Function HasCreditForPlayer()
        If GetCreditUnits() >= m_credit_units_per_game Then
            HasCreditForPlayer = True
        Else
            Log "Request denied. Not enough credits."
            Glf_BcpSendEvent "not_enough_credits", Null
            DispatchPinEvent "not_enough_credits", Null
            HasCreditForPlayer = False
        End If
    End Function

    Public Sub PlayerAdded()
        Dim new_credit_units : new_credit_units = GetCreditUnits() - m_credit_units_per_game
        If new_credit_units < 0 Then
            new_credit_units = 0
        End If
        SetMachineVar "credit_units", new_credit_units
        UpdateCreditStrings()
    End Sub

    Public Sub GameStarted()
        RemoveDelay m_name & "_clear_fractional_credits"
        RemoveDelay m_name & "_clear_all_credits"
        m_credit_units_for_pricing_tiers = 0
        m_reset_pricing_tier_count_this_game = False
    End Sub

    ' Money put in during a game counts toward the pricing tiers only until the second ball
    Public Sub BallStarting(kwargs)
        If Not IsObject(kwargs) Then
            Exit Sub
        End If
        If kwargs("player") = 1 And kwargs("ball") = 2 Then
            If Not m_reset_pricing_tier_count_this_game Then
                m_credit_units_for_pricing_tiers = 0
                m_reset_pricing_tier_count_this_game = True
            End If
        End If
    End Sub

    ' ----- Adding credits -----

    Public Sub CoinSwitch(coin_switch)
        Log "Coin switch " & coin_switch.Switch & ". Value: " & coin_switch.Value
        AddCreditUnits AsWhole(coin_switch.Value / m_credit_unit), True
        ResetTimeouts()
    End Sub

    Public Sub CreditEvent(credit_event)
        If credit_event.EventObject.Evaluate() = False Then
            Exit Sub
        End If
        Log "Credit event. Credits: " & credit_event.Credits
        AddCreditUnits AsWhole(credit_event.Credits * m_credit_units_per_game), False
        ResetTimeouts()
    End Sub

    Public Sub ServiceCredit()
        Log "Service credit added"
        AddCredit False
    End Sub

    ' One whole credit. price_tiering says whether it counts toward the tier discounts.
    Public Sub AddCredit(price_tiering)
        AddCreditUnits m_credit_units_per_game, price_tiering
    End Sub

    Private Sub AddCreditUnits(credit_units, price_tiering)
        Dim previous_credit_units, total_credit_units, max_credit_units, i
        previous_credit_units = GetCreditUnits()
        total_credit_units = credit_units + previous_credit_units

        m_credit_units_for_pricing_tiers = m_credit_units_for_pricing_tiers Mod m_pricing_tiers_wrap_around
        If price_tiering Then
            For i = 1 To credit_units
                m_credit_units_for_pricing_tiers = m_credit_units_for_pricing_tiers + 1
                total_credit_units = total_credit_units + m_pricing_table(CStr(m_credit_units_for_pricing_tiers))
                m_credit_units_for_pricing_tiers = m_credit_units_for_pricing_tiers Mod m_pricing_tiers_wrap_around
            Next
        End If

        max_credit_units = m_max_credits * m_credit_units_per_game
        If max_credit_units > 0 And total_credit_units > max_credit_units Then
            Log "Max credits reached"
            Glf_BcpSendEvent "max_credits_reached", Null
            DispatchPinEvent "max_credits_reached", Null
            SetMachineVar "credit_units", max_credit_units
            UpdateCreditStrings()
        End If
        If max_credit_units <= 0 Or max_credit_units > previous_credit_units Then
            If max_credit_units <= 0 Or total_credit_units <= max_credit_units Then
                SetMachineVar "credit_units", total_credit_units
            End If
            UpdateCreditStrings()
            Glf_BcpSendEvent "credits_added", Null
            DispatchPinEvent "credits_added", Null
        End If
    End Sub

    ' ----- Expiry -----

    Private Sub ResetTimeouts()
        If m_fractional_credit_expiration_time > 0 Then
            SetDelay m_name & "_clear_fractional_credits", "CreditsEventHandler", Array(Array("clear_fractional_credits", Me), Null), m_fractional_credit_expiration_time
        End If
        If m_credit_expiration_time > 0 Then
            SetDelay m_name & "_clear_all_credits", "CreditsEventHandler", Array(Array("clear_all_credits", Me), Null), m_credit_expiration_time
        End If
    End Sub

    Public Sub ClearFractionalCredits()
        Log "Clearing fractional credits"
        Dim units : units = GetCreditUnits()
        SetMachineVar "credit_units", units - (units Mod m_credit_units_per_game)
        UpdateCreditStrings()
    End Sub

    Public Sub ClearAllCredits()
        Log "Removing all credits"
        SetMachineVar "credit_units", 0
        m_credit_units_for_pricing_tiers = 0
        UpdateCreditStrings()
    End Sub

    ' ----- Display strings -----

    Private Sub UpdateCreditStrings()
        If m_free_play Then
            SetMachineVar "credits_string", m_free_play_string
            Exit Sub
        End If
        Dim units, whole_num, numerator, denominator, display_fraction
        units = GetCreditUnits()
        If m_credit_units_per_game > 0 Then
            whole_num = units \ m_credit_units_per_game
            numerator = units Mod m_credit_units_per_game
            denominator = m_credit_units_per_game
        Else
            whole_num = 0
            numerator = 0
            denominator = 0
        End If
        If numerator <> 0 Then
            If whole_num <> 0 Then
                display_fraction = whole_num & " " & numerator & "/" & denominator
            Else
                display_fraction = numerator & "/" & denominator
            End If
        Else
            display_fraction = CStr(whole_num)
        End If
        SetMachineVar "credits_string", m_credits_string & " " & display_fraction
        SetMachineVar "credits_value", display_fraction
        SetMachineVar "credits_whole_num", whole_num
        SetMachineVar "credits_numerator", numerator
        SetMachineVar "credits_denominator", denominator
    End Sub

    Private Sub Log(message)
        If m_debug = True Then
            glf_debugLog.WriteToLog m_name, message
        End If
    End Sub

    ' The machine-wide credits: section of an MPF config
    Public Function ToYaml()
        Dim yaml, item, index
        yaml = "credits:" & vbCrLf
        yaml = yaml & "  max_credits: " & m_max_credits & vbCrLf
        If m_free_play Then
            yaml = yaml & "  free_play: yes" & vbCrLf
        Else
            yaml = yaml & "  free_play: no" & vbCrLf
        End If
        If UBound(m_service_credits_switches) > -1 Then
            yaml = yaml & "  service_credits_switch: " & Join(m_service_credits_switches, ", ") & vbCrLf
        End If
        If UBound(m_switches.Keys) > -1 Then
            yaml = yaml & "  switches:" & vbCrLf
            For Each item in m_switches.Items()
                yaml = yaml & "    - switch: " & item.Switch & vbCrLf
                yaml = yaml & "      type: " & item.SwitchType & vbCrLf
                yaml = yaml & "      value: " & item.Value & vbCrLf
                If Not IsEmpty(item.Label) Then
                    yaml = yaml & "      label: " & item.Label & vbCrLf
                End If
            Next
        End If
        If UBound(m_events.Keys) > -1 Then
            yaml = yaml & "  events:" & vbCrLf
            For Each item in m_events.Items()
                yaml = yaml & "    - event: " & item.EventObject.Raw & vbCrLf
                yaml = yaml & "      type: " & item.EventType & vbCrLf
                yaml = yaml & "      credits: " & item.Credits & vbCrLf
            Next
        End If
        If UBound(m_tier_prices) > -1 Then
            yaml = yaml & "  pricing_tiers:" & vbCrLf
            For index = 0 To UBound(m_tier_prices)
                yaml = yaml & "    - price: " & m_tier_prices(index) & vbCrLf
                yaml = yaml & "      credits: " & m_tier_credits(index) & vbCrLf
            Next
        End If
        If m_fractional_credit_expiration_time > 0 Then
            yaml = yaml & "  fractional_credit_expiration_time: " & m_fractional_credit_expiration_time & "ms" & vbCrLf
        End If
        If m_credit_expiration_time > 0 Then
            yaml = yaml & "  credit_expiration_time: " & m_credit_expiration_time & "ms" & vbCrLf
        End If
        yaml = yaml & "  free_play_string: " & m_free_play_string & vbCrLf
        yaml = yaml & "  credits_string: " & m_credits_string & vbCrLf
        ToYaml = yaml
    End Function
End Class

Function CreditsEventHandler(args)
    Dim ownProps, kwargs : ownProps = args(0)
    If IsObject(args(1)) Then
        Set kwargs = args(1)
    Else
        kwargs = args(1)
    End If
    Dim evt : evt = ownProps(0)
    Dim credits_device : Set credits_device = ownProps(1)
    Select Case evt
        Case "enable_free_play"
            credits_device.EnableFreePlay True
        Case "enable_credit_play"
            credits_device.EnableCreditPlay True
        Case "toggle_credit_play"
            credits_device.ToggleCreditPlay
        Case "clear_all_credits"
            credits_device.ClearAllCredits
        Case "clear_fractional_credits"
            credits_device.ClearFractionalCredits
        Case "coin"
            credits_device.CoinSwitch ownProps(2)
        Case "credit_event"
            credits_device.CreditEvent ownProps(2)
        Case "service_credit"
            credits_device.ServiceCredit
        Case "player_added"
            credits_device.PlayerAdded
        Case "game_started"
            credits_device.GameStarted
        Case "ball_starting"
            credits_device.BallStarting kwargs
        Case "player_add_request"
            ' A relay: pass a refusal from an earlier listener straight on
            If VarType(kwargs) = vbBoolean Then
                If kwargs = True Then
                    kwargs = credits_device.HasCreditForPlayer()
                End If
            End If
        Case "request_to_start_game"
            ' Also a relay. The start button posts it during a game as well, where it does nothing.
            If VarType(kwargs) = vbBoolean And glf_gameStarted = False Then
                If kwargs = True Then
                    kwargs = credits_device.HasCreditForPlayer()
                End If
            End If
    End Select
    If IsObject(args(1)) Then
        Set CreditsEventHandler = kwargs
    Else
        CreditsEventHandler = kwargs
    End If
End Function
