#!/usr/bin/env node
// Generated by CoffeeScript 1.3.1

/*
CLI to automatically deploy stuff, kind of like heroku. 
Ubuntu only! (upstart)

gogogo dev master
 - work without "deploy" keyword

gogogo
 - deploy sets .ggg/_.js -> branch=master, 
 - runs last "gogogo" command, whatever that was
 - stores to .ggg/_.js
*/


(function() {
  var APP, CONFIG, PREFIX, addGitRemote, create, deploy, exec, fs, help, install, installCommand, list, local, logs, mainConfig, namedConfig, path, pckg, readConfig, readMainConfig, readNamedConfig, reponame, restart, restartCommand, run, serviceId, spawn, ssh, start, stop, usage, version, writeConfig, writeMainConfig, _ref;

  APP = "gogogo";

  PREFIX = "ggg";

  CONFIG = ".ggg";

  _ref = require('child_process'), spawn = _ref.spawn, exec = _ref.exec;

  fs = require('fs');

  path = require('path');

  run = function(args, cb) {
    return readMainConfig(function(lastName, lastBranch) {
      var action, name, server;
      action = args[0];
      name = args[1] || lastName;
      switch (action) {
        case "--version":
          return version(cb);
        case "list":
          return list(cb);
        case "help":
          return help(cb);
        case "--help":
          return help(cb);
        case "-h":
          return help(cb);
        case "create":
          server = args[2];
          return create(name, server, cb);
        default:
          return readNamedConfig(name, function(err, config) {
            var branch;
            if (err != null) {
              return cb(new Error("Could not find remote name: " + name));
            }
            console.log("GOGOGO " + action + " " + name);
            switch (action) {
              case "restart":
                return restart(config, cb);
              case "start":
                return start(config, cb);
              case "stop":
                return stop(config, cb);
              case "logs":
                return logs(config, cb);
              case "deploy":
                branch = args[2] || lastBranch;
                return deploy(config, branch, cb);
              default:
                return cb(new Error("Invalid Action " + action));
            }
          });
      }
    });
  };

  create = function(name, server, cb) {
    console.log("GOGOGO CREATING!");
    console.log(" - name: " + name);
    console.log(" - server: " + server);
    return reponame(process.cwd(), function(err, rn) {
      var deployurl, hook, hookfile, id, log, parent, remote, repo, service, upstart, wd;
      if (err != null) {
        return cb(err);
      }
      id = serviceId(rn, name);
      parent = "$HOME/" + PREFIX;
      repo = wd = "" + parent + "/" + id;
      upstart = "/etc/init/" + id + ".conf";
      log = "log.txt";
      hookfile = "" + repo + "/.git/hooks/post-receive";
      deployurl = "ssh://" + server + "/~/" + PREFIX + "/" + id;
      console.log(" - id: " + id);
      console.log(" - repo: " + repo);
      console.log(" - remote: " + deployurl);
      service = "description '" + id + "'\nstart on startup\nchdir " + repo + "\nrespawn\nrespawn limit 5 5 \nexec npm start >> " + log + " 2>&1";
      hook = "read oldrev newrev refname\necho 'GOGOGO checking out:'\necho \\$newrev\ncd " + repo + "/.git\nGIT_WORK_TREE=" + repo + " git reset --hard \\$newrev || exit 1;";
      remote = "mkdir -p " + repo + "\ncd " + repo + "\necho \"Locating git\"\nwhich git \nif (( $? )); then\n    echo \"Could not locate git\"\n    exit 1\nfi\ngit init\ngit config receive.denyCurrentBranch ignore\n\necho \"" + service + "\" > " + upstart + "\n\necho \"" + hook + "\" > " + hookfile + "\nchmod +x " + hookfile;
      return ssh(server, remote, function(err) {
        var config;
        if (err != null) {
          return cb(err);
        }
        config = {
          name: name,
          server: server,
          id: id,
          repoUrl: deployurl,
          repo: repo
        };
        return writeConfig(namedConfig(name), config, function(err) {
          if (err != null) {
            return cb(new Error("Could not write config file"));
          }
          console.log("-------------------------------");
          console.log("deploy: 'gogogo deploy " + name + " <branch>'");
          return writeMainConfig(name, null, function(err) {
            if (err != null) {
              return cb(new Error("Could not write main config"));
            }
            return cb();
          });
        });
      });
    });
  };

  deploy = function(config, branch, cb) {
    console.log("  branch: " + branch);
    console.log("PUSHING");
    return local("git", ["push", config.repoUrl, branch], function(err) {
      var command;
      if (err != null) {
        return cb(err);
      }
      command = installCommand(config) + restartCommand(config);
      return ssh(config.server, command, function(err) {
        if (err != null) {
          return cb(err);
        }
        return writeMainConfig(config.name, branch, cb);
      });
    });
  };

  installCommand = function(config) {
    return "echo 'INSTALLING'\ncd " + config.repo + "\nnpm install --unsafe-perm || exit 1;";
  };

  install = function(config, cb) {
    console.log("INSTALLING");
    return ssh(config.server, installCommand(config), cb);
  };

  restartCommand = function(config) {
    return "echo 'RESTARTING'\nstop " + config.id + "\nstart " + config.id;
  };

  restart = function(config, cb) {
    return ssh(config.server, restartCommand(config), cb);
  };

  stop = function(config, cb) {
    console.log("STOPPING");
    return ssh(config.server, "stop " + config.id + ";", cb);
  };

  start = function(config, cb) {
    console.log("STARTING");
    return ssh(config.server, "start " + config.id + ";", cb);
  };

  version = function(cb) {
    return pckg(function(err, info) {
      return console.log("GOGOGO v" + info.version);
    });
  };

  help = function(cb) {
    console.log("--------------------------");
    console.log("gogogo restart [<name>]");
    console.log("gogogo start [<name>]");
    console.log("gogogo stop [<name>]");
    console.log("gogogo logs [<name>] — tail remote log");
    console.log("gogogo list — show available names");
    console.log("gogogo help");
    console.log("gogogo deploy [<name>] [<branch>] — deploys branch to named server");
    console.log("gogogo create <name> <server> - creates a new named server");
    return cb();
  };

  logs = function(config, cb) {
    var log;
    log = config.repo + "/log.txt";
    console.log("Tailing " + log + "... Control-C to exit");
    console.log("-------------------------------------------------------------");
    return ssh(config.server, "tail -n 40 -f " + log, cb);
  };

  list = function(cb) {
    return local("ls", [".ggg"], cb);
  };

  usage = function() {
    return console.log("Usage: gogogo create NAME USER@SERVER");
  };

  pckg = function(cb) {
    return fs.readFile(path.join(__dirname, "package.json"), function(err, data) {
      if (err != null) {
        return cb(err);
      }
      return cb(null, JSON.parse(data));
    });
  };

  reponame = function(dir, cb) {
    return exec("git config --get remote.origin.url", {
      cwd: dir
    }, function(err, stdout, stderr) {
      var url;
      if (err != null) {
        return cb(null, path.basename(path.dirname(dir)));
      } else {
        url = stdout.replace("\n", "");
        return cb(null, path.basename(url).replace(".git", ""));
      }
    });
  };

  writeConfig = function(f, obj, cb) {
    return fs.mkdir(path.dirname(f), function(err) {
      return fs.writeFile(f, "module.exports = " + JSON.stringify(obj), 0x1fd, cb);
    });
  };

  readConfig = function(f, cb) {
    var m;
    try {
      m = require(f);
      return cb(null, m);
    } catch (e) {
      return cb(e);
    }
  };

  namedConfig = function(name) {
    return path.join(process.cwd(), CONFIG, name + ".js");
  };

  mainConfig = function() {
    return path.join(process.cwd(), CONFIG, "_main.js");
  };

  readNamedConfig = function(name, cb) {
    return readConfig(namedConfig(name), cb);
  };

  readMainConfig = function(cb) {
    return readConfig(namedConfig("_main"), function(err, config) {
      if (err != null) {
        return cb();
      }
      return cb(config.name, config.branch);
    });
  };

  writeMainConfig = function(name, branch, cb) {
    return writeConfig(namedConfig("_main"), {
      name: name,
      branch: branch
    }, cb);
  };

  serviceId = function(repoName, name) {
    return repoName + "_" + name;
  };

  addGitRemote = function(name, url, cb) {
    return exec("git remote rm " + name, function(err, stdout, stderr) {
      return exec("git remote add " + name + " " + url, function(err, stdout, stderr) {
        if (err != null) {
          return cb(err);
        }
        return cb();
      });
    });
  };

  ssh = function(server, commands, cb) {
    return local('ssh', [server, commands], function(err) {
      if (err != null) {
        return cb(new Error("SSH Command Failed"));
      }
      return cb();
    });
  };

  local = function(command, args, cb) {
    var process;
    process = spawn(command, args);
    process.stdout.on('data', function(data) {
      return console.log(data.toString().replace(/\n$/, ""));
    });
    process.stderr.on('data', function(data) {
      return console.log(data.toString().replace(/\n$/, ""));
    });
    return process.on('exit', function(code) {
      if (code) {
        return cb(new Error("Command Failed"));
      }
      return cb();
    });
  };

  run(process.argv.slice(2), function(err) {
    if (err != null) {
      console.log("!!! " + err.message);
      process.exit(1);
    }
    return console.log("OK");
  });

}).call(this);
