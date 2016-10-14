{CompositeDisposable, Point, Range} = require 'atom'

String::addSlashes = ->
  @replace(/[\\"]/g, "\\$&").replace /\u0000/g, "\\0"

apps =
  iterm: 'iTerm'
  iterm2: 'iTerm2'
  terminal: 'Terminal'


module.exports =
  config:
    whichApp:
      type: 'string'
      enum: [apps.iterm, apps.iterm2, apps.terminal]
      default: apps.iterm2
      description: 'Which application to send code to'
    pasteFromClipboard:
      title: 'String to write to shell through the clipboard'
      description: 'String to write into shell to copy selections/cells through clipboard? (if empty, text is directly pasted)'
      type: 'string'
      default: ''
    advancePosition:
      type: 'boolean'
      default: true
      description: 'Cursor advances to the next line after ' +
        'sending the current line when there is no selection'
    focusWindow:
      type: 'boolean'
      default: false
      description: 'After code is sent, bring focus to where it was sent'
    shellCellStringPrefix:
      type: 'string'
      default: '##'
      description: 'Specify the string prefix to delimit different cells.'

  subscriptions: null

  activate: (state) ->
    @subscriptions = new CompositeDisposable()
    @subscriptions.add atom.commands.add 'atom-workspace',
      'ipython-exec:setwd': => @setWorkingDirectory()
      'ipython-exec:send-command': => @sendCommand()
      'ipython-exec:send-cell': => @sendCell()
      'ipython-exec:prev-cell': => @moveToPrevCell()
      'ipython-exec:next-cell': => @moveToNextCell()
      'ipython-exec:set-iterm': => @setIterm()
      'ipython-exec:set-iterm2': => @setIterm2()
      'ipython-exec:set-terminal': => @setTerminal()

  deactivate: ->
    @subscriptions.dispose()


  setIterm: ->
    atom.config.set('ipython-exec.whichApp', apps.iterm)
  setIterm2: ->
    atom.config.set('ipython-exec.whichApp', apps.iterm2)
  setTerminal: ->
    atom.config.set('ipython-exec.whichApp', apps.terminal)


  sendCode: (code, whichApp) ->
    switch whichApp
      when apps.iterm then @iterm(code)
      when apps.iterm2 then @iterm2(code)
      when apps.terminal then @terminal(code)
      else console.error 'ipython-exec.whichApp "' + whichApp + '" is not supported.'


  setWorkingDirectory: ->
    return unless editor = atom.workspace.getActiveTextEditor()
    whichApp = atom.config.get 'ipython-exec.whichApp'

    cwd = editor.getPath()
    if not cwd
      console.error 'No current working directory (save the file first).'
      return
    cwd = cwd.substring(0, cwd.lastIndexOf('/'))
    cwd = "cd \"" + cwd + "\""
    @sendCode(cwd.addSlashes(), whichApp)


  sendCommand: ->
    return unless editor = atom.workspace.getActiveTextEditor()
    whichApp = atom.config.get( 'ipython-exec.whichApp' )
    pasteFromClipboard = atom.config.get('ipython-exec.pasteFromClipboard').addSlashes()

    if selection = editor.getSelectedText()
        if pasteFromClipboard and selection.indexOf('\n') != -1
            atom.clipboard.write( selection )
            @sendCode(pasteFromClipboard, whichApp)
        else
            @sendCode(selection.addSlashes(), whichApp)
    else if cursor = editor.getCursorBufferPosition()
        line = editor.lineTextForBufferRow(cursor.row).toString()
        if pasteFromClipboard
            atom.clipboard.write( line )
            @sendCode(pasteFromClipboard, whichApp)
        else
            @sendCode(line.addSlashes(), whichApp)
        if atom.config.get 'ipython-exec.advancePosition'
            editor.moveDown( 1 )


  sendCell: ->
    return unless editor = atom.workspace.getActiveTextEditor()
    return unless nLines = editor.getLineCount()
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
    # @terminal.stopScrolling()
    whichApp = atom.config.get 'ipython-exec.whichApp'
    pasteFromClipboard = atom.config.get('ipython-exec.pasteFromClipboard').addSlashes()
    selection = editor.getTextInBufferRange( [[first, 0], [last, Infinity]] )
    atom.clipboard.write( selection )
    @sendCode(pasteFromClipboard, whichApp)


  moveToPrevCell: ->
    return unless editor = atom.workspace.getActiveTextEditor()
    return unless nLines = editor.getLineCount()
    lines = editor.buffer.getLines()
    cellPrefix = atom.config.get('ipython-exec.shellCellStringPrefix')
    return unless pos = editor.getCursorBufferPosition().row # skip first line

    # get row of prev cell
    nextPos = 0
    for i in[pos-1...0]
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


  iterm: (selection) ->
    # This assumes the active pane item is an console
    osascript = require 'node-osascript'
    command = []
    focusWindow = atom.config.get 'ipython-exec.focusWindow'
    if focusWindow
      command.push 'tell application "iTerm" to activate'
    command.push 'tell application "iTerm"'
    command.push '  tell the current terminal'
    # if focusWindow
    #   command.push '    activate current session'
    command.push '    tell the last session'
    command.push '      write text code'
    command.push '    end tell'
    command.push '  end tell'
    command.push 'end tell'
    command = command.join('\n')
    osascript.execute command, {code: selection}, (error, result, raw) ->
      if error
        console.error(error)


  iterm2: (selection) ->
    # This assumes the active pane item is an console
    osascript = require 'node-osascript'
    command = []
    focusWindow = atom.config.get 'ipython-exec.focusWindow'
    if focusWindow
      command.push 'tell application "iTerm" to activate'
    command.push 'tell application "iTerm"'
    command.push '  tell the current window'
    command.push '    tell current session'
    command.push '      write text code'
    command.push '    end tell'
    command.push '  end tell'
    command.push 'end tell'
    command = command.join('\n')
    osascript.execute command, {code: selection}, (error, result, raw) ->
      if error
        console.error(error)


  terminal: (selection) ->
    # This assumes the active pane item is an console
    osascript = require 'node-osascript'
    command = []
    focusWindow = atom.config.get 'ipython-exec.focusWindow'
    if focusWindow
      command.push 'tell application "Terminal" to activate'
    command.push 'tell application "Terminal"'
    command.push 'do script code in window 1'
    command.push 'end tell'
    command = command.join('\n')

    osascript.execute command, {code: selection}, (error, result, raw) ->
      if error
        console.error(error)
