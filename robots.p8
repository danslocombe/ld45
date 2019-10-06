pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

-- written for ludum dare 45 "start with nothing"
-- inspired by the amazing ricochet robots
--
-- dan slocombe 2019

debug = true

function print_debug(s)
  if debug then
    printh(s)
  end
end

none=0
left=1
right=2
up=3
down=4

flags_border_none   = 0x00
flags_border_left   = 0x01
flags_border_right  = 0x02
flags_border_top    = 0x04
flags_border_bottom = 0x08
flags_border_all = bor(flags_border_left, bor(flags_border_right, bor(flags_border_top, flags_border_bottom)))

unlock_none = 0
unlock_robot = 1
unlock_tile = 2

robot_cols = {
  14,
  12,
  9,
  6,
}

unlock_pattern = {
  unlock_none,
  unlock_robot,
  unlock_none,
  unlock_none,

  unlock_tile,
  unlock_none,
  unlock_none,
  unlock_none,
  unlock_none,
  unlock_robot,
  unlock_none,
  unlock_none,
  unlock_none,
  unlock_none,

  unlock_tile,
  unlock_none,
  unlock_none,

  unlock_tile,
  unlock_none,
  unlock_none,
  unlock_none,
  unlock_none,
  unlock_robot,

}

-- tile chars:
-- l / r / t / b for single
-- 0 / 1 / 2 / 3 for corner peice rotated 90deg resp
tiles = {
[[
..........
.    r   .
.  3     .
.        .
. 0      .
.b     1 .
.        .
.     2  .
.   3   ..
..........
]],
[[
..........
.   r    .
. 0      .
.      2 .
.        .
.  3     .
.b      ..
.        .
.       ..
..........
]],
[[
..........
. r      .
.    1   .
. 2      .
.      3 .
.        .
.        .
.t  0    .
.       ..
..........
]],
[[
..........
. r      .
.    2   .
.        .
. 0      .
.        .
.b    1  .
.   3    .
.       ..
..........
]],
} 

function _init()
  t_menu = 0
  update_fn = update_menu
  draw_fn = draw_menu
end

function _update60()
  update_fn()
end

function _draw()
  draw_fn()
end

function update_menu()
  t_menu += 1
  if anykey_pressed() then
    t = 0
    stage = 0
    static_t = 4
    drawables = {}
    update_fn = update_help
    draw_fn = draw_help
    sfx(7)
  end
end

function draw_menu()
  cls(13)
  print("metal wombles", 40, 54, 7)
  print("play", 58, 68, 7)
  print("dan slocombe", 42, 112, 7)
  if flr(t_menu / 30) % 2 == 0 then
    spr(17, 48, 67)
  end
  local dir = t_menu / 100
  local r = 2
  local x = 80 + r*cos(dir)
  local y = 80 + r*sin(dir)
  local sx = 0
  if (flr(t_menu / 50) % 8) < 2 then
    sx = 3*8
  end
  sspr(sx, 4*8, 3*8, 2*8, x, y, 3*16, 2*16)
end

function update_help()
  t+=1
  if anykey_pressed() then
    if stage == 0 then
      static_t = 4
      sfx(7)
      stage = 1
    else
      start_game()
      return
    end
  end

  if stage == 1 then
    if t % 80 == 0 then
      local prev_selected = selected_rid
      selected_rid = 1 + ((selected_rid) % 2)
      add(drawables, create_select_anim(prev_selected, selected_rid, cur_state))
    end

    for i,o in pairs(drawables) do
      o.tick(o)
    end

  end
end

function draw_help()
  cls(13)
  if stage == 0 then
    print("guide the robots to\nhelp regrow the forest", 26, 64 - 16, 7)
    selected_rid = 1
    local rr = {x = 0, y = 0, id = 1}
    draw_robot(6, 10, 8, rr)
    spr(17, 60, 97 - 16)
    target_x = 0
    target_y = 0
    target_rid = 1
    draw_target(9, 10, 8)
  else
    print("press (x) to switch robots", 16, 60 - 16, 7)
    local rr = {x = 0, y = 0, id = 1}
    draw_robot(6, 8, 8, rr)
    local rr2 = {x = 3, y = 0, id = 2}
    cur_state = {robots = {rr, rr2}}
    draw_robot(6, 8, 8, rr2)
    for i,o in pairs(drawables) do
      o.draw(o, 6, 8, 8)
    end
    print("and (z) to rewind moves", 18, 84, 7)
  end

  if static_t > 0 then
    dump_noise(static_t / 4)
    static_t -= 1
  end
end

function show_reset()
  update_fn = update_reset
  draw_fn = draw_reset
  t_menu = 0
end

function update_reset()
  t_menu += 1
  if anykey_pressed() then
    start_game()
  end
end

function draw_reset()
  cls(13)
  print("planted " .. level .. " trees", 40, 54, 7)
  print("retry?", 58, 68, 7)
  if flr(t_menu / 30) % 2 == 0 then
    spr(17, 48, 67)
  end
  local dir = t_menu / 100
  local r = 2
  local x = 80 + r*cos(dir)
  local y = 80 + r*sin(dir)
  local sx = 0
  if (flr(t_menu / 50) % 8) < 2 then
    sx = 3*8
  end
  sspr(sx, 4*8, 3*8, 2*8, x, y, 3*16, 2*16)
end

function start_game()
  reset()
  load_tile(0, 0, tiles[1 + flr(rnd(#tiles))])
  cur_state = {}
  cur_state = {
    t = 0,
    robots = {
      create_robot(2, 2, 1, robot_cols[1]),
    },
  }
  local target_robot = 1 -- + flr(rnd(3))
  generate_target(target_robot)

  update_fn = update_game
  draw_fn = draw_game
end

function reset()
  print_debug("resetting..")
  grid = {}
  drawables = {}
  drawables_bg = {}
  drawables_perm = {}
  cur_state = {}

  history = {}
  actions = {}

  target_x = 1
  target_y = 1
  target_rid = 1
  level = 0
  shake_t = 0
  shake_t_max = 4
  animating = false
  should_gotonext = false
  rewind_t = 0
  rewind_t_max = 6

  draw_scale = 8
  draw_xoffset = 3
  draw_yoffset = 3
  target_draw_scale = 8
  target_draw_xoffset = 3
  target_draw_yoffset = 3

  bgsize_x = 10
  bgsize_y = 10

  turns_left_max = 16
  turns_left = turns_left_max
  turns_left_t_max = 68
  turns_left_t = turns_left_t_max

  selected_rid = 1
  t=0

  tile_count = 1
end 

function update_game()
  tick_vars()

  for i,o in pairs(drawables) do
    -- pass in "this" object to prevent self references in closures, gc issues
    o.tick(o)
  end
  for i,o in pairs(drawables_bg) do
    o.tick(o)
  end
  for i,o in pairs(drawables_perm) do
    o.tick(o)
  end

  if animating and animation_obj != nil then
    animation_obj.xvel += animation_obj.xaccel
    animation_obj.yvel += animation_obj.yaccel
    animation_obj.x += animation_obj.xvel
    animation_obj.y += animation_obj.yvel
    local d = animation_obj.dir

    if d == down and animation_obj.y > animation_obj.new.y then
      animating = false
    elseif d == up and animation_obj.y < animation_obj.new.y then
      animating = false
    elseif d == right and animation_obj.x > animation_obj.new.x then
      animating = false
    elseif d == left and animation_obj.x < animation_obj.new.x then
      animating = false
    end

    --if rnd(1) < 0.5 then
      --create_part(animation_obj.x, animation_obj.y)
    --end

    if not animating then
      sfx(2)
      shake_t = shake_t_max / 3
    end
  else
    if should_gotonext then
      should_gotonext = false
      next_level()

      local end_robot = get_robot(selected_rid, cur_state)
      for i = 0,8 do
        local dir = rnd(1)
        local r = 0.05 + rnd(1)
        local xx = end_robot.x + r * cos(dir)
        local yy = end_robot.y + r * sin(dir)
        create_part(xx, yy)
      end
      create_flower(end_robot.x, end_robot.y)
    else
      update_player()
    end
  end
end

function tick_vars()
  t += 1

  if rewind_t > 0 then
    rewind_t -= 1
  end

  draw_scale = ease_epsilon(draw_scale, target_draw_scale, 10)
  draw_xoffset = ease_epsilon(draw_xoffset, target_draw_xoffset, 10)
  draw_yoffset = ease_epsilon(draw_yoffset, target_draw_yoffset, 10)

  if turns_left_t > 0 then
    turns_left_t -= 1
  else
    turns_left_t = turns_left_t_max
    turns_left -= 1

    --local tt = turns_left - cur_state.t
    local tt = turns_left
    if tt <= 0 then
      show_reset()
      return
    elseif tt <= 5 then
      sfx(6)
    elseif turns_left < 8 then
      sfx(5)
    elseif turns_left < 12 then
      sfx(7)
    end
  end
end

function update_player()
  local ndir = none
  if btnp(0) then
    ndir = left
  elseif btnp(1) then
    ndir = right
  elseif btnp(2) then
    ndir = up
  elseif btnp(3) then
    ndir = down
  elseif btnp(4) then
    if #history > 0 then
      cur_state = history[#history]
      del(history, cur_state)
      local action = actions[#actions]
      del(actions, action)
      rewind_t = rewind_t_max
      sfx(4)
    end
  elseif btnp(5) then
    local prev_selected = selected_rid
    selected_rid = 1 + ((selected_rid) % #cur_state.robots)
    add(drawables, create_select_anim(prev_selected, selected_rid, cur_state))
    sfx(3)
  end

  --local tt = turns_left - cur_state.t
  local tt = turns_left -- cur_state.t
  if ndir != none and rewind_t <= 0 and tt > 0 then
    -- setup next move --

    -- alert on low numbers of moves left
    if tt <= 5 then
      sfx(6)
    else
      sfx(1)
    end

    local old_state = cur_state
    cur_state = move_robot(ndir, selected_rid, cur_state)

    local old_robot = {}
    for i,r in pairs(old_state.robots) do
      if r.id == selected_rid then
        old_robot = r
        break
      end
    end
    local new_robot = {}
    for i,r in pairs(cur_state.robots) do
      if r.id == selected_rid then
        new_robot = r
        break
      end
    end

    local move_vec = vec_from_dir(ndir)
    local accel = 0.13
    animation_obj = {
      rid = selected_rid,
      old = old_robot,
      new = new_robot,
      dir = ndir,
      x = old_robot.x,
      y = old_robot.y,
      xvel = 0,
      yvel = 0,
      xaccel = accel * move_vec.x,
      yaccel = accel * move_vec.y,
    }

    animating = true

    -- todo only add to history if states are different
    add(history, old_state)
    add(actions, {rid = selected_rid, dir = ndir})

    -- check goal
    if new_robot.id == target_rid then
      if new_robot.x == target_x and new_robot.y == target_y then

        -- delay next level until animation finishes
        should_gotonext = true
      end
    end
  end
end

function next_level()
  sfx(0)
  level += 1
  local unlock = unlock_pattern[level]
  if unlock == unlock_robot then
    -- add new robot
    local rx = flr(rnd(bgsize_x))
    local ry = flr(rnd(bgsize_y))
    local rid = #cur_state.robots + 1
    while place_rid(rx, ry, cur_state) > 0 or enclosed_grid(rx, ry) do
      rx = flr(rnd(bgsize_x))
      ry = flr(rnd(bgsize_y))
    end
    add(cur_state.robots, create_robot(rx, ry, rid, robot_cols[rid]))
  elseif unlock == unlock_tile then
    -- extend map
    add_tile()
  end
  local target_robot = 1 + flr(rnd(#cur_state.robots))
  generate_target(target_robot)
  history = {}
  actions = {}
  cur_state.t = 0

  turns_left = turns_left_max
  turns_left_t = turns_left_t_max

  shake_t = shake_t_max
end

function add_tile()
  if tile_count == 1 then
    load_tile(9, 0, tiles[1 + flr(rnd(#tiles))])
    -- hacky - remove border
    for i,o in pairs(grid) do
      if o.x == 9 and o.y > 0 and o.y < 9 then
        del(grid, o)
      end
    end
    target_draw_xoffset = 1
    target_draw_yoffset = 4
    bgsize_x = 19
    target_draw_scale = 6
  elseif tile_count == 2 then
    load_tile(0, 9, tiles[1 + flr(rnd(#tiles))])
    local new_grid = {}
    for i,o in pairs(grid) do
      if (o.y != 9) or (o.x <= 0) or (o.x >= 9) then
        add(new_grid, o)
      end
    end
    grid = new_grid

    target_draw_xoffset = 3
    target_draw_yoffset = 3
    target_draw_scale = 5
    bgsize_y = 19

  elseif tile_count == 3 then
    load_tile(9, 9, tiles[1 + flr(rnd(#tiles))])
    local new_grid = {}
    for i,o in pairs(grid) do
      if ((o.y != 9) or (o.x <= 9) or (o.x >= 18)) and ((o.x != 9) or (o.y <= 9) or (o.y >= 18)) then
        add(new_grid, o)
      end
    end
    grid = new_grid
  end

  tile_count += 1
end

function create_robot(x, y, id, col)
  create_face(id, 80, 80)
  sfx(7 + id)
  local prev_selected = selected_rid
  selected_rid = id
  if prev_selected != nil and id > 1 then
    add(drawables, create_select_anim(prev_selected, id, cur_state))
  end
  return {x = x, y = y, id = id, col = col}
end

function clone_robot(r)
  -- robot should be immutable, clone on changes
  return {x = r.x, y = r.y, id = r.id, col = r.col}
end

function load_tile(xoffset, yoffset, tile)
  print_debug("loading tile at " .. xoffset .. " " .. yoffset)
  local px = 0
  local py = 0

  lines = split_lines(tile)
  for y,l in pairs(lines) do
    for x=1,#l do
      local ss = sub(l,x,x)
      local borders = flags_border_none

      if ss == "." then
        borders = flags_border_all
      elseif ss == "l" then
        borders = flags_border_left
      elseif ss == "r" then
        borders = flags_border_right
      elseif ss == "t" then
        borders = flags_border_top
      elseif ss == "b" then
        borders = flags_border_bottom
      elseif ss == "0" then
        borders = bor(flags_borders_bottom, flags_border_left)
      elseif ss == "1" then
        borders = bor(flags_border_top, flags_border_left)
      elseif ss == "2" then
        borders = bor(flags_border_top, flags_border_right)
      elseif ss == "3" then
        borders = bor(flags_border_right, flags_border_bottom)
      end

      if (borders != flags_border_none) then
        local xx = x + xoffset - 1
        local yy = y + yoffset - 1
        local cell = {x = xx, y = yy, borders = borders}
        add(grid, cell)
      end
    end
  end
end

function generate_target(target_robot)
  local best = generate_target_candidate(target_robot)
  for i = 0,8 do
    local c = generate_target_candidate(target_robot)
    if c.score > best.score then
      best = c
    end
  end

  target_x = best.x
  target_y = best.y
  target_rid = best.rid
end

function pick_robot(target_robot, robot_count)
  if rnd(1) < 0.75 then
    return target_robot
  else
    return 1 + flr(rnd(robot_count))
  end
end

function generate_target_candidate(target_robot)
  local state = cur_state
  local robot_count = #cur_state.robots
  local pointwise_cols = {}
  local hashes = {}
  local inputs = {}
  local gen_history = {}
  add(gen_history, state)
  add(hashes, hash_state(state))

  local last_id = -1
  local last_dir = none

  local movecount = flr(1.5 * sqrt(4 * #cur_state.robots + 2*level)) + 1

  for i = 0, movecount do
    local col_info = {rid = 0}
    local id = 0
    local dir = none

    timeout = 4
    -- avoid picking something that would create prev position
    while timeout >= 0 do
      timeout -= 1
      id = pick_robot(target_robot, robot_count)

      -- moving idempotent so don't pick same as last time
      -- also don't invert last move
      while dir == none or 
        (id == last_id and (dir == last_dir or dir == invert_dir(last_dir))) do
        dir = 1 + flr(rnd(4))
      end

      last_dir = dir
      last_id = id

      state = move_robot(dir, id, state, col_info)

      local state_eq = true
      -- ugly code :/
      for i,s in pairs(gen_history) do
        local state_eq = true
        for j = 1,robot_count do
          local r0 = s.robots[j]
          local r1 = state.robots[j]

          different = r0.x != r1.x or r0.y != r1.y

          if different then
            --print_debug("is different")
            state_eq = false
            break
          end
        end

        if state_eq then
          --print_debug("state same")
          break
        end
      end

      if not state_eq then
        break
      end
    end

    if col_info.rid > 0 then
      local rid_min = min(id, col_info.rid)
      local rid_max = max(id, col_info.rid)
      local pointwise = get_or_add(
        pointwise_cols,
        {rid_min = rid_min, rid_max = rid_max, count = 0},
        function(x, y) return x.rid_min == y.rid_min and x.rid_max == y.rid_max end)

      pointwise.count += 1
    end

    add(inputs, {rid = id, dir = dir})
    add(hashes, hash_state(state))
  end

  local tr = get_robot(target_robot, state)

  local final_borders = flags_border_none
  for i,cell in pairs(grid) do
    if cell.x == tr.x and cell.y == tr.y then
      final_borders = bor(final_borders, cell.borders)
    elseif cell.x == tr.x and cell.y == tr.y - 1 then
      -- cell above
      final_borders = bor(final_borders, band(cell.borders, flags_border_bottom))
    elseif cell.x == tr.x and cell.y == tr.y + 1 then
      -- cell below
      final_borders = bor(final_borders, band(cell.borders, flags_border_top))
    elseif cell.x == tr.x - 1 and cell.y == tr.y then
      -- cell left
      final_borders = bor(final_borders, band(cell.borders, flags_border_right))
    elseif cell.x == tr.x + 1 and cell.y == tr.y then
      -- cell right
      final_borders = bor(final_borders, band(cell.borders, flags_border_left))
    end
  end

  local pos_deltas = {}
  for i,r in pairs(state.robots) do
    local init = get_robot(r.id, cur_state)
    local delta = {
      id = r.id,
      dx = r.x - init.x,
      dy = r.y - init.y,
    }
    add(pos_deltas, delta)
  end

  local score = score_candidate(
    pointwise_cols,
    pos_deltas,
    final_borders,
    inputs,
    hashes,
    robot_count,
    target_robot)

  return {
    x = tr.x,
    y = tr.y,
    rid = target_robot,
    score = score,
  }
end

function score_candidate(pointwise_cols, pos_deltas, final_borders, inputs, hashes, robot_count, moving_robot)
  local from_moves = 0
  local from_cols = 0
  local from_borders = 0
  local from_deltas = 0
  local from_hashes = 0

  print_debug("\n-- scoring candidate --")
  print_debug("inputs " .. #inputs)

  per_robot_moves = {}
  for i = 1,robot_count do
    per_robot_moves[i] = 0
  end

  for i,x in pairs(inputs) do
    print_debug(x.rid .. " " .. tostring_dir(x.dir))
    per_robot_moves[x.rid] += 1
  end

  for i = 1,robot_count do
    local mult = 1
    if i == moving_robot then
      mult = 3
    end
    from_moves += mult * sqrt(per_robot_moves[i])
  end

  print_debug("pointwise_cols " .. #pointwise_cols)
  for i,p in pairs(pointwise_cols) do
    print_debug(p.rid_min .. " " .. p.rid_max .. " " .. p.count)
    local mult = 1
    if p.rid_min == moving_robot or p.rid_max == moving_robot then
      mult = 3
    end
    from_cols += mult * p.count * (sqr(per_robot_moves[p.rid_min] + 1) + sqr(per_robot_moves[p.rid_max] + 1))
  end

  for i = 0,3 do
    local b = band(shr(final_borders, i), 0x01)
    print_debug("i = " .. i .. " borders = " .. b)
    from_borders += b
  end

  for i,d in pairs(pos_deltas) do
    -- maybe manhattan dist
    local dist2 = sqr(d.dx) + sqr(d.dy)
    local mult = 1
    if d.id == moving_robot then
      mult = 3
    end
    from_deltas += mult * dist2 
  end

  local c_moves = 1
  local c_cols = 0.2
  local c_borders = 2
  local c_deltas = 0.4
  local c_hashes = 4

  from_moves *= c_moves
  from_cols *= c_moves
  from_borders *= c_borders
  from_deltas *= c_deltas
  from_hashes *= c_hashes

  print_debug("score from moves " .. from_moves)
  print_debug("score from cols " .. from_cols)
  print_debug("score from borders " .. from_borders)
  print_debug("score from deltas " .. from_deltas)
  print_debug("score from hashes " .. from_hashes)

  local score = from_moves + from_cols + from_borders + from_deltas + from_hashes
  print_debug("total score: " .. score)

  return score
end

function hash_state(state)
  return 0
end

function place_rid(x, y, state, colobj)
  for i,r in pairs(state.robots) do
    if r.x == x and r.y == y then
      return r.id
    end
  end

  return 0
end

function enclosed_grid(x, y)
  for i,cell in pairs(grid) do
    if cell.x == x and cell.y == y then
      return band(cell.borders, flags_border_all) == flags_border_all
    end
  end

  return false
end

function should_stop(x, y, dir)
  for i,cell in pairs(grid) do
    if cell.x == x and cell.y == y then
      if (dir == up and (band(cell.borders, flags_border_top) != 0))
        or (dir == left and (band(cell.borders, flags_border_left) != 0))
        or (dir == right and (band(cell.borders, flags_border_right) != 0))
        or (dir == down and (band(cell.borders, flags_border_bottom) != 0)) then
        return true
      end
    elseif (cell.x == x and cell.y == y+1) then
      -- above
      if dir == down and band(cell.borders, flags_border_top) != 0 then
        return true
      end
    elseif (cell.x == x and cell.y == y-1) then
      -- below
      if dir == up and band(cell.borders, flags_border_bottom) != 0 then
        return true
      end
    elseif (cell.x == x-1 and cell.y == y) then
      -- to right
      if dir == left and band(cell.borders, flags_border_right) != 0 then
        return true
      end
    elseif (cell.x == x+1 and cell.y == y) then
      -- to left
      if dir == right and band(cell.borders, flags_border_left) != 0 then
        return true
      end
    end
  end

  return false
end

function move_robot(dir, id, state, col_info)
  local player = state.robots[id]
  for i,r in pairs(state.robots) do
    if r.id == id then
      new_robot = clone_robot(r)
      break
    end
  end

  local move_vec = vec_from_dir(dir)
  while true do
    if should_stop(new_robot.x, new_robot.y, dir) then
      break
    end

    local col_rid = place_rid(new_robot.x + move_vec.x, new_robot.y + move_vec.y, state)
    if col_rid > 0 then
      if col_info != nil then
        col_info.rid = col_rid
      end
      break
    end

    new_robot.x = new_robot.x + move_vec.x
    new_robot.y = new_robot.y + move_vec.y
  end

  local new_state = {
    t = state.t + 1,
    robots = {
      new_robot,
    },
  }

  -- copy over non-moving robots into new state
  -- as robots are immutable we can reference existing objs
  for i,r in pairs(state.robots) do
    if r.id != id then
      add(new_state.robots, r)
    end
  end

  return new_state
end

-- drawing --

function draw_game()
  cls(13)

  local scale = draw_scale
  local x0 = draw_xoffset
  local y0 = draw_yoffset

  if shake_t > 0 then
    shake_t -= 1
    local d = rnd(1.0)
    local r = 0.5 * shake_t / shake_t_max
    x0 += r * cos(d)
    y0 += r * sin(d)
  end

  for i,o in pairs(drawables_perm) do
    o.draw(o, x0, y0, scale)
  end

  local bgcol = 2
  --if (t % 64 < 32) then
    --fillp(0b0101101001011010.1)
  --end
  for i = 0,bgsize_x do
    line((x0 + i) * scale, y0 * scale, (x0 + i) * scale, (y0 + bgsize_y) * scale, bgcol)
  end
  for i = 0,bgsize_y do
    line(x0 * scale, (y0 + i) * scale, (x0 + bgsize_x) * scale, (y0 + i) * scale, bgcol)
  end
  fillp()

  draw_target(x0, y0, scale)

  for i,cell in pairs(grid) do
    draw_cell(x0, y0, scale, cell)
  end

  for i,o in pairs(drawables_bg) do
    o.draw(o, x0, y0, scale)
  end

  for i,r in pairs(cur_state.robots) do
    draw_robot(x0, y0, scale, r)
  end

  for i,o in pairs(drawables) do
    o.draw(o, x0, y0, scale)
  end

  local max_actions = 12
  local start = max(1, #actions - max_actions)
  for i=start,#actions do
    local action = actions[i]
    local s = 15 + action.dir
    pal(7, robot_cols[action.rid])
    spr(s, 115, 12 +  8*(i-start))
    pal()
  end

  if shake_t > 0 then
    dump_noise(shake_t / shake_t_max)
  end

  if should_gotonext then
    dump_noise(1)
    print("recomputing", 50, 64, 7)
  end

  if rewind_t > 0 then
    dump_rewind_noise()
  end

  --print(turns_left - cur_state.t, 60, 100, 7)
  local xx = 60
  local yy = 110
  --local n = turns_left - cur_state.t
  local n = turns_left
  pal(7, 4)
  draw_big_num(n, 60, 10)
  pal(7, 8)
  draw_big_num(n, 60, 9)
  pal()
  draw_big_num(level, 60, 110)
end

function draw_big_num(n, x, y)
  local xx = x
  while n >= 10 do
    local displ = n % 10
    spr(displ, xx, y)
    n = n / 10
    xx -= 8
  end
  spr(n, xx, y)
end

function draw_robot(xoffset, yoffset, scale, r)
  local rx = r.x
  local ry = r.y

  if animating and r.id == animation_obj.rid then
    rx = animation_obj.x
    ry = animation_obj.y
  end

  local x0 = (rx + xoffset + 0.25) * scale
  local y0 = (ry + yoffset + 0.25) * scale
  local x1 = (rx + xoffset + 0.75) * scale
  local y1 = (ry + yoffset + 0.75) * scale

  if selected_rid == r.id then
    local k = 2
    local c = 0.5
    if animating then
      y0 += k + c
    else
      y0 += k * sqr(abs(sin(t / 300), 2)) + c
    end
  end

  rectfill(x0, y0 - 1, x1, y1, 2)

  if selected_rid != r.id then
    fillp(0b0101101001011010.1)
  end
  rectfill(x0, y0 - 1, x1, y1 - 1, robot_cols[r.id])
  fillp()
end

function draw_target(xoffset, yoffset, scale)
  local x0 = (target_x + xoffset + 0.13) * scale
  local y0 = (target_y + yoffset + 0.13) * scale
  local x1 = (target_x + xoffset + 0.96) * scale
  local y1 = (target_y + yoffset + 0.96) * scale

  rectfill(x0, y0, x1, y1, 7)

  -- lookup color of target
  local col = robot_cols[target_rid]

  local shift = 2 * (flr(t / 18) % 4)
  local pat = 0b0110110110110110
  fillp(flr(lshr(pat,shift)))
    rectfill(x0, y0, x1, y1, bor(0xd0, col))
  fillp()
end

function draw_cell(xoffset, yoffset, scale, cell)
  local col = 15
  local b = cell.borders
  if band(b, flags_border_left) != 0 then
    local x0 = (cell.x + xoffset) * scale
    local y0 = (cell.y + yoffset) * scale
    local y = (cell.y + yoffset + 1) * scale - 1
    line(x0, y0, x0, y, col)
  end
  if band(b, flags_border_right) != 0 then
    local x0 = (cell.x + xoffset) * scale + (scale - 1)
    local y0 = (cell.y + yoffset) * scale
    local y = (cell.y + yoffset + 1) * scale - 1
    line(x0, y0, x0, y, col)
  end
  if band(b, flags_border_top) != 0 then
    local x0 = (cell.x + xoffset) * scale
    local y0 = (cell.y + yoffset) * scale
    local x = (cell.x + xoffset + 1) * scale - 1
    line(x0, y0, x, y0, col)
  end
  if band(b, flags_border_bottom) != 0 then
    local x0 = (cell.x + xoffset) * scale
    local y0 = (cell.y + yoffset) * scale + (scale - 1)
    local x = (cell.x + xoffset + 1) * scale - 1
    line(x0, y0, x, y0, col)
  end
end

function dump_noise(mag)
  local screen_start = 0x6000
  local screen_size = 8000
  for i=1,mag * 30 do
    local len = 50 + rnd(100)
    local pos = rnd(screen_size) + screen_start
    len = min(len, screen_start + screen_size - pos)
    memset(pos, rnd(64), len)
  end
end

function dump_rewind_noise()
  local screen_start = 0x6000
  local screen_size = 8000
  local bar_size = 1000
  local bar_start_frac = t / 100 % 1
  local top_start = screen_start + screen_size * bar_start_frac
  local top_end = top_start + bar_size
  for i=1,10 do
    local len = 50 + rnd(100)
    local pos = rnd(bar_size) + top_start
    len = min(len, screen_start + screen_size - pos)
    memset(pos, 6001.44444, len)
  end
end

-- other --

function create_flower(x, y)
  local obj = {
    t = 0,
  }

  local bloom = 20

  obj.tick = function(o)
    if o.t < bloom then
      o.t += 1
    end
  end

  local frame = 48 + flr(rnd(5))

  obj.draw = function(o, xoffset, yoffset, scale)
    spr(frame, (x + xoffset) * scale, (y + yoffset) * scale)
  end

  add(drawables_perm, obj)
end

function create_part(x, y)
  local obj = {
    frame = 0,
  }

  local t = 10
  local k = 6 + rnd(2)

  obj.tick = function(o)
    o.frame += 1

    if (o.frame > t * k) then
      del(drawables_bg, o)
    end
  end

  obj.draw = function(o, xoffset, yoffset, scale)
    local f = flr(o.frame / k)
    spr(32 + f, (x + xoffset) * scale, (y + yoffset) * scale)
  end

  add(drawables_bg, obj)
end

function create_face(id, x, y)
  local obj = {
    t = 0,
  }

  local k0 = 35
  local k = 90

  obj.tick = function(o)
    o.t += 1
    if (o.t > k) then
      del(drawables, o)
    end
  end

  obj.draw = function(o, xoffset, yoffset, scale)
    local xx = x
    local yy = y
    local sx = 0
    local sy = 4*8

    if id == 2 or id == 4 then
      sx = 6 * 8
    end

    if id > 2 then
      sy += 2*8 
    end

    if o.t > k0 then
      sx += 3*8
    end
    sspr(sx, sy, 3*8, 2*8, x, y, 3*16, 2*16)
  end

  add(drawables, obj)
end

function create_select_anim(start_rid, end_rid)
  -- ok to use cur_state as we are just creating an animation
  -- that doesnt effect state

  local start = get_robot(start_rid, cur_state)

  local obj = {
    state = 0,
    t = 0,
    x = start.x,
    y = start.y,
  }

  obj.tick = function(o)
    local scale = 4
    local target = get_robot_anim_pos(end_rid, cur_state)

    if target == nil then
      del(drawables, o)
      return
    end

    if o.state == 0 then
      scale = 2
      if o.t > 5 then
        o.state = 1
        local start = get_robot_anim_pos(start_rid, cur_state)
        o.x = start.x
        o.y = start.y
      end
    else 
      if o.t > 20 then
        del(drawables, o)
        return
      end
    end

    o.x = (o.x * (scale - 1) + target.x) / scale
    o.y = (o.y * (scale - 1) + target.y) / scale

    o.t += 1
  end

  obj.draw = function(o, xoffset, yoffset, scale)
    local col = 0
    local other = {}

    if cur_state == nil then
      return
    end

    if o.state == 0 then
      col = robot_cols[start_rid]
      other = get_robot_anim_pos(start_rid, cur_state)
    else
      col = robot_cols[end_rid]
      other = get_robot_anim_pos(end_rid, cur_state)
    end

    if other != nil then
      local this_x = (xoffset + o.x + 0.5) * scale
      local this_y = (yoffset + o.y + 0.5) * scale
      local other_x = (xoffset + other.x + 0.5) * scale
      local other_y = (yoffset + other.y + 0.5) * scale

      line(this_x, this_y, other_x, other_y, col)
    end
  end

  return obj
end

-- utils -- 

function split_lines(s)
  local start = 1
  local ret = {}
  for i = 1,#s do
    if sub(s, i,i) == "\n" then
      local ss = sub(s, start, i - 1) 
      if #ss > 0 then
        add(ret, ss)
      end
      start = i + 1
    end
  end

  -- final line
  local ss = sub(s, start, -1) 
  if #ss > 0 and ss ~= "\n" then
    add(ret, ss)
  end

  return ret
end

function vec_from_dir(dir)
  local mx = 0
  local my = 0
  if dir == left then
    mx = -1
  elseif dir == right then
    mx = 1
  elseif dir == down then
    my = 1
  elseif dir == up then
    my = -1
  end

  return {x = mx, y = my}
end

function get_robot_anim_pos(rid, state)
  if not animating or rid != animation_obj.rid then 
    return get_robot(rid, state)
  end

  return animation_obj
end

function get_robot(rid, state)
  for i,r in pairs(state.robots) do
    if r.id == rid then
      return r
    end
  end

  print_debug("could not find: " .. rid)
  return nil
end

epsilon = 0.1
function ease_epsilon(old, new, k)
  if (abs(new - old) < epsilon) then
    return new
  end

  return (old * (k - 1) + new) / k
end

function sqr(x) 
  return x * x
end

function get_or_add(t, v, cmp)
  for i,x in pairs(t) do
    if cmp(x, v) then
      return x
    end
  end

  add(t, v)
  return v
end

  -- could probably do something nicer for below two
function tostring_dir(d)
  if d == none then
    return "none" 
  elseif d == left then
    return "left"
  elseif d == right then
    return "right"
  elseif d == up then
    return "up"
  elseif d == down then
    return "down"
  end
end

function invert_dir(d)
  if d == none then
    return none
  elseif d == left then
    return right
  elseif d == right then
    return left
  elseif d == up then
    return down
  elseif d == down then
    return up
  end
end

function anykey_pressed()
  return btnp(0) or btnp(1) or btnp(2) or btnp(3) or btnp(4) or btnp(5)
end

__gfx__
00777700000070000007700000077700000770000007770000077000007777000007700000777700000000000000000000000000000000000000000000000000
00700700000770000070070000000700007070000007000000700000000007000070070000700700000000000000000000000000000000000000000000000000
00700700000070000000070000000700007070000007000000700000000070000070070000700700000000000000000000000000000000000000000000000000
00700700000070000000700000077700007070000007770000777000000070000007700000777700000000000000000000000000000000000000000000000000
00700700000070000007700000000700007777000000070000700700000700000070070000000700000000000000000000000000000000000000000000000000
00700700000070000070000000000700000070000000070000700700000700000070070000000700000000000000000000000000000000000000000000000000
00700700000070000070000000000700000070000000070000700700007000000070070000000700000000000000000000000000000000000000000000000000
00777700000777000077770000077700000070000007770000077000007000000007700000000700000000000000000000000000000000000000000000000000
00000000000000000000700000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700000000007000007770000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07700000000007700077777000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77777777077777770000700000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07700000000007700000700000777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700000000007000000700000077700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000700000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000040000040000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000
00000000000000000000040000040400000040000000340000000300003303000000030000000000000000000000000000000000000000000000000000000000
00000000000040000040400000004400000440000003300000033300000333000000000000000000000000000000000000000000000000000000000000000000
00004000000040000040400000444000004304000043300000003000000303000003000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000044000000430000003300000003000000330000300300000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00090000000c000000a9a0000001000000f4f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
009a900000cac00000989000001c1000004940000000000000000300000000000000000000000000000000000000000000000000000000000000000000000000
00090000000c000000a9a0000001000000f4f0000000000000033300000000000000000000000000000000000000000000000000000000000000000000000000
00030000000330000033000000033000000330000000000000003000000000000000000000000000000000000000000000000000000000000000000000000000
00030000000300000003000000030000003300000000000000003000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000e2000000000000000000000000e000000000000000000000c2000000000000000000000000c0000000000000000000000000000000000000
00000000000000000e200000000000000000000000e2000000000000000000000c200000000000000000000000c2000000000000000000000000000000000000
00000000000000000e20000000000000000000000e20000000000000000000000c20000000000000000000000c20000000000000000000000000000000000000
00000000000000000e20000000000000000000000e20000000000000000000000c20000000000000000000000c20000000000000000000000000000000000000
00000000000000000e20000000000000000000000e20000000000000000000000c20000000000000000000000c20000000000000000000000000000000000000
00000eeeeeeeeeeeeee0000000000eeeeeeeeeeeeee0000000000cccccccccccccc0000000000cccccccccccccc0000000000000000000000000000000000000
0000eeeeeeeeeeeeeeee00000000eeeeeeeeeeeeeeee000000000c2222cccc2222cc000000000c2222cccc2222cc000000000000000000000000000000000000
0000eee2eeeeeeee2eee00000000eee2eeeeeeee2eee0000000002dddd2cc2dddd2c0000000002dddd2cc2dddd2c000000000000000000000000000000000000
0000ee2e2eeeeee2e2ee00000000ee2e2eeeeee2e2ee000000000211dd222211dd220000000002d11d2222d11d22000000000000000000000000000000000000
0000e2eee2eeee2eee2e00000000e2eee2eeee2eee2e000000000211dd2cc211dd2c0000000002d11d2cc2d11d2c000000000000000000000000000000000000
0000eeeeeeeeeeeeeeee00000000eeeeeeeeeeeeeeee00000000c2dddd2cc2dddd2c00000000c2dddd2cc2dddd2c000000000000000000000000000000000000
0000eeeeeeeeeeeeeeee00000000eeee2222222eeeee0000000cc222222cc222222cc000000cc222222cc222222cc00000000000000000000000000000000000
0000eeee2222222eeeee00000000eeee2222222eeeee0000000cccccccccccccccccc000000cccccccccccccccccc00000000000000000000000000000000000
0000eeee2222222eeeee00000000eeee2222222eeeee0000000ccccccc2222ccccccc000000ccccccc2222ccccccc00000000000000000000000000000000000
00000eeeeeeeeeeeeee0000000000eeeeeeeeeeeeee000000000cccccccccccccccc00000000cccccccccccccccc000000000000000000000000000000000000
00000222222222222220000000000222222222222220000000000222111111111110000000000222111111111110000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000090000000000000000000000090000000000000000000000006200000000000000000000000060000000000000000000000000000000000000000
00000000000090000000000000000000000090000000000000000000022226200000000000000000022222620000000000000000000000000000000000000000
00000000000090000000000000000000000090000000000000000002225556222000000000000002225556252000000000000000000000000000000000000000
00000000999999990000000000000000999999990000000000000025555556255200000000000025555556255200000000000000000000000000000000000000
00000000922992290000000000000000922992290000000000000255556666255520000000000255556666255520000000000000000000000000000000000000
00000000999999990000000000000000922992290000000000000255566666655520000000000255566666655520000000000000000000000000000000000000
000000009922229900000000000000009999999900000000000002552222222255200000000002556dd665565520000000000000000000000000000000000000
00000000924444290000000000000000999229990000000000000255222222225520000000000255222222225520000000000000000000000000000000000000
00000000924444290000000000000000992992990000000000000255222662225520000000000255222662225520000000000000000000000000000000000000
00000000999999990000000000000000999999990000000000000255566666655520000000000255566666655520000000000000000000000000000000000000
00002222999999992222200000000000999999990000000000000025666666665200000000000025666666665200000000000000000000000000000000000000
00002499222222229994200000002222222222222222200000000002666666662000000000000002666666662000000000000000000000000000000000000000
00002499999999999994200000002499999999999994200000000002666666662000000000000002666666662000000000000000000000000000000000000000
00022999999999999999220000002499999999999994200000000002666666662000000000000002666666662000000000000000000000000000000000000000
__sfx__
000100000a65009650076500365002650026500265001650223602236021260016500265001650016500165002650016500165001650016500165002650016000000000000000000000000000000000000000000
000100002a650126500a6500665000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010100001701014110120100f0100c010091100a01008010070100701006610050100401004110040100401000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300000713010130092301912011220221201a22022030220202201022000251000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200003c6003d6103c6103c6103d6103d6103d6203d6203d6203d6003d600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000002d0502d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000003905000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000002105000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000600002655026550267502675030750307503275035750000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000600002405024050117502405010750107502405025750000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000b00002575025750267502675010750107501075010750107501175000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000b00001305011050100502405025050260502600026000107001170000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000000235302450023100225002353024500231002250023530245002310022500e2530000000000000000235302450023100225002353024500231002250023530245002310022500e253000000000000000
011000000e2501a2501d2501c2501a2501a2501a2501a2501a2501a2501a2501a2501a2530c0000e2400e2400e2501a2501d2501c2501a2501a2501a2501a2501a2501a2501a2501a2501a253000000000000000
011000000e3530000000000000001a653000000000000000000000000000000000001a6530000000000000000e3530e00300000000001a653000000000000000000003e6211a653000001a653000000000000000
011000001035304450043100425004353044500431004250043530445004310042500425300000000000000007353074500731007250073530745007310072500535305450053100525011253000000000000000
__music__
00 0c0e4d44
00 0c0e4d44
00 0c0e0d44
00 0f0e0d44

