{spawn} = require 'child_process'
Cron = require './Cron'
Process = require './Process'

PREFIX = "ggg"

makeCreateScript =  (hook, upstartInstall, cronInstallScript, repoDir, hookFile) ->
  # denyCurrentBranch ignore allows it to accept pushes without complaining
  """
    echo '\nCREATING...'
    mkdir -p #{repoDir}
    cd #{repoDir}
    echo "Locating git"
    which git
    if (( $? )); then
        echo "Could not locate git"
        exit 1
    fi
    git init
    git config receive.denyCurrentBranch ignore

    #{upstartInstall}

    echo "#{hook}" > #{hookFile}
    chmod +x #{hookFile}
    echo "[√] created"
    #{cronInstallScript}
  """


###
# A Service object represents one deploy on one physical machine. You deploy
# to a Target, but the Target creates one Service per machine to manage
# actually putting your code on the machine.
###
class Service
  # we let the host group handle the logging
  log: (msg) ->
    @parent.log @host, msg

  runCommand: (commands, cb) =>
    if @isLocal
      @localCommand "bash", ["-c", commands], cb
    else
      @sshCommand commands, cb

  sshCommand: (commands, cb) =>
    @localCommand 'ssh', ["-o StrictHostKeyChecking=no", @host, commands], (err) ->
      if err? then return cb new Error "SSH Command Failed"
      cb()

  # runs the commands and dumps output as we get it
  localCommand: (command, args, cb) ->
    proc = spawn command, args, {env: process.env}
    proc.stdout.on 'data', (data) => @log data.toString().replace(/\n$/, "")
    proc.stderr.on 'data', (data) => @log data.toString().replace(/\n$/, "")

    proc.on 'exit', (code) ->
      if code then return cb(new Error("Command Failed"))
      cb()

    return proc

  constructor: (@name, @repoName, @config, @parent, @isLocal = false) ->
    # pre compute all the fields we might need
    @id = @repoName + "_" + @name
    @repoDir = "$HOME/#{PREFIX}/#{@id}"
    @historyFile = "$HOME/#{PREFIX}/#{@id}-history.txt"
    @serverUser = @config.getUser()
    @hookFile = "#{@repoDir}/.git/hooks/post-receive"

    @noUpstart = !@config.getStart()

    if @isLocal
      @host = "localhost"
      # for some reason, things aren't preserved, so manually make sure this is
      # set!
      @repoDir = "#{process.env.HOME}/#{PREFIX}/#{@id}"
      @repoUrl = @repoDir
    else
      @host = @config.getHost()
      @repoUrl = "ssh://#{@host}/~/#{PREFIX}/#{@id}"
    @processes = @parseStartCommands @config, @id

  parseStartCommands: (config) ->
    start = config.getStart()
    # some processes have no start
    return [] unless start
    isSingleStartCommand = typeof start is 'string'
    if isSingleStartCommand
      return [new Process {@repoName, @repoDir, target: @name, startCommand: start}]

    Object.keys(start).map (processName) =>
      new Process {@repoName, @repoDir, processName: processName, target: @name, startCommand: start[processName]}

  create: (cb) ->
    @log " - id: #{@id}"
    @log " - repo: #{@repoDir}"
    @log " - remote: #{@repoUrl}"
    @log " - start: #{@config.getStart()}"
    @log " - install: #{@config.getInstall()}"

    hookScript = @makeHookScript @historyFile, @repoDir
    # CRON SUPPORT
    cronConfig = @config.getCron()
    cronScript = ''

    if cronConfig
      cron = new Cron cronConfig, @id, @repoDir, @serverUser
      cronScript = cron.buildCron()

    upstartInstall = @createUpstartInstall @processes, @serverUser

    createRemoteScript = makeCreateScript hookScript, upstartInstall, cronScript,  @repoDir, @hookFile

    @runCommand createRemoteScript, (err) ->
      if err? then return cb err
      cb()

  createUpstartInstall: (processes, serverUser) ->
    return '' if @noUpstart
    processes.map((p) -> p.makeLogUpstartAndLogRotateFilesCommand(serverUser)).join('\n')

  makeHookScript: (historyFile, repoDir) ->
    # http://toroid.org/ams/git-website-howto
    # this hook ensures that we check out the right revision and also keep
    # track of what we have deploy
    """
      read oldrev newrev refname
      echo 'GOGOGO checking out:'
      echo \\$newrev
      echo \\`date\\` - \\$newrev >> #{historyFile}
      cd #{repoDir}/.git
      GIT_WORK_TREE=#{repoDir} git reset --hard \\$newrev || exit 1;
    """

  deploy: (branch, cb) ->
    @log " - name: #{@name}"
    @log " - server: #{@host}"
    @log " - branch: #{branch}"

    # create first
    @create (err) =>
      if err? then return cb err

      @log "\nPUSHING"

      @localCommand "git", ["push", @repoUrl, branch, "-f"], (err) =>
        if err? then return cb err
        @log "[√] pushed"

        # now install and run
        installCommand = @makeInstallCommand() + "\n" + @makeRestartCommands(@processes)
        @runCommand installCommand, (err) =>
          if err? then return cb err

          # no op this so the kill doesn't cause an error!
          command = @serverLogs 10, ->

          # for some reason it takes a while to actually kill it, like 10s
          kill = ->
            command.kill()
            cb()
          setTimeout kill, 2000

  makeRestartCommands: (processes) ->
    @processes.map((p) -> p.makeRestartCommand()).join('\n')

  makeInstallCommand: ->
    """
      echo '\nINSTALLING'
      cd #{@repoDir}
      #{@config.getInstall()} || exit 1;
      echo '[√] installed'
    """

  restart: (processName, cb) ->
    if typeof processName is 'function'
      return @runAllCommand 'restart', processName
    @runCommandForProcess 'restart', processName, cb

  runAllCommand: (command, cb) ->
    @log "RUNNING #{command.toUpperCase()} for all processes"
    commandToRun = @processes.map((p) -> p[command]()).join('\n')
    @runCommand commandToRun, cb

  runCommandForProcess: (command, processName, cb) ->
    @log "RUNNING #{command.toUpperCase()} for #{processName}"
    process = @findProcess processName
    if not process
      return cb new Error 'no process for ' + processName + ', can\'t run ' + command
    @runCommand process[command](), cb

  stop: (processName, cb) ->
    if typeof processName is 'function'
      return @runAllCommand 'stop', processName
    @runCommandForProcess 'stop', processName, cb

  start: (processName, cb) ->
    if typeof processName is 'function'
      return @runAllCommand 'start', processName
    @runCommandForProcess 'start', processName, cb

  findProcess: (processName) ->
    @processes.filter((p) -> p.processName is processName)[0]

  logFileForCommandName: (processName) ->
    "#{@repoDir}/#{processName}.ggg.log"

  # this will never exit. You have to Command-C it, or stop the spawned process
  serverLogs: (lines, processName, cb) ->
    process = null
    if typeof processName is 'function'
      cb = processName
      # just find the first one?
      process = @processes[0]
    else
      process = @findProcess processName

    if !process
      return cb new Error 'Could not find process to log :('
    logFile = process.logFile()
    @log "Tailing #{logFile}... Control-C to exit"
    @log "-------------------------------------------------------------"
    @runCommand "tail -n #{lines} -f #{logFile}", cb

  getHistory: (revisions, cb) ->
    @log "Retrieving last #{revisions} deploys, most recent first!"
    @log "-------------------------------------------------------------"
    @runCommand "tail -n #{revisions} #{@historyFile} | tac", cb

  runCommandInRepo: (command, cb) ->
    @log "Running command #{command} in #{@repoDir}"
    @runCommand "cd #{@repoDir} && #{command}", cb

module.exports = Service
