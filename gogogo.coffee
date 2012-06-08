###
CLI to automatically deploy stuff, kind of like heroku. 
Ubuntu only! (upstart)

gogogo dev master
 - work without "deploy" keyword

gogogo
 - deploy sets .ggg/_.js -> branch=master, 
 - runs last "gogogo" command, whatever that was
 - stores to .ggg/_.js


REQUIREMENTS
 - don't require node on the server?
 + write a bash script on deploy! (YES)
 - we know the user has node/npm on their LOCAL

CONFIG FILE FORMAT: (json?)
  ggg.js (or .coffee!)

  module.exports = { 
    services: {
      blah: ""
      something: ""
    }
  , cron: ""
  , dev: "root@dev.i.tv"
  , telus: "root@telus"
  }

###

APP = "gogogo"
PREFIX = "ggg"
CONFIG = "ggg"

LOGS_LINES = 40

{spawn, exec} = require 'child_process'
fs = require 'fs'
path = require 'path'



## RUN #############################################################

# figure out what to call, and with which arguments
# args = actual args
run = (args, cb) ->
  action = args[0]
  name = args[1] || lastName
  switch action
    when "init" then init cb
    when "--version" then version cb
    # when "list" then list cb
    # when "help" then help cb
    # when "--help" then help cb
    # when "-h" then help cb
    else
      readMainConfig (err, mainConfig) ->
        if err then return cb new Error "Bad gogogo config file, ggg.js. Run 'gogogo init' to create one. Err=#{err.message}"
        server = configServer mainConfig, name
        if !server then return cb new Error("Invalid Server Name: #{name}")
        console.log "GOGOGO #{action} #{name}"
        switch action
          # when "restart" then restart config, cb
          # when "start" then start config, cb
          # when "stop" then stop config, cb
          # when "logs" then logs config, LOGS_LINES, cb
          when "deploy"
            # branch = args[2] || lastBranch
            branch = args[2]
            deploy name, branch, mainConfig, cb
          else
            cb new Error("Invalid Action #{action}")

## ACTIONS #########################################################

# creates the init file for you
init = (cb) ->
  initConfigContent = """
    // example ggg.json. Delete what you don't need
    module.exports = {

      // services
      service: "node app.js",

      // cron jobs
      cron: "* * * * *",

      // deploy targets
      dev: "deploy@dev.mycompany.com",
      staging: "deploy@staging.mycompany.com",
      production: ["deploy@app1.mycompany.com", "deploy@app2.mycompany.com"],
    }
  """

  console.log "GOGOGO INITIALIZING!"
  console.log "*** Written to ggg.json ***"
  console.log initConfigContent

  fs.writeFile mainConfigPath() + ".js", initConfigContent, 0o0775, cb


# PATHS AND HELPERS
serviceId = (repoName, name) -> repoName + "_" + name
hookFile = (id) -> "#{repoDir(id)}/.git/hooks/post-receive"
logFile = (id) -> path.join repoDir(id), "log.txt"
parentDir = -> "$HOME/" + PREFIX
upstartFile = (id) -> "/etc/init/#{id}.conf"
repoDir = (id) -> "#{parentDir()}/#{id}"
repoUrl = (id, server) -> "ssh://#{server}/~/#{PREFIX}/#{id}"
serverUser = (server) -> server.replace(/@.*$/, "")


# DEPLOY!!
create = (name, server, mainConfig, cb) ->

  reponame process.cwd(), (err, rn) ->
    if err? then return cb err

    # names and paths
    id = serviceId rn, name

    console.log " - id: #{id}"
    console.log " - repo: #{repoDir id}"
    console.log " - remote: #{repoUrl id, server}"
    console.log " - start: #{configStart mainConfig}"
    console.log " - install: #{configInstall mainConfig}"

    # upstart service
    # we use 'su root -c' because we need to keep our environment variables
    # http://serverfault.com/questions/128605/have-upstart-read-environment-from-etc-environment-for-a-service
    # TODO add deploy user
    service = """
      description '#{id}'
      start on startup
      chdir #{repoDir id}
      respawn
      respawn limit 5 5 
      exec su #{serverUser server} -c '#{configStart mainConfig}' >> #{logFile id} 2>&1
    """

    # http://toroid.org/ams/git-website-howto
    # we don't use the hook for anything, except making sure it checks out.
    # you still need the hook. It won't check out otherwise. Not sure why
    hook = """
      read oldrev newrev refname
      echo 'GOGOGO checking out:'
      echo \\$newrev
      cd #{repoDir id}/.git
      GIT_WORK_TREE=#{repoDir id} git reset --hard \\$newrev || exit 1;
    """

    # command
    # denyCurrentBranch ignore allows it to accept pushes without complaining
    createRemoteScript = """
      echo '\nCREATING...'
      mkdir -p #{repoDir id}
      cd #{repoDir id}
      echo "Locating git"
      which git 
      if (( $? )); then
          echo "Could not locate git"
          exit 1
      fi
      git init
      git config receive.denyCurrentBranch ignore

      echo "#{service}" > #{upstartFile id}

      echo "#{hook}" > #{hookFile id}
      chmod +x #{hookFile id}
      echo "[√] created"
    """

    ssh server, createRemoteScript, (err) ->
      if err? then return cb err
      cb()


# pushes directly to the url and runs the post stuff by hand. We still use a post-receive hook to checkout the files. 
deploy = (name, branch, mainConfig, cb) ->

  server = configServer(mainConfig, name)

  reponame process.cwd(), (err, rn) ->
    if err? then return cb err

    console.log " - name: #{name}"
    console.log " - server: #{server}"
    console.log " - branch: #{branch}"

    # create first
    create name, server, mainConfig, (err) ->
      if err? then return cb err

      id = serviceId rn, name
      console.log "\nPUSHING"

      local "git", ["push", repoUrl(id, server), branch, "-f"], (err) ->
        if err? then return cb err

        console.log "[√] pushed"

        # now install and run
        command = installCommand(id, mainConfig) + "\n" + restartCommand(id)
        ssh server, command, (err) ->
          if err? then return cb err

          console.log ""
          command = logs name, server, 1, cb

          # for some reason it takes a while to actually kill it, like 10s
          kill = -> command.kill()
          setTimeout kill, 2000


## SIMPLE CONTROL ########################################################

installCommand = (id, mainConfig) -> """
    echo '\nINSTALLING'
    cd #{repoDir id}
    #{configInstall mainConfig} || exit 1;
    echo '[√] installed'
  """

restartCommand = (id) -> """
    echo '\nRESTARTING'
    stop #{id}
    start #{id}
    echo '[√] restarted'
  """

restart = (config, cb) ->
  ssh config.server, restartCommand(config), cb

stop = (config, cb) ->
  console.log "STOPPING"
  ssh config.server, "stop #{config.id};", cb

start = (config, cb) ->
  console.log "STARTING"
  ssh config.server, "start #{config.id};", cb

version = (cb) ->
  pckg (err, info) ->
    console.log "GOGOGO v#{info.version}"

help = (cb) ->
  console.log "--------------------------"
  console.log "gogogo restart [<name>]"
  console.log "gogogo start [<name>]"
  console.log "gogogo stop [<name>]"
  console.log "gogogo logs [<name>] — tail remote log"
  console.log "gogogo list — show available names"
  console.log "gogogo help"
  console.log "gogogo deploy [<name>] [<branch>] — deploys branch to named server"
  console.log "gogogo create <name> <server> - creates a new named server"
  cb()

# this will never exit. You have to Command-C it, or stop the spawned process
logs = (name, server, lines, cb) ->
  reponame process.cwd(), (err, rn) ->
    if err? then return cb err
    id = serviceId rn, name
    log = logFile id

    console.log "Tailing #{log}... Control-C to exit"
    console.log "-------------------------------------------------------------"
    ssh server, "tail -n #{lines} -f #{log}", ->

list = (cb) ->
  local "ls", [".ggg"], cb

usage = -> console.log "Usage: gogogo create NAME USER@SERVER"























## HELPERS #################################################

pckg = (cb) ->
  fs.readFile path.join(__dirname, "package.json"), (err, data) ->
    if err? then return cb err
    cb null, JSON.parse data

# gets the repo url for the current directory
# if it doesn't exist, use the directory name
reponame = (dir, cb) ->
  exec "git config --get remote.origin.url", {cwd:dir}, (err, stdout, stderr) ->
    if err?
      cb null, path.basename(dir)
    else
      url = stdout.replace("\n","")
      cb null, path.basename(url).replace(".git","")

# write a config file
writeConfig = (f, obj, cb) ->
  fs.mkdir path.dirname(f), (err) ->
    fs.writeFile f, "module.exports = " + JSON.stringify(obj), 0o0775, cb

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
  constructor: ({@start, @install, @servers}) ->
    @servers ?= {}

configServer = (cfg, name) -> cfg.servers[name]
configStart = (cfg) -> cfg.start || throw new Error "You must specify 'start:' in your config file"
configInstall = (cfg) -> cfg.install || throw new Error "You must specify 'install:' in your config file"

mainConfigPath = -> path.join process.cwd(), CONFIG
readMainConfig = (cb) ->
  readConfig mainConfigPath(), (err, config) ->
    if err? then return cb err
    cb null, new MainConfig config


# namedConfig = (name) -> path.join process.cwd(), CONFIG, name+".js"
# mainConfig = -> path.join process.cwd(), CONFIG, "_main.js"

# readNamedConfig = (name, cb) ->
#   readConfig namedConfig(name), cb

# readMainConfig = (cb) ->
#   readConfig namedConfig("_main"), (err, config) ->
#     if err? then return cb()
#     cb config.name, config.branch

# writeMainConfig = (name, branch, cb) ->
#   writeConfig namedConfig("_main"), {name, branch}, cb


# add a git remote
# NOT IN USE (you can push directly to a git url)
addGitRemote = (name, url, cb) ->
  exec "git remote rm #{name}", (err, stdout, stderr) ->
    # ignore errs here, the remote might not exist
    exec "git remote add #{name} #{url}", (err, stdout, stderr) ->
      if err? then return cb err
      cb()

ssh = (server, commands, cb) ->
  local 'ssh', [server, commands], (err) ->
    if err? then return cb new Error "SSH Command Failed"
    cb()


# runs the commands and dumps output as we get it
local = (command, args, cb) ->
  process = spawn command, args
  process.stdout.on 'data', (data) -> console.log data.toString().replace(/\n$/, "")
  process.stderr.on 'data', (data) -> console.log data.toString().replace(/\n$/, "")

  process.on 'exit', (code) ->
    if code then return cb(new Error("Command Failed"))
    cb()

  return process





# RUN THE THING
run process.argv.slice(2), (err) ->
  if err?
    console.log "!!! " + err.message
    process.exit 1
  console.log "OK"

