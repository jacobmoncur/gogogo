
path = require "path"

# read a config file
readConfig = (f, cb) ->
  try
    m = require f
    cb null, m
  catch e
    console.log "BAD", e
    throw e
    cb e


class MainConfig

  constructor: ({@start, @install, @cron, servers}) ->
    # normalize to an array for multi server deploys
    @servers = []
    for name, server of servers
      @servers[name] = if Array.isArray(server) then server else [server]

  getServerByName: (name) ->
    @servers[name] || throw new Error "Cannot find server named #{name}. Check your config file"

  getStart: ->
    @start || throw new Error "You must specify 'start:' in your config file"

  getInstall: ->
    @install || throw new Error "You must specify 'install:' in your config file"

  getServerNames: ->
    Object.keys @servers

  #returns false if not defined
  getCronConfig: ->
    return false if not @cron?
    matches = @cron.match(/([0-9\s\*]+)\s+(.*)/)
    if not matches? then throw new Error "Invalid Cron: #{@cron}"
    return {time: matches[1], command: matches[2]}


MainConfig.loadFromFile = (file, cb) ->
  readConfig file, (err, config) ->
    if err? then return cb err
    cb null, new MainConfig config

module.exports = MainConfig
