
path = require "path"

# read a config file
readConfig = (f, cb) ->
  try
    m = require f
  catch e
    console.log "BAD", e
    throw e
    cb e
  cb null, m


class MainConfig

  constructor: ({@start, @install, @cron, servers}) ->
    # normalize to an array for multi server deploys
    @layers = []
    for name, layer of servers 
      @layers[name] = @normalizeLayer layer

  getLayerByName: (name) ->
    @layers[name] || throw new Error "Cannot find server named #{name}. Check your config file"

  getStart: ->
    @start

  getInstall: ->
    @install

  getLayerNames: ->
    Object.keys @layers

  #returns false if not defined
  getCron: ->
    if @cron? then @normalizeCron @cron else false

  normalizeCron: (cron) ->
    # support the old syntax
    if typeof cron == "string"
      console.log "using deprecated cron syntax"
      matches = cron.match(/([0-9\s\*]+)\s+(.*)/)
      if not matches? then throw new Error "Invalid Cron: #{@cron}"
      warning = 
        """
        you should switch your cron to instead be the following in ggg.js:
          cron: { cronName: {time: #{matches[1]}, command: #{matches[2]} } }
        """
      console.log warning
      cron = {default: {time: matches[1], command: matches[2]}}

    return cron


  normalizeLayer: (config) ->
    if typeof config == "string"
      config = {
        hosts: [config]
      }
    else if Array.isArray config
      config = {
        hosts: config
      }
    else if typeof config.hosts == "string"
      config.hosts = [config.hosts]

    return config


MainConfig.loadFromFile = (file, cb) ->
  readConfig file, (err, config) ->
    if err? then return cb err
    cb null, new MainConfig config

module.exports = MainConfig
