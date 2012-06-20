
Service = require "./Service"
async = require "async"
{curry} = require "fjs"

# Represnts a group of hosts in a service

class HostGroup

  constructor: (@name, @servers, @mainConfig, @repoName) ->
    console.log "WORKING WITH #{@servers.length} SERVERS: #{@servers.join(',')}"
    @services = []
    for server in servers
      @services.push new Service(@name, server, @mainConfig, @repoName, true)

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

module.exports = HostGroup
