local Headland = CpObject()

--- Create a headland from a base polygon. The headland is a new polygon, offset by width, that is, inside
--- of the base polygon.
---@param basePolygon cg.Polygon
---@param passNumber number of the headland pass, the outermost is 1
---@param width number
---@param outward boolean if true, the generated headland will be outside of the basePolygon, inside otherwise
function Headland:init(basePolygon, passNumber, width, outward)
    self.logger = cg.Logger('Headland ' .. passNumber or '')
    self.clockwise = basePolygon:isClockwise()
    self.logger:debug('start generating, base clockwise %s, width %.1f, outward: %s',
            self.clockwise, width, outward)
    if self.clockwise then
        -- to generate headland inside the polygon we need to offset the polygon to the right if
        -- the polygon is clockwise
        self.offsetVector = cg.Vector(0, -1)
        -- Dubins path types to use when changing to the next headland
        self.transitionPathTypes = { DubinsSolver.PathType.RSL, DubinsSolver.PathType.RSR }
    else
        self.offsetVector = cg.Vector(0, 1)
        self.transitionPathTypes = { DubinsSolver.PathType.LSR, DubinsSolver.PathType.LSL }
    end
    if outward then
        self.offsetVector = -self.offsetVector
    end
    self.recursionCount = 0
    ---@type cg.Polygon
    self.polygon = self:generate(basePolygon, width, 0)
    if self.polygon then
        self.polygon:calculateProperties()
        self.polygon:ensureMaximumEdgeLength(cg.cMaxEdgeLength, cg.cMaxDeltaAngleForMaxEdgeLength)
        self.polygon:calculateProperties()
        self.polygon:_removeLoops(basePolygon:isClockwise())
        self.logger:debug('polygon with %d vertices generated, area %.1f, cw %s',
                #self.polygon, self.polygon:getArea(), self.polygon:isClockwise())
        if #self.polygon < 3 then
            self.logger:warning('invalid headland, polygon too small (%d vertices)', #self.polygon)
            self.polygon = nil
        elseif self.polygon:isClockwise() ~= basePolygon:isClockwise() then
            self.polygon = nil
            self.logger:warning('no room left for this headland')
        end
    else
        self.logger:error('could not generate headland')
    end
end

--- Make sure all corners are rounded to have at least minimumRadius radius.
function Headland:roundCorners(minimumRadius)
    self.logger:debug('applying minimum radius %.1f', minimumRadius)
    self.polygon:ensureMinimumRadius(minimumRadius, false)
    self.polygon:calculateProperties()
end

--- Make sure all corners are rounded to have at least minimumRadius radius.
function Headland:sharpenCorners(minimumRadius)
    self.logger:debug('sharpen corners under radius %.1f', minimumRadius)
    self.polygon:ensureMinimumRadius(minimumRadius, true)
    self.polygon:calculateProperties()
end

function Headland:isValid()
    return self.polygon ~= nil
end

function Headland:getPolygon()
    return self.polygon
end

--- Vertices with coordinates unpacked, to draw with love.graphics.polygon
function Headland:getUnpackedVertices()
    if not self.unpackedVertices then
        self.unpackedVertices = self.polygon:getUnpackedVertices()
    end
    return self.unpackedVertices
end

function Headland:generate(polygon, targetOffset, currentOffset)
    -- done!
    if currentOffset >= targetOffset then
        return polygon
    end

    -- limit of the number of recursions based on how far we want to go
    self.recursionCount = self.recursionCount + 1
    if self.recursionCount > math.max(math.floor(targetOffset * 20), 600) then
        self.logger:error('Headland generation: recursion limit reached (%d)', self.recursionCount)
        return nil
    end
    -- we'll use the grassfire algorithm and approach the target offset by
    -- iteration, generating headland tracks close enough to the previous one
    -- so the resulting offset polygon can be kept clean (no intersecting edges)
    -- this can be ensured by choosing an offset small enough
    local deltaOffset = math.max(polygon:getShortestEdgeLength() / 8, 0.01)
    currentOffset = currentOffset + deltaOffset
    polygon = polygon:createOffset(deltaOffset * self.offsetVector, 1, false)
    if polygon == nil then
        return nil
    end
    polygon:ensureMinimumEdgeLength(cg.cMinEdgeLength)
    return self:generate(polygon, targetOffset, currentOffset)
end

function Headland:bypassIsland(island, circle)
    return self.polygon:goAround(island:getHeadlands()[1]:getPolygon(), nil, circle)
end

--- Generate a path to switch from this headland to the other, starting as close as possible to the
--- given vertex on this headland
---@param other cg.Headland
---@return number index of the vertex on other where the transition ends
function Headland:connectTo(other, ix, workingWidth, turningRadius)
    local function ignoreIslandBypass(v)
        return not v:getAttributes():getIslandBypass()
    end
    -- determine the theoretical minimum length of the transition (depending on the width and radius)
    local transitionLength = Headland._getTransitionLength(workingWidth, turningRadius)
    local transition = self:_continueUntilStraightSection(ix, transitionLength)
    -- index on the other polygon closest to the location where the transition will start
    local otherClosest = other:getPolygon():findClosestVertexToPoint(self.polygon:at(ix + #transition), ignoreIslandBypass)
    -- index on the other polygon where the transition will approximately end
    local transitionEndIx = other:getPolygon():moveForward(otherClosest.ix, transitionLength, ignoreIslandBypass)
    if transitionEndIx then
        -- try a few times to generate a Dubins path as depending on the orientation of the waypoints on
        -- the own headland and the next, we may need more room than the calculated, ideal transition length.
        -- In that case, the Dubins path generated will end up in a loop, so we use a target further ahead on the next headland.
        local tries = 5
        for i = 1, tries do
            local connector, length = cg.AnalyticHelper.getDubinsSolutionAsVertices(
                    self.polygon:at(ix + #transition):getExitEdge():getBaseAsState3D(),
                    other.polygon:at(transitionEndIx):getExitEdge():getBaseAsState3D(),
                    -- enable any path type on the very last try
                    turningRadius, i < tries and self.transitionPathTypes or nil)
            -- maximum length without loops
            local maxPlausiblePathLength = workingWidth + 4 * turningRadius
            if length < maxPlausiblePathLength or i == tries then
                -- the whole transition is the straight section on the current headland and the actual connector between
                -- the current and the next
                transition:appendMany(connector)
                self.polygon:appendMany(transition)
                self.polygon:_setAttributes(#self.polygon - #transition, #self.polygon,
                        cg.WaypointAttributes.setHeadlandTransition, true)
                self.polygon:calculateProperties()
                self.logger:debug('Transition to next headland added, length %.1f, ix on next %d, try %d.',
                        length, transitionEndIx, i)
                return transitionEndIx
            else
                self.logger:warning('Generated path to next headland too long (%.1f > %.1f), try %d.',
                        length, maxPlausiblePathLength, i)
            end
            transitionEndIx = transitionEndIx + 1
        end
        self.logger:error('Could not connect to next headland after %d tries, giving up', tries)
    else
        self.logger:warning('Could not connect to next headland, can\'t find transition end')
    end
    return nil
end

---@param ix number the vertex to start the search
---@param straightSectionLength number how long at the minimum the straight section should be
---@param searchRange number how far should the search for the straight section should go
---@return cg.Polyline array of vectors (can be empty) from ix to the start of the straight section
function Headland:_continueUntilStraightSection(ix, straightSectionLength, searchRange)
    local dTotal = 0
    local count = 0
    local waypoints = cg.Polyline()
    searchRange = searchRange or 100
    while dTotal < searchRange do
        dTotal = dTotal + self.polygon:at(ix):getExitEdge():getLength()
        local r = self.polygon:getSmallestRadiusWithinDistance(ix, straightSectionLength, 0)
        if r > NewCourseGenerator.headlandChangeMinRadius then
            self.logger:debug('Added %d waypoint(s) to reach a straight section for the headland change after %.1f m, r = %.1f',
                    count, dTotal, r)
            return waypoints
        end
        waypoints:append((self.polygon:at(ix)):clone())
        ix = ix + 1
        count = count + 1
    end
    -- no straight section found, bail out here
    self.logger:debug('No straight section found after %1.f m for headland change to next', dTotal)
    return waypoints
end

--- determine the theoretical minimum length of the transition from one headland to another
---(depending on the width and radius)
function Headland._getTransitionLength(workingWidth, turningRadius)
    local transitionLength
    if turningRadius - workingWidth / 2 < 0.1 then
        -- can make two half turns within the working width
        transitionLength = 2 * turningRadius
    else
        local alpha = math.abs(math.acos((turningRadius - workingWidth / 2) / turningRadius) / 2)
        transitionLength = 2 * workingWidth / 2 / math.tan(alpha)
    end
    return transitionLength
end

---@class cg.Headland
cg.Headland = Headland