--- Given a number of rows (1-nRows), and a pattern, in what
--- sequence should these rows to be worked on.
local RowPattern = CpObject()

RowPattern.ALTERNATING = 1
RowPattern.SKIP = 2
RowPattern.SPIRAL = 3

function RowPattern.create(pattern, ...)
    if pattern == cg.RowPattern.ALTERNATING then
        return cg.RowPatternAlternating(...)
    elseif pattern == cg.RowPattern.SKIP then
        return cg.RowPatternSkip(...)
    elseif pattern == cg.RowPattern.SPIRAL then
        return cg.RowPatternSpiral(...)
    end
end

function RowPattern:init()
    self.logger = cg.Logger('RowPattern')
end

--- Generate a sequence in which the rows must be worked on. It is just an array
--- with the original row numbers, first element of the array is the index of the
--- row the works starts with, last element is the index of the row to finish the
--- work with.
--- We assume that in iterator() we receive a contiguous list of rows.
--- this default implementation leaves them in the original order (which is what
--- the alternating pattern uses)
function RowPattern:_generateSequence(nRows)
    self.sequence = {}
    for i = 1, nRows do
        table.insert(self.sequence, i)
    end
    return self.sequence
end

--- Iterate through rows in the order they need to be worked on.
---@param rows cg.Row[] rows to work on
function RowPattern:iterator(rows)
    local i = 0
    local sequence = self:_generateSequence(#rows)
    return function()
        i = i + 1
        if i <= #rows then
            return i, rows[sequence[i]]
        else
            return nil, nil
        end
    end
end

--- Iterate through rows in the sequence according to the generated sequence,
---@param rows cg.Row[]
function RowPattern:__tostring()
    return 'default'
end

--- Get the possible entries to this pattern. If we have block with up/down rows, in theory, we can use any end of
--- the first or last row to enter the pattern, work through the pattern, and exit at the opposite end.
--- Which of the four possible ends are valid, and, if a given entry is selected, which will be the exit, depends
--- on the pattern and the number of rows.
---@param rows cg.Row[]
---@return cg.RowPattern.Entry[] list of entries that can be used to enter this pattern
function RowPattern:getPossibleEntries(rows)
    return {}
end

---@class cg.RowPattern
cg.RowPattern = RowPattern

--- An entry point into the pattern. The entry has a position and instructions to sequence the rows in
--- case this entry is selected.
--- Entries are always generated from a list of rows, the same list of rows what RowPattern:getPossibleEntries() or
--- RowPattern:iterator() expects.
RowPattern.Entry = CpObject()

---@param position cg.Vector the position of this entry point
---@param reverseRowOrderBefore boolean this entry is on the last row (of the rows passed in to getPossibleEntries(),
--- so when using this entry, the order of the rows should be reversed _before_ calling any RowPattern:iterator()
---@param reverseRowOrderAfter boolean this entry would be on the last row after the rows passed in to getPossibleEntries()
--- are reordered, so when using this entry, the order of the rows must be reversed _after_ calling any RowPattern:iterator()
---@param reverseOddRows boolean this entry uses the last vertex of the row, so when iterating over the rows
--- with RowPattern:iterator, reverse the direction of the first and every odd row (otherwise the second and every
--- even row)
function RowPattern.Entry:init(position, reverseRowOrderBefore, reverseRowOrderAfter, reverseOddRows)
    self.position = position
    self.reverseRowOrderBefore = reverseRowOrderBefore
    self.reverseRowOrderAfter = reverseRowOrderAfter
    self.reverseOddRows = reverseOddRows
end

function RowPattern.Entry:__tostring()
    return string.format('[%s] reverseRowOrderBefore/After:%s/%s reverseOddRows %s',
            self.position, self.reverseRowOrderBefore, self.reverseRowOrderAfter, self.reverseOddRows)
end

---@class cg.RowPattern.Entry
cg.RowPattern.Entry = RowPattern.Entry

--- Default alternating pattern
local RowPatternAlternating = CpObject(cg.RowPattern)
---@class cg.RowPatternAlternating : cg.RowPattern
cg.RowPatternAlternating = RowPatternAlternating

--- An alternating pattern can be started at either end of the first or last row
---@param rows cg.Row[]
---@return cg.RowPattern.Entry[] list of entries usable for this pattern
function RowPatternAlternating:getPossibleEntries(rows)
    local firstRow, lastRow = rows[1], rows[#rows]
    local entries = {
        cg.RowPattern.Entry(firstRow[1], false, false, false),
        cg.RowPattern.Entry(firstRow[#firstRow], false, false, true),
        cg.RowPattern.Entry(lastRow[1], true, false, false),
        cg.RowPattern.Entry(lastRow[#lastRow], true, false, true),
    }
    return entries
end

function RowPatternAlternating:__tostring()
    return 'alternating'
end

--- Skipping one or more rows
local RowPatternSkip = CpObject(cg.RowPattern)

---@param nRowsToSkip number number of rows to skip
---@param leaveSkippedRowsUnworked boolean if true, sequence will finish after it reaches the last row, leaving
--- the skipped rows unworked. Otherwise, it will work on the skipped rows backwards to the beginning, and then
--- back and forth until all rows are covered.
function RowPatternSkip:init(nRowsToSkip, leaveSkippedRowsUnworked)
    cg.RowPattern.init(self)
    self.nRowsToSkip = nRowsToSkip
    self.leaveSkippedRowsUnworked = leaveSkippedRowsUnworked
end

---@param rows cg.Row[]
---@return cg.RowPattern.Entry[] list of entries usable for this pattern
function RowPatternSkip:getPossibleEntries(rows)
    local sequence = self:_generateSequence(#rows)
    self.logger:debug('%d rows, first row is %d, last %d', #rows, sequence[1], sequence[#sequence])
    local firstRowBefore, lastRowBefore = rows[1], rows[#rows]
    -- last row when we start at either end of rows[1]
    local lastRowAfter = rows[sequence[#sequence]]
    -- last row whe we start at either end of rows[#rows]
    local lastRowAfterReversed = rows[#rows - sequence[#sequence] + 1]
    local entries = {
        -- we can start at either end of the first or the last row
        cg.RowPattern.Entry(firstRowBefore[1], false, false, false),
        cg.RowPattern.Entry(firstRowBefore[#firstRowBefore], false, false, true),
        cg.RowPattern.Entry(lastRowBefore[1], true, false, false),
        cg.RowPattern.Entry(lastRowBefore[#lastRowBefore], true, false, true),
        -- as opposed to the alternating pattern, where all four entry points are also
        -- exits (on the diagonally opposite corner), where do we exit when using one of the
        -- above entries, depends on the total number of rows and the number of rows skipped
        -- now, we can also drive the whole patern in the opposite direction, that is what
        -- these entries are for.
        cg.RowPattern.Entry(lastRowAfterReversed[1], true, true, false),
        cg.RowPattern.Entry(lastRowAfterReversed[#lastRowAfterReversed], true, true, true),
        cg.RowPattern.Entry(lastRowAfter[1], false, true, false),
        cg.RowPattern.Entry(lastRowAfter[#lastRowAfter], false, true, true),
    }
    return entries
end

function RowPatternSkip:__tostring()
    return 'skip'
end

function RowPatternSkip:_generateSequence(nRows)
    self.sequence = {}
    local workedRows = {}
    local lastWorkedRow
    local done = false
    -- need to work on this until all rows are covered
    while (#self.sequence < nRows) and not done do
        -- find first non-worked row
        local start = 1
        while workedRows[start] do
            start = start + 1
        end
        for i = start, nRows, self.nRowsToSkip + 1 do
            table.insert(self.sequence, i)
            workedRows[i] = true
            lastWorkedRow = i
        end
        -- if we don't want to work on the skipped rows, we are done here
        if self.leaveSkippedRowsUnworked then
            done = true
        else
            -- now work on the skipped rows if that is desired
            -- we reached the last Row, now turn back and work on the
            -- rest, find the last unworked Row first
            for i = lastWorkedRow + 1, 1, -(self.nRowsToSkip + 1) do
                if (i <= nRows) and not workedRows[i] then
                    table.insert(self.sequence, i)
                    workedRows[i] = true
                end
            end
        end
    end
    return self.sequence
end

---@class cg.RowPatternSkip : cg.RowPattern
cg.RowPatternSkip = RowPatternSkip

--- A spiral pattern, clockwise or not, starting from inside or outside
local RowPatternSpiral = CpObject(RowPattern)

---@param clockwise boolean direction to travel the spiral
---@param fromInside boolean if true, start in the middle and continue outwards. If false,
--- start from one of the outermost rows and continue inwards
function RowPatternSpiral:init(clockwise, fromInside)
    cg.RowPattern.init(self)
    self.clockwise = clockwise
    self.fromInside = fromInside
end

function RowPatternSpiral:__tostring()
    return 'spiral'
end

function RowPatternSpiral:_generateSequence(nRows)
    self.sequence = {}
    -- sequence from outside
    for i = 1, math.floor(nRows / 2) do
        table.insert(self.sequence, i)
        table.insert(self.sequence, nRows - i + 1)
    end
    if nRows % 2 ~= 0 then
        table.insert(self.sequence, math.ceil(nRows / 2))
    end
    if self.fromInside then
        -- flip if starting from the inside
        cg.reverseArray(self.sequence)
    end
    return self.sequence
end

---@param rows cg.Row[]
---@return cg.RowPattern.Entry[] list of entries usable for this pattern
function RowPatternSpiral:getPossibleEntries(rows)
    local sequence = self:_generateSequence(#rows)
    local odd = #rows % 2 ~= 0
    local firstRow = rows[sequence[1]]
    local secondRow = rows[sequence[2]]
    -- normalize rows, making sure the second (and all other) row are on the
    -- right side of the first row when looking into the row's direction
    -- this makes life easier later as reduces the number of combinations we need to think about.
    if firstRow[1]:getExitEdge():isLeft(secondRow[1]) then
        self.logger:debug('normalizing rows')
        for _, row in ipairs(rows) do
            row:reverse()
        end
    end
    self.logger:debug('from inside %s, clockwise %s, odd %s', self.fromInside, self.clockwise, odd)
    if self.fromInside then
        if self.clockwise then
            -- from inside, clockwise
            if odd then
                return {
                    cg.RowPattern.Entry(firstRow[1], false, false, false)
                }
            else
                return {
                    cg.RowPattern.Entry(firstRow[#firstRow], true, false, true),
                }
            end
        else
            -- from inside, counterclockwise
            if odd then
                return {
                    cg.RowPattern.Entry(firstRow[#firstRow], false, false, true)
--                    cg.RowPattern.Entry(firstRow[1], false, false, false),
                }
            else
                return {
                    -- if there is only one row we can enter either end of it
                    secondRow and cg.RowPattern.Entry(secondRow[1], true, false, false) or
                            cg.RowPattern.Entry(firstRow[1], false, false, false),
                }
            end

        end
    else
        if self.clockwise then
            -- from outside, clockwise
            return {
                cg.RowPattern.Entry(firstRow[1], false, false, false),
                -- if there is only one row we can enter either end of it
                secondRow and cg.RowPattern.Entry(secondRow[#secondRow], true, false, true) or
                        cg.RowPattern.Entry(firstRow[#firstRow], false, false, true),

            }
        else
            -- from outside, counterclockwise
            return {
                cg.RowPattern.Entry(firstRow[#firstRow], false, false, true),
                -- if there is only one row we can enter either end of it
                secondRow and cg.RowPattern.Entry(secondRow[1], true, false, false) or
                        cg.RowPattern.Entry(firstRow[1], false, false, false),
            }
        end
    end
    -- phuu. that was a long one ...
end

---@class cg.RowPatternSpiral : RowPattern
cg.RowPatternSpiral = RowPatternSpiral