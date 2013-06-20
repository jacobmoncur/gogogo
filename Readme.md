Go Go Go
========

Gogogo is a simple command-line tool designed to let you deploy web applications as easily as possible. It puts files into place on any server with upstart and gets it all configured.

### Goals

1. Easy to setup
2. Easy to redeploy
3. Deploy to multiple servers
4. Deploy different branches to the same server

Installation
------------

    npm -g install gogogo

Change Log
----------

* 0.4.10 - Add a command to run a command on the server
* 0.4.8 - automatically add logrotate files, make upstart work properly on reboot
* 0.4.3 - added support for local deploys, and sudo for non-root users (see note below)
* 0.4.0 - Added support for tracking support history, plugins, and a chef plugin
* 0.3.3 - multi cron support, plus per-layer config
* 0.3.0 - custom config file, cron support
* 0.2.6 - git push force
* 0.2.5 - Server Environment variables are preserved! Deploy monitors the log for a couple seconds.
* 0.2.0 - gogogo list, logs, start, stop, restart, deploy

Server Requirements
-------------------

1. Upstart (included with ubuntu)
2. SSH Access
3. Git installed on both local computer and server
4. for non-root users, sudo must work without a password

Usage
-----

In your local repo

1. `gogogo init`

2. edit ggg.js:

``` JavaScript
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
```

3. gogogo deploy dev master

### Redeploy

    # change some stuff and commit
    ...

    # deploy again
    gogogo deploy test master

### Plugins

As of 0.4.0, gogogo supports plugins to help your deploys be more dynamic.

gogogo plugins override a single deploy parameter (such as hosts) and are a simple
file that exports a single function with the following signature:

``` JavaScript
module.exports = function(opts, cb) {
...
  cb(err, overrides)
}
```
where opts is a hash of user definied options


Currently, there is one bundled plugin, chefHosts, which integrates with opscode's knife to
retrieve a list of servers to deploy too. Example of using a plugin is show below

``` JavaScript
...
plugins: {
  "chefHosts" : {
    overrides: "hosts", // required field! defines the property to override
    opts: {
      role: "myapp",
      env: "production"
    }
  },
  "./plugins/myPlugin" { // user plugins are supported, relative to cwd
    overrides: "install"
  }
},
...
```


Limitations
-----------

1. Only works on ubuntu (requires upstart to be installed)
2. You must change the port in either the code or an environment variable to run the same app twice on the same server

Roadmap
-------

* gogogo rm
* gogogo ps
* ability to specify sub-folders that contain package.json files

Help
----

### Actions

    gogogo help
    gogogo init - creates a ggg.js config file for you
    gogogo deploy <name> <branch> — deploys branch to named server
    gogogo restart <name>
    gogogo start <name>
    gogogo stop <name>
    gogogo logs <name> — tail remote log
    gogogo list — show available names
    gogogo history <name> - shows a history of deployed commits
    gogogo command <name> <command> - run a command on the server in base directory


    gogogo has an alias of ggg for saving you those precious keystrokes

### Cron Support

Gogogo currently supports a single cron action.

``` JavaScript
    module.exports = {
        cron: {
         cronName: {time: "0 3 * * *" command: " node something.js"}
        }
        ...
    }
```

It will create a script in /etc/cron.d/, set the permissions correctly, and redirect log output to `cron.txt`

### Environment variables

If they are the same no matter which server is deployed, put them in your start script.

    "start":"DB_HOST=localhost node app.js"

If they refer to something about the server you are on, put them in /etc/environment.

    # /etc/environment
    NODE_ENV="production"

### Multiple servers

To deploy to multiple servers, just add multiple servers to the config file

``` JavaScript
    // ggg.js
    module.exports = {
        servers: {
            dev: "deploy@dev.mycompany.com",
            staging: "deploy@staging.mycompany.com"
        }
    }
```

Then deploy to them separately

    gogogo deploy dev master
    gogogo deploy staging master

### Multiple branches on the same server

You can deploy any branch over your old remote by pushing to it. To have multiple versions of an app running at the same time, call `gogogo create` with different names and the same server.

``` JavaScript
    // ggg.js
    module.exports = {
        servers: {
            dev: "deploy@dev.mycompany.com",
            featurex: "deploy@dev.mycompany.com"
        }
    }
```

Then deploy to them separately

    gogogo deploy dev master
    gogogo deploy featurex featurex

Note that for web servers you'll want to change the port in your featurex branch or it will conflict.

### Reinstall / Upgrade

To reinstall, run `npm install -g gogogo` again, then redo the create step in your repository.

### Gitignore

Commit ggg.js to your repo, so anyone using the repo can deploy as long as they have ssh access to the server.

### Deploying without start
If you want to deploy code without having to run anything (such as machines that only do cron) just define no
start command (or override it with an empty string)

### IMPORTANT NOTES!

SSH is run with host key checking disabled! Its up to you to verify the authenticity of your hosts!


