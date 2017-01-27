{CompositeDisposable, Point, Range} = require 'atom'

child_process = require( 'child_process' )

if process.platform is "darwin"
    osaCommands = require( './osa-commands.coffee' )
else
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
      order: 1
    advancePosition:
      title: 'Advance to next line'
      description: 'If True, the cursor advances to the next line after sending the current line (when there is no selection).'
      type: 'boolean'
      default: true
      order: 2
    focusOnTerminal:
      title: 'Focus on terminal after sending commands'
      description: 'After code is sent, bring focus to the terminal.'
      type: 'boolean'
      default: false
      order: 3
    shellProfile:
      title: 'Shell profile'
      description: 'Create a terminal with this profile'
      type: 'string'
      default: ''
      order: 4
    notifications:
      type: 'boolean'
      default: true
      description: 'Send notifications in case of errors/warnings'
      order: 5

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


  osaPrepareCmd: ( CMDs, VARs ) ->
    return "" if CMDs.length is 0
    CMD = "osascript"
    for key, value of VARs
        CMD += " -e 'set " + key + " to "
        if typeof(value) == "string"
            CMD += '"' + value + '"'
        else
            CMD += value
        CMD += "'"
    if typeof(CMDs) is "object"
        for c in CMDs
            CMD += " -e '" + c.trim() + "'"
    else
        CMD += " -e '" + CMDs.trim() + "'"
    return CMD


  # Change grammar to "Python (IDE)"
  changeGrammar: ->
    return unless editor = atom.workspace.getActiveTextEditor()
    if editor.getGrammar().scopeName is 'source.python'
        editor.setGrammar( atom.grammars.grammarForScopeName('source.python.ipython-exec') )


  isTerminalOpen: ->
    if process.platform is "linux"
        try child_process.execSync( "xdotool getwindowname "+idTerminal ); return true
        catch error then return false
    else
        CMD = @osaPrepareCmd( osaCommands.isTerminalOpen, {} )
        val = child_process.execSync( CMD ).toString()
        return ( val[0] is "t" )


  openTerminal: ->
    return unless editor = atom.workspace.getActiveTextEditor()
    @changeGrammar()

    shellProfile = atom.config.get('ipython-exec.shellProfile')

    if process.platform is "linux"
        return if @isTerminalOpen()
        idAtom = child_process.execSync( 'xdotool getactivewindow' ).toString()
        CMD = 'gnome-terminal --title=ATOM-IPYTHON-SHELL'
        if shellProfile
            CMD += " --profile="+shellProfile
        CMD += ' -e ipython &'
        child_process.exec( CMD )
        idTerminal = child_process.execSync( 'xdotool search --sync --name ATOM-IPYTHON-SHELL | head -1', {stdio: 'pipe' } ).toString()
        if !atom.config.get('ipython-exec.focusOnTerminal')
            child_process.execSync( 'xdotool windowactivate '+idAtom )
    else
        CMD = @osaPrepareCmd( osaCommands.openTerminal, {'myProfile': shellProfile} )
        child_process.execSync( CMD )
        if atom.config.get('ipython-exec.focusOnTerminal')
            CMD = @osaPrepareCmd( 'tell application "iTerm" to activate', {} )
            child_process.execSync( CMD )

    if atom.config.get('ipython-exec.notifications')
        atom.notifications.addSuccess("[ipython-exec] ipython terminal connected")


  sendCode: (code) ->
    return if not code
    if not @isTerminalOpen()
        if atom.config.get('ipython-exec.notifications')
            atom.notifications.addError("[ipython-exec] Open the ipython terminal first")
        return

    if process.platform is "darwin" then @iterm2(code)
    else @gnometerminal(code)


  setWorkingDirectory: ->
    return unless editor = atom.workspace.getActiveTextEditor()
    if not @isTerminalOpen()
        if atom.config.get('ipython-exec.notifications')
            atom.notifications.addError("[ipython-exec] Open the ipython terminal first")
        return
    @changeGrammar()

    cwd = editor.getPath()
    if not cwd
        if atom.config.get('ipython-exec.notifications')
            atom.notifications.addWarning("[ipython-exec] Cannot get working directory from file: save it first")
            return
    if atom.config.get('ipython-exec.notifications')
        atom.notifications.addSuccess("[ipython-exec] Changing working directory")
    @sendCode( ('cd "' + cwd.substring(0, cwd.lastIndexOf('/')) + '"').addSlashes() )


  sendCommand: ->
    return unless editor = atom.workspace.getActiveTextEditor()
    @changeGrammar()
    if not @isTerminalOpen()
        if atom.config.get('ipython-exec.notifications')
            atom.notifications.addError("[ipython-exec] Open the ipython terminal first")
        return

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
        if atom.config.get('ipython-exec.advancePosition')
            editor.moveDown( 1 )


  sendCell: ->
    return unless editor = atom.workspace.getActiveTextEditor()
    return unless nLines = editor.getLineCount()
    @changeGrammar()
    if not @isTerminalOpen()
        if atom.config.get('ipython-exec.notifications')
            atom.notifications.addError("[ipython-exec] Open the ipython terminal first")
        return

    lines = editor.buffer.getLines()
    pos = editor.getCursorBufferPosition().row

    # get cell boundaries
    first = 0
    last = nLines-1
    for i in [pos..0]
        if lines[i].indexOf('##') == 0
            first = i
            break
    for i in[pos+1...nLines]
        if lines[i].indexOf('##') == 0
            last = i-1
            break

    # pass text to shell through clipboard
    return unless codeToExecute = editor.getTextInBufferRange( [[first, 0], [last, Infinity]] ).trim()
    atom.clipboard.write( codeToExecute )
    @sendCode( atom.config.get('ipython-exec.textToPaste').addSlashes() )


  moveToPrevCell: ->
    return unless editor = atom.workspace.getActiveTextEditor()
    return unless pos = editor.getCursorBufferPosition().row
    @changeGrammar()

    # get row of prev cell
    lines = editor.buffer.getLines()
    nextPos = 0
    for i in [pos-1...0]
        if lines[i].indexOf('##') == 0
            nextPos = i
            break

    # move cursor
    editor.setCursorBufferPosition([nextPos, 0])


  moveToNextCell: ->
    return unless editor = atom.workspace.getActiveTextEditor()
    return unless nLines = editor.getLineCount()
    pos = editor.getCursorBufferPosition().row
    @changeGrammar()

    # get row of next cell
    lines = editor.buffer.getLines()
    nextPos = pos
    for i in[pos+1...nLines]
        if lines[i].indexOf('##') == 0
            nextPos = i
            break
    # move cursor
    editor.setCursorBufferPosition([nextPos, 0])


  iterm2: (codeToExecute) ->
    if atom.config.get 'ipython-exec.focusOnTerminal'
        CMD = @osaPrepareCmd( 'tell application "iTerm" to activate', {} )
        child_process.execSync( CMD ).toString()
    CMD = @osaPrepareCmd( osaCommands.writeText, {'myCode':codeToExecute} )
    child_process.execSync( CMD )


  gnometerminal: (codeToExecute) ->
    child_process.execSync( 'xdotool windowactivate '+idTerminal )
    child_process.execSync( 'xdotool type --delay 10 --clearmodifiers "'+codeToExecute+'"' )
    child_process.execSync( 'xdotool key --clearmodifiers Return' )
    if !atom.config.get 'ipython-exec.focusOnTerminal'
        child_process.execSync( 'xdotool windowactivate '+idAtom )
