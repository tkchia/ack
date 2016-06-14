local posix = require("posix")

-- Targets:
--
-- {
--   fullname = full name of target
--   dir = target's build directory
--   outs = target's object files
--   is = { set of rule types which made the target }
-- }

local environment = {}
local rules = {}
local targets = {}
local buildfiles = {}
local globals
local cwd = "."

local function inherit(high, low)
	local o = {}
	setmetatable(o, {
		__index = function(self, k)
			local x = high[k]
			if x then
				return x
			end
			return low[k]
		end
	})
	return o
end

local function asstring(o)
	local t = type(o)
	if (t == "nil") then
		return ""
	elseif (t == "string") then
		return o
	elseif (t == "number") then
		return o
	elseif (t == "table") then
		if o.is then
			return asstring(o.outs)
		else
			local s = {}
			for _, v in pairs(o) do
				s[#s+1] = asstring(v)
			end
			return table.concat(s, " ")
		end
	else
		error(string.format("can't turn values of type '%s' into strings", t))
	end
end

local function concatpath(...)
	local p = table.concat({...}, "/")
	return p:gsub("/+", "/"):gsub("^%./", ""):gsub("/%./", "/")
end

local function filenamesof(targets, pattern)
	local f = {}
	if targets then
		if targets.is then
			targets = {targets}
		end

		for _, r in pairs(targets) do
			if (type(r) == "table") and r.is then
				if r.outs then
					for _, o in pairs(r.outs) do
						if not pattern or o:find(pattern) then
							f[#f+1] = o
						end
					end
				end
			elseif (type(r) == "string") then
				f[#f+1] = r
			else
				error(string.format("list of targets contains a %s which isn't a target",
					type(r)))
			end
		end
	end
	return f
end

local function dotocollection(collection, callback)
	if (type(collection) == "string") then
		return callback(collection)
	elseif collection.is then
		local files = filenamesof(collection.outs)
		if (#files ~= 1) then
			error("inputs with more than one output need to be in a list")
		end
		return callback(files[1])
	end

	local o = {}
	for _, s in pairs(collection) do
		if s.is then
			for _, b in pairs(dotocollection(filenamesof(s), callback)) do
				o[#o+1] = b
			end
		else
			local b = callback(s)
			if (b ~= "") then
				o[#o+1] = b
			end
		end
	end
	return o
end

local function abspath(collection)
	return dotocollection(collection,
		function(filename)
			return concatpath(posix.getcwd(), filename)
		end
	)
end
	
local function basename(collection)
	return dotocollection(collection,
		function(filename)
			local _, _, b = filename:find("^.*/([^/]*)$")
			if not b then
				return filename
			end
			return b
		end
	)
end

local function dirname(collection)
	return dotocollection(collection,
		function(filename)
			local _, _, b = filename:find("^(.*)/[^/]*$")
			if not b then
				return ""
			end
			return b
		end
	)
end

local function fpairs(collection)
	if (type(collection) == "string") or collection.is then
		return fpairs({collection})
	end

	return pairs(filenamesof(collection))
end

-- Selects all targets containing at least one output file that matches
-- the pattern (or all, if the pattern is nil).
local function selectof(targets, pattern)
	local o = {}
	for k, v in pairs(targets) do
		if v.is and v.outs then
			local matches = false
			for _, f in pairs(v.outs) do
				if f:find(pattern) then
					matches = true
					break
				end
			end
			if matches then
				o[#o+1] = v
			end
		end
	end
	return o
end

local function uniquify(collection)
	local s = {}
	local o = {}
	for _, v in pairs(collection) do
		if not s[v] then
			s[v] = true
			o[#o+1] = v
		end
	end
	return o
end

local function startswith(needle, haystack)
	return haystack:sub(1, #needle) == needle
end

local function emit(...)
	local n = select("#", ...)
	local args = {...}

	for i=1, n do
		local s = asstring(args[i])
		io.stdout:write(s)
		if not s:find("\n$") then
			io.stdout:write(" ")
		end
	end
end

local function templateexpand(list, vars)
	vars = inherit(vars, globals)

	local o = {}
	for _, s in ipairs(list) do
		o[#o+1] = s:gsub("%%%b{}",
			function(expr)
				expr = expr:sub(3, -2)
				local chunk, e = loadstring("return "..expr, expr, "text", vars)
				if e then
					error(string.format("error evaluating expression: %s", e))
				end
				return asstring(chunk())
			end
		)
	end
	return o
end
	
local function loadbuildfile(filename)
	if not buildfiles[filename] then
		buildfiles[filename] = true

		local fp, data, chunk, e
		io.stderr:write("loading ", filename, "\n")
		fp, e = io.open(filename)
		if not e then
			data, e = fp:read("*a")
			fp:close()
			if not e then
				local thisglobals = {_G = thisglobals}
				setmetatable(thisglobals, {__index = globals})
				chunk, e = loadstring(data, filename, "text", thisglobals)
			end
		end
		if e then
			error(string.format("couldn't load '%s': %s", filename, e))
		end

		local oldcwd = cwd
		cwd = dirname(filename)
		chunk()
		cwd = oldcwd
	end
end

local function loadtarget(targetname)
	if targets[targetname] then
		return targets[targetname]
	end

	local target
	if not targetname:find("%+") then
		local files
		if targetname:find("[?*]") then
			files = posix.glob(targetname)
			if not files then
				error(string.format("glob '%s' matches no files", targetname))
			end
		else
			files = {targetname}
		end

		target = {
			outs = files,
			is = {
				__implicitfile = true
			}
		}
		targets[targetname] = target
	else
		local _, _, filepart, targetpart = targetname:find("^([^+]*)%+([%w-_]+)$")
		if not filepart or not targetpart then
			error(string.format("malformed target name '%s'", targetname))
		end
		if (filepart == "") then
			filepart = cwd
		end
		local filename = concatpath(filepart, "/build.lua")
		loadbuildfile(concatpath(filename))

		target = targets[targetname]
		if not target then
			error(string.format("build file '%s' contains no rule '%s'",
				filename, targetpart))
		end
	end

	return target
end

local typeconverters = {
	targets = function(propname, i)
		if (type(i) == "string") then
			i = {i}
		elseif (type(i) ~= "table") then
			error(string.format("property '%s' must be a target list", propname))
		end

		local o = {}
		for k, s in pairs(i) do
			if (type(s) == "table") and s.is then
				o[k] = s
			elseif (type(s) == "string") then
				if s:find("^%+") then
					s = cwd..s
				elseif s:find("^%./") then
					s = concatpath(cwd, s)
				end
				o[k] = loadtarget(s)
			else
				error(string.format("member of target list '%s' is not a string or a target",
					propname))
			end
		end
		return o
	end,

	strings = function(propname, i)
		if (type(i) == "string") then
			i = {i}
		elseif (type(i) ~= "table") then
			error(string.format("property '%s' must be a string list", propname))
		end
		return i
	end,

	string = function(propname, i)
		if (type(i) ~= "string") then
			error(string.format("property '%s' must be a string", propname))
		end
		return i
	end,

	table = function(propname, i)
		if (type(i) ~= "table") then
			error(string.format("property '%s' must be a table", propname))
		end
		return i
	end,
}
	
local function definerule(rulename, types, cb)
	if rules[rulename] then
		error(string.format("rule '%s' is already defined", rulename))
	end

	types.name = { type="string" }

	for propname, typespec in pairs(types) do
		if not typeconverters[typespec.type] then
			error(string.format("property '%s' has unrecognised type '%s'",
				propname, typespec.type))
		end
	end

	rules[rulename] = function(e)
		local args = {}
		for propname, typespec in pairs(types) do
			if not e[propname] then
				if not typespec.optional and not typespec.default then
					error(string.format("missing mandatory property '%s'", propname))
				end

				args[propname] = typespec.default
			else
				args[propname] = typeconverters[typespec.type](propname, e[propname])
				e[propname] = nil
			end
		end

		local propname, _ = next(e)
		if propname then
			error(string.format("don't know what to do with property '%s'", propname))
		end

		args.environment = environment
		args.fullname = cwd.."+"..args.name

		local result = cb(args) or {}
		result.is = result.is or {}
		result.is[rulename] = true
		result.fullname = args.fullname
		targets[result.fullname] = result
		return result
	end
end

-----------------------------------------------------------------------------
--                              DEFAULT RULES                              --
-----------------------------------------------------------------------------

function environment:rule(ins, outs)
	local firstout = outs[1]
	for i = 2, #outs do
		emit(outs[i]..":", outs[1], "\n")
	end
	for i = 1, #ins do
		emit(firstout..":", ins[i], "\n")
	end
	emit(firstout..":\n")
end

function environment:phony(ins, outs)
	emit(".PHONY:", outs, "\n")
	self:rule(ins, outs)
end

function environment:label(...)
	local s = table.concat({...}, " ")
	emit("\t@echo", s, "\n")
end

function environment:mkdirs(dirs)
	dirs = uniquify(dirs)
	if (#dirs > 0) then
		emit("\t@mkdir -p", dirs, "\n")
	end
end

function environment:exec(commands)
	for _, s in ipairs(commands) do
		emit("\t$(hide)", s, "\n")
	end
end

function environment:endrule()
	emit("\n")
end

definerule("simplerule",
	{
		ins = { type="targets" },
		outs = { type="strings" },
		label = { type="string", optional=true },
		commands = { type="strings" },
		vars = { type="table", default={} },
	},
	function (e)
		e.environment:rule(filenamesof(e.ins), e.outs)
		e.environment:label(e.fullname, " ", e.label or "")
		e.environment:mkdirs(dirname(e.outs))

		local vars = inherit(e.vars, {
			ins = e.ins,
			outs = e.outs
		})

		e.environment:exec(templateexpand(e.commands, vars))
		e.environment:endrule()

		return {
			outs = e.outs
		}
	end
)

definerule("installable",
	{
		map = { type="targets", default={} },
	},
	function (e)
		local deps = {}
		local commands = {}
		local srcs = {}
		local dests = {}
		for dest, src in pairs(e.map) do
			if src.is.installable then
				if (type(dest) ~= "number") then
					error("can't specify a destination filename when installing an installable")
				end
				deps[#deps+1] = src.fullname
			elseif (type(dest) == "number") then
				error("only references to other installables can be missing a destination")
			else
				local f = filenamesof(src)
				if (#f ~= 1) then
					error("installable can only cope with targets emitting single files")
				end

				srcs[#srcs+1] = src
				dests[#dests+1] = dest
				commands[#commands+1] = "cp "..f[1].." "..dest
				deps[#deps+1] = dest
			end
		end

		if (#dests > 0) then
			e.environment:rule(srcs, dests)
			e.environment:label(e.fullname, " ", e.label or "")
			if (#commands > 0) then
				e.environment:mkdirs(dirname(dests))
				e.environment:exec(commands)
			end
			e.environment:endrule()
		end

		e.environment:phony(deps, {cwd.."+"..e.name})
		e.environment:endrule()
	end
)

-----------------------------------------------------------------------------
--                               MAIN PROGRAM                              --
-----------------------------------------------------------------------------

globals = {
	abspath = abspath,
	asstring = asstring,
	basename = basename,
	concatpath = concatpath,
	cwd = function() return cwd end,
	definerule = definerule,
	dirname = dirname,
	emit = emit,
	environment = environment,
	filenamesof = filenamesof,
	inherit = inherit,
	selectof = selectof,
	startswith = startswith,
	fpairs = fpairs,
	uniquify = uniquify,
}
setmetatable(globals,
	{
		__index = function(self, k)
			local rule = rules[k]
			if rule then
				return rule
			else
				return _G[k]
			end
		end
	}
)

emit("hide=@\n")
for _, file in ipairs({...}) do
	loadbuildfile(file)
end

