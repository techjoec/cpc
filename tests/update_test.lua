-- The cpc.autoUpdate setting, run on the host with stand-ins for Mudlet: what happens at load
-- and when the version list arrives, for "notify" (the default), "on" and "off".
--     lua5.1 tests/update_test.lua
local xml = io.open("cpc.xml"):read("*a")
local script
for body in xml:gmatch("<script>(.-)</script>") do
  if #body > (script and #script or 0) then script = body end
end
script = script:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"'):gsub("&amp;", "&")

local out, downloads, links, installs, versionsOnDisk, packages = {}, {}, {}, {}, nil, {}
function getProfiles() return {} end
function getProfileName() return "Mage-Test" end
function cecho(s) out[#out + 1] = s end
function echo(s) out[#out + 1] = s end
function cechoLink(text, cmd, hint) links[#links + 1] = { text = text, cmd = cmd }; out[#out + 1] = text end
function registerAnonymousEventHandler() return 1 end
function killAnonymousEventHandler() end
function downloadFile(path, url) downloads[#downloads + 1] = url end
function io.exists(p) return versionsOnDisk ~= nil or not p:find("versions.lua") end
lfs = { mkdir = function() end }
function getMudletHomeDir() return "/tmp" end
function table.load(path, t) for i, v in ipairs(versionsOnDisk) do t[i] = v end end
function table.index_of(t, v) for i, x in ipairs(t) do if x == v then return i end end end
function table.contains(t, v) for _, x in ipairs(t) do if x == v then return true end end return false end
function getPackages() return packages end
function expandAlias() end
function uninstallPackage() installs[#installs + 1] = "uninstall" end
function installPackage() installs[#installs + 1] = "install" end
function print() end
string.ends = function(s, e) return e == "" or s:sub(-#e) == e end

local fails = 0
local function check(cond, what)
  if cond then print_ = nil; io.write("ok:   " .. what .. "\n") else fails = fails + 1; io.write("FAIL: " .. what .. "\n") end
end
local function load(preset)
  cpc = preset
  out, downloads, links, installs = {}, {}, {}, {}
  assert(loadstring(script))()
  cpc.version = "v0.4.0"
end
local function arrive(list)
  versionsOnDisk = list
  cpc.downloading = true
  out, links, downloads, installs = {}, {}, {}, {}
  arg = { "/tmp/cpc downloads/versions.lua" }
  cpc:onFileDownloaded("sysDownloadDone", arg[1])
end
local function text() return table.concat(out) end

-- default: notify
load(nil)
check(cpc.autoUpdate == "notify", "autoUpdate defaults to notify")
check(#downloads == 1 and downloads[1]:find("techjoec/cpc/main/versions.lua"), "notify: the version list is fetched at load")
arrive({ "v0.3.5", "v0.4.0" })
check(#out == 0 and #downloads == 0, "notify: nothing said when this is the newest release")
arrive({ "v0.3.5", "v0.4.0", "v0.4.1" })
check(text():find("release v0.4.1 is available") and #links == 1 and links[1].cmd == "openUrl('https://github.com/techjoec/cpc/releases/tag/v0.4.1')",
  "notify: a newer release is announced with a link to its release page")
check(text():find("#CPC UPDATE to install") and #downloads == 0 and #installs == 0, "notify: nothing is downloaded or installed")
check(cpc:checkVersion():find("1 behind online %- v0.4.1"), "#VERSION shows how far behind")
arrive({ "v0.3.5" })
check(#out == 0, "a list that does not know this version says nothing")

-- off
versionsOnDisk = nil
load({ autoUpdate = "off" })
check(#downloads == 0, "off: nothing is fetched at load")
check(cpc:checkVersion() == "<orange>(auto update off)", "off: #VERSION says so instead of guessing")

-- on, installed as a package
load({ autoUpdate = "on" })
packages = { "Cross Profile Communication" }
arrive({ "v0.3.5", "v0.4.0", "v0.4.1" })
check(text():find("installing v0.4.1") and #downloads == 1 and downloads[1]:find("releases/latest/download/cpc.mpackage"),
  "on, package: the release is downloaded at load")
cpc.downloading = true
arg = { "/tmp/cpc downloads/cpc.mpackage" }
cpc:onFileDownloaded("sysDownloadDone", arg[1])
check(installs[1] == "uninstall" and installs[2] == "install", "on, package: the downloaded package replaces the installed one")

-- on, installed as a module from a git clone
load({ autoUpdate = "on" })
packages = {}
arrive({ "v0.3.5", "v0.4.0", "v0.4.1" })
check(#downloads == 0 and text():find("pull the clone") and #links == 1, "on, module: told to pull, with the link, nothing downloaded")

if fails > 0 then io.write(fails .. " failed\n"); os.exit(1) end
io.write("all passed\n")
