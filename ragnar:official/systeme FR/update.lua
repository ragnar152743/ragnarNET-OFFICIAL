-- update.lua : Installation / MAJ complète RagnarNet (met à jour manifest & version)
-- Adapté pour GitHub RAW (wget/http), plus de Pastebin.

local function println(c, msg)
  if term and colors and c then term.setTextColor(c) end
  print(msg)
  if term and colors then term.setTextColor(colors.white) end
end

-- Télécharge un fichier depuis une URL (http direct, sinon wget)
local function download(url, dest)
  url = url:gsub("/refs/heads/", "/") -- Corrige les refs
  if fs.exists(dest) then fs.delete(dest) end

  -- HTTP direct
  if http then
    local ok, res = pcall(http.get, url)
    if ok and res then
      local data = res.readAll()
      res.close()
      if data and #data > 0 then
        local f = fs.open(dest, "w")
        f.write(data)
        f.close()
        return true
      end
    end
  end

  -- wget fallback
  if shell then
    local cmd = ("wget -f %q %q"):format(url, dest)
    return shell.run(cmd)
  end

  return false
end

local function readAll(p)
  if not fs.exists(p) or fs.isDir(p) then return "" end
  local f = fs.open(p, "r")
  local s = f.readAll() or ""
  f.close()
  return s
end

-- BXOR portable + FNV1a
local function BXOR(a, b)
  if bit and bit.bxor then return bit.bxor(a, b) end
  if bit32 and bit32.bxor then return bit32.bxor(a, b) end
  local r, v = 0, 1
  while a > 0 or b > 0 do
    local A, B = a % 2, b % 2
    if (A + B) % 2 == 1 then r = r + v end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    v = v * 2
  end
  return r
end

local function fnv1a(s)
  local h = 2166136261
  for i = 1, #s do
    h = BXOR(h, s:byte(i))
    h = (h * 16777619) % 4294967296
  end
  return tostring(h)
end

local function fileHash(path)
  return fnv1a(readAll(path))
end

local function extractCodeVer(txt)
  return txt:match('CODE_VER%s*=%s*"%s*([^"]-)%s*"')
end

-- URLs RAW GitHub OFFICIELLES
local files = {
  { url = "https://raw.githubusercontent.com/ragnar152743/ragnarNET-OFFICIAL/main/ragnar%3Aofficial/systeme%20FR/startup.lua", name = "startup.lua" },
  { url = "https://raw.githubusercontent.com/ragnar152743/ragnarNET-OFFICIAL/main/ragnar%3Aofficial/systeme%20FR/ui.lua",      name = "ui.lua" },
  { url = "https://raw.githubusercontent.com/ragnar152743/ragnarNET-OFFICIAL/main/ragnar%3Aofficial/systeme%20FR/config.lua", name = "config.lua" },
  { url = "https://raw.githubusercontent.com/ragnar152743/ragnarNET-OFFICIAL/main/ragnar%3Aofficial/systeme%20FR/update.lua", name = "update.lua" },
}

println(colors.cyan, "=== RagnarNet Installer (GitHub) ===")

-- 1) Téléchargements
for _, f in ipairs(files) do
  println(colors.lightBlue, "Téléchargement de "..f.name.." ...")
  local ok = download(f.url, f.name)
  if not ok then
    println(colors.red, "Echec de téléchargement: "..f.name)
    return
  end
end

-- 2) Heuristique anti-sabotage pour le startup
local sTxt = readAll("startup.lua")
local ok_ver  = sTxt:match('local%s+CODE_VER%s*=%s*"7%.1%.0"')
local ok_db   = sTxt:match('usersDB%s*=%s*"users%.db"')
if not (ok_ver and ok_db) then
  println(colors.red, "Startup invalide (signature heuristique). Annulation.")
  return
end

-- 3) Manifest & expected version
local cfg = {}
local ver  = extractCodeVer(sTxt) or "7.1.0"

cfg.expectedStartupVersion = ver
cfg.autoSeal = true
cfg.tamperAction, cfg.outdatedAction = "error","error"
cfg.askUpdateAtBoot = true
cfg.key="RAGNAR123456789KEYULTRA2025"
cfg.protocol="ragnarnet"
cfg.adminUser="ragnar"
cfg.adminCode="2013.2013"
cfg.spamLimit=5
cfg.maxMessageLength=200
cfg.spamResetTime=300
cfg.pepper="RAG-PEPPER-2025"
cfg.pwdHashRounds=512
cfg.updateURL_startup=files[1].url
cfg.updateURL_ui=files[2].url
cfg.updateURL_config=files[3].url
cfg.updateURL_update=files[4].url
cfg.errorCodeTamper=163
cfg.errorCodeOutdated=279
cfg.manifest = {
  ["startup.lua"] = fileHash("startup.lua"),
  ["ui.lua"]      = fileHash("ui.lua"),
  ["update.lua"]  = fileHash("update.lua"),
}

local function writeConfigTable(tbl)
  local ser = textutils.serialize(tbl)
  local f = fs.open("config.lua", "w")
  f.write("return " .. ser)
  f.close()
end
writeConfigTable(cfg)

println(colors.lime, "Installation terminée. Redémarrage dans 3 secondes...")
sleep(3)
os.reboot()
