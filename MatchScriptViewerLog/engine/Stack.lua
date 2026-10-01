local addonName, ns = ...

-- ENGINE/STACK — pile minimale (remplace la classe Ace de l'original).

ns.Engine = ns.Engine or {}
local Stack = {}
ns.Engine.Stack = Stack
Stack.__index = Stack

function Stack.New()
    return setmetatable({ stack = {} }, Stack)
end

function Stack:Push(item)
    if item ~= nil then
        tinsert(self.stack, 1, item)
    end
end

function Stack:Pop()
    return table.remove(self.stack, 1)
end

function Stack:Top()
    return self.stack[1]
end
