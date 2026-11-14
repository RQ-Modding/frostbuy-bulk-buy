-- Frostbuy Bulk Buy. A BULK BUY tile in Frostbuy's rack window turns its list into ticks and the left
-- side into a cart: tick items from every rack, set how many of each, and buy the whole cart with one
-- question. An item the shop puts back on sale on every visit (most weapons and armor, the special
-- items that come back, Forbidden Talent in the third world) can be bought up to 99 times at once, and
-- each copy of a weapon or armor is a level up, as leaving and entering the shop makes it. Lua owns the
-- window; the loader gives the shop's own rules and prices (rq.shop.restocks, restock, next: 2.49.0).
-- API reference: https://rq-modding.github.io/rq-modding-docs/reference/

local ui = rq.uikit
local call = rq.ain.call

local SHOP = 6
local MAX_EACH = 99
local COIN = 10304 -- the footer's MONEY coin
local YELLOW = { 236, 222, 52 }
local RED = { 255, 90, 90 }
local CYAN = { 120, 230, 255 }
local CIRCLED = { "①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨" }
local BALLOON = "Buyin' in bulk, Boss?$Now yer talkin'!"

-- Where things go (1024 x 768): the tile in the free part of the window's right column, the cart
-- over Frostbuy's picture down to the footer, the party's cards dimmed up to the window's frame
-- (x 532), and the window's close button (the game keeps it).
local TILE = { x = 945, y = 488, w = 73, h = 76 }
local PX, PY, PW, PH = 8, 194, 410, 541
local HEAD, FOOT, LH, SHOWN, BAR_W = 36, 70, 62, 7, 20
local CX2 = PX + PW - 8 - BAR_W - 6 -- the rows' right edge, left of the scroll bar
local LY = PY + HEAD
local FRAME_X = 532
local CLOSE = { x = 988, y = 0, w = 36, h = 36 }
local PICKER = "bulk"

local S = {
  on = false,   -- bulk mode
  cart = {},    -- lines in the order ticked: { no, n, max, copies (rq.shop.next), ii (on sale) }
  cur = 1,      -- the current line
  top = 0,      -- the cart's scroll
  back = {},    -- items a mod's on_buy put back on sale at once (this visit)
  typed = false, -- the picker starts on the window's rack
  dirty = false,
  busy = false, -- BUY is running
  keys = {},
}

-- ---- The game ----

local function store_open()
  local ok, kind = pcall(rq.ain.global, "g_sStoreItem", "m_nStoreType")
  return ok and kind == 3
end

-- The rack the window shows (its item type: 21, 1, 11 or 17).
local function rack_type()
  local ok, t = pcall(rq.ain.global, "g_sStoreItem", "m_sList", "m_sList", "m_nItemType")
  if ok and math.type(t) == "integer" and t ~= 0 then return t end
  ok, t = pcall(rq.ain.global, "g_sStoreItem", "m_sLimitItem", "m_nItemType")
  return ok and math.type(t) == "integer" and t or 0
end

-- Frostbuy's balloon (T_ShopMessage@set); her own line back with Ｔアイテム屋／テキスト(0).
local function say(s)
  pcall(rq.ain.method, { "g_sShop", "m_sMessage" }, "T_ShopMessage@set", s)
end

local function say_default()
  local ok, s = pcall(call, "Ｔアイテム屋／テキスト", 0)
  if ok and type(s) == "string" then say(s) end
end

local function on_sale(no)
  local list = rq.item.find(no, { place = SHOP })
  return list[1]
end

local function commas(n)
  local s = tostring(n)
  while true do
    local t, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    s = t
    if k == 0 then return s end
  end
end

-- ---- The cart ----

local function line_of(no)
  for i, l in ipairs(S.cart) do
    if l.no == no then return l, i end
  end
end

-- One BUY takes up to 99 of an item the shop puts back after each, else 1.
local function limit(no)
  return (rq.shop.restocks(no) or S.back[no]) and MAX_EACH or 1
end

-- A line's copies and prices, from the shop as it is now.
local function refresh(l)
  local want = limit(l.no)
  l.copies = rq.shop.next(l.no, want)
  -- The shop's rules do not cover an item a mod puts back: its copies are the one on sale again.
  if S.back[l.no] and #l.copies == 1 then
    for k = 2, want do l.copies[k] = l.copies[1] end
  end
  l.max = #l.copies
  l.ii = l.copies[1] and l.copies[1].ii
  l.n = math.min(l.n, l.max)
end

local function refresh_all()
  local kept = {}
  for _, l in ipairs(S.cart) do
    refresh(l)
    if l.ii and l.n > 0 then kept[#kept + 1] = l end
  end
  S.cart = kept
  S.cur = math.min(math.max(S.cur, 1), math.max(#kept, 1))
  S.dirty = false
end

local function sum(l, n)
  local s = 0
  for k = 1, math.min(n or l.n, #l.copies) do s = s + (l.copies[k].price or 0) end
  return s
end

local function totals()
  local t, pieces = 0, 0
  for _, l in ipairs(S.cart) do
    t = t + sum(l)
    pieces = pieces + l.n
  end
  return t, pieces
end

-- How many copies of a line the money pays for, with the rest of the cart as it is.
local function affordable(l, money, total)
  local left = money - (total - sum(l))
  local k = 0
  while k < l.max and left >= l.copies[k + 1].price do
    left = left - l.copies[k + 1].price
    k = k + 1
  end
  return k
end

local function add(ii)
  local no = rq.item.number(ii)
  if not no or line_of(no) then return end
  local l = { no = no, n = 1 }
  refresh(l)
  if l.ii then
    S.cart[#S.cart + 1] = l
    S.cur = #S.cart
    if S.cur > S.top + SHOWN then S.top = S.cur - SHOWN end
  end
end

local function drop(no)
  local _, i = line_of(no)
  if i then table.remove(S.cart, i) end
end

local function reset()
  S.on, S.cart, S.cur, S.top, S.back, S.typed, S.dirty = false, {}, 1, 0, {}, false, false
end

-- The rows the picker lists now (its filters applied), as instances.
local function listed()
  local out = {}
  for _, r in ipairs(ui.state("picker:" .. PICKER).list or {}) do
    local ii = type(r) == "table" and r.ii or r
    if math.type(ii) == "integer" then out[#out + 1] = ii end
  end
  return out
end

-- ---- BUY ----

-- The whole cart, copy by copy: each bought with the game's purchase (rq.item.buy, which runs every
-- mod's rq.shop.on_buy), then the next copy put on sale as the next visit would (rq.shop.restock).
-- It stops at the first copy that does not buy.
local function buy_all()
  S.busy = true
  local total, pieces = totals()
  local text = ("Purchase %d item%s for %s Gold?"):format(pieces, pieces == 1 and "" or "s", commas(total))
  if not rq.ui.confirm(text) then
    S.busy = false
    return
  end
  local got, why = 0, nil
  for _, l in ipairs(S.cart) do
    l.bought = 0
    for _ = 1, l.n do
      local ii = on_sale(l.no)
      if not ii then
        why = "none left on sale"
        break
      end
      local price = rq.item.get(ii).price
      if not rq.item.buy(ii, { ask = false }) then
        why = price > rq.game.gold() and "not enough money" or "the shop refused one"
        break
      end
      got, l.bought = got + 1, l.bought + 1
      if on_sale(l.no) then
        -- A mod's on_buy put one back at once: this item restocks, the shop's rule or not.
        if not rq.shop.restocks(l.no) then S.back[l.no] = true end
      else
        rq.shop.restock(l.no)
      end
    end
    if why then break end
  end
  -- The game's list as the shop's own purchase leaves it (T_Shop::buyItem).
  pcall(call, "アイテム倉庫_再作成", -1, -1, -1, -1, -1)
  for _, l in ipairs(S.cart) do l.n = l.n - (l.bought or 0) end
  refresh_all()
  if got > 0 then rq.log(("Frostbuy Bulk Buy: bought %d of %d"):format(got, pieces)) end
  if got < pieces then
    rq.ui.notice(("Bought %d of %d: %s."):format(got, pieces, why or "the shop refused one"))
  end
  S.busy = false
end

-- ---- Drawing ----

local function text(x, y, s, o)
  o = o or {}
  rq.hud.text(x, y, s, { font = "game", face = o.face or 258, size = o.size or 18, r = o.r or 255,
    g = o.g or 255, b = o.b or 255, w = o.w, h = o.h, align = o.align, valign = o.valign,
    bold = o.bold, spacing = o.spacing or 0.95 })
end

local function width(s, size)
  return rq.hud.text_width(s, { font = "game", face = 258, size = size, spacing = 0.95 })
end

local coin_w, coin_h
-- Gold digits right-aligned at `right`, the footer's coin before them.
local function gold(n, right, y, tint)
  local x = ui.number(n, { x = right - 160, y = y, w = 160, font = "gold", align = "right", gap = 1, tint = tint })
  if coin_w == nil then coin_w, coin_h = rq.hud.cg_size(COIN) end
  if coin_w and coin_w > 0 then
    rq.hud.cg(x - 25, y + 2, COIN, { w = 20, h = math.floor(20 * coin_h / coin_w + 0.5) })
  end
end

local function panel(x, y, w, h)
  rq.hud.rect(x, y, w, h, 0, 0, 0, 205)
  local c = YELLOW
  rq.hud.rect(x, y, w, 2, c[1], c[2], c[3], 255)
  rq.hud.rect(x, y + h - 2, w, 2, c[1], c[2], c[3], 255)
  rq.hud.rect(x, y, 2, h, c[1], c[2], c[3], 255)
  rq.hud.rect(x + w - 2, y, 2, h, c[1], c[2], c[3], 255)
end

-- A name without the shop level's " ①" at its end (the levels are shown apart).
local function plain(name)
  for _, ch in ipairs(CIRCLED) do
    local at = name:find(" " .. ch, 1, true)
    if at then return name:sub(1, at - 1) end
  end
  return name
end

-- The copies' levels in what fits: "② ③ ④", or "② ③ … ⑨".
local function levels(l, room)
  local list = {}
  for k = 1, l.n do
    local p = l.copies[k] and l.copies[k].plus or 0
    list[k] = p > 0 and CIRCLED[p] or "－"
  end
  local s = table.concat(list, " ")
  if #list <= 3 or width(s, 20) <= room then return s end
  return list[1] .. " " .. list[2] .. " … " .. list[#list]
end

local function draw_line(l, i, y0, money, total)
  if i == S.cur then rq.hud.rect(PX + 6, y0 + 1, CX2 - PX - 6, LH - 2, YELLOW[1], YELLOW[2], YELLOW[3], 38) end
  if i > S.top + 1 then rq.hud.rect(PX + 6, y0, CX2 - PX - 6, 1, YELLOW[1], YELLOW[2], YELLOW[3], 90) end
  local row = l.copies[1]
  ui.item_icon(row, { x = PX + 12, y = y0 + 5, size = 52, id = "bulk-icon-" .. l.no, tip = false })
  text(PX + 74, y0 + 6, plain(row.name or ""), { face = 256, size = 18 })
  gold(sum(l), CX2 - 4, y0 + 4)
  -- + and MAX stop at what the money pays; a count already above it stays until changed.
  local top = math.max(l.n, math.min(l.max, affordable(l, money, total)))
  local n = ui.stepper(l.n, { id = "n-" .. l.no, x = PX + 74, y = y0 + 32, h = 24, ends = "max", min = 0,
    max = math.max(top, 1), disabled = S.busy })
  if n ~= l.n then
    l.n = n
    S.cur = i
  end
  local after = PX + 74 + 160
  if row.kind == 1 or row.kind == 11 then
    if l.max > 1 then
      text(after + 8, y0 + 32, levels(l, CX2 - after - 12), { size = 20, r = CYAN[1], g = CYAN[2], b = CYAN[3] })
    else
      text(after + 8, y0 + 36, "One at a time", { size = 14, r = 170, g = 170, b = 160 })
    end
  else
    text(after + 8, y0 + 36, l.max > 1 and "Restocks every visit" or "One at a time",
      { size = 14, r = 170, g = 170, b = 160 })
  end
  if rq.hud.clicked(PX + 6, y0, CX2 - PX - 6, LH) then S.cur = i end
end

local function draw_cart()
  rq.hud.rect(0, 588, FRAME_X, 152, 0, 0, 0, 200) -- the party's cards, dimmed
  panel(PX, PY, PW, PH)
  local money = rq.game.gold()
  local total, pieces = totals()
  text(PX + 14, PY + 7, "CART", { size = 24, r = YELLOW[1], g = YELLOW[2], b = YELLOW[3], bold = true })
  text(PX + 88, PY + 12, ("%d item%s, %d piece%s"):format(#S.cart, #S.cart == 1 and "" or "s", pieces,
    pieces == 1 and "" or "s"), { size = 16, r = 200, g = 200, b = 190 })
  if #S.cart == 0 then
    text(PX + 14, LY + 20, "Tick items in the list on the right.", { size = 18, r = 200, g = 200, b = 190 })
    text(PX + 14, LY + 46, "The filters on the right show the other racks.", { size = 16, r = 170, g = 170, b = 160 })
  end
  S.top = math.min(math.max(S.top, 0), math.max(#S.cart - SHOWN, 0))
  local gone
  for i = S.top + 1, math.min(S.top + SHOWN, #S.cart) do
    local l = S.cart[i]
    draw_line(l, i, LY + (i - S.top - 1) * LH, money, total)
    if l.n == 0 then gone = l.no end
  end
  if gone then drop(gone) end
  S.top = ui.scrollbar(S.top, #S.cart, SHOWN, { x = CX2 + 6, y = LY, h = SHOWN * LH, id = "bulk-cart-bar",
    wheel = { PX, LY, PW, SHOWN * LH } })

  -- The sums, BUY and EMPTY CART.
  total, pieces = totals()
  local FY = PY + PH - FOOT
  rq.hud.rect(PX + 6, FY, PW - 12, 2, YELLOW[1], YELLOW[2], YELLOW[3], 200)
  local short = total > money
  local red = short and RED or nil
  text(PX + 14, FY + 10, "TOTAL", { size = 20, r = YELLOW[1], g = YELLOW[2], b = YELLOW[3], bold = true })
  gold(total, PX + 250, FY + 8, red)
  text(PX + 14, FY + 41, short and "SHORT BY" or "LEFT", { size = 17,
    r = short and 255 or 200, g = short and 110 or 200, b = short and 110 or 190 })
  gold(short and total - money or money - total, PX + 250, FY + 38, red)
  if ui.button("BUY", { style = "short", x = PX + PW - 152, y = FY + 8, w = 138, id = "bulk-buy",
      disabled = short or pieces == 0 or S.busy }) then
    rq.spawn(buy_all)
  end
  if ui.button("EMPTY CART", { style = "short", x = PX + PW - 152, y = FY + 38, w = 138, id = "bulk-empty",
      disabled = #S.cart == 0 or S.busy }) then
    S.cart, S.cur, S.top = {}, 1, 0
  end
end

-- The shop panel's empty rows (CG 11405, painted at x 307), so the game's own list under the kit's
-- does not show where the kit's has no rows.
local EMPTY = { cg = 11405, src = { 231, 0, 381, 768 } }

local function draw_list()
  ui.draw(EMPTY, 538, 0, 381, 768)
  local marks = {}
  for _, l in ipairs(S.cart) do
    if l.ii then marks[l.ii] = l.n end
  end
  local picked = ui.item_picker({ x = 538, y = 0, id = PICKER, where = "shop", marks = marks })
  if picked and not S.busy then
    local no = rq.item.number(picked)
    if line_of(no) then drop(no) else add(picked) end
  end
end

local function enter()
  S.on = true
  if not S.typed then
    -- The picker starts on the window's rack.
    local st = ui.state("picker:" .. PICKER)
    st.filter = { type = rack_type(), sub = 0, class = 0, lock = 0, equip = 0 }
    ui.state("itemlist:" .. PICKER .. "-list").top = 0
    S.typed = true
  end
  refresh_all()
  say(BALLOON)
end

local function leave()
  S.on = false
  say_default()
end

-- A key's press, once.
local function pressed(name)
  local down = rq.input.key(rq.input.code(name))
  local was = S.keys[name]
  S.keys[name] = down
  return down and not was
end

local function frame()
  if S.on then
    if S.dirty and not S.busy then refresh_all() end
    -- The kit takes the mouse and the keys, but for the window's close button.
    local mx, my, _, right = rq.input.mouse()
    local on_close = mx >= CLOSE.x and my >= CLOSE.y and mx < CLOSE.x + CLOSE.w and my < CLOSE.y + CLOSE.h
    if not on_close then rq.hud.capture_mouse() end
    -- The game's own dialogs (BUY's question) need the keys.
    local asking = rq.ui.choosing()
    if not asking then rq.hud.block_keys() end
    draw_list()
    draw_cart()
    local back = (right and not S.right) or pressed("esc")
    S.right = right
    if back and not S.busy and not asking then leave() end
  end
  if ui.rack("BULK\nBUY", { x = TILE.x, y = TILE.y, w = TILE.w, h = TILE.h, id = "bulk-buy-tile",
      disabled = S.busy }) then
    if S.on then leave() else enter() end
  end
  if S.on then
    local col = { style = "short", x = TILE.x, w = TILE.w, disabled = S.busy }
    if ui.button("Select all", { style = col.style, x = col.x, y = 590, w = col.w, id = "bulk-all",
        disabled = col.disabled }) then
      for _, ii in ipairs(listed()) do add(ii) end
    end
    if ui.button("Clear", { style = col.style, x = col.x, y = 622, w = col.w, id = "bulk-none",
        disabled = col.disabled }) then
      for _, ii in ipairs(listed()) do drop(rq.item.number(ii)) end
    end
  end
end

rq.on_frame(function()
  if not store_open() then
    if S.on or #S.cart > 0 then reset() end
    return
  end
  -- The hub's look for the kit, and the theme put back for the other mods whatever happens.
  local old = ui.theme
  ui.use(ui.themes.hub)
  local ok, err = pcall(frame)
  ui.use(old)
  if not ok then error(err, 0) end
end)

-- A new visit refills the shop: the cart starts again. A purchase from the game's own list (a drag)
-- changes what is on sale.
rq.shop.on_stock(function() reset() end)
rq.shop.on_buy(function() if not S.busy then S.dirty = true end end)

rq.log("Frostbuy Bulk Buy loaded")

return {
  -- For tests and other mods: bulk mode and the cart.
  state = function() return S end,
  totals = totals,
}
