--[[
-- genconf.lua - a generic configuration files generator
--]]

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

-- figure out the path separator
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

dofile('genconf' .. os.pathsep .. 'genconf.conf.lua')

-- cache
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

-- process command line
if arg[1] == '--gitignore' then
	print('.genconf.cache.lua')
	for _, temp in ipairs(templates) do
		io.write(temp.target, '\n')
	end
	return
end

local cachedValues = cache.load()

local null = {}

-- get the value of variables

--- --use-cached
local useCached = false
if arg[1] == '--use-cached' then
	table.remove(arg, 1)
	useCached = true
end

local VARNAME_PATT = '[%w._-]+'

local values = {}

do
	local ok, err = pcall(function()
		for _, varname in ipairs(vars) do
			tassert(string.match(varname, '^'..VARNAME_PATT..'$') ~= nil, 'Invalid var name: '..varname..' (must match '..VARNAME_PATT..')')
			if useCached and cachedValues[varname] then
				values[varname] = cachedValues[varname]
			else
				values[varname] = null
			end
		end

		--- try command line arguments
		for _, line in ipairs(arg) do
			local i = string.find(line, '=', 1, true)
			if i == nil then
				throw("Can't find '=' in :" .. line)
			else
				local name = string.sub(line, 1, i - 1)
				local value = string.sub(line, i + 1)
				tassert(values[name] ~= nil, 'name is not in vars: ' .. name)
				-- command line has a higher priority than cached values
				values[name] = value
			end
		end
	end)

	if not ok then
		io.write(err, '\n')
		os.exit(1)
	end
end

-- ask user
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
	if values[name] == null then
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

-- save cache
cache.save(values)

-- generate
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
