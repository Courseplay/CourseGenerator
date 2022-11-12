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
lu.assertIsTrue(o[1]:almostEquals(cg.Vector(1, 0)))
lu.assertIsTrue(o[2]:almostEquals(cg.Vector(1, 1)))
lu.assertIsTrue(o[3]:almostEquals(cg.Vector(1, 2)))
lu.assertIsTrue(o[4]:almostEquals(cg.Vector(1, 3)))

o = p:createOffset(cg.Vector(0, 1), 1, false)
lu.assertIsTrue(o[1]:almostEquals(cg.Vector(-1, 0)))
lu.assertIsTrue(o[2]:almostEquals(cg.Vector(-1, 1)))
lu.assertIsTrue(o[3]:almostEquals(cg.Vector(-1, 2)))
lu.assertIsTrue(o[4]:almostEquals(cg.Vector(-1, 3)))

p = cg.Polyline({cg.Vector(0, 0), cg.Vector(1, 1), cg.Vector(2, 2), cg.Vector(3, 3)})
o = p:createOffset(cg.Vector(0, math.sqrt(2)), 1, false)
lu.assertIsTrue(o[1]:almostEquals(cg.Vector(-1, 1)))
lu.assertIsTrue(o[2]:almostEquals(cg.Vector(0, 2)))
lu.assertIsTrue(o[3]:almostEquals(cg.Vector(1, 3)))
lu.assertIsTrue(o[4]:almostEquals(cg.Vector(2, 4)))

-- inside corner
p = cg.Polyline({cg.Vector(0, 0), cg.Vector(0, 2), cg.Vector(2, 2)})
o = p:createOffset(cg.Vector(0, -1), 1, false)
lu.assertIsTrue(o[1]:almostEquals(cg.Vector(1, 0)))
lu.assertIsTrue(o[2]:almostEquals(cg.Vector(1, 1)))
lu.assertIsTrue(o[3]:almostEquals(cg.Vector(2, 1)))

-- outside corner, cut corner
o = p:createOffset(cg.Vector(0, 1), 1, false)
lu.assertIsTrue(o[1]:almostEquals(cg.Vector(-1, 0)))
lu.assertIsTrue(o[2]:almostEquals(cg.Vector(-1, 2)))
lu.assertIsTrue(o[3]:almostEquals(cg.Vector(0, 3)))
lu.assertIsTrue(o[4]:almostEquals(cg.Vector(2, 3)))

-- outside corner, preserve corner
o = p:createOffset(cg.Vector(0, 1), 1, true)
lu.assertIsTrue(o[1]:almostEquals(cg.Vector(-1, 0)))
lu.assertIsTrue(o[2]:almostEquals(cg.Vector(-1, 3)))
lu.assertIsTrue(o[3]:almostEquals(cg.Vector(2, 3)))
