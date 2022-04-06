local Exclude = {['.git'] = true}

local LOCs = {}
local Inconsistencies = {}
local SortLOCs = {}
local LocPath = nil
local USdb = {}

local StrFind = string.find

function ParseLOCs(s)
  local i = 1
  local i2 = 1
  local i3, i4, s2, s3
  while true do
    _, i = StrFind(s, '<LOC ', i, true)
    if i == nil then return end
    while true do
      _, i3 = StrFind(s, '#', i2, true)
      _, i4 = StrFind(s, '--', i2, true)
      if (i4 ~= nil) and ((i3 == nil) or (i4 < i3)) then i3 = i4 end
      if i3 == nil then break end
      if i < i3 then break end
      i3 = i3 + 1
      if (s:sub(i3, i3 + 1) == '[[') then
        _, i2 = StrFind(s, ']]', i3 + 2, true)
      else
        _, i2 = StrFind(s, '\n', i3)
      end
      if i2 == nil then return end
    end
    if i < i2 then
      i = i2 + 1
      continue
    end
    i = i + 1
    _, i3 = StrFind(s, '[^\\]["\']', i)
    s2, s3 = s:sub(i, i3):match('([%w%d_]+)%s*>(.*' .. s:sub(i3, i3) .. ')')
    if (s2) and (s3) then
      local v = s:sub(i3, i3) .. s3
      if not LOCs[s2] then
        LOCs[s2] = v
      elseif v:len() > 2 then
        if LOCs[s2]:len() < 3 then
          LOCs[s2] = v
        elseif LOCs[s2] ~= v then
          Inconsistencies[s2] = true
        end
      end
    end
    i = i3 + 1
  end
end

function ParseDB(file)
  local f = io.open(file, 'r')
  local s = f:read('*all')
  f:close()
  local i = 1
  local i2 = 1
  local i3, i4, i5, s2
  Doubles = {}
  while true do
    i5, i = StrFind(s, '[%w%d_]+%s*=%s*[\'"]', i)
    if i == nil then return Doubles end
    while true do
      _, i3 = StrFind(s, '#', i2, true)
      _, i4 = StrFind(s, '--', i2, true)
      if (i4 ~= nil) and ((i3 == nil) or (i4 < i3)) then i3 = i4 end
      if i3 == nil then break end
      if i < i3 then break end
      i3 = i3 + 1
      if (s:sub(i3, i3 + 1) == '[[') then
        _, i2 = StrFind(s, ']]', i3 + 2, true)
      else
        _, i2 = StrFind(s, '\n', i3)
      end
      if i2 == nil then return Doubles end
    end
    if i < i2 then
      i = i2 + 1
      continue
    end
    s2 = s:match('([%w%d_]+)%s*=%s*[\'"]', i5)
    if s2 then
      if not Doubles[s2] then
        Doubles[s2] = 0
      else
        Doubles[s2] = Doubles[s2] + 1
      end
    end
    i = StrFind(s, '[^\\]["\']', i + 1)
  end
end

function ParseDir(dir)
  function ParseExts(exts)
    for i,v in exts do
      local files = io.dir(dir .. v)
      for i,v in files do
        if not loadfile(dir .. v) then continue end
        local f = io.open(dir .. v, 'r')
        local text = f:read('*all')
        f:close()
        ParseLOCs(text)
      end
    end
  end

  ParseExts({'*.lua', '*.bp'});
  local files = io.dir(dir .. '*', 0x10)
  for i = 3, table.getn(files) do
    local path = dir .. files[i] .. '/'
    if Exclude[files[i]] then continue end
    if files[i] == 'loc' then
      if not LocPath then
        LocPath = path
      end
    else
      ParseDir(path)
    end
  end
end

function doscript(file, env)
  local f = assert(loadfile(file))
  setfenv(f, env)
  return f()
end

function CheckDB(file)
  local env = {}
  doscript(file, env)
  io.write('From Lua code:\n\n')
  for i,k in SortLOCs do
    if not env[k] then
      io.write(k .. '=' .. LOCs[k] .. '\n')
    end
  end
  io.write('\n\nFrom US .db:\n\n')
  for k,v in USdb do
    if (not env[k]) and (not LOCs[k]) then
      io.write(k .. '=\'' .. v .. '\'\n')
    end
  end
  io.write('\n\nDoubles:\n\n')
  local Doubles = ParseDB(file)
  for k,v in Doubles do
    if v > 0 then
      io.write(k .. '\n')
    end
  end
end

ParseDir(arg[1] .. '/')
local i = 1
for k,v in LOCs do
  SortLOCs[i] = k
  i = i + 1
end
table.sort(SortLOCs)
io.output([[Found_LOCs.txt]])
io.write('From Lua code:\n\n')
for i,k in SortLOCs do
  io.write(k .. '=' .. LOCs[k] .. '\n')
end
io.write('\n\nInconsistencies:\n\n')
for k,v in Inconsistencies do
  io.write(k .. '\n')
end

doscript(LocPath .. '/US/strings_db.lua', USdb)
local dirs = io.dir(LocPath .. '/*', 0x10)

for i = 3, table.getn(dirs) do
  if dirs[i] == 'US' then continue end
  io.output('Missing_' .. dirs[i] .. '.txt')
  CheckDB(LocPath .. dirs[i] .. '/strings_db.lua');
end

io.output('Missing_US.txt')
io.write('From Lua code:\n\n')
for i,k in SortLOCs do
  if not USdb[k] then
    io.write(k .. '=' .. LOCs[k] .. '\n')
  end
end
io.write('\n\nFrom other .db:\n\n')
for i = 3, table.getn(dirs) do
  if dirs[i] == 'US' then continue end
  local env = {}
  doscript(LocPath .. dirs[i] .. '/strings_db.lua', env)
  for k,v in env do
    if (not USdb[k]) and (not LOCs[k]) then
      io.write(k .. '\n')
      USdb[k] = true
    end
  end
end
io.write('\n\nDoubles:\n\n')
local Doubles = ParseDB(LocPath .. '/US/strings_db.lua')
for k,v in Doubles do
  if v > 0 then
    io.write(k .. '\n')
  end
end