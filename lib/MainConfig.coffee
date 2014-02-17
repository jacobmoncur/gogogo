path = require 'path'

# read a config file
readConfig = (f, cb) ->
  try
    m = require f
  catch e
    return cb e
  cb null, m

# TODO: this is hacky, duplicating logic in the ServerConfig thing. Do
# we even need that?
formatTargetForListing = (targetName, target, globalStart) ->
  console.log 'targetName', targetName, 'target', target
  target.start or= globalStart
  return targetName if typeof target.start is 'string'

  Object.keys(target.start).map((s) -> "#{targetName}:#{s}").join('\n')

class MainConfig

  constructor: ({@start, @install, @plugins, @cron, targets, servers}) ->
    # allow old ggg.js syntax where 'targets' used to be called 'servers'
    if !targets
      targets = servers

    # normalize to an array for multi server deploys
    @targets = {}
    for name, target of targets
      @targets[name] = @normalizeTarget target

  getTargetByName: (name) ->
    @targets[name] || throw new Error "Cannot find server named #{name}. Check your config file"

  getStart: -> @start

  getInstall: -> @install

  getPlugins: -> @plugins

  disablePlugins: -> @plugins = null

  getTargetNames: -> Object.keys @targets

  # return a string describing the targets and processes
  listTargetsAndProcesses: ->
    Object.keys(@targets).map (targetName) =>
      formatTargetForListing targetName, @targets[targetName], @start
    .join('\n')

  #returns false if not defined
  getCron: -> if @cron? then @normalizeCron @cron else false

  normalizeCron: (cron) ->
    # support the old syntax
    if typeof cron == "string"
      console.log "using deprecated cron syntax"
      matches = cron.match(/([0-9\s\*]+)\s+(.*)/)
      if not matches? then throw new Error "Invalid Cron: #{@cron}"
      warning =
        """
        you should switch your cron to instead be the following in ggg.js:
          cron: { cronName: {time: '#{matches[1]}', command: '#{matches[2]}' } }
        """
      console.log warning
      cron = {default: {time: matches[1], command: matches[2]}}

    return cron

  normalizeTarget: (config) ->
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

  @loadFromFile = (file, cb) ->
    readConfig file, (err, config) ->
      if err? then return cb new Error "Could not load config file #{file}. Are you sure it exists?"
      cb null, new MainConfig config

module.exports = MainConfig
