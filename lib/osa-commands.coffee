module.exports =

    openTerminal: '
    tell application "System Events" to set is_running to (name of processes contains "iTerm2")\n
    tell application "iTerm"\n
        if not is_running then\n
            if (count windows) is not 0 then tell current tab of current window to close\n
            try\n
                set w to (create window with profile myProfile command "bash -l -c ipython -i")\n
            on error\n
                set w to (create window with default profile command "bash -l -c ipython -i")\n
            end try\n
            tell current session of w to set name to "ATOM-IPYTHON-EXEC"\n
        else\n
            repeat with w in windows\n
                repeat with t in tabs of w\n
                    if (name of sessions of t) contains "ATOM-IPYTHON-EXEC" then\n
                        select w\n
                        return\n
                    end if\n
                end repeat\n
            end repeat\n
            try\n
                set w to (create window with profile myProfile command "bash -l -c ipython -i")\n
            on error\n
                set w to (create window with default profile command "bash -l -c ipython -i")\n
            end try\n
            tell current session of w to set name to "ATOM-IPYTHON-EXEC"\n
        end if\n
    end tell'

    writeText: '
    tell application "iTerm"
        tell current session of current window to write text code
    end tell'
