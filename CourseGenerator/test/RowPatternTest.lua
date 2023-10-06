require('include')
lu.EPS = 0.01
function testRowPatternSkip()
    local rows = {}
    local row = cg.Row(5, { cg.Vector(0, 1), cg.Vector(20, 1) })
    for _ = 1, 10 do
        table.insert(rows, row)
        row = row:createNext(1)
    end

    lu.assertEquals(#rows, 10)
    rows[1][1]:assertAlmostEquals(cg.Vector(0, 1))
    rows[5][1]:assertAlmostEquals(cg.Vector(0, 5))
    rows[10][1]:assertAlmostEquals(cg.Vector(0, 10))

    -----------------------------------------------------------------------------------
    local p = cg.RowPatternSkip(1)
    local orderedRows = {}
    for _, r in p:iterator(rows) do
        table.insert(orderedRows, r)
    end
    lu.assertEquals(#orderedRows, 10)
    orderedRows[1][1]:assertAlmostEquals(cg.Vector(0, 1))
    orderedRows[2][1]:assertAlmostEquals(cg.Vector(0, 3))
    orderedRows[3][1]:assertAlmostEquals(cg.Vector(0, 5))
    orderedRows[4][1]:assertAlmostEquals(cg.Vector(0, 7))
    orderedRows[5][1]:assertAlmostEquals(cg.Vector(0, 9))
    orderedRows[6][1]:assertAlmostEquals(cg.Vector(0, 10))
    orderedRows[7][1]:assertAlmostEquals(cg.Vector(0, 8))
    orderedRows[8][1]:assertAlmostEquals(cg.Vector(0, 6))
    orderedRows[9][1]:assertAlmostEquals(cg.Vector(0, 4))
    orderedRows[10][1]:assertAlmostEquals(cg.Vector(0, 2))

    local entries = p:getPossibleEntries(rows)
    lu.assertEquals(#entries, 8)
    entries[1].position:assertAlmostEquals(cg.Vector(0, 1))
    entries[2].position:assertAlmostEquals(cg.Vector(20, 1))
    entries[3].position:assertAlmostEquals(cg.Vector(0, 10))
    entries[4].position:assertAlmostEquals(cg.Vector(20, 10))
    entries[5].position:assertAlmostEquals(cg.Vector(0, 9))
    entries[6].position:assertAlmostEquals(cg.Vector(20, 9))
    entries[7].position:assertAlmostEquals(cg.Vector(0, 2))
    entries[8].position:assertAlmostEquals(cg.Vector(20, 2))

    local sequence, exit = p:getWorkSequenceAndExit(rows, entries[5])
    lu.assertEquals(sequence[1].rowIx, 9)
    lu.assertNil(sequence[1].reverse)
    lu.assertEquals(sequence[2].rowIx, 7)
    lu.assertTrue(sequence[2].reverse)
    lu.assertEquals(sequence[3].rowIx, 5)
    lu.assertEquals(sequence[4].rowIx, 3)
    lu.assertEquals(sequence[5].rowIx, 1)
    lu.assertEquals(sequence[6].rowIx, 2)
    lu.assertEquals(sequence[7].rowIx, 4)
    lu.assertEquals(sequence[8].rowIx, 6)
    lu.assertEquals(sequence[9].rowIx, 8)
    lu.assertEquals(sequence[10].rowIx, 10)
    exit:assertAlmostEquals(cg.Vector(0, 10))

    -----------------------------------------------------------------------------------

    p = cg.RowPatternSkip(2)
    orderedRows = {}
    for _, r in p:iterator(rows) do
        table.insert(orderedRows, r)
    end
    lu.assertEquals(#orderedRows, 10)
    orderedRows[1][1]:assertAlmostEquals(cg.Vector(0, 1))
    orderedRows[2][1]:assertAlmostEquals(cg.Vector(0, 4))
    orderedRows[3][1]:assertAlmostEquals(cg.Vector(0, 7))
    orderedRows[4][1]:assertAlmostEquals(cg.Vector(0, 10))
    orderedRows[5][1]:assertAlmostEquals(cg.Vector(0, 8))
    orderedRows[6][1]:assertAlmostEquals(cg.Vector(0, 5))
    orderedRows[7][1]:assertAlmostEquals(cg.Vector(0, 2))
    orderedRows[8][1]:assertAlmostEquals(cg.Vector(0, 3))
    orderedRows[9][1]:assertAlmostEquals(cg.Vector(0, 6))
    orderedRows[10][1]:assertAlmostEquals(cg.Vector(0, 9))

    entries = p:getPossibleEntries(rows)
    lu.assertEquals(#entries, 8)
    entries[1].position:assertAlmostEquals(cg.Vector(0, 1))
    entries[2].position:assertAlmostEquals(cg.Vector(20, 1))
    entries[3].position:assertAlmostEquals(cg.Vector(0, 10))
    entries[4].position:assertAlmostEquals(cg.Vector(20, 10))
    entries[5].position:assertAlmostEquals(cg.Vector(0, 2))
    entries[6].position:assertAlmostEquals(cg.Vector(20, 2))
    entries[7].position:assertAlmostEquals(cg.Vector(0, 9))
    entries[8].position:assertAlmostEquals(cg.Vector(20, 9))

    --------------------------------------------------------------------------------------
    table.insert(rows, rows[#rows]:createNext(1))
    --------------------------------------------------------------------------------------

    p = cg.RowPatternSkip(1)
    orderedRows = {}
    for _, r in p:iterator(rows) do
        table.insert(orderedRows, r)
    end
    lu.assertEquals(#orderedRows, 11)
    orderedRows[1][1]:assertAlmostEquals(cg.Vector(0, 1))
    orderedRows[2][1]:assertAlmostEquals(cg.Vector(0, 3))
    orderedRows[3][1]:assertAlmostEquals(cg.Vector(0, 5))
    orderedRows[4][1]:assertAlmostEquals(cg.Vector(0, 7))
    orderedRows[5][1]:assertAlmostEquals(cg.Vector(0, 9))
    orderedRows[6][1]:assertAlmostEquals(cg.Vector(0, 11))
    orderedRows[7][1]:assertAlmostEquals(cg.Vector(0, 10))
    orderedRows[8][1]:assertAlmostEquals(cg.Vector(0, 8))
    orderedRows[9][1]:assertAlmostEquals(cg.Vector(0, 6))
    orderedRows[10][1]:assertAlmostEquals(cg.Vector(0, 4))
    orderedRows[11][1]:assertAlmostEquals(cg.Vector(0, 2))

    entries = p:getPossibleEntries(rows)
    lu.assertEquals(#entries, 8)
    entries[1].position:assertAlmostEquals(cg.Vector(0, 1))
    entries[2].position:assertAlmostEquals(cg.Vector(20, 1))
    entries[3].position:assertAlmostEquals(cg.Vector(0, 11))
    entries[4].position:assertAlmostEquals(cg.Vector(20, 11))
    entries[5].position:assertAlmostEquals(cg.Vector(0, 10))
    entries[6].position:assertAlmostEquals(cg.Vector(20, 10))
    entries[7].position:assertAlmostEquals(cg.Vector(0, 2))
    entries[8].position:assertAlmostEquals(cg.Vector(20, 2))

    -----------------------------------------------------------------------------------

    p = cg.RowPatternSkip(2)
    orderedRows = {}
    for _, r in p:iterator(rows) do
        table.insert(orderedRows, r)
    end
    lu.assertEquals(#orderedRows, 11)
    orderedRows[1][1]:assertAlmostEquals(cg.Vector(0, 1))
    orderedRows[2][1]:assertAlmostEquals(cg.Vector(0, 4))
    orderedRows[3][1]:assertAlmostEquals(cg.Vector(0, 7))
    orderedRows[4][1]:assertAlmostEquals(cg.Vector(0, 10))
    orderedRows[5][1]:assertAlmostEquals(cg.Vector(0, 11))
    orderedRows[6][1]:assertAlmostEquals(cg.Vector(0, 8))
    orderedRows[7][1]:assertAlmostEquals(cg.Vector(0, 5))
    orderedRows[8][1]:assertAlmostEquals(cg.Vector(0, 2))
    orderedRows[9][1]:assertAlmostEquals(cg.Vector(0, 3))
    orderedRows[10][1]:assertAlmostEquals(cg.Vector(0, 6))
    orderedRows[11][1]:assertAlmostEquals(cg.Vector(0, 9))

    entries = p:getPossibleEntries(rows)
    lu.assertEquals(#entries, 8)
    entries[1].position:assertAlmostEquals(cg.Vector(0, 1))
    entries[2].position:assertAlmostEquals(cg.Vector(20, 1))
    entries[3].position:assertAlmostEquals(cg.Vector(0, 11))
    entries[4].position:assertAlmostEquals(cg.Vector(20, 11))
    entries[5].position:assertAlmostEquals(cg.Vector(0, 3))
    entries[6].position:assertAlmostEquals(cg.Vector(20, 3))
    entries[7].position:assertAlmostEquals(cg.Vector(0, 9))
    entries[8].position:assertAlmostEquals(cg.Vector(20, 9))
end

function testRowPatternExit()
    local rows = {}
    local row = cg.Row(5, { cg.Vector(0, 1), cg.Vector(20, 1) })
    for _ = 1, 10 do
        table.insert(rows, row)
        row = row:createNext(1)
    end
    local p = cg.RowPatternAlternating()
    local entries = p:getPossibleEntries(rows)
    entries[1].position:assertAlmostEquals(cg.Vector(0, 1))
    local _, exit = p:getWorkSequenceAndExit(rows, entries[1])
    exit:assertAlmostEquals(cg.Vector(0, 10))
    entries[2].position:assertAlmostEquals(cg.Vector(20, 1))
    _, exit = p:getWorkSequenceAndExit(rows, entries[2])
    exit:assertAlmostEquals(cg.Vector(20, 10))
    entries[3].position:assertAlmostEquals(cg.Vector(0, 10))
    _, exit = p:getWorkSequenceAndExit(rows, entries[3])
    exit:assertAlmostEquals(cg.Vector(0, 1))

    -- odd number of rows
    rows = {}
    row = cg.Row(5, { cg.Vector(0, 1), cg.Vector(20, 1) })
    for _ = 1, 3 do
        table.insert(rows, row)
        row = row:createNext(1)
    end
    p = cg.RowPatternAlternatingFirstRowEntryOnly()
    entries = p:getPossibleEntries(rows)
    entries[1].position:assertAlmostEquals(cg.Vector(0, 1))
    _, exit = p:getWorkSequenceAndExit(rows, entries[1])
    exit:assertAlmostEquals(cg.Vector(20, 3))
    entries[2].position:assertAlmostEquals(cg.Vector(20, 1))
    _, exit = p:getWorkSequenceAndExit(rows, entries[2])
    exit:assertAlmostEquals(cg.Vector(0, 3))
end

os.exit(lu.LuaUnit.run())