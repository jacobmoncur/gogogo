Go Go Go
========

Gogogo is a simple command-line tool for easily deploying command-line
applications. It deploys git branches to named targets.

Assumptions
-----------

0. Your project uses git
0. You are using ubuntu, or something else with upstart
0. Git is installed locally and on your target machines
0. If you aren't deploying as root, you can use sudo without a password


Installation
------------

    npm -g install gogogo

Usage
-----

In your local repo

1. Run `ggg init` to generate a default ggg.js file. It looks something like
   this by default:

``` JavaScript
module.exports = {
  // services
  // can either be a string or an object with mutiple processes to start up
  start: "node app.js",
  /* or
  start: {
    web: 'node app.js',
    worker 'node worker.js',
    montior: 'node monitor.js'
  },
  */

  // install
  install: "npm install",

  // cron jobs (from your app folder)
  cron: {
    someTask: { time: "0 3 * * *", command: "node sometask.js"},
  },

  // targets to deploy to
  targets: {
    dev: "deploy@dev.mycompany.com",
    staging: ["deploy@staging.mycompany.com", "deploy@staging2.mycompany.com"],
    prod: {
      hosts: ["deploy@mycompany.com", "deploy@backup.mycompany.com"],
      // override top-level cron specified above
      cron: {
        someTask: {time: "0 3 * * *", command: "node sometask.js"},
        anotherTask: {time: "0 3 * * *", command: "node secondTask.js"}
      },
      // override top-level start specified above
      start: "prodstart app.js"
    }
  }
}
```

2. edit ggg.js to match your deploy targets.

3. `ggg deploy dev master` to deploy the local master branch to the dev target.


### Actions

gogogo can do these things:

```bash
ggg help
ggg init - creates a ggg.js config file for you
ggg deploy <target> <branch> — deploys branch to named server
ggg restart <target:process>
ggg start <target:process>
ggg stop <target:process>
ggg logs <target:process> — tail remote log
ggg list — show available names
ggg history <target> - shows a history of deployed commits
ggg command <target> <command> - run a command on the server in base directory
```

gogogo is aliased to ggg for SWEET EFFICIENCY

### ggg.js files

The `ggg.js` file is configuration for gogogog. It tells gogogo where to
deploy and what to run when deploying. Since gogogo is just a node program,
ggg.js is just a node module that exports a single configuration object.

This object can have the following fields:

* `install`: command to be run after each deploy. Use this to install any
   dependencies your program needs.
* `start`: command used to start up your app. Run every time your app starts
   or restarts.
* `cron`: an object containing cron jobs to set up. The cron commands will be
  run relative to your program's directory
* `targets`: an object containing targets to deploy to. The keys are the target
  names you will use in running gogogo commands. If the values are strings,
  they are assumed to be single host names to deploy to. Arrays of strings are
  assumed to be a group of hosts to deploy to. An object is assumed to be
  configuration for a single target. This can also be called 'servers' for
  backwards-compatibility.

Lets talk more about the target configuration object. By default each target
uses the top-level `install`, `start` and `cron` properties. If you have a
ggg.js file that looks like this, then your `dev` target will use
`'node index.js'` as the start command and `'npm install'` as the install command.

```JavaScript
module.exports = {
  start: 'node index.js',
  install: 'npm install',
  servers: {
    dev: 'foo@example.com'
  }
}
```

Let's say you add a prod target, and you need to run a build step as part of
your installation. You can use an object instead of a hostname string, and
specify your own prod-specific install command like so:

```JavaScript
module.exports = {
  start: 'node index.js',
  install: 'npm install',
  servers: {
    dev: 'foo@example.com',
    prod: {
      hosts: 'foo@prod.example.com',
      install: 'npm install && ./node_modules/.bin/grunt build'
    }
  }
}
```

### Cron Support

gogogo can create cron jobs for you on deploy.

``` JavaScript
module.exports = {
  cron: {
    cronName: {time: "0 3 * * *" command: " node something.js"}
  }
}
```

It will create a script in /etc/cron.d/, set the permissions correctly, and
redirect log output to `cron_cronName.log`.

You can have multiple cron commands by having multiple keys in the cron object:

```JavaScript
module.exports = {
  cron: {
    cronName: {time: "0 3 * * *" command: "node something.js"},
    anotherCron: {time: "0 1 * * *" command: "node somethingElse.js"}
  }
}
```

gogogo isn't smart enough yet to remove old cron files it created when you
change or remove cronjobs, so you'll have to do that yourself now.

### Multiple processes under one deploy target

gogogo supports running multiple processes under one deploy target. Let's look
at an example.

If the value of the `start` property is a string, your target will only have
one process. You can start, stop, restart and log it by running
`ggg <start|stop|logs|restart> <target>`.


```JavaScript
module.exports = {
  start: 'echo "foo"'
}
```

If the value of the `start` property is an object, your target will have
multiple processes associated with it. Check out an example ggg.js file.

```JavaScript
module.exports = {
  servers: {
    prod: {
      hosts: ["deploy@mycompany.com", "deploy@backup.mycompany.com"],
      install: "npm install",
      start: {
        web: 'echo "starting web"',
        worker: 'echo "starting worker"',
        monitor: 'echo "starting monitor"'
      }
    }
  }
}
```

Here we define one target, `prod`, with three processes. Each process gets its
own upstart script, log file, and logrotate file. Deploying will restart all
three processes at once. If you run `ggg prod <stop|restart|start>` gogogo will
stop|restart|start all three processes at once.

You can start, stop, restart or log individual processes by running
`ggg <command> prod:<processName>`. If you wanted to restart the web process,
you would run `ggg restart prod:web`

### Plugins

Plugins allow you to manipulate fields in the ggg.js file at runtime.

gogogo plugins override a single deploy parameter (such as hosts) and are a
simple file that exports a single function with the following signature:

``` JavaScript
module.exports = function(opts, cb) {
  cb(err, overrides)
}
```
where opts is a hash of user definied options, and overrides is the value to
replace the field with.


Currently, there is one bundled plugin, chefHosts, which integrates with
opscode's knife to retrieve a list of servers to deploy to. An example of using
a plugin is shown below.

``` JavaScript
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
```

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

You can deploy any branch over your old remote by pushing to it. To have
multiple versions of an app running at the same time, call `ggg create`
with different names and the same server.

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

    ggg deploy dev master
    ggg deploy featurex featurex

Note that for web servers you'll want to change the port in your featurex
branch or it will conflict.

### Deploying without start
If you want to deploy code without having to run anything (such as machines
that only do cron) just don't define a start command or override it with an
empty string.

### SSH key host checking warning
SSH is run with host key checking disabled. It's up to you to verify the
authenticity of your hosts.


Change Log
----------

* 0.5.1 - `ggg list` now lists all processes as well as targets
* 0.5.0 - Add ability to support running multiple processes in one deploy
  target
* 0.4.10 - Add a command to run a command on the server, plus colorized output
* 0.4.8 - automatically add logrotate files, make upstart work properly on
  reboot
* 0.4.3 - added support for local deploys, and sudo for non-root users (see
  note below)
* 0.4.0 - Added support for tracking support history, plugins, and a chef
  plugin
* 0.3.3 - multi cron support, plus per-layer config
* 0.3.0 - custom config file, cron support
* 0.2.6 - git push force
* 0.2.5 - Server Environment variables are preserved! Deploy monitors the log
  for a couple seconds.
* 0.2.0 - gogogo list, logs, start, stop, restart, deploy


Roadmap
-------

* Clean up cron files when removing a cronjob after a deploy


Contributing
-----------

Check it out locally and install the dependencies with

```bash
git clone git@github.com:idottv/gogogo.git
cd gogogo
npm install
```

Make your changes, write tests to cover them, and run tests with `npm test`.
