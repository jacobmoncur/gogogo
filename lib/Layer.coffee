
Service = require "./Service"
Server = require "./Server"
async = require "async"
{curry} = require "fjs"

# Represnts a layer for deployment

class Layer 

  constructor: (@name, layer, @repoName, mainConfig) ->

    layer = @normalizeConfig layer

    if layer.hosts.length > 1
      @groupDeploy = true

    console.log "WORKING WITH #{layer.hosts.length} SERVERS: #{layer.hosts.join(',')}"
    @services = []
    for server in layers.hosts
      serverConfig = new Server @name, server, layer, mainConfig 
      @services.push new Service(@name, serverConfig, @repoName, this)

  deployOne: curry (branch, service, cb) ->
    service.deploy branch, cb

  deploy: (branch, cb) ->
    withBranch = @deployOne branch
    async.forEach @services, withBranch, cb

  logOne: curry (lines, service, cb) ->
    service.serverLogs lines, cb

  serverLogs: (lines, cb) ->
    withLines = @logOne lines
    async.forEach @services, withLines, cb

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
