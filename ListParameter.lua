---
--- A parameter with a list of string values that the user can adjust by pressing keys in LOVE
---

---@class ListParameter
ListParameter = CpObject()

function ListParameter:init(current, name, up, down, values)
	self.current = current
	self.name = name
	self.up = up
	self.down = down
	self.values = values
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

function ListParameter:__tostring()
	return string.format('%s (%s/%s): %s', self.name, self.down, self.up, self:get())
end