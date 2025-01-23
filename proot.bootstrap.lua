function panic(ae)
    term.setBackgroundColor(32768)
    term.setTextColor(16384)
    term.setCursorBlink(false)
    local p, q = term.getCursorPos()
    p = 1
    local af, ag = term.getSize()
    ae = "panic: " .. (ae or "unknown")
    for ah in ae:gmatch "%S+" do
        if p + #ah >= af then
            p, q = 1, q + 1
            if q > ag then
                term.scroll(1)
                q = q - 1
            end
        end
        term.setCursorPos(p, q)
        if p == 1 then term.clearLine() end
        term.write(ah .. " ")
        p = p + #ah + 1
    end
    p, q = 1, q + 1
    if q > ag then
        term.scroll(1)
        q = q - 1
    end
    if debug then
        local ai = debug.traceback(nil, 2)
        for aj in ai:gmatch "[^\n]+" do
            term.setCursorPos(1, q)
            term.write(aj)
            q = q + 1
            if q > ag then
                term.scroll(1)
                q = q - 1
            end
        end
    end
    term.setCursorPos(1, q)
    term.setTextColor(2)
    term.write("panic: We are hanging here...")
    mainThread = nil
    while true do coroutine.yield() end
end
xpcall(function ()
    local ofs = fs
    local expect,textutils,toastfs

    function loadfile(filename, mode, env)
        -- Support the previous `loadfile(filename, env)` form instead.
        if type(mode) == "table" and env == nil then
            mode, env = nil, mode
        end

        expect(1, filename, "string")
        expect(2, mode, "string", "nil")
        expect(3, env, "table", "nil")

        local file = ofs.open(filename, "r")
        if not file then return nil, "File not found" end

        local func, err = load(file.readAll(), "@/" .. ofs.combine(filename), mode, env)
        file.close()
        return func, err
    end

    function dofile(_sFile)
        expect(1, _sFile, "string")

        local fnFile, e = loadfile(_sFile, nil, _G)
        if fnFile then
            return fnFile()
        else
            error(e, 2)
        end
    end

    do
        local h = fs.open("rom/modules/main/cc/expect.lua", "r")
        local f, err = (_VERSION == "Lua 5.1" and loadstring or load)(h.readAll(), "@/rom/modules/main/cc/expect.lua")
        h.close()

        if not f then error(err) end
        expect = f()
    end
    do
        local h = fs.open("/proot/txtUtil.lua", "r")
        local f, err = (_VERSION == "Lua 5.1" and loadstring or load)(h.readAll(), "@/rom/apis/textutils.lua")
        h.close()

        if not f then error(err) end
        textutils = f()
    end
    function setfenv(fn, env)
        if not debug then error("could not set environment", 2) end
        if type(fn) == "number" then fn = debug.getinfo(fn + 1, "f").func end
        local i = 1
        while true do
            local name = debug.getupvalue(fn, i)
            if name == "_ENV" then
                debug.upvaluejoin(fn, i, (function()
                    return env
                end), 1)
                break
            elseif not name then
                break
            end

            i = i + 1
        end

        return fn
    end

    local function writeANSI(nativewrite)
        return function(str)
            local seq = nil
            local bold = false
            local lines = 0
            local function getnum(d) 
                if seq == "[" then return d or 1
                elseif string.find(seq, ";") then return 
                    tonumber(string.sub(seq, 2, string.find(seq, ";") - 1)), 
                    tonumber(string.sub(seq, string.find(seq, ";") + 1)) 
                else return tonumber(string.sub(seq, 2)) end 
            end
            for c in string.gmatch(str, ".") do
                if seq == "\27" then
                    if c == "c" then
                        term.setBackgroundColor(0x8000)
                        term.setTextColor(1)
                        term.setCursorBlink(true)
                    elseif c == "[" then seq = "["
                    else seq = nil end
                elseif seq ~= nil and string.sub(seq, 1, 1) == "[" then
                    if tonumber(c) ~= nil or c == ';' then seq = seq .. c else
                        
                        if c == "A" then term.setCursorPos(term.getCursorPos(), select(2, term.getCursorPos()) - getnum())
                        elseif c == "B" then term.setCursorPos(term.getCursorPos(), select(2, term.getCursorPos()) + getnum())
                        elseif c == "C" then term.setCursorPos(term.getCursorPos() + getnum(), select(2, term.getCursorPos()))
                        elseif c == "D" then term.setCursorPos(term.getCursorPos() - getnum(), select(2, term.getCursorPos()))
                        elseif c == "E" then term.setCursorPos(1, select(2, term.getCursorPos()) + getnum())
                        elseif c == "F" then term.setCursorPos(1, select(2, term.getCursorPos()) - getnum())
                        elseif c == "G" then term.setCursorPos(getnum(), select(2, term.getCursorPos()))
                        elseif c == "H" then term.setCursorPos(getnum())
                        elseif c == "J" then term.clear() -- ?
                        elseif c == "K" then term.clearLine() -- ?
                        elseif c == "T" then term.scroll(getnum())
                        elseif c == "f" then term.setCursorPos(getnum())
                        elseif c == "m" then
                            local n, m = getnum(0)
                            if n == 0 then
                                term.setBackgroundColor(0x8000)
                                term.setTextColor(1)
                            elseif n == 1 then bold = true
                            elseif n == 7 or n == 27 then
                                local bg = term.getBackgroundColor()
                                term.setBackgroundColor(term.getTextColor())
                                term.setTextColor(bg)
                            elseif n == 22 then bold = false
                            elseif n >= 30 and n <= 37 then term.setTextColor(2^(15 - (n - 30) - (bold and 8 or 0)))
                            elseif n == 39 then term.setTextColor(1)
                            elseif n >= 40 and n <= 47 then term.setBackgroundColor(2^(15 - (n - 40) - (bold and 8 or 0)))
                            elseif n == 49 then term.setBackgroundColor(0x8000) 
                            elseif n >= 90 and n <= 97 then
                                
                                term.setTextColor(2^(15 - (n - 90) - 8))
                            elseif n >= 100 and n <= 107 then term.setBackgroundColor(2^(15 - (n - 100) - 8))
                            end
                            if m ~= nil then
                                if m == 0 then
                                    term.setBackgroundColor(0x8000)
                                    term.setTextColor(1)
                                elseif m == 1 then bold = true
                                elseif m == 7 or m == 27 then
                                    local bg = term.getBackgroundColor()
                                    term.setBackgroundColor(term.getTextColor())
                                    term.setTextColor(bg)
                                elseif m == 22 then bold = false
                                elseif m >= 30 and m <= 37 then term.setTextColor(2^(15 - (m - 30) - (bold and 8 or 0)))
                                elseif m == 39 then term.setTextColor(1)
                                elseif m >= 40 and m <= 47 then term.setBackgroundColor(2^(15 - (m - 40) - (bold and 8 or 0)))
                                elseif m == 49 then term.setBackgroundColor(0x8000) 
                                elseif n >= 90 and n <= 97 then term.setTextColor(2^(15 - (n - 90) - 8))
                                elseif n >= 100 and n <= 107 then term.setBackgroundColor(2^(15 - (n - 100) - 8)) end
                            end
                        elseif c == "z" then
                            local n, m = getnum(0)
                            if n == 0 then
                                term.setBackgroundColor(0x8000)
                                term.setTextColor(1)
                            elseif n == 7 or n == 27 then
                                local bg = term.getBackgroundColor()
                                term.setBackgroundColor(term.getTextColor())
                                term.setTextColor(bg)
                            elseif n >= 25 and n <= 39 then term.setTextColor(n-25)
                            elseif n >= 40 and n <= 56 then term.setBackgroundColor(n-40)
                            end
                            if m ~= nil then
                                if m == 0 then
                                    term.setBackgroundColor(0x8000)
                                    term.setTextColor(1)
                                elseif m == 7 or m == 27 then
                                    local bg = term.getBackgroundColor()
                                    term.setBackgroundColor(term.getTextColor())
                                    term.setTextColor(bg)
                                elseif m >= 25 and m <= 39 then term.setTextColor(m-25)
                                elseif m >= 40 and m <= 56 then term.setBackgroundColor(m-40)
                            end
                        end
                        end
                        seq = nil
                    end
                elseif c == string.char(0x1b) then seq = "\27"
                else lines = lines + (nativewrite(c) or 0) end
            end
            return lines
        end
    end

    local function intrnl_write(sText)
        expect(1, sText, "string", "number")

        local w, h = term.getSize()
        local x, y = term.getCursorPos()

        local nLinesPrinted = 0
        local function newLine()
            if y + 1 <= h then
                term.setCursorPos(1, y + 1)
            else
                term.setCursorPos(1, h)
                term.scroll(1)
            end
            x, y = term.getCursorPos()
            nLinesPrinted = nLinesPrinted + 1
        end

        -- Print the line with proper word wrapping
        sText = tostring(sText)
        while #sText > 0 do
            local whitespace = string.match(sText, "^[ \t]+")
            if whitespace then
                -- Print whitespace
                term.write(whitespace)
                x, y = term.getCursorPos()
                sText = string.sub(sText, #whitespace + 1)
            end

            local newline = string.match(sText, "^\n")
            if newline then
                -- Print newlines
                newLine()
                sText = string.sub(sText, 2)
            end

            local text = string.match(sText, "^[^ \t\n]+")
            if text then
                sText = string.sub(sText, #text + 1)
                if #text > w then
                    -- Print a multiline word
                    while #text > 0 do
                        if x > w then
                            newLine()
                        end
                        term.write(text)
                        text = string.sub(text, w - x + 2)
                        x, y = term.getCursorPos()
                    end
                else
                    -- Print a word normally
                    if x + #text - 1 > w then
                        newLine()
                    end
                    term.write(text)
                    x, y = term.getCursorPos()
                end
            end
        end

        return nLinesPrinted
    end

    write = writeANSI(intrnl_write)



    function print(...)
        local nLinesPrinted = 0
        local nLimit = select("#", ...)
        for n = 1, nLimit do
            local s = tostring(select(n, ...))
            if n < nLimit then
                s = s .. "\t"
            end
            nLinesPrinted = nLinesPrinted + write(s)
        end
        nLinesPrinted = nLinesPrinted + write("\n")
        return nLinesPrinted
    end

    function printError(...)
        local oldColour
        if term.isColour() then
            oldColour = term.getTextColour()
            term.setTextColour(colors.red)
        end
        print(...)
        if term.isColour() then
            term.setTextColour(oldColour)
        end
    end

    function printWarning(...)
        local oldColour
        if term.isColour() then
            oldColour = term.getTextColour()
            term.setTextColour(colors.yellow)
        end
        print(...)
        if term.isColour() then
            term.setTextColour(oldColour)
        end
    end

    print("Bootstrapping OS file system")

    

    toastfs = dofile("/proot/tfs.lua")
    local FS = toastfs:new()
    FS:loadFromDisk("/proot/fs.img")
    FS:saveToDisk("/proot/fs.img")
    print("OS")
    local t,e = FS:list("/boot/",0)
    print(e)
    for key, value in pairs(t) do
        print(FS:Permissions("/boot/"..value,0),value)
        
    end
    --local wfs = FS:exec("/lib/wrapperFS.lua",0)()
    --fs =wfs:new(FS)
    fs = FS
    
    --FS.root.dev.permissions[0] = 7
    if fs:isDir("/lib") then
        print("The /lib directory exists")
    else
        print("The /lib directory does not exist")
    end
    local f,e = FS:exec("/boot/kern.lua",0)
    print(e)
    
    --f = setfenv(f,{fs=FS,_ENV})
    print(f())
    panic()
end,panic)
panic("OS")