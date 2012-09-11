# genconf.lua

A generic configuration files generator

## Motivation

In your application there are many configurations (db host/port/username/password...), and you may save these configurations in some files.

It's a bad practice to put the configuration files in your revision control.

I want to seperate configuration from codebase(revision control), so I generate the configurations.

When generating configurations, only configuration templates need to be checked into revision control.

## Example Usage

Suppose I write a application that uses redis as cache, and I need to configure it.

Make a `genconf` dir in root of your code repo like this(these files are all in revision control):

	genconf
	  |-appname.json -> configuration template for the app
	  |-redis.conf -> configuration template for redis
	  |-genconf.conf.lua -> configuration for genconf.lua

And the content of genconf.conf.lua:

	vars = {
		'redis.host',
		'redis.port',
	}
	
	files = {
		{ name = appname.json', target = 'src/main/resources/appname.json' },
		{ name = 'redis.conf', target = 'redis.conf' },
	}

It defines 2 variables, and target path of configuration templates.

`name` is relative to genconf/ dir, and `target` path is relative to current dir. You MUST use '/' as path separator no matter what OS you are using.

Let's see how to use variables in configuration template(`appname.json`):

	{
		redis: {
			host: "${redis.host}",
			port: ${redis.port}
		}
	}

and `redis.conf` looks like:

	port ${redis.port}
	bind 127.0.0.1
	
	timeout 0
	......

So, use the bash-like `${name}` notation to reference the variable.

The first time you checkout the code into a local dir, run genconf.lua to generate configurations:

	lua genconf.lua redis.host=localhost redis.port=6379

And you can also just run:

	luajit genconf.lua

It will ask you the value of variables. And then you can build your app.

NOTE: lua and luajit both are OK, luajit is preferred. I use readline via [luajit-ffi](http://luajit.org/ext_ffi.html) when it's available. So with luajit you can do better line editing.

## Cache

Once you have specified or inputed the value of a variable, genconf.lua will cache it in a file named `.genconf.cache.lua`.

Next time when you need to run genconf.lua, just run:

	lua genconf.lua --use-cached

And you need not type the values again. If there are new variables, you can still specify them in command line:

	lua genconf.lua --use-cached "new.var=another test"

NOTE: above example also showed how to deal with values that contains spaces.

How to clean the cache? Just remove `.genconf.cache.lua`.

## Dependencies

(Optional)

* luajit-ffi
* readline

## Features

* Auto-detect OS (Linux / Windows)

## Limitations

Variable name can only contains [A-Za-z0-9.]

## Files

* genconf/genconf.conf.lua -> configuration
* .genconf.cache.lua -> cache

## Command line reference

Generate what should be added to `.gitignore`:

	lua genconf.lua --gitignore

Use cached values:

	lua genconf.lua --use-cached
