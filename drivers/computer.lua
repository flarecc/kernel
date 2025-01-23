return {
    name = "root",
    type = "!",
    properties = {
        "label",
        "id"
    },
    methods = {
        getLabel = function(node, process) return os.getComputerLabel() end,
        setLabel = function(node, process, label) os.setComputerLabel(label)end,
        getId = function(node, process) return os.getComputerID() end,
        shutdown = function(node, process) end,
        reboot = function(node, process) end
    },
    init = function(node,device)
        -- initialize node
        device.id = os.getComputerID()
        device.label = os.getComputerLabel()
        system.addDevice("label",function(op, data)
            if op == "write" then
                os.setComputerLabel(data)
                return nil
            elseif op == "read" then
                return os.getComputerLabel()
            end
        end)
    end,
    deinit = function(node)
        -- deinitialize node
        system.removeDevice("label")
    end
}