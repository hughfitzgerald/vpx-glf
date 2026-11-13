'*******************************************
'  GLF configuration under test
'*******************************************
' One device per behaviour worth testing, and one mode per feature. A mode
' only starts when a scenario posts its start event, so scenarios do not
' interfere with each other.

Sub TB_BuildVirtualTable()
    TB_AddDevice "plunger",  Array("s_tb_plunger")
    TB_AddDevice "scoop",    Array("s_tb_scoop")
    TB_AddDevice "saucer",   Array("s_tb_saucer")
    TB_AddDevice "lock",     Array("s_tb_lock_a", "s_tb_lock_b")
    TB_AddDevice "passthru", Array("s_tb_passthru")
    TB_AddDevice "chain_a",  Array("s_tb_chain_a")
    TB_AddDevice "chain_b",  Array("s_tb_chain_b")
End Sub

Sub ConfigureGlfDevices()

    '*********** DEVICES ***********

    'Plunger lane. Set up like a table with a manual plunger that can also auto-launch.
    With CreateGlfBallDevice("plunger")
        .BallSwitches = Array("s_tb_plunger")
        .EjectTimeout = TB_EJECT_TIMEOUT
        .MechanicalEject = True
        .DefaultDevice = True
        .EjectCallback = "TB_Eject_plunger"
        .AutoFireOnUnexpectedBall = False
    End With

    'Plain single-ball scoop. An unclaimed ball is ejected automatically.
    With CreateGlfBallDevice("scoop")
        .BallSwitches = Array("s_tb_scoop")
        .EjectTimeout = TB_EJECT_TIMEOUT
        .EntranceCountDelay = TB_ENTRANCE_COUNT_DELAY
        .EjectCallback = "TB_Eject_scoop"
    End With

    'Single-ball saucer that keeps an unclaimed ball until told to eject.
    With CreateGlfBallDevice("saucer")
        .BallSwitches = Array("s_tb_saucer")
        .EjectTimeout = TB_EJECT_TIMEOUT
        .EntranceCountDelay = TB_ENTRANCE_COUNT_DELAY
        .AutoFireOnUnexpectedBall = False
        .EjectAllEvents = Array("tb_eject_saucer")
        .EjectCallback = "TB_Eject_saucer"
    End With

    'Two-ball lock. Switch a is the exit.
    With CreateGlfBallDevice("lock")
        .BallSwitches = Array("s_tb_lock_a", "s_tb_lock_b")
        .EjectTimeout = TB_EJECT_TIMEOUT
        .EntranceCountDelay = TB_ENTRANCE_COUNT_DELAY
        .EjectCallback = "TB_Eject_lock"
    End With

    'Pass-through kicker that ejects as soon as its own switch closes.
    With CreateGlfBallDevice("passthru")
        .BallSwitches = Array("s_tb_passthru")
        .EjectTimeout = TB_EJECT_TIMEOUT
        .EntranceCountDelay = TB_ENTRANCE_COUNT_DELAY
        .MechanicalEject = True
        .AutoFireOnUnexpectedBall = False
        .EjectAllEvents = Array("s_tb_passthru_active")
        .EjectCallback = "TB_Eject_passthru"
    End With

    'Two devices in a chain: chain_a ejects into chain_b, whose switch confirms the eject.
    With CreateGlfBallDevice("chain_a")
        .BallSwitches = Array("s_tb_chain_a")
        .EjectTimeout = TB_EJECT_TIMEOUT
        .EntranceCountDelay = TB_ENTRANCE_COUNT_DELAY
        .MechanicalEject = True
        .AutoFireOnUnexpectedBall = False
        .EjectAllEvents = Array("tb_eject_chain_a")
        .EjectTargets = Array("s_tb_chain_b")
        .EjectCallback = "TB_Eject_chain_a"
    End With

    With CreateGlfBallDevice("chain_b")
        .BallSwitches = Array("s_tb_chain_b")
        .EjectTimeout = TB_EJECT_TIMEOUT
        .EntranceCountDelay = TB_ENTRANCE_COUNT_DELAY
        .AutoFireOnUnexpectedBall = False
        .EjectAllEvents = Array("tb_eject_chain_b")
        .EjectCallback = "TB_Eject_chain_b"
    End With

    '*********** MODES ***********

    'Holds one ball in the scoop
    With CreateGlfMode("tb_hold", 200)
        .StartEvents = Array("tb_start_hold")
        .StopEvents = Array("tb_stop_hold")
        With .BallHolds("scoop_hold")
            .BallsToHold = 1
            .HoldDevices = Array("scoop")
            .ReleaseAllEvents = Array("tb_release_hold")
        End With
    End With

    'Holds two balls in the two-ball lock device
    With CreateGlfMode("tb_hold2", 210)
        .StartEvents = Array("tb_start_hold2")
        .StopEvents = Array("tb_stop_hold2")
        With .BallHolds("lock_hold")
            .BallsToHold = 2
            .HoldDevices = Array("lock")
            .ReleaseAllEvents = Array("tb_release_hold2")
        End With
    End With

    'Two-ball multiball lock
    With CreateGlfMode("tb_lock", 300)
        .StartEvents = Array("tb_start_lock")
        .StopEvents = Array("tb_stop_lock")
        With .MultiballLocks("mbl")
            .LockDevices = Array("lock")
            .BallsToLock = 2
            .BallsToReplace = 2
        End With
    End With

    'Two-ball multiball fed from the lock, then the trough
    With CreateGlfMode("tb_mb", 400)
        .StartEvents = Array("tb_enable_mb")
        .StopEvents = Array("tb_disable_mb")
        With .Multiballs("mb")
            .StartEvents = Array("tb_start_mb")
            .BallCount = 2
            .BallCountType = "total"
            .ShootAgain = 0
            .BallLocks = Array("lock")
        End With
    End With

End Sub
