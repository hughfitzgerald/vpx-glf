'*******************************************
'  Table events
'*******************************************

Sub Table1_Init
    TB_BuildVirtualTable
    ConfigureGlfDevices
    Glf_Init(Table1)
End Sub

Sub Table1_Exit
    Glf_Exit()
End Sub

Sub Table1_KeyDown(ByVal keycode)
    Glf_KeyDown keycode
End Sub

Sub Table1_KeyUp(ByVal keycode)
    Glf_KeyUp keycode
End Sub

'TB_Timer is a table timer with interval -1, so this runs every frame
Sub TB_Timer_Timer()
    TB_Tick
End Sub
