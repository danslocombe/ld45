pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

none=0
left=1
right=2
up=3
down=4

maps = {
[[
.......
.     .
.p   t.
.......
]],
} 

function load_map(map)
  local px = 0
  local py = 0
  blocks = {}

  lines = split_lines(map)
  player = create_player(px, py)
  blocks = {}
  drawables = {}

  map_width = 1
  for i = 1,#lines do
    map_width = max(w,#lines[i])
  end
  map_height = #lines

  local xoffset = 7 - map_width / 2
  local yoffset = 7 - map_height / 2

  for y,l in pairs(lines) do
    for x=1,#l do
      local xx = (x + xoffset) * 8
      local yy = (y + yoffset) * 8
      local ss = sub(l,x,x)

      if ss == "." then
        local block = create_block(xx, yy)
        add(blocks, block)
        add(drawables, block)
      elseif ss == "p" then
        player.x = xx
        player.y = yy
      end
    end
  end
end

function _init()
  load_map(maps[1])
end

function _update60()
  player.tick(player)
  for i,b in pairs(blocks) do
    b.tick(b)
  end
end

function _draw()
  cls(0)
  for i,b in pairs(drawables) do
    b.draw(b)
  end

  player.draw(player)
end

function create_player()
  local obj = {
    x = 2,
    y = 2,
    speed = 2,
    dir = none,
    tx = 0,
    ty = 0,
  }

  obj.tick = function(o)
    if obj.dir == none then
      if btnp(0) then
        obj.dir = left
      elseif btnp(1) then
        obj.dir = right
      elseif btnp(2) then
        obj.dir = up
      elseif btnp(3) then
        obj.dir = down
      end
    else
      local mov_x = 0
      local mov_y = 0
      if obj.dir == left then
        mov_x -= 1
      elseif obj.dir == right then
        mov_x += 1
      elseif obj.dir == up then
        mov_y -= 1
      elseif obj.dir == down then
        mov_y += 1
      end

      --obj.x = obj.x + mov_x * obj.speed
      --obj.y = obj.y + mov_y * obj.speed
    end
  end

  obj.draw = function(o)
    rectfill(o.x, o.y, o.x + 7, o.y + 7, 8)
  end

  return obj
end

function create_block(x, y)
  local obj = {
    x = x,
    y = y,
  }

  obj.tick = function(o)
  end

  obj.draw = function(o)
    rectfill(o.x, o.y, o.x + 7, o.y + 7, 2)
  end

  return obj
end

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

  local ss = sub(s, start, -1) 
  if #ss > 0 and ss ~= "\n" then
    add(ret, ss)
  end

  return ret
end
