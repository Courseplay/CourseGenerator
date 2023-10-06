--- These functions help to create curved paths, especially rows 
--- following a (curved) edge of a field.

---@class CurvedPathHelper
local CurvedPathHelper = {}

local logger = cg.Logger('CurvedPathHelper')

---@param boundary cg.Polygon the boundary, usually headland or virtual headland. Rows must cover the area within the
--- boundary - working width / 2
---@param baselineLocation cg.Vector the field edge closest to this location will be the one the generated rows follow
---@param nRows number how many rows to generate. If not given, keep generating until the area
--- within boundary is covered.
function CurvedPathHelper.generateCurvedUpDownRows(boundary, baselineLocation, workingWidth, turningRadius, nRows)
    local rows = {}
    nRows = nRows or 300
    local function getIntersectionsExtending(row)
        local intersections, extensions = {}, 0
        repeat
            intersections = row:getIntersections(boundary, 1)
            local evenNumberOfIntersections = #intersections % 2 == 0
            if #intersections < 2 or not evenNumberOfIntersections then
                row:extendStart(50)
                row:extendEnd(50)
                extensions = extensions + 1
            end
        until (#intersections > 1 and evenNumberOfIntersections) or extensions > 3
        if #intersections > 1 and extensions > 0 then
            logger:debug('Row %d extended to intersect boundary', #rows + 1)
        elseif #intersections < 2 then
            logger:debug('Row %d could not be extended to intersect boundary (tries: %d)', #rows + 1, extensions)
        end
        return intersections
    end

    --- Create a baseline for the up/down rows, which is not necessarily straight, instead, it follows a section
    --- of the field boundary. This way some odd-shaped fields can be covered with less turns.
    local closest = boundary:findClosestVertexToPoint(baselineLocation or boundary:at(1))
    local baseline = cg.Row(workingWidth)
    CurvedPathHelper.findLongestStraightSection(boundary, closest.ix, turningRadius, baseline)

    baseline:extendStart(50)
    baseline:extendEnd(50)
    -- always generate inwards
    local offset = boundary:isClockwise() and -workingWidth or workingWidth
    local row, intersections = baseline
    repeat
        row = row:createNext(offset)
        intersections = getIntersectionsExtending(row)
        table.insert(rows, row)
    until #rows >= nRows or #intersections < 2
    return rows
end

---@param boundary cg.Polyline
---@param ix number the vertex of the boundary to start the search at
---@param radiusThreshold number straight section ends when the radius is under this threshold
---@param section cg.Row empty row passed in to hold the straight section around ix
---@return cg.Row the straight section as a row, same object as passed in as the section
function CurvedPathHelper.findLongestStraightSection(boundary, ix, radiusThreshold, section)
    local i = ix
    while math.abs(boundary:at(i):getRadius()) > radiusThreshold do
        section:append((boundary:at(i)):clone())
        i = i - 1
    end
    section:reverse()
    i = ix + 1
    while math.abs(boundary:at(i):getRadius()) > radiusThreshold do
        section:append((boundary:at(i)):clone())
        i = i + 1
    end
    section:calculateProperties()
    -- no straight section found, bail out here
    logger:debug('Longest straight section found %d vertices, %.1f m', #section, section:getLength())
    cg.addDebugPolyline(section)
    return section
end

---@class cg.CurvedPathHelper
cg.CurvedPathHelper = CurvedPathHelper