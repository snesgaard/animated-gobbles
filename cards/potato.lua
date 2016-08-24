cards = cards or {}

local deactive_stream = love.mousepressed
  :filter(function(_, _, b) return b == 2 end)

local function create_target_stream(userid)
  return combat_engine.input.target_select
    :takeUntil(deactive_stream)
    :filter(function(tid) return tid ~= userid end)
    :take(1)
end

local function activate(id, userid)
  local activate_stream = combat_engine.state.selected_card
    :filter(function(cid) return cid == id end)

  activate_stream
    :flatMapLatest(function()
      return create_target_stream(userid)
    end)
    :map(function(tid)
      return id, userid, tid
    end)
    :subscribe(function(...) combat_engine.event.card.play:onNext(...) end)

  activate_stream
    :flatMapLatest(function()
      return deactive_stream:take(1)
    end)
    :map(function() return userid end)
    :subscribe(function(...)
      combat_engine.event.general.turn_start:onNext(...)
    end)

  rx.Observable.merge(
    activate_stream
      :map(function()
        return draw_engine.screen_ui_draw
      end),
    combat_engine.event.card.play
      :merge(deactive_stream)
      :map(function()
        return rx.Observable.never()
      end)
  ) :switch()
    :subscribe(function()
      love.graphics.print("Select Target", 100, 100, 0, 5, 5)
    end)
  -- Display text "Select target"
end

function cards.potato(gd, id, userid)
  cards.generic_init(gd, id)
  local str = ""
  str = str .. "Draw 1 card.\n"
  str = str .. "Gain 2 action.\n"
  str = str .. "Deal 1 damage.\n"
  str = str .. "\nAt the start of the next\nround, draw 1 card."
  gamedata.card.text[id] = str
  local atlas, anime = cards.get_gfx()
  gamedata.card.image[id] = function() return anime.potato end
  gamedata.card.activate[id] = activate
  gamedata.card.name[id] = "Potato"
  gamedata.card.cost[id] = 0
  activate(id, userid)
end
