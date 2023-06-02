if package.loaded.math3d then
    error "need init math3d MAXPAGE"
end
debug.getregistry().MATH3D_MAXPAGE = 10240

local fs       = require "filesystem"
local lfs      = require "filesystem.local"
local sha1     = require "editor.hash".sha1
local config   = require "editor.config"
local depends  = require "editor.depends"

local function get_filename(pathname)
    pathname = pathname:lower()
    local filename = pathname:match "[/]?([^/]*)$"
    return filename.."_"..sha1(pathname)
end

local compile

local function absolute_path(base, path)
	if path:sub(1,1) == "/" then
		return compile(path)
	end
	return lfs.absolute(base:parent_path() / (path:match "^%./(.+)$" or path))
end

local function compile_file(input)
    local inputstr = input:string()
    local ext = inputstr:match "[^/]%.([%w*?_%-]*)$"
    local cfg = config.get(ext)
    local output = cfg.binpath / get_filename(inputstr)
    local changed = depends.dirty(output / ".dep")
    if changed then
        local ok, deps = cfg.compiler(input, output, function (path)
            return absolute_path(input, path)
        end, changed)
        if not ok then
            local err = deps
            error("compile failed: " .. input:string() .. "\n" .. err)
        end
        depends.insert_front(deps, input)
        depends.writefile(output / ".dep", deps)
    end
    return output
end

function compile(pathstring)
    local pos = pathstring:find("|", 1, true)
    if pos then
        local resource = fs.path(pathstring:sub(1,pos-1)):localpath()
        return compile_file(resource) / pathstring:sub(pos+1):gsub("|", "/")
    else
        return fs.path(pathstring):localpath()
    end
end

return {
    compile = compile,
    compile_file = compile_file,
}
