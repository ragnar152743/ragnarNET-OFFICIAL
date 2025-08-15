-- ui.lua : RagnarNet UI (adapté 7.2.x)
-- Exporte: ui.drawUI(username, isAdmin, w, h, version)
--          ui.showMessages(messages, uiHeight, blacklist, adminUser)

local ui = {}

-- Couleurs sûres (fallback si écran non couleur)
local HAS_COLOR = term.isColor and term.isColor()
local C_BG      = HAS_COLOR and colors.lightGray or colors.white
local C_TITLE   = HAS_COLOR and colors.blue      or colors.black
local C_TEXT    = HAS_COLOR and colors.white     or colors.black
local C_MUTE    = HAS_COLOR and colors.gray      or colors.black
local C_WARN    = HAS_COLOR and colors.orange    or colors.black
local C_BAD     = HAS_COLOR and colors.red       or colors.black

local function fill(x1,y1,x2,y2,c)
  paintutils.drawFilledBox(x1,y1,x2,y2,c)
end

local function titleBar(w, title)
  paintutils.drawLine(1, 1, w, 1, C_TITLE)
  term.setCursorPos(2,1)
  term.setTextColor(C_TEXT)
  term.write(title or "")
end

local function footBar(w, h, text)
  paintutils.drawLine(1, h-2, w, h-2, C_MUTE)
  term.setCursorPos(2, h-1)
  term.setTextColor(C_MUTE)
  term.write(text or "")
end

local function trunc(s, maxw)
  if #s <= maxw then return s end
  return s:sub(1, math.max(0, maxw-1)) .. "?"
end

-- Public: dessine l'UI statique (cadre, barres, bouton arrêter)
function ui.drawUI(username, isAdmin, w, h, version)
  term.setBackgroundColor(colors.black)
  term.clear()
  fill(1,1,w,h,C_BG)

  local head = " RagnarNet UI "
  if version then head = head .. "v"..tostring(version).." " end
  titleBar(w, head)

  -- bande inférieure (zone d'aide)
  local who = "Connecté en tant que " .. (username or "?") .. (isAdmin and " [ADMIN]" or "")
  footBar(w, h, who)

  -- bouton arrêt (click: y==1, x>=w-12)
  term.setCursorPos(math.max(1, w-12), 1)
  term.setTextColor(C_BAD)
  term.write("[ARRETER]")
end

-- Public: affiche la liste des messages dans la zone centrale
-- messages = { {id=1, from="u", text="...", admin=false}, ... }
function ui.showMessages(messages, uiHeight, blacklist, adminUser)
  local w, h = term.getSize()
  -- on nettoie la zone centrale (lignes 2..h-3)
  for y = 2, (h-3) do
    term.setCursorPos(2, y)
    term.clearLine()
  end

  local maxWidth = math.max(1, w - 4) -- marge à gauche/droite
  local start = math.max(1, #messages - uiHeight + 1)

  for i = start, #messages do
    local m = messages[i]
    local line = (i - start) + 2 -- commence sous la barre titre

    -- couleur par type
    if m and m.admin then
      term.setTextColor(C_WARN)
    elseif m and m.from and blacklist and blacklist[m.from] then
      term.setTextColor(C_BAD)
    else
      term.setTextColor(C_TEXT)
    end

    local id   = tostring(m.id or i)
    local from = tostring(m.from or "?")
    local txt  = tostring(m.text or "")

    local raw = "["..id.."] "..from..": "..txt
    local out = trunc(raw, maxWidth)

    term.setCursorPos(2, line)
    term.write(out)
  end
end

return ui