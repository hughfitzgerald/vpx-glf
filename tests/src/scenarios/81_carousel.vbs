'A carousel highlights one item at a time, wraps round, skips items whose condition
'is false and selects once.
'Covers feat/carousel.
TB_Scenario "carousel"

Function Scenario_carousel(stage)
    Scenario_carousel = 0
    Select Case stage
        Case 0
            If Not TB_Require("carousel") Then
                Scenario_carousel = TB_DONE
                Exit Function
            End If
            TB_Watch "carousel_item_highlighted"
            TB_Watch "carousel_item_selected"
            TB_Watch "carousel_items_empty"
            TB_Watch "tb_carousel_two_highlighted"
            TB_Post "tb_start_carousel"
            Scenario_carousel = 300
        Case 1
            TB_Eq "first item highlighted as the mode starts", TB_Kwarg("carousel_item_highlighted", "item"), "one"
            TB_Eq "carousel named after its mode", TB_Kwarg("carousel_item_highlighted", "carousel"), "tb_carousel"
            TB_Post "tb_car_next"
            Scenario_carousel = 300
        Case 2
            TB_Eq "next item", TB_Kwarg("carousel_item_highlighted", "item"), "two"
            TB_Eq "direction is forwards", TB_Kwarg("carousel_item_highlighted", "direction"), "forwards"
            TB_Eq "event with the names in it", TB_Seen("tb_carousel_two_highlighted"), 1
            TB_Post "tb_car_next"
            Scenario_carousel = 300
        Case 3
            TB_Eq "item with a false condition is left out", TB_Kwarg("carousel_item_highlighted", "item"), "three"
            TB_Post "tb_car_next"
            Scenario_carousel = 300
        Case 4
            TB_Eq "wraps to the first item", TB_Kwarg("carousel_item_highlighted", "item"), "one"
            TB_Post "tb_car_prev"
            Scenario_carousel = 300
        Case 5
            TB_Eq "wraps back to the last item", TB_Kwarg("carousel_item_highlighted", "item"), "three"
            TB_Eq "direction is backwards", TB_Kwarg("carousel_item_highlighted", "direction"), "backwards"
            TB_Post "tb_car_block"
            Scenario_carousel = 300
        Case 6
            TB_Post "tb_car_next"
            Scenario_carousel = 300
        Case 7
            TB_Eq "blocked carousel does not move", glf_modes("tb_carousel").Carousel.HighlightedItem, "three"
            TB_Post "tb_car_release"
            Scenario_carousel = 300
        Case 8
            TB_Post "tb_car_select"
            Scenario_carousel = 300
        Case 9
            TB_Eq "selected the highlighted item", TB_Kwarg("carousel_item_selected", "item"), "three"
            TB_Post "tb_car_select"
            Scenario_carousel = 300
        Case 10
            TB_Eq "only the first selection counts", TB_Seen("carousel_item_selected"), 1
            TB_Post "tb_car_next"
            Scenario_carousel = 300
        Case 11
            TB_Eq "no movement after selecting", glf_modes("tb_carousel").Carousel.HighlightedItem, "three"
            TB_Post "tb_stop_carousel"
            TB_Post "tb_start_carousel_empty"
            Scenario_carousel = 500
        Case 12
            TB_Eq "carousel with nothing to offer says so", TB_Seen("carousel_items_empty"), 1
            TB_Eq "and stops its mode", glf_modes("tb_carousel_empty").GetValue("active"), False
        Case Else
            Scenario_carousel = TB_DONE
    End Select
End Function
