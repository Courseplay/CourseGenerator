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
        if self.polygon:isClockwise() ~= basePolygon:isClockwise() then
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
function Headland:connectTo(other, ix, workingWidth, turningRadius)
    -- determine the theoretical minimum length of the transition (depending on the width and radius)
    local transitionLength = Headland._getTransitionLength(workingWidth, turningRadius)
    local transition = self:_continueUntilStraightSection(ix, transitionLength)
    -- index on the other polygon closest to the location where the transition will start
    local otherClosest = other:getPolygon():findClosestVertex(self.polygon:at(ix + #transition))
    -- index on the other polygon where the transition will approximately end
    local transitionEndIx = other:getPolygon():moveForward(otherClosest.ix, transitionLength + 1)
    if not transitionEndIx then
        self.logger:error('Could not connect to next headland, can\'t find transition end')
        return
    end
    local connector, length = cg.AnalyticHelper.getDubinsSolutionAsVertices(
            self.polygon:at(ix + #transition):getExitEdge():getBaseAsState3D(),
            other.polygon:at(transitionEndIx):getExitEdge():getBaseAsState3D(),
            turningRadius, self.transitionPathTypes)
    print(ix, #transition, otherClosest.ix, transitionEndIx, transitionLength, length, workingWidth + 1.5 * turningRadius)
    if true or length < workingWidth + 2 * turningRadius then
        transition:appendMany(connector)
        self.polygon:appendMany(transition)
        self.polygon:calculateProperties()
    else
        self.logger:error('Could generate path to next headland.')
    end
end

---@param ix number the vertex to start the search
---@param straightSectionLength number how long the straight section should be
---@return cg.Polyline array of vectors (can be empty) from ix to the start of the straight section
function Headland:_continueUntilStraightSection(ix, straightSectionLength)
    local dElapsed = 0
    local count = 0
    local waypoints = cg.Polyline()
    while dElapsed < straightSectionLength do
        dElapsed = dElapsed + self.polygon:at(ix):getExitEdge():getLength()
        local r = self.polygon:getSmallestRadiusWithinDistance(ix, straightSectionLength, 0)
        -- nice straight section, done
        if r > NewCourseGenerator.headlandChangeMinRadius then
            self.logger:debug('Added %d waypoint(s) to reach a straight section for the headland change after %.1f m, r = %.1f',
                    count, dElapsed, r)
            return waypoints
        end
        waypoints:append((self.polygon:at(ix)):clone())
        ix = ix + 1
        count = count + 1
    end
    -- no straight section found, bail out here
    self.logger:debug('No straight section found after %1.f m for headland change to next', dElapsed)
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