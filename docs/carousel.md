# Carousel

A carousel is a mode that lets the player step through a list of items and select one. It is the usual way to build a mode select screen, a menu, or a set of attract screens. It follows MPF's carousel mode.

Any mode becomes a carousel by configuring its `.Carousel()`. While the mode runs one item is highlighted. Events move the highlight forwards and backwards, and an event selects the highlighted item. What an item means is up to the table.

## Example

```
With CreateGlfMode("mode_select", 300)
    .StartEvents = Array("start_mode_select")
    .StopEvents = Array("carousel_item_selected")

    With .Carousel()
        .SelectableItems = Array("multiball", "frenzy", "wizard{current_player.modes_done==2}")
        .NextItemEvents = Array("s_right_flipper_active")
        .PreviousItemEvents = Array("s_left_flipper_active")
        .SelectItemEvents = Array("s_start_active", "timer_mode_select_complete")
    End With

    With .EventPlayer()
        .Add "mode_select_multiball_selected", Array("start_multiball_mode")
        .Add "mode_select_frenzy_selected", Array("start_frenzy_mode")
        .Add "mode_select_wizard_selected", Array("start_wizard_mode")
    End With
End With
```

The flippers move through the modes and the start button picks one. The wizard mode is only offered once the player has finished two modes.

## Settings

### SelectableItems
```Array```

The item names, in order. An item may carry a condition in braces; it is then only offered if the condition is true when the mode starts. If every item has a condition and all are false, the mode posts *carousel_items_empty* and stops.

### NextItemEvents
```Array``` Default: None

Events that highlight the next item.

### PreviousItemEvents
```Array``` Default: None

Events that highlight the previous item.

### SelectItemEvents
```Array``` Default: None

Events that select the highlighted item. Only the first selection counts. The carousel does not stop its mode; stop it on *carousel_item_selected* if that is what you want.

### BlockEvents and ReleaseEvents
```Array``` Default: None

While blocked, the highlight does not move. Use these to stop a flipper cancel from also changing the item.

### WrapItems
```Boolean``` Default: True

Go round from the last item to the first and back. When False the highlight stops at either end.

## Events

| Event | When | Arguments |
| --- | --- | --- |
| `carousel_item_highlighted` | An item was highlighted, including the first item as the mode starts | `carousel`, `item`, `direction` |
| `carousel_item_selected` | The highlighted item was selected | `carousel`, `item` |
| `carousel_items_empty` | No item's condition was true | `carousel` |
| `<mode>_<item>_highlighted` | With `carousel_item_highlighted` | the same |
| `<mode>_<item>_selected` | With `carousel_item_selected` | the same |

`carousel` is the mode's name. `direction` is `forwards`, `backwards`, or empty for the first item. The two events with the names in them are a GLF addition; MPF posts only the three `carousel_` events.
