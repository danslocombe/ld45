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

unlock_robot = 0
unlock_tile = 1

robot_cols = {
  14,
  12,
  11,
}

unlock_pattern = {
  unlock_robot,
  unlock_tile,
  unlock_robot,
  unlock_tile,
  unlock_tile,
  unlock_robot,
  unlock_tile,
  unlock_tile,
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
.   3   1.
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
      create_robot(2, 2, 1, 14),
      --create_robot(5, 5, 2, 12),
      --create_robot(6, 8, 3, 11),
    },
  }

  history = {}

  target_x = 1
  target_y = 1
  target_id = 1
  level = 0
end 

function _init()
  reset()
  load_tile(0, 0, tiles[1])
  local target_robot = 1 -- + flr(rnd(3))
  generate_target(target_robot)

  t = 0
  selected_robot_id = 1
end

function _update60()
  --if t % 4 == 0 then
    --print_debug(stat(7))
  --end

  t += 1

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
    --selected_robot_id = 1 + ((selected_robot_id - 2) % #cur_state.robots)
    --print_debug("selecting " .. selected_robot_id)
    if #history > 0 then
      cur_state = history[#history]
      del(history, cur_state)
    end
  elseif btnp(5) then
    selected_robot_id = 1 + ((selected_robot_id) % #cur_state.robots)
    print_debug("selecting " .. selected_robot_id)
  end

  if ndir != none then

    local old_state = cur_state
    cur_state = move_robot(ndir, selected_robot_id, cur_state)

    -- todo only add to history if states are different
    add(history, old_state)

    -- check goal
    for i,r in pairs(cur_state.robots) do
      if r.id == target_id then
        if r.x == target_x and r.y == target_y then
          next_level()
        end

        break
      end
    end
  end
end

function next_level()
  level += 1
  local unlock = unlock_pattern[level]
  if unlock == unlock_robot then
      local rx = 2
      local ry = 2
      local rid = #cur_state.robots + 1
      add(cur_state.robots, create_robot(rx, ry, rid, robot_cols[rid]))
  end
  local target_robot = 1 + flr(rnd(#cur_state.robots))
  generate_target(target_robot)
  history = {}
end

function create_robot(x, y, id, col)
  return {x = x, y = y, id = id, col = col}
end

function clone_robot(r)
  -- robot should be immutable, clone on changes
  return {x = r.x, y = r.y, id = r.id, col = r.col}
end

function load_tile(xoffset, yoffset, tile)
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
        local cell = {x = x - 1, y = y - 1, borders = borders}
        add(grid, cell)
      end
    end
  end
end

function generate_target(target_robot)
  local state = cur_state
  for i = 0,200 do
    local dir = 1 + flr(rnd(4))
    local id = 1 + flr(rnd(#cur_state.robots))
    state = move_robot(dir, id, state)
  end

  target_x = state.robots[target_robot].x
  target_y = state.robots[target_robot].y
  target_id = target_robot
end

function place_free(x, y, state)
  for i,o in pairs(state.robots) do
    if o.x == x and o.y == y then
      return false
    end
  end

  return true
end

function should_stop(x, y, dir, state)
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

  while (not should_stop(new_robot.x, new_robot.y, dir, state)) 
    and (place_free(new_robot.x + mx, new_robot.y + my, state)) do
    new_robot.x = new_robot.x + mx
    new_robot.y = new_robot.y + my
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

-- draw --

function _draw()
  cls(13)

  local scale = 8
  local x0 = 3
  local y0 = 3

  local bgsize = 10
  for i = 0,10 do
    local bgcol = 2
    line((x0 + i) * scale, y0 * scale, (x0 + i) * scale, (y0 + bgsize) * scale, bgcol)
    line(x0 * scale, (y0 + i) * scale, (x0 + bgsize) * scale, (y0 + i) * scale, bgcol)
  end

  for i,cell in pairs(grid) do
    draw_cell(x0, y0, scale, cell)
  end

  for i,b in pairs(drawables) do
    b.draw()
  end

  draw_state(x0, y0, scale, cur_state)
end

function draw_state(xoffset, yoffset, scale, state)
  draw_target(xoffset, yoffset, scale, cur_state)
  for i,r in pairs(state.robots) do
    local x0 = (r.x + xoffset + 0.25) * scale
    local y0 = (r.y + yoffset + 0.25) * scale
    local x1 = (r.x + xoffset + 0.75) * scale
    local y1 = (r.y + yoffset + 0.75) * scale
    rectfill(x0, y0 - 1, x1, y1, 2)
    if selected_robot_id != r.id then
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
    if r.id == target_id then
      col = r.col
      break
    end
  end

  fillp(0b0110110110110110.1)
    rectfill(x0, y0, x1, y1, col)
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
