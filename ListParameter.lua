---
--- A parameter with a list of string values that the user can adjust by pressing keys in LOVE
---

---@class ListParameter
ListParameter = CpObject()

function ListParameter:init(current, name, up, down, values, names)
	self.current = current
	self.name = name
	self.up = up
	self.down = down
	self.values = values
	self.names = names
end

function ListParameter:onKey(key, callback)
	if key == self.up then
		self.current = self.current + 1
		self.current = self.current > #self.values and 1 or self.current
	elseif key == self.down then
		self.current = self.current - 1
		self.current = self.current < 1 and #self.values or self.current
	end
	callback()
end

function ListParameter:get()
	return self.values[self.current]
end

---@return table to use with love.graphics.print()
function ListParameter:toColoredText(nameColor, keyColor, valueColor)
	return {nameColor, self.name, keyColor, string.format(' (%s/%s): ', self.down, self.up),
			valueColor, self.values[self.current]}
end

function ListParameter:__tostring()
	return string.format('%s (%s/%s): %s', self.name, self.down, self.up, self.names[self.current])
end