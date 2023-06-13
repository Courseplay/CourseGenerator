---
--- A parameter that the user can adjust by pressing keys in LOVE
---

---@class ToggleParameter
ToggleParameter = CpObject()

---@param noCallback boolean|nil if true, just change the value, do not call the callback, for instance, a parameter
--- which does not require the course to be regenerated because only affects the display
function ToggleParameter:init(name, value, toggle, noCallback)
    self.name = name
    self.value = value
    self.toggle = toggle
    self.noCallback = noCallback
end

function ToggleParameter:onKey(key, callback)
    if key == self.toggle then
        self.value = not self.value
        if not self.noCallback then
            callback()
        end
    end
end

function ToggleParameter:get()
    return self.value
end

function ToggleParameter:__tostring()
    return string.format('%s (%s): %s', self.name, self.toggle, self.value)
end