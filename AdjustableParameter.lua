---
--- A parameter that the user can adjust by pressing keys in LOVE
---

---@class AdjustableParameter
AdjustableParameter = CpObject()

function AdjustableParameter:init(value, up, down, step, lowerLimit, upperLimit)
	self.value = value
	self.up = up
	self.down = down
	self.step = step
	self.lowerLimit = lowerLimit
	self.upperLimit = upperLimit
end

function AdjustableParameter:onKey(key, callback)
	if key == self.up then
		self.value = math.min(self.upperLimit, self.value + self.step)
		callback()
	elseif key == self.down then
		self.value = math.max(self.lowerLimit, self.value - self.step)
		callback()
	end
end

function AdjustableParameter:get()
	return self.value
end