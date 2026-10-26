-- #CPC CONFIG: show the settings, set one in the global file, reject what it should.
--     lua5.1 tests/config_test.lua
local xml = io.open("cpc.xml"):read("*a")
local script
for body in xml:gmatch("<script>(.-)</script>") do
  if #body > (script and #script or 0) then script = body end
end
script = script:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"'):gsub("&amp;", "&")

local root = "/tmp/cpc-config-test"
os.execute("rm -rf " .. root .. " && mkdir -p " .. root .. "/profiles/Mage-Test")
local out = {}
function getProfiles() return {} end
function getProfileName() return "Mage-Test" end
function getMudletHomeDir() return root .. "/profiles/Mage-Test" end
function cecho(s) out[#out + 1] = s end
function echo(s) out[#out + 1] = s end
function cechoLink(text) out[#out + 1] = text end
function registerAnonymousEventHandler() return 1 end
function killAnonymousEventHandler() end
function downloadFile() end
function io.exists() return false end
lfs = { mkdir = function() end }
function table.index_of(t, v) for i, x in ipairs(t) do if x == v then return i end end end
function table.contains(t, v) for _, x in ipairs(t) do if x == v then return true end end return false end
function expandAlias() end
function print() end
function debugc() end
string.ends = function(s, e) return e == "" or s:sub(-#e) == e end

local fails = 0
local function check(cond, what)
  if cond then io.write("ok:   " .. what .. "\n") else fails = fails + 1; io.write("FAIL: " .. what .. "\n") end
end
-- the command output without its colour tags
local function run(args) out = {}; cpc:handleCommand("cpc", args); return (table.concat(out):gsub("<[%a_]+>", "")) end
local global = root .. "/profiles/cpc-settings.lua"

cpc = nil
assert(loadstring(script))()
local shown = run("config")
check(shown:find("autoUpdate%s+= notify%s+%(default%)") and shown:find("strictTargets%s+= false"), "config shows each setting with its value and source")
check(shown:find("#CPC CONFIG autoUpdate <notify|on|off>") and shown:find("#CPC CONFIG strictTargets <on|off>"), "and how to set each")
check(shown:find("Cfg: " .. global, 1, true), "and the global file's path")

local set = run("config autoUpdate off")
check(cpc.autoUpdate == "off" and set:find("Cfg: " .. global, 1, true), "setting applies now and names the file")
local t = dofile(global)
check(t.autoUpdate == "off" and t.strictTargets == nil, "the file holds the setting and nothing it was not told")

run("config strictTargets ON")
t = dofile(global)
check(cpc.strictTargets == true and t.strictTargets == true and t.autoUpdate == "off", "a bool from on/off, case aside; earlier settings kept")
check(run("config strictTargets maybe"):find("strictTargets takes on or off"), "a bad bool is refused")
check(run("config autoUpdate sometimes"):find("autoUpdate takes notify, on, off"), "a bad choice is refused")
check(run("config dingdongaroonie 42"):find("no setting 'dingdongaroonie'; the settings are autoUpdate, strictTargets, localEcho, debug"), "an unknown setting is refused with the list")

-- the written file is what the next load reads
cpc = nil
assert(loadstring(script))()
check(cpc.autoUpdate == "off" and cpc.strictTargets == true, "the next load reads the file back")
shown = run("config")
check(shown:find("autoUpdate%s+= off%s+%(global file%)"), "config now says the value comes from the global file")

-- a hand-written extra key in the file survives a set
local f = io.open(global, "w"); f:write('return { autoUpdate = "notify", extra = 7 }'); f:close()
run("config debug on")
t = dofile(global)
check(t.extra == 7 and t.debug == true and t.autoUpdate == "notify", "keys the file already held are kept")

-- a profile's own file shows as the source and is named
f = io.open(root .. "/profiles/Mage-Test/cpc-settings.lua", "w"); f:write('return { localEcho = false }'); f:close()
cpc = nil
assert(loadstring(script))()
shown = run("config")
check(shown:find("localEcho%s+= false%s+%(this profile's file%)") and shown:find("Cfg %(this profile, applied over it%): "), "the profile file is shown as the source and named")

os.execute("rm -rf " .. root)
if fails > 0 then io.write(fails .. " failed\n"); os.exit(1) end
io.write("all passed\n")
