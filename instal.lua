-- RagnarNet - Installeur global (ComputerCraft / CC:Tweaked)
-- Installe : startup.lua, config.lua, ui.lua, update.lua, users.db
-- Source : uniquement les RAW GitHub donnés (correction refs/heads -> main)

local FILES = {
  { name="startup.lua", url="https://raw.githubusercontent.com/ragnar152743/ragnarNET-OFFICIAL/refs/heads/main/ragnar%3Aofficial/systeme%20FR/startup.lua", binary=false },
  { name="config.lua",  url="https://raw.githubusercontent.com/ragnar152743/ragnarNET-OFFICIAL/refs/heads/main/ragnar%3Aofficial/systeme%20FR/config.lua",  binary=false },
  { name="ui.lua",      url="https://raw.githubusercontent.com/ragnar152743/ragnarNET-OFFICIAL/refs/heads/main/ragnar%3Aofficial/systeme%20FR/ui.lua",      binary=false },
  { name="update.lua",  url="https://raw.githubusercontent.com/ragnar152743/ragnarNET-OFFICIAL/refs/heads/main/ragnar%3Aofficial/systeme%20FR/update.lua",  binary=false },
  { name="users.db",    url="https://raw.githubusercontent.com/ragnar152743/ragnarNET-OFFICIAL/refs/heads/main/ragnar%3Aofficial/systeme%20FR/users.db",    binary=true  },
}

-- ========== Utils ==========
local function normalize(url)
  -- garde le RAW fourni, mais remplace juste /refs/heads/main/ par /main/ (toujours RAW)
  return url:gsub("/refs/heads/main/", "/main/")
end

local function bytes(n)
  if n >= 1024*1024 then return string.format("%.2f MB", n/1024/1024)
  elseif n >= 1024 then return string.format("%.2f KB", n/1024)
  else return tostring(n).." B" end
end

local function readAll(handle)
  local s, c = "", handle.read()
  while c do s = s .. c; c = handle.read() end
  handle.close()
  return s
end

local function backup(path)
  if fs.exists(path) then
    local bak = path .. ".bak"
    if fs.exists(bak) then fs.delete(bak) end
    fs.move(path, bak)
    print("Backup  -> " .. bak)
  end
end

local function writeFile(path, data, binary)
  local dir = fs.getDir(path)
  if dir and dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
  local mode = binary and "wb" or "w"
  local f = fs.open(path, mode)
  if not f then return false, "cannot open for write" end
  f.write(data)
  f.close()
  return true
end

local function readFile(path, binary)
  if not fs.exists(path) then return nil end
  local f = fs.open(path, binary and "rb" or "r"); if not f then return nil end
  local d = f.readAll(); f.close(); return d
end

-- Télécharge depuis l’URL RAW donnée (HTTP direct, sinon wget; toujours la même URL RAW)
local function download_raw(url, dest, binary)
  url = normalize(url)
  -- HTTP direct (préféré)
  if http then
    local ok, res = pcall(function() return http.get(url, nil, binary) end)
    if ok and res then
      local data = readAll(res)
      if data and #data > 0 then return data end
    end
  end
  -- Fallback wget (toujours vers la même URL RAW)
  if shell then
    local tmp = dest .. ".wget.tmp"
    if fs.exists(tmp) then fs.delete(tmp) end
    local cmd = ("wget -f %q %q"):format(url, tmp)
    local ok = shell.run(cmd)
    if ok and fs.exists(tmp) then
      local data = readFile(tmp, binary)
      fs.delete(tmp)
      if data and #data > 0 then return data end
    end
  end
  return nil, "download failed"
end

local function is_sqlite_header(s)
  if not s or #s < 16 then return false end
  -- on teste "SQLite format 3" (sans le \0 final pour compatibilité)
  return s:sub(1, 15) == "SQLite format 3"
end

-- ========== Install ==========
print("=== RagnarNet Global Installer (RAW GitHub) ===")
print(("HTTP: %s  | shell: %s"):format(tostring(http ~= nil), tostring(shell ~= nil)))
print("----")

local results = {}
for _, it in ipairs(FILES) do
  local dest, url, binary = it.name, it.url, it.binary
  print(("Téléchargement: %s"):format(dest))
  local data, why = download_raw(url, dest, binary)
  if not data then
    results[dest] = { ok=false, reason=why or "unknown" }
    print(("✗ %s : %s"):format(dest, results[dest].reason))
    print("----")
  else
    print(("Reçu %s (%s)"):format(dest, bytes(#data)))
    -- heuristiques minimales
    if dest == "users.db" then
      if not is_sqlite_header(data) then
        print("⚠ users.db ne ressemble pas à un SQLite (header).")
      else
        print("✔ users.db header OK (SQLite)")
      end
    else
      if #data < 10 then print("⚠ " .. dest .. " semble très petit.") end
    end
    -- écriture atomique
    backup(dest)
    local tmp = dest .. ".dl"
    if fs.exists(tmp) then fs.delete(tmp) end
    local ok, werr = writeFile(tmp, data, binary)
    if not ok then
      results[dest] = { ok=false, reason=werr or "write failed" }
      print(("✗ %s : %s"):format(dest, results[dest].reason))
      print("----")
    else
      if fs.exists(dest) then fs.delete(dest) end
      fs.move(tmp, dest)
      local written = readFile(dest, binary)
      if not written or #written ~= #data then
        results[dest] = { ok=false, reason="size mismatch after write" }
        print(("✗ %s : %s"):format(dest, results[dest].reason))
      else
        results[dest] = { ok=true, size=#written }
        print(("✔ Installé %s (%s)"):format(dest, bytes(#written)))
      end
      print("----")
    end
  end
end

print("Résumé :")
local okc, fc = 0, 0
for _, it in ipairs(FILES) do
  local r = results[it.name]
  if r and r.ok then
    okc = okc + 1
    print(("  ✔ %s (%s)"):format(it.name, bytes(r.size)))
  else
    fc = fc + 1
    print(("  ✗ %s (%s)"):format(it.name, r and r.reason or "not attempted"))
  end
end
print(("Terminé : %d OK, %d échec(s)."):format(okc, fc))

-- proposer d'exécuter update.lua si présent, puis reboot
if results["update.lua"] and results["update.lua"].ok and shell then
  io.write("Lancer update.lua maintenant ? [Y/n] ")
  local a = read()
  if not a or a == "" or a:lower() == "y" or a:lower() == "yes" then
    print("Execution de update.lua ...")
    sleep(0.2)
    local ok = shell.run("update.lua")
    if not ok then print("update.lua terminé avec erreurs (ou shell indisponible).") end
  end
end

io.write("Rebooter maintenant pour appliquer ? [Y/n] ")
local a = read()
if not a or a == "" or a:lower() == "y" or a:lower() == "yes" then
  print("Reboot...")
  sleep(0.4)
  os.reboot()
else
  print("Reboote plus tard pour appliquer les changements.")
end
