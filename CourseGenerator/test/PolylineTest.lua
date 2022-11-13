require('include')

---@type cg.Polyline
local p = cg.Polyline({cg.Vector(0, 0), cg.Vector(0, 1), cg.Vector(0, 2), cg.Vector(1, 2)})
lu.assertEquals(p[1], cg.Vector(0, 0))
lu.assertEquals(#p, 4)
p:append(cg.Vector(2, 2))
lu.assertEquals(p[5], cg.Vector(2, 2))
local e = p:calculateEdges()
lu.assertEquals(e[1], cg.LineSegment(0, 0, 0, 1))
lu.assertEquals(e[2], cg.LineSegment(0, 1, 0, 2))
lu.assertEquals(e[3], cg.LineSegment(0, 2, 1, 2))

p = cg.Polyline({cg.Vector(0, 0), cg.Vector(0, 1), cg.Vector(0, 2), cg.Vector(0, 3)})
local o = p:createOffset(cg.Vector(0, -1), 1, false)
o[1]:assertAlmostEquals(cg.Vector(1, 0))
o[2]:assertAlmostEquals(cg.Vector(1, 1))
o[3]:assertAlmostEquals(cg.Vector(1, 2))
o[4]:assertAlmostEquals(cg.Vector(1, 3))

o = p:createOffset(cg.Vector(0, 1), 1, false)
o[1]:assertAlmostEquals(cg.Vector(-1, 0))
o[2]:assertAlmostEquals(cg.Vector(-1, 1))
o[3]:assertAlmostEquals(cg.Vector(-1, 2))
o[4]:assertAlmostEquals(cg.Vector(-1, 3))

p = cg.Polyline({cg.Vector(0, 0), cg.Vector(1, 1), cg.Vector(2, 2), cg.Vector(3, 3)})
o = p:createOffset(cg.Vector(0, math.sqrt(2)), 1, false)
o[1]:assertAlmostEquals(cg.Vector(-1, 1))
o[2]:assertAlmostEquals(cg.Vector(0, 2))
o[3]:assertAlmostEquals(cg.Vector(1, 3))
o[4]:assertAlmostEquals(cg.Vector(2, 4))

-- inside corner
p = cg.Polyline({cg.Vector(0, 0), cg.Vector(0, 2), cg.Vector(2, 2)})
o = p:createOffset(cg.Vector(0, -1), 1, false)
o[1]:assertAlmostEquals(cg.Vector(1, 0))
o[2]:assertAlmostEquals(cg.Vector(1, 1))
o[3]:assertAlmostEquals(cg.Vector(2, 1))

-- outside corner, cut corner
o = p:createOffset(cg.Vector(0, 1), 1, false)
o[1]:assertAlmostEquals(cg.Vector(-1, 0))
o[2]:assertAlmostEquals(cg.Vector(-1, 2))
o[3]:assertAlmostEquals(cg.Vector(0, 3))
o[4]:assertAlmostEquals(cg.Vector(2, 3))

-- outside corner, preserve corner
o = p:createOffset(cg.Vector(0, 1), 1, true)
o[1]:assertAlmostEquals(cg.Vector(-1, 0))
o[2]:assertAlmostEquals(cg.Vector(-1, 3))
o[3]:assertAlmostEquals(cg.Vector(2, 3))

p = cg.Polyline({cg.Vector(0, 0), cg.Vector(0, 2), cg.Vector(0, 3), cg.Vector(0, 3.1), cg.Vector(0, 3.2), cg.Vector(0, 4)})
p:ensureMinimumEdgeLength(1)
p[1]:assertAlmostEquals(cg.Vector(0, 0))
p[2]:assertAlmostEquals(cg.Vector(0, 2))
p[3]:assertAlmostEquals(cg.Vector(0, 3))
p[4]:assertAlmostEquals(cg.Vector(0, 4))
