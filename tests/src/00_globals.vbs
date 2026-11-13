'*******************************************
'  GLF TEST BED
'*******************************************
' This table has no playfield parts. The trough, the plunger lane and every
' ball device are script objects (see 10_virtual_table.vbs), so balls go
' exactly where a test sends them and nothing depends on physics.
'
' Files are concatenated in name order by tests/run-tests.js, followed by the
' scenarios and then glf.vbs. Do not edit the generated script.vbs.

Option Explicit

' --- Globals GLF expects the table to define ---
Const cGameName = "glftest"
Const BallSize  = 50
Const BallMass  = 1
Const tnob      = 5                 'Balls in the trough

Dim gBOT
Dim tablewidth  : tablewidth  = Table1.width
Dim tableheight : tableheight = Table1.height

' --- Test bed timings, in milliseconds ---
Const TB_TROUGH_TRANSIT_MS = 150    'Ball rolling from one trough position to the next, or to the plunger
Const TB_EJECT_TRANSIT_MS  = 300    'Ball travelling from a device to wherever it is routed
Const TB_SHOT_TRANSIT_MS   = 100    'Ball travelling from the playfield into a device
Const TB_SETTLE_MS         = 200    'Balls in a multi-switch device rolling down after one leaves

' --- Timings given to the GLF ball devices under test ---
Const TB_ENTRANCE_COUNT_DELAY = 200
Const TB_EJECT_TIMEOUT        = 600
