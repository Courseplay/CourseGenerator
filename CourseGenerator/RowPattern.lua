--- Given a number of rows (1-nRows), and a pattern, in what
--- sequence should these rows to be worked on.
local RowPattern = CpObject()

RowPattern.ALTERNATING = 1
RowPattern.SKIP = 2

--- An entry point into the pattern. The entry has a position and instructions to sequence the rows in
--- case this entry is selected.
--- Entries are always generated from a list of rows, the same list of rows what RowPattern:getPossibleEntries() or
--- RowPattern:iterator() expects.
RowPattern.Entry = CpObject()

---@param position cg.Vector the position of this entry point
---@param reverseRowOrder boolean this entry is on the last row, so when using this entry, the order of the rows should
--- be reversed before calling any RowPattern:iterator()
---@param reverseOddRows boolean this entry uses the last vertex of the row, so when iterating over the rows
--- with RowPattern:iterator, reverse the direction of the first and every odd row (otherwise the second and every
--- even row)
function RowPattern.Entry:init(position, reverseRowOrder, reverseOddRows)
    self.position = position
    self.reverseRowOrder = reverseRowOrder
    self.reverseOddRows = reverseOddRows
end

function RowPattern.Entry:__tostring()
    return string.format('[%s] reverseRowOrder:%s reverseOddRows %s',
            self.position, self.reverseRowOrder, self.reverseOddRows)
end

function RowPattern.create(pattern, ...)
    if pattern == cg.RowPattern.ALTERNATING then
        return cg.RowPatternAlternating(...)
    elseif pattern == cg.RowPattern.SKIP then
        return cg.RowPatternSkip(...)
    end
end

function RowPattern:init()
    self.logger = cg.Logger('RowPattern')
end

--- Iterate through rows in the sequence according to the pattern,
--- this default implementation returns them in their original order
---@param rows cg.Row[]
function RowPattern:iterator(rows)
    local i = 0
    return function()
        i = i + 1
        if i <= #rows then
            return i, rows[i]
        else
            return nil, nil
        end
    end
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

function RowPattern:__tostring()
    return 'default'
end

---@class cg.RowPattern
cg.RowPattern = RowPattern

--- Default alternating pattern
local RowPatternAlternating = CpObject(cg.RowPattern)
---@class cg.RowPatternAlternating : cg.RowPattern
cg.RowPatternAlternating = RowPatternAlternating

---@param rows cg.Row[]
---@return cg.RowPattern.Entry[] list of entries usable for this pattern
function RowPatternAlternating:getPossibleEntries(rows)
    local firstRow, lastRow = rows[1], rows[#rows]
    local entries = {
        cg.RowPattern.Entry(firstRow[1], false, false),
        cg.RowPattern.Entry(firstRow[#firstRow], false, true),
        cg.RowPattern.Entry(lastRow[1], true, false),
        cg.RowPattern.Entry(lastRow[#lastRow], true, true),
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

--- Skipping one or more rows
---@param rows cg.Row[] rows to work on
function RowPatternSkip:iterator(rows)
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

---@class cg.RowPatternSkip : cg.RowPattern
cg.RowPatternSkip = RowPatternSkip
