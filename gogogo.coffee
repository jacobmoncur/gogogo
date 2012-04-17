###
CLI to automatically deploy stuff, kind of like heroku. 
Ubuntu only! (upstart)

gogogo dev master
 - work without "deploy" keyword

gogogo
 - deploy sets .ggg/_.js -> branch=master, 
 - runs last "gogogo" command, whatever that was
 - stores to .ggg/_.js
###

APP = "gogogo"
PREFIX = "ggg"
CONFIG = ".ggg"

{spawn, exec} = require 'child_process'
fs = require 'fs'
path = require 'path'



## RUN #############################################################

# figure out what to call, and with which arguments
# args = actual args
run = (args, cb) ->
  readMainConfig (lastName, lastBranch) ->
    action = args[0]
    name = args[1] || lastName
    switch action
      when "--version" then version cb
      when "list" then list cb
      when "help" then help cb
      when "--help" then help cb
      when "-h" then help cb
      when "create"
        server = args[2]
        create name, server, cb
      else
        readNamedConfig name, (err, config) ->
          if err? then return cb new Error("Could not find remote name: #{name}")
          console.log "GOGOGO #{action} #{name}"
          switch action
            when "restart" then restart config, cb
            when "start" then start config, cb
            when "stop" then stop config, cb
            when "logs" then logs config, cb
            when "deploy"
              branch = args[2] || lastBranch
              deploy config, branch, cb
            else
              cb new Error("Invalid Action #{action}")

## ACTIONS #########################################################

# sets everything up so gogogo deploy will work
# does not use a git remote, because we can git push to the url
create = (name, server, cb) ->
  console.log "GOGOGO CREATING!"
  console.log " - name: #{name}"
  console.log " - server: #{server}"

  reponame process.cwd(), (err, rn) ->
    if err? then return cb err

    # names and paths
    id = serviceId rn, name
    parent = "$HOME/" + PREFIX
    repo = wd = "#{parent}/#{id}"
    upstart = "/etc/init/#{id}.conf"
    log = "log.txt"
    hookfile = "#{repo}/.git/hooks/post-receive"
    deployurl = "ssh://#{server}/~/#{PREFIX}/#{id}"

    console.log " - id: #{id}"
    console.log " - repo: #{repo}"
    console.log " - remote: #{deployurl}"

    # upstart service
    service = """
      description '#{id}'
      start on startup
      chdir #{repo}
      respawn
      respawn limit 5 5 
      exec npm start >> #{log} 2>&1
    """

    # http://toroid.org/ams/git-website-howto
    # we don't use the hook for anything, except making sure it checks out.
    # you still need the hook. It won't check out otherwise. Not sure why
    hook = """
      read oldrev newrev refname
      echo 'GOGOGO checking out:'
      echo \\$newrev
      cd #{repo}/.git
      GIT_WORK_TREE=#{repo} git reset --hard \\$newrev || exit 1;
    """

    # command
    # denyCurrentBranch ignore allows it to accept pushes without complaining
    remote = """
      mkdir -p #{repo}
      cd #{repo}
      echo "Locating git"
      which git 
      if (( $? )); then
          echo "Could not locate git"
          exit 1
      fi
      git init
      git config receive.denyCurrentBranch ignore

      echo "#{service}" > #{upstart}

      echo "#{hook}" > #{hookfile}
      chmod +x #{hookfile}
    """

    ssh server, remote, (err) ->
      if err? then return cb err

      # write config
      config = {name: name, server: server, id: id, repoUrl: deployurl, repo: repo}

      writeConfig namedConfig(name), config, (err) ->
        if err? then return cb new Error "Could not write config file"

        console.log "-------------------------------"
        console.log "deploy: 'gogogo deploy #{name} <branch>'"

        writeMainConfig name, null, (err) ->
          if err? then return cb new Error "Could not write main config"

          cb()

# pushes directly to the url and runs the post stuff by hand. We still use a post-receive hook to checkout the files. 
deploy = (config, branch, cb) ->
  console.log "  branch: #{branch}"
  console.log "PUSHING"
  local "git", ["push", config.repoUrl, branch], (err) ->
    if err? then return cb err

    # now install and run
    command = installCommand(config) + restartCommand(config)
    ssh config.server, command, (err) ->
      if err? then return cb err
      writeMainConfig config.name, branch, cb

## SIMPLE CONTROL ########################################################

installCommand = (config) -> """
    echo 'INSTALLING'
    cd #{config.repo}
    npm install --unsafe-perm || exit 1;
  """

install = (config, cb) ->
  console.log "INSTALLING"
  ssh config.server, installCommand(config), cb

restartCommand = (config) -> """
    echo 'RESTARTING'
    stop #{config.id}
    start #{config.id}
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

# this should never exit. You have to Command-C it
logs = (config, cb) ->
  log = config.repo + "/log.txt"
  console.log "Tailing #{log}... Control-C to exit"
  console.log "-------------------------------------------------------------"
  ssh config.server, "tail -n 40 -f #{log}", cb

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
      cb null, path.basename(path.dirname(dir))
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
    cb e


namedConfig = (name) -> path.join process.cwd(), CONFIG, name+".js"
mainConfig = -> path.join process.cwd(), CONFIG, "_main.js"

readNamedConfig = (name, cb) ->
  readConfig namedConfig(name), cb

readMainConfig = (cb) ->
  readConfig namedConfig("_main"), (err, config) ->
    if err? then return cb()
    cb config.name, config.branch

writeMainConfig = (name, branch, cb) ->
  writeConfig namedConfig("_main"), {name, branch}, cb

serviceId = (repoName, name) -> repoName + "_" + name

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






# RUN THE THING
run process.argv.slice(2), (err) ->
  if err?
    console.log "!!! " + err.message
    process.exit 1
  console.log "OK"

