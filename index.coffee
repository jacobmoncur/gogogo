###
CLI to automatically deploy stuff, kind of like heroku.
Ubuntu only! (upstart)

TODO remember last command again
TODO multiple services
TODO multiple cron

###

CONFIG = "ggg"

LOGS_LINES = 40
COMMIT_HISTORY = 5
VERSION = "0.4.8"

{exec} = require "child_process"
fs = require 'fs'
path = require 'path'

program = require 'commander'

MainConfig = require "./lib/MainConfig"
Layer = require "./lib/Layer"

program
  .version(VERSION)
  .option("-l, --local <user>", "deploy locally for bootstrapping")
  .option("-n, --noPlugin", "disable plugins")

program
  .command("init")
  .description("creates a ggg.js config file for you")
  .action ->
    init finish


program
  .command("deploy <name> [branch]")
  .description("deploys a branch (defaults to origin/master) to named server")
  .action (name, branch) ->
    getLayer name, (err, layer) ->
      return finish err if err?

      branch = branch || "origin/master"

      layer.deploy branch, finish


program
  .command("restart <name>")
  .description("restarts named server")
  .action (name) ->
    getLayer name, (err, layer) ->
      return finish err if err?
      layer.restart finish


program
  .command("start <name>")
  .description("starts named server")
  .action (name) ->
    getLayer name, (err, layer) ->
      return finish err if err?
      layer.start finish

program
  .command("stop <name>")
  .description("stops named server")
  .action (name) ->
    getLayer name, (err, layer) ->
      return finish err if err?
      layer.stop finish

program
  .command("logs <name>")
  .description("Logs #{LOGS_LINES} lines of named servers log files")
  .option("-l, --lines <num>", "the number of lines to log")
  .action (name) ->
    getLayer name, (err, layer) ->
      return finish err if err?
      lines = program.lines || LOGS_LINES
      layer.serverLogs lines, finish

program
  .command("history <name>")
  .description("Shows a history of #{COMMIT_HISTORY} last commits deployed")
  .option("-r, --revisions <num>", "the number of commits to show")
  .action (name) ->
    getLayer name, (err, layer) ->
      return finish err if err?
      revisions = program.args.revisions || COMMIT_HISTORY
      layer.commitHistory revisions, finish

program
  .command("list")
  .description("lists all the servers")
  .action ->
    getConfigRepo (err, repoName, mainConfig) ->
      return finish err if err?

      list mainConfig, finish

program
  .command("help")
  .description("display this help")
  .action ->
    console.log program.helpInformation()
    finish()

program
  .command("*")
  .action ->
    finish new Error "bad command!"

## ACTIONS #########################################################

# creates the init file for you
init = (cb) ->
  initConfigContent = """
    // example ggg.js. Delete what you don't need
    module.exports = {

      // services
      start: "node app.js",

      // install
      install: "npm install",

      // cron jobs (from your app folder)
      cron: {
        someTask: { time: "0 3 * * *", command: "node sometask.js"},
      },

      // servers to deploy to
      servers: {
        dev: "deploy@dev.mycompany.com",
        staging: ["deploy@staging.mycompany.com", "deploy@staging2.mycompany.com"],
        prod: {
          hosts: ["deploy@mycompany.com", "deploy@backup.mycompany.com"],
          cron: {
            someTask: {time: "0 3 * * *", command: "node sometask.js"},
            anotherTask: {time: "0 3 * * *", command: "node secondTask.js"}
          },
          start: "prodstart app.js"
        }
      }
    }
  """

  console.log "GOGOGO INITIALIZING!"
  console.log "*** Written to ggg.js ***"
  console.log initConfigContent

  fs.writeFile mainConfigPath() + ".js", initConfigContent, 0o0755, cb

list = (mainConfig, cb) ->
  console.log "GOGOGO servers (see ggg.js)"
  console.log " - " + mainConfig.getLayerNames().join("\n - ")

## HELPERS #################################################
# gets the repo url for the current directory
# if it doesn't exist, use the directory name
reponame = (dir, cb) ->
  exec "git config --get remote.origin.url", {cwd:dir}, (err, stdout, stderr) ->
    if err?
      cb null, path.basename(dir)
    else
      url = stdout.replace("\n","")
      cb null, path.basename(url).replace(".git","")


# gets the main path for config
mainConfigPath = -> path.join process.cwd(), CONFIG

# returns the config object and the repoName
getConfigRepo = (cb) ->
  reponame process.cwd(), (err, repoName) ->
    return cb err if err?
    MainConfig.loadFromFile mainConfigPath(), (err, mainConfig) ->
      if err then return cb new Error "Bad gogogo config file, ggg.js. Run 'gogogo init' to create one. Err=#{err.message}"

      cb null, repoName, mainConfig

#returns the layer object
getLayer = (name, cb) ->
  getConfigRepo (err, repoName, mainConfig) ->
    return cb err if err?

    layerConfig = mainConfig.getLayerByName name
    if !layerConfig then return cb new Error("Invalid Layer Name: #{name}")

    if program.noPlugin
      layerConfig.plugins = null
      mainConfig.disablePlugins()

    if program.local
      layerConfig.hosts = ["#{program.local}@localhost"]

    layer = new Layer name, layerConfig, repoName, mainConfig, program.local
    layer.on "error", (err) -> return cb err
    layer.on "ready", ->
      cb null, layer

# our handler on the finish
finish = (err) ->
  if err?
    console.log "!!! " + err.message
    console.log "stack follows:\n\n #{err.stack}"
    process.exit 1
  console.log "OK"

# just export our program object
module.exports = program
