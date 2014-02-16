
path = require "path"
{EventEmitter} = require "events"
Service = require "./Service"
Server = require "./Server"
async = require "async"
{curry} = require "fjs"
clc = require "cli-color"

COLORS = [
  "white",
  "red",
  "green",
  "yellow",
  "blue",
  "magenta",
  "cyan"
]
# Represnts a target for deployment

class Target extends EventEmitter

  constructor: (@name, target, @repoName, mainConfig, isLocal) ->
    @runPlugins target, mainConfig, (err) =>
      return @emit "error", err if err?

      @services = []

      # if we are local, we want to keep around one host to parse its info, but
      # we just want to deploy locally
      if isLocal
        console.log "DEPLOYING LOCALLY"
        target.hosts = [target.hosts[0]]
      else
        console.log "WORKING WITH #{target.hosts.length} SERVERS: #{target.hosts.join(',')}"

      @colorMap = {}
      if target.hosts.length > 1
        @groupDeploy = true

      for server, index in target.hosts
        serverConfig = new Server @name, server, target, mainConfig
        service = new Service(@name, @repoName, serverConfig, this, isLocal)
        @services.push service
        @colorMap[service.host] = COLORS[index % COLORS.length]

      console.log 'service is', service
      @emit "ready"

  # we resolve and run the plugins here, as they can change any parameters here
  runPlugins: (target, mainConfig, cb) ->
    plugins = target.plugins || mainConfig.getPlugins()
    # this needs to go on the next tick so we have time to attached the handler
    return process.nextTick cb if not plugins
    toRun = []
    for name, plugin of plugins
      plugin.name = name
      toRun.push plugin

    withTarget = @runPlugin target
    async.forEach toRun, withTarget, cb

  runPlugin: curry (target, plugin, cb) ->
    if not plugin.overrides
      return cb new Error("invalid plugin definition, you need an overrides directive")

    pluginPath = ''
    if plugin.name.match /^\.\//
      pluginPath = path.join process.cwd(), plugin.name
    else
      pluginPath = path.join __dirname, '../plugins/', plugin.name

    pluginModule = require pluginPath
    console.log "running plugin at #{pluginPath}"
    pluginModule plugin.opts, (err, res) ->
      return cb err if err?
      target[plugin.overrides] = res
      cb()

  deployOne: curry (branch, service, cb) ->
    service.deploy branch, cb

  deploy: (branch, cb) ->
    withBranch = @deployOne branch
    async.forEach @services, withBranch, cb

  logOne: curry (lines, service, cb) ->
    service.serverLogs lines, cb

  logOneForProcess: curry (lines, processName, service, cb) ->
    service.serverLogs lines, processName, cb

  historyOne: curry (revisions, service, cb) ->
    service.getHistory revisions, cb

  serverLogs: (lines, processName, cb) ->
    if typeof processName is 'function'
      cb = processName
      withLines = @logOne lines
    else
      withLines = @logOneForProcess lines, processName
    async.forEach @services, withLines, cb

  commitHistory: (revisions, cb) ->
    withRevisions = @historyOne revisions
    async.forEach @services, withRevisions, cb

  runCommandOne: curry (command, service, cb) ->
    service.runCommandInRepo command, cb

  runCommand: (command, cb) ->
    async.forEach @services, @runCommandOne(command), cb

  # do these ones generically, because no params
  restart: (processName, cb) ->
    @serviceAction 'restart', processName, cb

  start: (processName, cb) ->
    @serviceAction 'start', processName, cb

  stop: (processName, cb) ->
    @serviceAction 'stop', processName, cb

  serviceAction: (action, processName, cb) =>
    if typeof processName is 'function'
      cb = processName
      actionCurry = @action action
    else
      actionCurry = @actionForProcess action, processName
    async.forEach @services, actionCurry, cb

  actionForProcess: curry (action, processName, service, cb) ->
    service[action] processName, cb

  action: curry (action, service, cb) ->
    service[action] cb

  log: (parentAddress, msg) ->
    logLine = (line) =>
      color = @colorMap[parentAddress] || "white"
      console.log clc[color](parentAddress + ": ") + line

    if @groupDeploy
      msg.split("\n").forEach logLine
    else
      console.log msg

module.exports = Target
