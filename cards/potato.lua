cards = cards or {}

local deactive_stream = love.mousepressed
  :filter(function(_, _, b) return b == 2 end)

local function create_target_stream(id, userid, pile, card)
  return combat_engine.input.target_select
    :takeUntil(deactive_stream)
    :filter(function(tid) return tid ~= userid end)
    :take(1)
    :map(function(targetid) return id, userid, pile, card, targetid end)
end

local function activate(id, userid)
  local activate_stream = combat_engine.state.card.selected
    :filter(function(cid) return cid == id end)

  activate_stream
    :flatMapLatest(function(id, userid, pile, card)
      return create_target_stream(id, userid, pile, card)
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
      :map(function(id)
        return draw_engine.screen_ui_draw
          :map(function() return id end)
      end),
    combat_engine.event.card.play
      :merge(deactive_stream)
      :map(function()
        return rx.Observable.never()
      end)
  ) :switch()
    :subscribe(function(id)
      local x = gamedata.spatial.x[id]
      local y = gamedata.spatial.y[id]
      gfx.setColor(0, 255, 80)
      love.graphics.print("Select Target", 800, 1080 * 0.25, 0, 4, 4)
    end)
  -- Display text "Select target"
end

function ui_run(gd, id)
  target_id = combat_engine.select_target(all_entities)
  local dmg = combat_engine.damage_calculation(user_id, target_id, base_dmg)
end

function cards.potato(gd, id, userid)
  cards.generic_init(gd, id)
  local str = ""
  str = str .. "Deal 1 damage.\n"
  gamedata.card.text[id] = str
  local atlas, anime = cards.get_gfx()
  gamedata.card.image[id] = function() return anime.potato end
  gamedata.card.activate[id] = activate
  gamedata.card.name[id] = "Potato"
  gamedata.card.cost[id] = 0
  activate(id, userid)
end
