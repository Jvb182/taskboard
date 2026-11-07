-- Static checks over the source: syntax, and every API/event/template/font/sound
-- the code names must exist in the WoW: Forever client (per the API fixture).
local T, Mock = ...
local API = Mock.API

local function readToc()
    local files = {}
    for line in io.lines(QB_ADDON_ROOT .. "Questboard.toc") do
        line = line:gsub("\r", "")
        if line ~= "" and not line:match("^##") then files[#files + 1] = line:gsub("\\", "/") end
    end
    return files
end

local function read(path)
    local f = assert(io.open(QB_ADDON_ROOT .. path, "r"))
    local s = f:read("*a")
    f:close()
    return s
end

local files = readToc()
local sources = {}
for _, file in ipairs(files) do sources[file] = read(file) end

-- Removes comments so examples in comments are not checked.
local function code(src)
    return (src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", ""))
end

describe("static", function()
    it("toc targets the Forever interface and lists existing files", function()
        local toc = read("Questboard.toc")
        T.contains(toc, "## Interface: 16001")
        T.contains(toc, "## SavedVariables: QuestboardDB, QuestboardLog")
        T.ok(#files >= 20, "toc lists the addon files")
        for _, file in ipairs(files) do
            T.ok(io.open(QB_ADDON_ROOT .. file, "r"), "toc file exists: " .. file)
        end
    end)

    it("every file compiles under Lua 5.1", function()
        for _, file in ipairs(files) do
            local chunk, err = loadstring(sources[file], file)
            T.ok(chunk, err)
        end
    end)

    it("every C_ API used exists in the client", function()
        local missing = {}
        for file, src in pairs(sources) do
            for ns, fn in code(src):gmatch("(C_%w+)%.([%w_]+)") do
                if not (API.namespaces[ns] and API.namespaces[ns][fn]) then missing[#missing + 1] = file .. ": " .. ns .. "." .. fn end
            end
        end
        -- Diagnostics lists capabilities as strings; check those too.
        for ns, fn in sources["Core/Diagnostics.lua"]:gmatch('"(C_%w+)%.([%w_]+)"') do
            if not (API.namespaces[ns] and API.namespaces[ns][fn]) then missing[#missing + 1] = "capability " .. ns .. "." .. fn end
        end
        T.eq(table.concat(missing, ", "), "", "missing APIs")
    end)

    it("every event registered exists", function()
        local unknown = {}
        for file, src in pairs(sources) do
            for event in code(src):gmatch('RegisterEvent%("([%u_]+)"') do
                if not API.events[event] then unknown[#unknown + 1] = file .. ": " .. event end
            end
            -- Event tables like Goals.EVENTS / Reminders.NPC_EVENTS: KEY = ...
            for event in code(src):gmatch("\n%s+([%u][%u_]+[%u])%s*=%s*[{\"]") do
                if event:find("_") and not API.events[event] and not event:match("^QUESTBOARD") and not event:match("^BINDING_")
                    and not event:match("^SLASH_") then
                    unknown[#unknown + 1] = file .. ": " .. event
                end
            end
        end
        T.eq(table.concat(unknown, ", "), "", "unknown events")
    end)

    it("every template and font object used exists", function()
        local unknown = {}
        for file, src in pairs(sources) do
            local c = code(src)
            for template in c:gmatch('CreateFrame%(%s*"%w+"%s*,%s*[^,\n]+,%s*[^,\n]+,%s*"([%w_, ]+)"') do
                for t in template:gmatch("[^,%s]+") do
                    if not API.templates[t] then unknown[#unknown + 1] = file .. ": template " .. t end
                end
            end
            for font in c:gmatch('"(%u%l+Font[%w]*)"') do
                if not API.templates[font] then unknown[#unknown + 1] = file .. ": font " .. font end
            end
            for font in c:gmatch('"(GameFont[%w]+)"') do
                if not API.templates[font] then unknown[#unknown + 1] = file .. ": font " .. font end
            end
        end
        T.eq(table.concat(unknown, ", "), "", "unknown templates/fonts")
    end)

    it("every SOUNDKIT name used exists", function()
        local src = sources["UI/Toast.lua"]
        local block = src:match("local SOUNDS = (%b{})")
        T.ok(block, "Toast.lua defines SOUNDS")
        for name in block:gmatch('"([%u_%d]+)"') do
            T.ok(API.soundkit[name], "SOUNDKIT." .. name .. " exists")
        end
    end)

    it("Bindings.xml calls functions the addon defines", function()
        local xml = read("Bindings.xml")
        for fn in xml:gmatch("Questboard:(%w+)%(%)") do
            T.contains(sources["Core/Commands.lua"], "function ns:" .. fn .. "(", "binding target " .. fn)
        end
        for name in xml:gmatch('name="(QUESTBOARD_%u+)"') do
            T.contains(sources["Core/Commands.lua"], "BINDING_NAME_" .. name, "binding label " .. name)
        end
    end)

    it("no file uses Lua 5.2+ features or the os/io libraries", function()
        for file, src in pairs(sources) do
            local c = code(src)
            T.no(c:find("goto%s"), file .. " uses goto")
            T.no(c:find("[^%w_%.]io%."), file .. " uses io")
            T.no(c:find("os%.%a+%(") and not c:find("os%.time%(%)") and not c:find("os%.clock%(%)"), file .. " uses os")
            T.no(c:find("//"), file .. " uses //")
            T.no(c:find("loadstring"), file .. " uses loadstring")
        end
    end)
end)
