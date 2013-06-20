
path = require "path"
{EventEmitter} = require "events"
Service = require "./Service"
Server = require "./Server"
async = require "async"
{curry} = require "fjs"

# Represnts a layer for deployment

class Layer extends EventEmitter

  constructor: (@name, layer, @repoName, mainConfig, isLocal) ->
    @runPlugins layer, mainConfig, (err) =>
      return @emit "error", err if err?

      @services = []

      # if we are local, we want to keep around one host to parse its info, but
      # we just want to deploy locally
      if isLocal
        console.log "DEPLOYING LOCALLY"
        layer.hosts = [layer.hosts[0]]
      else
        console.log "WORKING WITH #{layer.hosts.length} SERVERS: #{layer.hosts.join(',')}"

      if layer.hosts.length > 1
        @groupDeploy = true

      for server in layer.hosts
        serverConfig = new Server @name, server, layer, mainConfig
        @services.push new Service(@name, @repoName, serverConfig, this, isLocal)

      @emit "ready"

  # we resolve and run the plugins here, as they can change any parameters here
  runPlugins: (layer, mainConfig, cb) ->
    plugins = layer.plugins || mainConfig.getPlugins()
    # this needs to go on the next tick so we have time to attached the handler
    return process.nextTick cb if not plugins
    toRun = []
    for name, plugin of plugins
      plugin.name = name
      toRun.push plugin

    withLayer = @runPlugin layer
    async.forEach toRun, withLayer, cb

  runPlugin: curry (layer, plugin, cb) ->
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
      layer[plugin.overrides] = res
      cb()

  deployOne: curry (branch, service, cb) ->
    service.deploy branch, cb

  deploy: (branch, cb) ->
    withBranch = @deployOne branch
    async.forEach @services, withBranch, cb

  logOne: curry (lines, service, cb) ->
    service.serverLogs lines, cb

  historyOne: curry (revisions, service, cb) ->
    service.getHistory revisions, cb

  serverLogs: (lines, cb) ->
    withLines = @logOne lines
    async.forEach @services, withLines, cb

  commitHistory: (revisions, cb) ->
    withRevisions = @historyOne revisions
    async.forEach @services, withRevisions, cb

  runCommandOne: curry (command, service, cb) ->
    service.runCommandInRepo command, cb

  runCommand: (command, cb) ->
    async.forEach @services, @runCommandOne(command), cb

  # do these ones generically, because no params
  restart: (cb) ->
    @serviceAction "restart", cb

  start: (cb) ->
    @serviceAction "start", cb

  stop: (cb) ->
    @serviceAction "stop", cb

  serviceAction: (action, cb) =>
    actionCurry = @actionOne action
    async.forEach @services, actionCurry, cb

  actionOne: curry (action, service, cb) ->
    service[action] cb

  log: (parentAddress, msg) ->
    if @groupDeploy
      console.log "#{parentAddress}: #{msg}"
    else
      console.log msg

module.exports = Layer
