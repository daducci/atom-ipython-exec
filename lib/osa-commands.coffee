module.exports =

    isTerminalOpen : [
        'tell application "System Events" to set is_running to (name of processes contains "iTerm2")',
        'if not is_running then return false',
        'tell application "iTerm"',
        '    repeat with w in windows',
        '        repeat with t in tabs of w',
        '            if (name of sessions of t) contains "ATOM-IPYTHON-EXEC" then return true',
        '        end repeat',
        '    end repeat',
        '    return false',
        'end tell'
    ]

    openTerminal: [
        'tell application "System Events" to set is_running to (name of processes contains "iTerm2")',
        'tell application "iTerm"',
        '    if not is_running then',
        '        if (count windows) is not 0 then tell current tab of current window to close',
        '        try',
        '            set w to (create window with profile myProfile command "bash -l -c ipython -i")',
        '        on error',
        '            set w to (create window with default profile command "bash -l -c ipython -i")',
        '        end try',
        '        tell current session of w to set name to "ATOM-IPYTHON-EXEC"',
        '    else',
        '        repeat with w in windows',
        '            repeat with t in tabs of w',
        '                if (name of sessions of t) contains "ATOM-IPYTHON-EXEC" then',
        '                    tell t to select',
        '                    tell w to select',
        '                    return',
        '                end if',
        '            end repeat',
        '        end repeat',
        '        try',
        '            set w to (create window with profile myProfile command "bash -l -c ipython -i")',
        '        on error',
        '            set w to (create window with default profile command "bash -l -c ipython -i")',
        '        end try',
        '        tell current session of w to set name to "ATOM-IPYTHON-EXEC"',
        '    end if',
        'end tell'
    ]

    writeText: [
        'tell application "iTerm"',
        '    tell current session of current window to write text myCode',
        'end tell'
    ]
