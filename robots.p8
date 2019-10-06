pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

-- an adaptation of the amazing ricochet robots

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
  unlock_robot,
  unlock_tile,
  --unlock_tile,
  unlock_robot,
  --unlock_tile,
  --unlock_tile,
  unlock_robot,
  --unlock_tile,
  --unlock_tile,
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
.   3   1.
..........
]],
[[
..........
.   r    .
. 0      .
.      2 .
.        .
.  3     .
.b      1.
.        .
.       1.
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
.       1.
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
.       1.
..........
]],
} 

function reset()
  print_debug("resetting..")
  grid = {}
  drawables = {}
  cur_state = {
    t = 0,
    robots = {
      create_robot(2, 2, 1, robot_cols[1]),
    },
  }

  history = {}
  actions = {}

  target_x = 1
  target_y = 1
  target_rid = 1
  level = 0
  shake_t = 0
  shake_t_max = 4
  animating = false
  animation_obj = {}
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

  turns_left_max = 24
  turns_left = turns_left_max
  turns_left_t_max = 240
  turns_left_t = turns_left_t_max
end 

function _init()
  reset()
  load_tile(0, 0, tiles[1 + flr(rnd(#tiles))])
  local target_robot = 1 -- + flr(rnd(3))
  generate_target(target_robot)

  t = 0
  selected_rid = 1
end

function _update60()

  tick_vars()

  for i,o in pairs(drawables) do
    o.tick(o)
  end

  if animating then
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

    if not animating then
      sfx(2)
      shake_t = shake_t_max / 3
    end

    return false
  end

  if should_gotonext then
    should_gotonext = false
    next_level()
  end

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
    print_debug("selecting " .. selected_rid)
    add(drawables, create_select_anim(prev_selected, selected_rid, cur_state))
    sfx(3)
  end

  local tt = turns_left - cur_state.t
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

    animating = true
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

    local tt = turns_left - cur_state.t
    if tt <= 0 then
      _init()
    elseif tt <= 5 then
      sfx(6)
    elseif turns_left < 10 then
      sfx(5)
    elseif turns_left < 16 then
      sfx(7)
    end
  end
end

function next_level()
  sfx(0)
  level += 1
  local unlock = unlock_pattern[level]
  if unlock == unlock_robot then
    local rx = flr(rnd(bgsize_x))
    local ry = flr(rnd(bgsize_y))
    local rid = #cur_state.robots + 1
    while not place_free(rx, ry, cur_state) or enclosed_grid(rx, ry) do
      rx = flr(rnd(bgsize_x))
      ry = flr(rnd(bgsize_y))
    end
    add(cur_state.robots, create_robot(rx, ry, rid, robot_cols[rid]))
  elseif unlock == unlock_tile then
    load_tile(9, 0, tiles[1 + flr(rnd(#tiles))])
    -- remove right side
    for i,o in pairs(grid) do
      if o.x == 9 and o.y > 0 and o.y < 9 then
        del(grid, o)
      end
    end
    target_draw_xoffset = 1
    target_draw_yoffset = 4
    bgsize_x = 19
    target_draw_scale = 6
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

function create_robot(x, y, id, col)
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
  local state = cur_state
  for i = 0,16 * #cur_state.robots + 2*level do
    local dir = 1 + flr(rnd(4))
    local id = 1 + flr(rnd(#cur_state.robots))
    state = move_robot(dir, id, state)
  end

  target_x = state.robots[target_robot].x
  target_y = state.robots[target_robot].y
  target_rid = target_robot
end

function place_free(x, y, state)
  for i,o in pairs(state.robots) do
    if o.x == x and o.y == y then
      return false
    end
  end

  return true
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

function move_robot(dir, id, state)
  local player = state.robots[id]
  for i,r in pairs(state.robots) do
    if r.id == id then
      new_robot = clone_robot(r)
      break
    end
  end

  local move_vec = vec_from_dir(dir)
  while (not should_stop(new_robot.x, new_robot.y, dir)) 
    and (place_free(new_robot.x + move_vec.x, new_robot.y + move_vec.y, state)) do
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

function _draw()
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

  draw_target(x0, y0, scale, cur_state)

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

  for i,cell in pairs(grid) do
    draw_cell(x0, y0, scale, cell)
  end

  draw_robots(x0, y0, scale, cur_state)

  for i,o in pairs(drawables) do
    o.draw(o, x0, y0, scale)
  end

  for i=1,#actions do
    local action = actions[i]
    local s = 15 + action.dir
    pal(7, robot_cols[action.rid])
    spr(s, 115, -4 +  8*i)
    pal()
  end

  if shake_t > 0 then
    dump_noise(shake_t / shake_t_max)
  end

  if rewind_t > 0 then
    dump_rewind_noise()
  end

  --print(turns_left - cur_state.t, 60, 100, 7)
  local xx = 60
  local yy = 110
  local n = turns_left - cur_state.t
  while n >= 10 do
    local displ = n % 10
    spr(displ, xx, yy)
    n = n / 10
    xx -= 8
  end
  spr(n, xx, yy)
end

function draw_robots(xoffset, yoffset, scale, state)
  for i,r in pairs(state.robots) do

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
    rectfill(x0, y0 - 1, x1, y1 - 1, r.col)
    fillp()
  end
end

function draw_target(xoffset, yoffset, scale, cur_state)
  local x0 = (target_x + xoffset + 0.13) * scale
  local y0 = (target_y + yoffset + 0.13) * scale
  local x1 = (target_x + xoffset + 0.96) * scale
  local y1 = (target_y + yoffset + 0.96) * scale

  rectfill(x0, y0, x1, y1, 7)

  -- lookup color of target
  local col = 1
  for i,r in pairs(cur_state.robots) do
    if r.id == target_rid then
      col = r.col
      break
    end
  end

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
        return;
      end
    end

    o.x = (o.x * (scale - 1) + target.x) / scale
    o.y = (o.y * (scale - 1) + target.y) / scale

    o.t += 1
  end

  obj.draw = function(o, xoffset, yoffset, scale)
    local col = 0
    local other = {}

    if o.state == 0 then
      col = robot_cols[start_rid]
      other = get_robot_anim_pos(start_rid, cur_state)
    else
      col = robot_cols[end_rid]
      other = get_robot_anim_pos(end_rid, cur_state)
    end

    local this_x = (xoffset + o.x + 0.5) * scale
    local this_y = (yoffset + o.y + 0.5) * scale
    local other_x = (xoffset + other.x + 0.5) * scale
    local other_y = (yoffset + other.y + 0.5) * scale

    line(this_x, this_y, other_x, other_y, col)
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
__sfx__
000100000a65009650076500365002650026500265001650223602236021260016500265001650016500165002650016500165001650016500165002650016000000000000000000000000000000000000000000
000100002a650126500a6500665000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100001705014150120500f0500c050091500a05008050070500705006650050500405004150040500405000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300000713010130092301912011220221201a22022030220202201022000251000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200003c6003d6103c6103c6203d6303d6303d6303d6403d6403d6003d600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000002d0502d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000003905000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000002105000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
