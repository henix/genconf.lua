# genconf.lua

A generic configuration files generator

PLEASE NOTE:
- this is a fork of the project https://github.com/henix/genconf.lua all credits for henix for paving the road
- main reason for existance of this fork is to allow me to add some flexibility for generation of similar configuration files to different paths
- documentation of this fork is not *yet* up-to-date

## Motivation

In your application there are many configurations (db host/port/username/password...), and you may save these in some configuration files.

It's a bad practice to check the configuration files into your revision control.

My solution is generating configurations. When generating configurations, only configuration file templates need to be checked into revision control.

## Usage Example

### Prepare files

Suppose You have 2 configuration files:

* src/main/resources/appname.json
* redis.conf

How could you switch to `genconf.lua`?

1. Remove those files from revision control, and add them to `.gitignore`
2. Create templates for `appname.json` and `redis.conf`
3. Make a `genconf` dir in root of your code repo as following and check these files into revision control:

		genconf
		  |-appname.json -> configuration template for the app
		  |-redis.conf -> configuration template for redis
		  |-genconf.conf.lua -> configuration for genconf.lua

The content of `genconf.conf.lua`:

	vars = {
		'redis.host',
		'redis.port',
	}
	
	templates = {
		{ name = 'appname.json', target = 'src/main/resources/appname.json' },
		{ name = 'redis.conf', target = 'redis.conf' },
	}

It defines variables, and target path of templates (i.e. where should genconf save the result).

`name` is relative to genconf/ dir, and `target` path is relative to current dir. You MUST use '/' as path separator no matter what OS you are using.

`appname.json`:

	{
		redis: {
			host: "${redis.host}",
			port: ${redis.port}
		}
	}

`redis.conf`:

	port ${redis.port}
	bind 127.0.0.1
	
	timeout 0
	......

In templates, use the bash-like `${name}` notation to reference the variable.

### Run genconf.lua

The first time you checkout the code into a local dir, run genconf.lua to generate configurations:

	lua genconf.lua redis.host=localhost redis.port=6379

And you can also just run:

	luajit genconf.lua

If values are not specified in command line, genconf.lua will prompt user to input the value:

	$ luajit genconf.lua
	redis.host=_

The cursor will be after '=', then you input the value.

After configuration files generated, you can build or run your app.

NOTE: Both lua and luajit are OK, luajit is preferred. I use [readline](http://www.gnu.org/software/readline/) via [luajit-ffi](http://luajit.org/ext_ffi.html) when it's available. So with luajit you can do better line editing.

### Cache

Once you have specified or inputed the value of a variable, genconf.lua will cache it in a file named `.genconf.cache.lua`.

Next time instead of typing them again, just run:

	lua genconf.lua --use-cached

genconf.lua will use the cached values. If there are new variables, you can still specify them in command line:

	lua genconf.lua --use-cached "new.var=another test"

NOTE: above example also showed how to deal with values that contains spaces.

And the prompt will also change. For example, if you have used `localhost` as the values of `redis.host`:

	$ luajit genconf.lua
	redis.host=[localhost]_

Then you type `Enter`, genconf.lua will automatically use `localhost` as the value of `redis.host`.

How to clean the cache? Just remove `.genconf.cache.lua`.

## Installation

There are two choices:

1. Add genconf.lua to your codebase
2. Install genconf.lua (to for example /usr/bin) on every machine you use genconf.lua

They both have advantages and disadvantages.

1. Add genconf.lua to your codebase: if you want to upgrade it you must make a commit to all your codebases.
2. Install it on machine: your code base depends on an external software.

I recommend 1. for small projects and 2. for larger projects.

## Dependencies

* lua

Optional:

* luajit-ffi
* readline

## Features

* Auto-detect OS (Linux / Windows)

## Restrictions

Variable name can only contains `[A-Za-z0-9._-]`

## Files

* genconf/genconf.conf.lua -> configuration
* .genconf.cache.lua -> cache

## Command line reference

Generate what should be added to `.gitignore`:

	lua genconf.lua --gitignore

Use cached values:

	lua genconf.lua --use-cached

Get help:

	lua genconf.lua --help
