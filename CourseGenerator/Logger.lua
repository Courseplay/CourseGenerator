local Logger = CpObject()

Logger.level = {
    error = 1,
    warning = 2,
    debug = 3,
    trace = 4
}

function Logger:init(debugPrefix, level)
    self.debugPrefix = debugPrefix
    self.logLevel = level or Logger.level.debug
end

function Logger:setLevel(level)
    self.logLevel = math.max(Logger.level.error, math.min(Logger.level.trace, level))
end

function Logger:debug(...)
    if self.logLevel >= Logger.level.debug then
        cg.debug(self.debugPrefix .. ': ' .. string.format(...))
    end
end

function Logger:trace(...)
    if self.logLevel >= Logger.level.trace then
        cg.debug(self.debugPrefix .. ': ' .. string.format(...))
    end
end

---@class cg.Logger
cg.Logger = Logger