
---@class Field
local Field = CpObject()

function Field:init(id)
	self.id = id
	---@type cg.Polygon
	self.boundary = cg.Polygon()
	---@type cg.Polygon
	self.islandNodes = cg.Polygon()
end

function Field:getId()
	return self.id
end

--- Read all fields saved in an XML file from the game console with the cpSaveAllFields command
---@return Field[] list of Fields in the file
function Field.loadSavedFields(fileName)
	local fields = {}
	local ix = 0
	for line in io.lines(fileName) do
		local fieldNum = string.match( line, '<field fieldNum="([%d%.-]+)"' )
		if fieldNum then
			-- a new field started
			ix = tonumber( fieldNum )
			fields[ix] = Field(ix)
			cg.debug('Loading field %d', ix)
		end
		local num, x, z = string.match( line, '<point(%d+).+pos="([%d%.-]+) [%d%.-]+ ([%d%.-]+)"' )
		if num then
			fields[ ix ].boundary:append(cg.Vector(tonumber(x), -tonumber(z)))
		end
		num, x, z = string.match( line, '<islandNode(%d+).+pos="([%d%.-]+) +([%d%.-]+)"' )
		if num then
			fields[ix].islandNodes:append(cg.Vector(tonumber(x ), -tonumber(z)))
		end
	end
	return fields
end

--- Center of the field (centroid)
---@return cg.Vector
function Field:getCenter()
	if not self.center then
		self.center = self.boundary:getCenter()
	end
	cg.debug('Center of field %d is %.1f/%.1f', self.id, self.center.x, self.center.y)
	return self.center
end

--- Bounding box
function Field:getBoundingBox()
	return self.boundary:getBoundingBox()
end

---@return Polygon
function Field:getBoundary()
	return self.boundary
end

--- Vertices with coordinates unpacked, to draw with love.graphics.polygon
function Field:getUnpackedVertices()
	if not self.unpackedVertices then
		self.unpackedVertices = self.boundary:getUnpackedVertices()
	end
	return self.unpackedVertices
end

---@class cg.Field
cg.Field = Field