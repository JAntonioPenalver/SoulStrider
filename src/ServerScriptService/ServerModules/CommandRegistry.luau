local CommandRegistry = {}
CommandRegistry.Commands = {}

function CommandRegistry.Register(name, func)
    CommandRegistry.Commands[string.lower(name)] = func
end

function CommandRegistry.Execute(player, cmd, msg)
    cmd = string.lower(tostring(cmd or ""))
    local func = CommandRegistry.Commands[cmd]
    if func then
        func(player, tostring(msg or ""))
    end
end

return CommandRegistry
