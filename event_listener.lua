EventListener = {}
EventListener.__index = EventListener

function EventListener:new()
    local instance = setmetatable({}, self)

    instance.eventFrame = CreateFrame("Frame")
    instance.events = {}

    instance.eventFrame:SetScript("OnEvent", function(_, event, ...)
        instance:onEvent(event, ...)
    end)

    return instance
end

function EventListener:on(event, callback)
    self.eventFrame:RegisterEvent(event)

    self.events[event] = function(...)
        callback(self, event, ...)
    end
end

function EventListener:onEvent(event, ...)
    if (self.events[event]) then
        self.events[event](...)
    end
end
