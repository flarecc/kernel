--[[
UID|NAME|PERMS|GROUP
]]

local user = {}

local function mysplit(inputstr, sep)
    if sep == nil then
      sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
      table.insert(t, str)
    end
    return t
  end

function user:new(system)
    local usr = {
        users={},
        metaFilePath="/etc/usr"
    }
    function usr:load()
        local f = fs:open(self.metaFilePath,"r",0)
        if f then
            local lines = mysplit(f.readAll(),"\n")
            for _,line in ipairs(lines) do
                local uid, name, perms, group,psswd = line:match("([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)")
                self.users[tonumber(uid)] = {
                    name = name,
                    perms = tonumber(perms),
                    group = tonumber(group),
                    psswd = psswd
                }
            end
            f:close()
            system.log.log({level="debug"},"User metadata loaded")
        else
            system.log.log({level="error"},"User metadata file not found at " .. self.metaFilePath .. ", starting fresh.")
        end
    end

    function usr:save()
        local file,e = fs.open(self.metaFilePath, "w")
        for uid, meta in pairs(self.users) do
            file.write(string.format("%d|%s|%d|%d|%s\n", uid,meta.name, meta.perms, meta.group,meta.psswd))
        end
        file.close()
    end
    function usr:user(usr)
        return self.users[usr]
    end

    usr:load()
    return usr
end

return user