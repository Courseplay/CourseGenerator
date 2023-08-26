---
--- A parameter that the user can adjust by pressing keys in LOVE
---

---@class AdjustableParameter
AdjustableParameter = CpObject()

function AdjustableParameter:init(value, name, up, down, step, lowerLimit, upperLimit)
	self.value = value
	self.name = name
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

---@return table to use with love.graphics.print()
function AdjustableParameter:toColoredText(nameColor, keyColor, valueColor)
	return {nameColor, self.name, keyColor, string.format(' (%s/%s): ', self.down, self.up),
			valueColor, string.format('%.1f', self.value)}
end


function AdjustableParameter:__tostring()
	return string.format('%s (%s/%s): %.1f', self.name, self.down, self.up, self.value)
end