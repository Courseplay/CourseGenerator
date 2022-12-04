---
--- A parameter that the user can adjust by pressing keys in LOVE
---

---@class ToggleParameter
ToggleParameter = CpObject()

function ToggleParameter:init(name, value, toggle)
    self.name = name
    self.value = value
    self.toggle = toggle
end

function ToggleParameter:onKey(key, callback)
    if key == self.toggle then
        self.value = not self.value
        callback()
    end
end

function ToggleParameter:get()
    return self.value
end

function ToggleParameter:__tostring()
    return string.format('%s (%s): %s', self.name, self.toggle, self.value)
end