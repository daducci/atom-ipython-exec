{CompositeDisposable, Point, Range} = require 'atom'
#{BufferedProcess} = require 'atom'

child_process = require( 'child_process' )

if process.platform is "darwin"
    osaNode = require( 'node-osascript' )
    osaCommands = require( './osa-commands.coffee' )

# windows' id to be used with xdotool (only linux)
idAtom = ""
idTerminal = ""


String::addSlashes = ->
  @replace(/[\\"]/g, "\\$&").replace /\u0000/g, "\\0"


module.exports =
  config:
    textToPaste:
      title: 'String to write to the terminal'
      description: 'String to write for copying selections/cells through clipboard (if empty, text is directly pasted).'
      type: 'string'
      default: '%paste -q'
    advancePosition:
      title: 'Advance to next line'
      description: 'If True, the cursor advances to the next line after sending the current line (when there is no selection).'
      type: 'boolean'
      default: true
    focusOnTerminal:
      title: 'Focus on terminal after sending commands'
      description: 'After code is sent, bring focus to the terminal.'
      type: 'boolean'
      default: false
    shellCellStringPrefix:
      title: 'Cell separator'
      description: 'String prefix to delimit different cells.'
      type: 'string'
      default: '##'
    shellProfile:
      title: 'Shell profile'
      description: 'Create a terminal with this profile'
      type: 'string'
      default: ''
    notifications:
      type: 'boolean'
      default: true
      description: 'Send notifications in case of errors/warnings'

  subscriptions: null


  activate: (state) ->
    @subscriptions = new CompositeDisposable()
    @subscriptions.add atom.commands.add 'atom-workspace',
      'ipython-exec:open-terminal': => @openTerminal()
      'ipython-exec:setwd': => @setWorkingDirectory()
      'ipython-exec:send-command': => @sendCommand()
      'ipython-exec:send-cell': => @sendCell()
      'ipython-exec:prev-cell': => @moveToPrevCell()
      'ipython-exec:next-cell': => @moveToNextCell()


  deactivate: ->
    @subscriptions.dispose()


  isTerminalOpen: ->
    try child_process.execSync( "xdotool getwindowname "+idTerminal ); return true
    catch error then return false


  openTerminal: ->
    return unless editor = atom.workspace.getActiveTextEditor()

    if process.platform is "linux"
        child_process.exec( 'xdotool getactivewindow', (error, stdout, stderr) -> idAtom = stdout )
        if not @isTerminalOpen()
            shellProfile = atom.config.get('ipython-exec.shellProfile')
            CMD = 'gnome-terminal --title=ATOM-IPYTHON-SHELL'
            if shellProfile
                CMD += " --profile="+shellProfile
            CMD += ' -e ipython &'
            child_process.exec( CMD )
            idTerminal = child_process.execSync( 'xdotool search --sync --name ATOM-IPYTHON-SHELL | head -1', {stdio: 'pipe' } ).toString()
    else if process.platform is "darwin"
        shellProfile = atom.config.get('ipython-exec.shellProfile')
        osaNode.execute osaCommands.openTerminal, {myProfile: shellProfile}, (error, result, raw) -> if error then console.error(error)
        if atom.config.get 'ipython-exec.focusOnTerminal'
            osaNode.execute 'tell application "iTerm" to activate', {}, (error, result, raw) -> if error then console.error(error)

    if atom.config.get( 'ipython-exec.notifications' )
        atom.notifications.addSuccess("ipython terminal created")


  sendCode: (code) ->
    return if not code
    if process.platform is "darwin" then @iterm2(code)
    else if @isTerminalOpen() then @gnometerminal(code)


  setWorkingDirectory: ->
    return unless editor = atom.workspace.getActiveTextEditor()
    return if process.platform is "linux" and not @isTerminalOpen()

    cwd = editor.getPath()
    if not cwd
        if atom.config.get( 'ipython-exec.notifications' )
            atom.notifications.addWarning("Cannot get working directory from file: save the file first")
            return
    @sendCode( ('cd "' + cwd.substring(0, cwd.lastIndexOf('/')) + '"').addSlashes() )


  sendCommand: ->
    return unless editor = atom.workspace.getActiveTextEditor()
    return if process.platform is "linux" and not @isTerminalOpen()

    textToPaste = atom.config.get('ipython-exec.textToPaste').addSlashes()
    if selection = editor.getSelectedText()
        if textToPaste and selection.indexOf('\n') != -1
            atom.clipboard.write( selection )
            @sendCode( textToPaste )
        else
            @sendCode( selection.addSlashes() )
    else if cursor = editor.getCursorBufferPosition()
        line = editor.lineTextForBufferRow(cursor.row).toString()
        if line
            if textToPaste
                atom.clipboard.write( line )
                @sendCode( textToPaste )
            else
                @sendCode( line.addSlashes() )
        if atom.config.get 'ipython-exec.advancePosition'
            editor.moveDown( 1 )


  sendCell: ->
    return unless editor = atom.workspace.getActiveTextEditor()
    return unless nLines = editor.getLineCount()
    return if process.platform is "linux" and not @isTerminalOpen()

    lines = editor.buffer.getLines()
    cellPrefix = atom.config.get('ipython-exec.shellCellStringPrefix')
    pos = editor.getCursorBufferPosition().row

    # get cell boundaries
    first = 0
    last = nLines-1
    for i in [pos..0]
        if lines[i].indexOf(cellPrefix) == 0
            first = i
            break
    for i in[pos+1...nLines]
        if lines[i].indexOf(cellPrefix) == 0
            last = i-1
            break

    # pass text to shell through clipboard
    textToPaste = atom.config.get('ipython-exec.textToPaste').addSlashes()
    selection = editor.getTextInBufferRange( [[first, 0], [last, Infinity]] )
    return if not selection
    atom.clipboard.write( selection )
    @sendCode( textToPaste )


  moveToPrevCell: ->
    return unless editor = atom.workspace.getActiveTextEditor()
    return unless nLines = editor.getLineCount()

    lines = editor.buffer.getLines()
    cellPrefix = atom.config.get('ipython-exec.shellCellStringPrefix')
    return unless pos = editor.getCursorBufferPosition().row # skip first line

    # get row of prev cell
    nextPos = 0
    for i in [pos-1...0]
        if lines[i].indexOf(cellPrefix) == 0
            nextPos = i
            break

    # move cursor
    editor.setCursorBufferPosition([nextPos, 0])


  moveToNextCell: ->
    return unless editor = atom.workspace.getActiveTextEditor()
    return unless nLines = editor.getLineCount()

    lines = editor.buffer.getLines()
    cellPrefix = atom.config.get('ipython-exec.shellCellStringPrefix')
    pos = editor.getCursorBufferPosition().row

    # get row of next cell
    nextPos = pos
    for i in[pos+1...nLines]
        if lines[i].indexOf(cellPrefix) == 0
            nextPos = i
            break

    # move cursor
    editor.setCursorBufferPosition([nextPos, 0])


  iterm2: (selection) ->
    if atom.config.get 'ipython-exec.focusOnTerminal'
        osaNode.execute 'tell application "iTerm" to activate', {}, (error, result, raw) -> if error then console.error(error)
    osaNode.execute osaCommands.writeText, {code: selection}, (error, result, raw) -> if error then console.error(error)


  gnometerminal: (selection) ->
    child_process.execSync( 'xdotool windowactivate '+idTerminal )
    child_process.execSync( 'xdotool type --delay 10 --clearmodifiers "'+selection+'"' )
    child_process.execSync( 'xdotool key --clearmodifiers Return' )
    if !atom.config.get 'ipython-exec.focusOnTerminal'
        child_process.execSync( 'xdotool windowactivate '+idAtom )
