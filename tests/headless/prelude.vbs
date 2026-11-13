' Stand-ins for the things Visual Pinball provides to a table script.
' Loaded by glftest_host before the assembled script.vbs.
' gametime, Table1, TB_HostPrint and TB_HostQuit come from the host program.

' The table collections GLF reads. The test bed has no table parts.
Dim Glf_Switches   : Glf_Switches   = Array()
Dim Glf_Slingshots : Glf_Slingshots = Array()
Dim Glf_Spinners   : Glf_Spinners   = Array()
Dim Glf_Lights     : Glf_Lights     = Array()

Function GetElements()
    GetElements = Array()
End Function

Class TbHostDebug
    Public Sub Print(text)
        TB_HostPrint text
    End Sub
End Class
Dim Debug : Set Debug = New TbHostDebug

Sub QuitPlayer(close_type)
    TB_HostQuit
End Sub

Sub Nudge(angle, force)
End Sub

' One simulated frame: Visual Pinball would fire both table timers
Sub TB_HostTick()
    Glf_GameTimer_Timer
    TB_Timer_Timer
End Sub
