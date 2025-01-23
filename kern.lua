local SYSCALL = {}
local _KERNEL = "ProotOS Kernel 0.1 alpha"
local nativeShutdown = os.shutdown
local PROC = {}
local PID = 0
SYS = {}

---@type FileSystem
fs = fs
local expect = dofile("rom/modules/main/cc/expect.lua")
if _VERSION == "Lua 5.1" and load("::a:: goto a") then
    _VERSION = "Lua 5.2"
    if load("return 1 >> 2 & 3") then
        _VERSION = "Lua 5.3"
        if load("local <const> a = 2") then _VERSION = "Lua 5.4" end
    end
end;
colors = fs:exec("/lib/colors.lua",0)()
local system = {
    proc = {
        qEvnt = false,
        procs = 0,
        curProc = 0,
        sys = {},
        ipc = {}
    },
    log = {},
    bios = os,
    user = {},
    os = {
    },kernel={}
}
setmetatable(system.os,{__index=os})
--os = nil

--#region DEFINES
local keys=fs:exec("/lib/keys.lua",0)()
--#endregion

--#region system
function SYSCALL.shutdown(proc,...)
    system.log.log({level="Notice"},"system shutdown")
    if #fs:list("/dev",0) > 0 then
        system.log.log({level="Warning"},"Devices not shutdown")
    end
    fs:unmount("/dev",0)
    system.log.log({level="info"},"saving fs...")
    fs:save("testfs.fs")


    system.log.log({level="info"},"Halting processes")
    for key, value in pairs(PROC) do
        system.log.log({level="debug"},"Halting PROC",key,value.name)
        value:endProc()
    end

    
    --system.bios.shutdown(...)
    while true do
        coroutine.yield()
    end
end
function SYSCALL.reboot(proc,...)
    system.bios.reboot()
    while true do
        coroutine.yield()
    end
end
function SYSCALL.queueEvent(proc,...)
    system.bios.queueEvent(...)
    while true do
        coroutine.yield()
    end
end
function system.os.pullEventRaw(tgt)
    local e = {coroutine.yield("EVENT",tgt)}

    return table.unpack(e)
end
function system.read(_sReplaceChar, _tHistory, _fnComplete, _sDefault)
    expect.expect(1, _sReplaceChar, "string", "nil")
    expect.expect(2, _tHistory, "table", "nil")
    expect.expect(3, _fnComplete, "function", "nil")
    expect.expect(4, _sDefault, "string", "nil")

    term.setCursorBlink(true)

    local sLine
    if type(_sDefault) == "string" then
        sLine = _sDefault
    else
        sLine = ""
    end
    local nHistoryPos
    local nPos, nScroll = #sLine, 0
    if _sReplaceChar then
        _sReplaceChar = string.sub(_sReplaceChar, 1, 1)
    end

    local tCompletions
    local nCompletion
    local function recomplete()
        if _fnComplete and nPos == #sLine then
            tCompletions = _fnComplete(sLine)
            if tCompletions and #tCompletions > 0 then
                nCompletion = 1
            else
                nCompletion = nil
            end
        else
            tCompletions = nil
            nCompletion = nil
        end
    end

    local function uncomplete()
        tCompletions = nil
        nCompletion = nil
    end

    local w = term.getSize()
    local sx = term.getCursorPos()

    local function redraw(_bClear)
        local cursor_pos = nPos - nScroll
        if sx + cursor_pos >= w then
            -- We've moved beyond the RHS, ensure we're on the edge.
            nScroll = sx + nPos - w
        elseif cursor_pos < 0 then
            -- We've moved beyond the LHS, ensure we're on the edge.
            nScroll = nPos
        end

        local _, cy = term.getCursorPos()
        term.setCursorPos(sx, cy)
        local sReplace = _bClear and " " or _sReplaceChar
        if sReplace then
            term.write(string.rep(sReplace, math.max(#sLine - nScroll, 0)))
        else
            term.write(string.sub(sLine, nScroll + 1))
        end

        if nCompletion then
            local sCompletion = tCompletions[nCompletion]
            local oldText, oldBg
            if not _bClear then
                oldText = term.getTextColor()
                oldBg = term.getBackgroundColor()
                term.setTextColor(1)
                term.setBackgroundColor(colors.gray)
            end
            if sReplace then
                term.write(string.rep(sReplace, #sCompletion))
            else
                term.write(sCompletion)
            end
            if not _bClear then
                term.setTextColor(oldText)
                term.setBackgroundColor(oldBg)
            end
        end

        term.setCursorPos(sx + nPos - nScroll, cy)
    end

    local function clear()
        redraw(true)
    end

    recomplete()
    redraw()

    local function acceptCompletion()
        if nCompletion then
            -- Clear
            clear()

            -- Find the common prefix of all the other suggestions which start with the same letter as the current one
            local sCompletion = tCompletions[nCompletion]
            sLine = sLine .. sCompletion
            nPos = #sLine

            -- Redraw
            recomplete()
            redraw()
        end
    end
    while true do
        local sEvent, param, param1, param2 = system.os.pullEventRaw()
        if sEvent == "char" then
            -- Typed key
            clear()
            sLine = string.sub(sLine, 1, nPos) .. param .. string.sub(sLine, nPos + 1)
            nPos = nPos + 1
            recomplete()
            redraw()
        elseif sEvent == "paste" then
            -- Pasted text
            clear()
            sLine = string.sub(sLine, 1, nPos) .. param .. string.sub(sLine, nPos + 1)
            nPos = nPos + #param
            recomplete()
            redraw()
        elseif sEvent == "key" then
            if param == keys.enter or param == keys.numPadEnter then
                -- Enter/Numpad Enter
                if nCompletion then
                    clear()
                    uncomplete()
                    redraw()
                end
                break
            elseif param == keys.left then
                -- Left
                if nPos > 0 then
                    clear()
                    nPos = nPos - 1
                    recomplete()
                    redraw()
                end
            elseif param == keys.right then
                -- Right
                if nPos < #sLine then
                    -- Move right
                    clear()
                    nPos = nPos + 1
                    recomplete()
                    redraw()
                else
                    -- Accept autocomplete
                    acceptCompletion()
                end
            elseif param == keys.up or param == keys.down then
                -- Up or down
                if nCompletion then
                    -- Cycle completions
                    clear()
                    if param == keys.up then
                        nCompletion = nCompletion - 1
                        if nCompletion < 1 then
                            nCompletion = #tCompletions
                        end
                    elseif param == keys.down then
                        nCompletion = nCompletion + 1
                        if nCompletion > #tCompletions then
                            nCompletion = 1
                        end
                    end
                    redraw()
                elseif _tHistory then
                    -- Cycle history
                    clear()
                    if param == keys.up then
                        -- Up
                        if nHistoryPos == nil then
                            if #_tHistory > 0 then
                                nHistoryPos = #_tHistory
                            end
                        elseif nHistoryPos > 1 then
                            nHistoryPos = nHistoryPos - 1
                        end
                    else
                        -- Down
                        if nHistoryPos == #_tHistory then
                            nHistoryPos = nil
                        elseif nHistoryPos ~= nil then
                            nHistoryPos = nHistoryPos + 1
                        end
                    end
                    if nHistoryPos then
                        sLine = _tHistory[nHistoryPos]
                        nPos, nScroll = #sLine, 0
                    else
                        sLine = ""
                        nPos, nScroll = 0, 0
                    end
                    uncomplete()
                    redraw()
                end
            elseif param == keys.backspace then
                -- Backspace
                if nPos > 0 then
                    clear()
                    sLine = string.sub(sLine, 1, nPos - 1) .. string.sub(sLine, nPos + 1)
                    nPos = nPos - 1
                    if nScroll > 0 then nScroll = nScroll - 1 end
                    recomplete()
                    redraw()
                end
            elseif param == keys.home then
                -- Home
                if nPos > 0 then
                    clear()
                    nPos = 0
                    recomplete()
                    redraw()
                end
            elseif param == keys.delete then
                -- Delete
                if nPos < #sLine then
                    clear()
                    sLine = string.sub(sLine, 1, nPos) .. string.sub(sLine, nPos + 2)
                    recomplete()
                    redraw()
                end
            elseif param == keys["end"] then
                -- End
                if nPos < #sLine then
                    clear()
                    nPos = #sLine
                    recomplete()
                    redraw()
                end
            elseif param == keys.tab then
                -- Tab (accept autocomplete)
                acceptCompletion()
            end
        elseif sEvent == "mouse_click" or sEvent == "mouse_drag" and param == 1 then
            local _, cy = term.getCursorPos()
            if param1 >= sx and param1 <= w and param2 == cy then
                -- Ensure we don't scroll beyond the current line
                nPos = math.min(math.max(nScroll + param1 - sx, 0), #sLine)
                redraw()
            end
        elseif sEvent == "term_resize" then
            -- Terminal resized
            w = term.getSize()
            redraw()
        end
    end

    local _, cy = term.getCursorPos()
    term.setCursorBlink(false)
    term.setCursorPos(w + 1, cy)
    print()

    return sLine
end
function system.sleep(nTime)
    expect.expect(1, nTime, "number", "nil")
    local timer = os.startTimer(nTime or 0)
    repeat
        local _, param = system.os.pullEventRaw("timer")
    until param == timer
end
--#endregion

--#region proc

local function preempt_hook()
    coroutine.yield()
end
local function makeProcFAKE(name)
    local p = {
        filter = nil,
        pid = PID,
        name = name,
        user = 0
    }
    PID = PID + 1
    system.proc.procs = system.proc.procs + 1
    function p:resume(sEvent, tEvent)
    end

    function p:endProc()
        PROC[p.pid] = nil
        system.proc.procs = system.proc.procs - 1
    end

    PROC[p.pid] = p
    return p.pid
end
local function makeProc(f, ...)
    local args = { ... }

    local p = {
        filter = nil,
        pid = PID,
        name = ("P_%d"):format(PID),
        user = 0
    }
    local function crash(a)
        system.log.log({level = "error",process=p.pid,traceback=true},"process crashed",a)
        p:endProc()
    end
    p.c = coroutine.create(function()
        xpcall(f, crash, table.unpack(args))
    end)
    debug.sethook(p.c, preempt_hook, "", 2000000)
    PID = PID + 1
    system.proc.procs = system.proc.procs + 1
    function p:continue(...)
        local result = { coroutine.resume(self.c, ...) }
        local ok, typ, sFunc, tArg = result[1], result[2], result[3], result[4]
        if ok then
            if typ == "SYSCALL" then
                if coroutine.status(self.c) == "dead" then
                    self:endProc()
                else
                    p:continue(SYSCALL[sFunc](self,table.unpack(tArg)))
                end
            elseif typ == "EVENT" then
                self.filter = sFunc
                --system.log.log({level="debug",process=self.pid},"filter set to",sFunc)
                system.proc.qEvnt = false
            else
                self.filter = nil
            end
        else
            print(typ)
            self:endProc()
        end
        if coroutine.status(self.c) == "dead" then
            self:endProc()
        end
    end

    function p:resume(sEvent, tEvent)
        system.proc.curProc = self.pid
        if self.filter == nil or self.filter == sEvent or sEvent == "terminate" then
            
            self:continue(table.unpack(tEvent))
            
        elseif sEvent ~= "_preempt_hook" and self.pid ~=1 then
            

           -- system.log.log({level="Debug",process=self.pid},self.filter, sEvent)
        end
    end

    function p:endProc()
        system.log.log({process=p.pid,level="spam"},"process stopped")
        PROC[p.pid] = nil
        system.proc.procs = system.proc.procs - 1
    end

    PROC[p.pid] = p
    return p.pid
end

function SYSCALL.proc(proc,func, ...)
    local p = makeProc(func, ...)
    return p
end
function SYSCALL.end_proc(proc,pid)
    pid = pid or proc
    PROC[pid]:endProc()
end

function SYSCALL.fork(proc,name,func)
    expect.expect(2,func,"function")
    local pid = SYSCALL.proc(proc,func)
    PROC[pid].name =name
    PROC[pid].user =proc.user
    return pid
end
function SYSCALL.setUser(proc,uid)
    proc.user = uid
end
function SYSCALL.procUser(proc)
    return proc.user
end

function SYSCALL.procs(proc)
    local t = {}
    for key, value in pairs(PROC) do
        table.insert(t,{PID=value.pid,name=value.name})
    end
    return t
end
function SYSCALL.nameProc(proc,name)
    proc.name = name
end
function SYSCALL.getPID(proc)
    return proc.pid
end

--#region sync
    function SYSCALL.procHasQueue(proc)
        return proc.queue ~=nil
    end
    function SYSCALL.procNewQueue(proc)
        proc.queue = {}
        return proc.queue
    end
    function SYSCALL.procGetQueue(proc,pid)
        return PROC[pid].queue
    end

    function SYSCALL.procIPCReg(proc,name)
        system.proc.ipc[name] = proc.pid
    end
    function SYSCALL.procIPCLookup(proc,name)
        return system.proc.ipc[name]
    end
--#endregion
makeProcFAKE("KERNEL")
--#endregion

--#region logs
local levels = {[-1] = "Spam"  ,[0] = "Debug", "Info", "Notice", "Warning", "Error", "Critical", "Panic" }
local levels_lower = {}
local levels_colors = {
    [-1] = '\27[90m',
    [0] = '\27[90m',
    '\27[34m',
    '\27[32m',
    '\27[93m',
    '\27[31m',
    '\27[95m',
    '\27[96m'
}
for v = -1, #levels do levels_lower[levels[v]:lower()] = v end
local e
system.log.syslogFile,e = fs:open("/var/log/kern.log","w",0)

---@param y any
---@param am any
---@param v number
---@param aa number
---@return string
local function merge(y, am, v, aa)
    if v >= aa then
        return tostring(y[v])
    else
        return tostring(y[v]) .. am .. merge(y, am, v + 1,
            aa)
    end
end

function system.log.log(field,...)
    local args = {...}
    expect.field(field, "name", "string", "nil")
    expect.field(field, "category", "string", "nil")
    expect.field(field, "level", "number", "string", "nil")
    expect.field(field, "time", "number", "nil")
    expect.field(field, "process", "number", "nil")
    expect.field(field, "thread", "number", "nil")
    expect.field(field, "module", "string", "nil")
    expect.field(field, "traceback", "boolean", "nil")
    if type(field.level) == "string" then
        field.level = levels_lower[field.level:lower()]
        if not field.level then error("bad field 'level' (invalid name)", 0) end
    elseif field.level and (field.level < 0 or field.level > #levels) then
        error("bad field 'level' (level out of range)", 0)
    end; field.name =
        field.name or "default"
    field.process = field.process or 0
    field.thread = field.thread or false
    field.level = field.level or 1
    field.time = field.time or system.bios.epoch("utc")

    local a0 = merge(args, " ", 1, #args)

    if field.traceback then
        a0 = a0:gsub("\t", "  "):gsub("([^\n]+):(%d+):",
            "\27[96m%1\27[37m:\27[95m%2\27[37m:"):gsub("'([^']+)'\n", "\27[93m'%1'\27[37m\n")
        a0 = a0.." "..debug.traceback()
    end
    local t = ("%s[%s]%s %s[%d%s]%s [%s]: %s%s"):format(
            levels_colors[field.level] or "",
            system.bios.date("%b %d %X", field.time / 1000),
            field.category and " <" .. field.category .. ">" or "",
            PROC[field.process] and PROC[field.process].name or "(unknown)",
            field.process,
            field.thread and ":" .. field.thread or "",
            field.module and " (" .. field.module .. ")" or "",
            levels[field.level],
            a0,
            "\27[0m" or "")
    print(t)
    t = ("%s[%s]<%9s> %8s[%02d%s]%s [%8s]: %s%s"):format(
            levels_colors[field.level] or "",
            system.bios.date("%b %d %X", field.time / 1000),
            field.category or "",
            PROC[field.process] and PROC[field.process].name or "(unknown)",
            field.process,
            field.thread and ":" .. field.thread or "",
            field.module and " (" .. field.module .. ")" or "",
            levels[field.level],
            a0,
            "\27[0m"
            )
    system.log.syslogFile.write(t.."\n")
    system.log.syslogFile.flush()
    
end

function SYSCALL.log(proc,param,...)
    param.process = proc.pid
    system.log.log(param,...)

end

system.log.log({level = "info"},"proot os starting")
system.log.log({level = 0},_VERSION)
system.log.log({level = 0},_HOST)
system.log.log({level = "debug"},_KERNEL)

if _VERSION ~= "Lua 5.2" then
    system.log.log({level = "Warning"},"Unsuported LUA VERSION")
end

system.log.log({level = "Notice"},"BOOTLOADER VERSION, os has NO access to the real file system")


--#endregion

--#region fs
system.log.log({level = "info"},"FS loading")
local DFS = fs:exec("/lib/devFS.lua",0)()
local dev = DFS:new()
system.log.log({level = "debug"},"mounting /dev")
fs:mount("/dev",dev,0)

dev:addDevice("null", function(op, data)
    if op == "write" then
        return nil  -- Discard data
    elseif op == "read" then
        return ""  -- Nothing to read from /dev/null
    end
end)

dev:addDevice("zero", function(op, data)
    if op == "write" then
        return nil  -- Discard data
    elseif op == "read" then
        return string.char(0) 
    end
end)

-- Add /dev/random (returns random data when read)
dev:addDevice("random", function(op, data)
    if op == "read" then
        return string.char(math.random(0, 255))  -- Simulate random byte output
    end
end)
dev:addDevice("urandom", function(op, data)
    if op == "read" then
        return string.char(math.random(0, 255))  -- Simulate random byte output
    end
end)

dev:addDevice("stderr", function(op, data)
    if op == "write" then
        system.log.log({level="error",process=system.proc.curProc},data)
        return nil
    elseif op == "read" then
        return ""
    end
end)

dev:addDevice("stdin", function(op, data)
    if op == "read" then
        return system.read()
    end
end)

dev:addDevice("stdout", function(op, data)
    if op == "write" then
        print(data)
        return nil
    elseif op == "read" then
        return ""
    end
end)
system.log.log({level="debug"},"/dev virtual files loaded")


function system.addDevice(path,f)
    dev:addDevice(path,f)
end


function system.removeDevice(path)
    dev:delete(path,0)
end

local UserFS = fs:exec("/lib/UserFS.lua",0)()

function SYSCALL.WriteFS(proc)
    fs:saveToDisk("/proot/fs.img")
    system.log.log({level="Notice",process=0},"Saved FS")
    --system.log.syslogFile:close()
    --system.log.syslogFile = fs:open("/var/log/kern.log","a",0)
    
end

local function FSMNG()
    system.log.log({level = "debug",category="DRIVERS"},"File system manager started")
    while true do
        system.sleep(60)
        if fs:isChanged() then
            fs:save("fs.img")
        end
    end
end

--#endregion

local dI = panic;
local function panic(ae)
    xpcall(
        function()
            system.log.log({ level = "panic" }, "Kernel panic:", ae)
            if debug then
                local ai = debug.traceback(nil, 2)
                system.log.log({ level = "panic", traceback = true }, ai)
            end; system.log.log({ level = "panic" }, "We are hanging here...")
            term.setCursorBlink(false)
            mainThread = nil; while true do coroutine.yield() end
        end, function(A) dI(ae .. "; and an error occurred while logging the error: " .. A) end)
end;

--#region Kernel Modules
system.log.log({level = "info"},"loading kernel modules")
for key, value in pairs(fs:list("/lib/modul/",0)) do
    system.log.log({level = "debug",category="DRIVERS"},"Loading module",value)
    fs:exec("/lib/modul/"..value,0)()
end

--#endregion

--#region drivers
local devices = {}
local drvr = {}


system.log.log({level = "info"},"loading drivers")

for key, value in pairs(fs:list("/boot/drv/",0)) do
    local _,e
    local function driverEnv()
        local t = {system = system,os = system.bios}
        t = setmetatable(t, {__index = _G})
        return t
    end
    do
        local env = driverEnv()
        e=  setfenv(fs:exec("/boot/drv/"..value,0),env)()
    end
    if e ~= nil and type(e)=="table" then
        system.log.log({level = "debug",category="DRIVERS"},"Loading driver",value)
        expect.field(e,"name","string")
        expect.field(e,"type","string")
        expect.field(e,"methods","table")
        if e.init then
            drvr[e.type] = e
        else
            system.log.log({level = "error",category="DRIVERS"},"Driver",value,"bad format")
        end
    else
        system.log.log({level = "error",category="DRIVERS"},"Failed to load driver",value)
    end
end
local function startDriver(node,driver)
    local drv = {}
    for key, value in pairs(driver.methods) do
        drv[key] = function (...)
            return value(node,...)
        end
    end
    driver.init(node,drv)
    devices[node] = drv
end
for key, value in pairs(drvr) do
    if string.match(key,"!") then
        system.log.log({level = "debug",category="DRIVERS"},"Core Driver",key,"starting")
        startDriver(value.name,value)
    end
end

local function deviceMng()
    coroutine.yield("SYSCALL","log",{{level = "debug",category="DRIVERS"},"device Manager started"})
    while true do
        local e,side = coroutine.yield("EVENT","peripheral")
        
        coroutine.yield("SYSCALL","log",{{level = "debug",category="DRIVERS"},"attached",side})
    end
    
end
system.log.log({level = "debug"},"Drivers Loaded")
--#endregion


--#region user
local function fsaddUser(user)
    fs:makeDir("/home/user"..user,0)
    fs:takeOwn("/home/user"..user,1)
end
local textutils
system.log.log({level = "info"},"loading users")
do
    local f = fs:exec("/lib/txtUtil.lua", 0)
    textutils = f()
end
local userHandl = fs:exec("/lib/user.lua",0)()
local users = userHandl:new(system)
if users:user(0).perms ~= 15 then
    system.log.log({level = "Critical"},users:user(0).name,"has perms",users:user(0).perms)
end
for key, value in pairs(users.users) do
    if not fs:exists("/home/user"..key) then
        system.log.log({level = "debug"},"Creating user",key,value.name)
        fsaddUser(key)
    end

end
if fs:Permissions("/",0) ~= 7 then
    system.log.log({level = "error"},"Root lacks perms")
end

function SYSCALL.getShortName(proc)
    return users:user(proc.user).name
end
system.log.log({level="info"},#users.users+1,"user(s)")

--#endregion

local function test()
    for i = 1, 10 do
        local x = 0
        for _ = 1, 1e6 do
            -- This loop exists only to keep the Lua VM busy and trigger the hook
            x = math.pow(i / (math.sqrt(i) * math.sin(i)), 5)
        end
        system.log.log({level="debug"},"step " .. i, x)
        --coroutine.yield() -- Simulate yielding in the task itself
    end
end
local function start_cash(uid)
    ---@type UserFS
    local ufs = UserFS:new(fs,uid)
    
    local function waitForAny(...)
        local procs = {}
        local curName = PROC[system.proc.curProc].name
        for key, value in ipairs({...}) do
            procs[key] = SYSCALL.fork(PROC[system.proc.curProc],curName.."_"..key,function()
                value()
                for index, value in ipairs(procs) do
                    SYSCALL.end_proc(nil,value)
                end
            end)
        end

    end
    local function ldFile(fname,env)
        local f,e = ufs.exec(fname)
        if e then
            error(e)
        end
        setfenv(f,env)
        return f
    end
    local k = {}
    setmetatable(k,{__index=function (t, k)
        return function(...)
            if SYSCALL[k] == nil then
                error(k.." unknown")
            end
            return SYSCALL[k](PROC[system.proc.curProc],...)
        end
    end})
    local e = {
        fs = ufs,
        coroutine=coroutine,
        parallel={waitForAny=waitForAny},
        textutils=textutils,
        os =system.os,
        kernel=k,
        keys = keys,
        loadfile=ldFile,
        read=system.read
    }
    setmetatable(e,{__index=_G})

    local f = fs:exec("/bin/cash.lua",0)
    local function F()
        system.log.log({level = "info"},"Starting Cash")
        f()
    end
    F = setfenv(F,e)
    f = setfenv(f,e)
    --F()
    return F

    --SYSCALL.shutdown(0)
end

local function USRMNG()
    local k = {}
    setmetatable(k,{__index=function (t, k)
        return function(...)
            if SYSCALL[k] == nil then
                error(k.." unknown")
            end
            return SYSCALL[k](PROC[system.proc.curProc],...)
        end
    end})
    local e = {
        coroutine=coroutine,
        textutils=textutils,
        os =system.os,
        kernel=k,
        keys = keys,
        
    }
    
    setmetatable(e,{__index=_G})

    function e.loadfile(fname,env)
        env = env or e
        local f,E = fs:exec(fname,0)
        if E then
            error(E)
        end
        setfenv(f,env)
        return f
    end
    
    coroutine.yield("SYSCALL","log",{{level="debug"},"User Manager starting"})
    
    local function F()
        ---@module "sync"
        local sync = loadfile("/lib/sync.lua")()
        kernel.procIPCReg("USRMNG")
        local q = sync:queue()
        while true do
            local d = q:pull()
            if d.data[1] == "confirm" then
                local u = users:user(d.data[2])
                d.lock:unlock(u.psswd == d.data[3])
            elseif d.data[1] == "shell" then
                d.lock:unlock(start_cash(d.data[2]))
            elseif d.data[1] == "lookup" then
                local found = false
                for key, value in pairs(users.users) do
                    if d.data[2] == value.name then
                        d.lock:unlock(key)
                        found = true
                        break
                    end
                end
                if not found then
                    d.lock:unlock(nil)    
                end
            else
                d.lock:unlock(nil)
            end
            
        end
    end
    F = setfenv(F,e)
    F()
    
end
local function execENV(f)
    local k = {}
    setmetatable(k,{__index=function (t, k)
        return function(...)
            if SYSCALL[k] == nil then
                error(k.." unknown")
            end
            return SYSCALL[k](PROC[system.proc.curProc],...)
        end
    end})
    local e = {
        coroutine=coroutine,
        textutils=textutils,
        os =system.os,
        kernel=k,
        keys = keys,
        read=system.read
    }
    
    setmetatable(e,{__index=_G})

    function e.loadfile(fname,env)
        env = env or e
        local f,E = fs:exec(fname,0)
        if E then
            error(E)
        end
        setfenv(f,env)
        return f
    end
    
    coroutine.yield("SYSCALL","log",{{level="debug"},"User Manager starting"})
    
    
    f = setfenv(f,e)
    return f
    
end



--#region thread
for key, value in pairs(fs:list("/dev/",0)) do
    system.log.log({level = "debug"},fs:getPermissions("/dev/"..value,0),value)
    
end
system.log.log({level = "info"},"threads starting")
system.log.log({level = "debug"},"system threads starting")
system.proc.sys.dev = SYSCALL.proc(0,deviceMng)
PROC[system.proc.sys.dev].name = "DEVMNG"

system.proc.sys.usr = SYSCALL.proc(0,USRMNG)
PROC[system.proc.sys.usr].name = "USRMNG"
system.proc.sys.login = SYSCALL.proc(0,execENV(fs:exec("/usr/bin/login.lua",0)))
PROC[system.proc.sys.login].name = "LOGIN"
system.log.log({level = "debug"},"system threads started")
--makeProc(task1)
--SYSCALL.fork(0,"FSMNG",FSMNG)
--SYSCALL.proc(0,task2)

system.bios.queueEvent("SYSTEM_STARTUP")
while true do
    local tEventData = { coroutine.yield() }
    local sEvent = tEventData[1]
    system.proc.qEvnt = true
    for key, value in pairs(PROC) do
        value:resume(sEvent, tEventData)
    end
    if system.proc.qEvnt then
        system.bios.queueEvent("_preempt_hook")
    end
end
--#endregion
panic("PANIX")
