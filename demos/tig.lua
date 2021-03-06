local ui = require('demos.lib.ui')
local tb = require('luabox')

package.path = package.path .. ";../luajix/?.lua"
package.cpath = package.cpath .. ";../luajix/?.so"
local git2 = require('git2')

-----------------------------------------

local window = ui.load()

-- create a 10x10 rectangle at coordinates 5x5
if not window then
  print "Unable to load UI."
  os.exit(1)
end

local header = ui.Box({ height = 1, bg_char = 0x2573 })
window:add(header)

local left = ui.Box({ top = 1, bottom = 1, width = 0.8, bg = tb.DARKER_GREY })
window:add(left)

local right = ui.Box({ top = 1, left = 0.8, bottom = 1, width = 0.5, bg = tb.DARK_GREY })
window:add(right)

text = [[
This function returns a formated version
of its variable number of arguments following
the description given in its first argument
(which must be a string). The format string
follows the same rules as the printf family
of standard C functions. The only differencies
are that the options/modifiers * , l , L , n , p ,
and h are not supported, and there is an extra
option, q . This option formats a string in a
form suitable to be safely read back by the
Lua interpreter. The string is written between
double quotes, and all double quotes, returns
and backslashes in the string are correctly
escaped when written.
]]

local para = ui.TextBox(text, { top = 1, left = 1, right = 1 })
right:add(para)

local footer = ui.Box({ height = 1, position = "bottom", bg = tb.BLACK })
window:add(footer)

local label = Label("Latest commits", { left = 1, right = 1, bg = tb.GREEN })
left:add(label)

---------------------------

local repo, walker, oid, ref_end, oid_end

function fmt_ts(unix)
  unix = unix or os.time()
  return os.date('%Y-%m-%dT%H:%M:%SZ', unix)
end

function fmt_message(message)
  local eol = message:find('[\r\n]$')
  if not eol then
    return message
  end
  return message:sub(1, eol - 1)
end

function format_entry(rep, oid, commit)
  local info = git2.commit_info(commit)
  local hash = git2.oid_hash(oid)

  local author, title, message;

  if info.committer ~= info.author then
    author = info.author .. " (via " .. info.committer .. ")"
  else
    author = info.author
  end

  if info.message and info.message:len() > 0 then
    message = info.message
  else
    message = 'Unknown'
  end

  return fmt_ts(info.time) .. ' ' .. author .. ' -> ' .. message:gsub("\n", "")
end

function next_commit()
  res = git2.revwalk_next(oid, walker)
  if res < 0 then return end

  if ref_end and git2.oid_equal(oid, oid_end) then
   print('Processed all commits in range')
   return
  end

  local commit = git2.commit_lookup(repo, oid)
  if commit ~= nil then
    return format_entry(repo, oid, commit)
  else
    print('Failed to lookup commit from oid')
  end
end

--------------------------

max_commits = 1000

local commits = ui.OptionList({}, { count = max_commits, top = 1, left = 1, right = 1 })
left:add(commits)

cache = {}

function commits:get_item(number)
  if number > max_commits then return nil end

  if cache[number] then
    return cache[number]
  else
    local item = next_commit()
    if item then
      cache[number] = item
    end

    return item -- could be nil
  end
end

commits:on('selected', function(index, string)
  if index then
    para.text = "Showing commit: " .. index
  end
end)

local obj = git2.load_repo('/home/tomas', 'HEAD', -1)
if not obj then
  print("Repo failed to load.")
  os.exit(1)
end

repo    = obj.repo
oid     = obj.oid
oid_end = obj.oid_end
ref_end = obj.ref_end
walker  = git2.load_walker(repo, oid)

commits:focus()
ui.start()
ui.unload()
