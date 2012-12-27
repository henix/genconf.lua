--[[
-- genconf.lua - a generic configuration files generator
--
-- https://github.com/henix/genconf.lua
--]]

-- ## 0 Common functions

-- ### 0.1 exception handling
function throw(msg)
	assert(msg)
	error(msg, 0)
end

function tassert(cond, msg, ...)
	if not cond then
		throw(msg)
	end
	return cond, msg, ...
end

-- ### 0.2 os path separator
do
	local ftest = io.open('/dev/null')
	if ftest == nil then
		os.pathsep = '\\' -- win
	else
		ftest:close()
		os.pathsep = '/' -- linux
	end
end

local normalizePath = nil

if os.pathsep == '\\' then
	normalizePath = function(path)
		return string.gsub(path, '/', '\\')
	end
else
	normalizePath = function(path)
		return path
	end
end

-- ### 0.3 string
function startsWith(str, prefix)
	return (string.sub(str, 1, string.len(prefix)) == prefix)
end

-- ### 0.4 table
function table.indexOf(t, obj)
	for i, v in ipairs(t) do
		if v == obj then
			return i
		end
	end
	return nil
end

-- ## 1 Input process

-- ### 1.1 parse command line
local Action = { -- enum
	PrintHelp = '--help',
	PrintGitignore = '--gitignore',
	UseCached = '--use-cached',
}
local action = nil
local cmdValues = nil

do
	function parseArgs(args)
		local action = nil
		local cmdValues = {}
		for _, param in ipairs(args) do
			if param == '--help' then
				if action ~= nil then throw('Option conflict: '..action..' and '..param) end
				action = Action.PrintHelp
			elseif param == '--gitignore' then
				if action ~= nil then throw('Option conflict: '..action..' and '..param) end
				action = Action.PrintGitignore
			elseif param == '--use-cached' then
				if action ~= nil then throw('Option conflict: '..action..' and '..param) end
				action = Action.UseCached
			elseif startsWith(param, '--') then
				throw('Unknown option: '..param)
			else
				local i = string.find(line, '=', 1, true)
				tassert(i ~= nil, "Can't find '=' in : "..param)
				local name = string.sub(line, 1, i - 1)
				local value = string.sub(line, i + 1)
				tassert(cmdValues[name] == nil, 'Duplicated name in cmdline: ' .. name)
				cmdValues[name] = value
			end
		end
		return action, cmdValues
	end

	local action_err, ok

	ok, action_err, cmdValues = pcall(parseArgs, arg)
	if not ok then
		io.write(action_err, '\n')
		os.exit(1)
	end

	action = action_err
end

-- ### 1.2 print help
if action == Action.PrintHelp then
	print('Usage: lua genconf.lua [--gitignore | --help | --use-cached] name1=value1 name2=value2 ...')
	os.exit(0)
end

-- ### 1.3 import genconf.conf.lua and validate
local VARNAME_PATT = '[%w._-]+'

do
local ok, err = pcall(function()
	dofile('genconf'..os.pathsep..'genconf.conf.lua')
	tassert(vars, 'genconf.conf.lua: vars not defined')
	tassert(templates, 'genconf.conf.lua: templates not defined')
	for _, varname in ipairs(vars) do
		tassert(string.match(varname, '^'..VARNAME_PATT..'$') ~= nil, 'Invalid var name: '..varname..' (must match '..VARNAME_PATT..')')
	end
	for k, v in pairs(cmdValues) do
		tassert(table.indexOf(vars, k), 'name is not in vars: '..k)
	end
end)
	if not ok then
		io.write(err, '\n')
		os.exit(2)
	end
end

-- ### 1.4 print .gitignore
if action == Action.PrintGitignore then
	print('.genconf.cache.lua')
	for _, temp in ipairs(templates) do
		io.write(temp.target, '\n')
	end
	os.exit(0)
end

-- ### 1.5 use cache
local useCached = (action == Action.UseCached)

local cache = {
	['load'] = function()
		local cached = nil
		pcall(function()
			cached = dofile('.genconf.cache.lua')
		end)
		if not cached then
			cached = {}
		end
		return cached
	end,
	save = function(values)
		local fout = assert(io.open('.genconf.cache.lua', 'w'))
		fout:write('return {', '\n')
		for k, v in pairs(values) do
			fout:write(string.format('[%q]=%q,', k, v), '\n')
		end
		fout:write('}', '\n')
		fout:close()
	end
}

local cachedValues = cache.load()

-- ### 1.6 apply cachedValues and cmdValues to values
local values = {}

for _, varname in ipairs(vars) do
	if useCached and cachedValues[varname] then
		values[varname] = cachedValues[varname]
	end
	if cmdValues[varname] then
		values[varname] = cmdValues[varname]
	end
end

-- ### 1.7 ask user
--- load readline library via ffi if available
local readline = nil
do
	local err = pcall(function()
		local ffi = require('ffi')
		ffi.cdef[[
			char *readline(const char *prompt);
		]]
		rl = ffi.load('readline')
		readline = function(prompt)
			return ffi.string(rl.readline(prompt))
		end
	end)
	if not readline then
		readline = function(prompt)
			io.write(prompt)
			return io.read()
		end
	end
end

for _, name in ipairs(vars) do
	if values[name] == nil then
		if cachedValues[name] then
			local line = readline(name..'=['..cachedValues[name]..']')
			if #line == 0 then
				values[name] = cachedValues[name]
			else
				values[name] = line
			end
		else
			values[name] = readline(name..'=')
		end
	end
end

-- ## 2. save cache
cache.save(values)

-- ## 3. generate
for _, file in ipairs(templates) do
	local ftmpl = assert(io.open('genconf' .. os.pathsep .. normalizePath(file.name)))
	local all = ftmpl:read('*a')
	io.close(ftmpl)

	local result = string.gsub(all, '%${('..VARNAME_PATT..')}', function(name)
		-- if not exists, leave it unchanged
		return (values[name] or '${'..name..'}')
	end)

	local outname = normalizePath(file.target)
	io.write('generating ', outname)
	local fout = assert(io.open(outname, 'w'))
	fout:write(result)
	io.close(fout)
	io.write(' ... done.\n')
end
