require('include')

---@type cg.Polyline
local p = cg.Polyline({cg.Vertex(0, 0), cg.Vertex(0, 1), cg.Vertex(0, 2), cg.Vertex(1, 2)})
lu.assertEquals(p[1], cg.Vertex(0, 0))
lu.assertEquals(#p, 4)
p:append(cg.Vertex(2, 2))
lu.assertEquals(p[5], cg.Vertex(2, 2))
local e = p:calculateEdges()
lu.assertEquals(e[1], cg.LineSegment(0, 0, 0, 1))
lu.assertEquals(e[2], cg.LineSegment(0, 1, 0, 2))
lu.assertEquals(e[3], cg.LineSegment(0, 2, 1, 2))

-- index
lu.assertIsNil(p[0])
lu.assertIsNil(p[-1])
lu.assertIsNil(p[#p + 1])

p = cg.Polyline({cg.Vertex(0, 0), cg.Vertex(0, 1), cg.Vertex(0, 2), cg.Vertex(0, 3)})
local o = p:createOffset(cg.Vertex(0, -1), 1, false)
o[1]:assertAlmostEquals(cg.Vertex(1, 0))
o[2]:assertAlmostEquals(cg.Vertex(1, 1))
o[3]:assertAlmostEquals(cg.Vertex(1, 2))
o[4]:assertAlmostEquals(cg.Vertex(1, 3))

o = p:createOffset(cg.Vertex(0, 1), 1, false)
o[1]:assertAlmostEquals(cg.Vertex(-1, 0))
o[2]:assertAlmostEquals(cg.Vertex(-1, 1))
o[3]:assertAlmostEquals(cg.Vertex(-1, 2))
o[4]:assertAlmostEquals(cg.Vertex(-1, 3))

p = cg.Polyline({cg.Vertex(0, 0), cg.Vertex(1, 1), cg.Vertex(2, 2), cg.Vertex(3, 3)})
o = p:createOffset(cg.Vertex(0, math.sqrt(2)), 1, false)
o[1]:assertAlmostEquals(cg.Vertex(-1, 1))
o[2]:assertAlmostEquals(cg.Vertex(0, 2))
o[3]:assertAlmostEquals(cg.Vertex(1, 3))
o[4]:assertAlmostEquals(cg.Vertex(2, 4))

-- inside corner
p = cg.Polyline({cg.Vertex(0, 0), cg.Vertex(0, 2), cg.Vertex(2, 2)})
o = p:createOffset(cg.Vertex(0, -1), 1, false)
o[1]:assertAlmostEquals(cg.Vertex(1, 0))
o[2]:assertAlmostEquals(cg.Vertex(1, 1))
o[3]:assertAlmostEquals(cg.Vertex(2, 1))

-- outside corner, cut corner
o = p:createOffset(cg.Vertex(0, 1), 1, false)
o[1]:assertAlmostEquals(cg.Vertex(-1, 0))
o[2]:assertAlmostEquals(cg.Vertex(-1, 2))
o[3]:assertAlmostEquals(cg.Vertex(0, 3))
o[4]:assertAlmostEquals(cg.Vertex(2, 3))

-- outside corner, preserve corner
o = p:createOffset(cg.Vertex(0, 1), 1, true)
o[1]:assertAlmostEquals(cg.Vertex(-1, 0))
o[2]:assertAlmostEquals(cg.Vertex(-1, 3))
o[3]:assertAlmostEquals(cg.Vertex(2, 3))

p = cg.Polyline({cg.Vertex(0, 0), cg.Vertex(0, 2), cg.Vertex(0, 3), cg.Vertex(0, 3.1), cg.Vertex(0, 3.2), cg.Vertex(0, 4)})
p:ensureMinimumEdgeLength(1)
p[1]:assertAlmostEquals(cg.Vertex(0, 0))
p[2]:assertAlmostEquals(cg.Vertex(0, 2))
p[3]:assertAlmostEquals(cg.Vertex(0, 3))
p[4]:assertAlmostEquals(cg.Vertex(0, 4))

lu.EPS = 0.01
p = cg.Polyline({cg.Vertex(0, 0), cg.Vertex(5, 0), cg.Vertex(10, 5), cg.Vertex(10, 10)})
p:calculateProperties()
lu.assertIsNil(p[1]:getEntryEdge())
p[1]:getExitEdge():assertAlmostEquals(cg.LineSegment(0, 0, 5, 0))
p[4]:getEntryEdge():assertAlmostEquals(cg.LineSegment(10, 5, 10, 10))
lu.assertIsNil(p[4]:getExitEdge())
lu.assertAlmostEquals(p:getRadiusAt(1), 5)
lu.assertAlmostEquals(p:getRadiusAt(2), 5)
lu.assertEquals(p:getRadiusAt(3), math.huge)

p = cg.Polyline({cg.Vertex(0, 0), cg.Vertex(5, 0), cg.Vertex(10, 5), cg.Vertex(10, 10), cg.Vertex(10, 15)})
p:calculateProperties()
lu.assertAlmostEquals(p[1]:getDistance(), 0)
lu.assertAlmostEquals(p[2]:getDistance(), 5)
lu.assertAlmostEquals(p[3]:getDistance(), 5 + math.sqrt(2) * 5)
lu.assertAlmostEquals(p[4]:getDistance(), 10 + math.sqrt(2) * 5)
lu.assertAlmostEquals(p[5]:getDistance(), 15 + math.sqrt(2) * 5)
lu.assertIsNil(p[1]:getEntryEdge())
p[1]:getExitEdge():assertAlmostEquals(cg.LineSegment(0, 0, 5, 0))
p[4]:getEntryEdge():assertAlmostEquals(cg.LineSegment(10, 5, 10, 10))
p[4]:getExitEdge():assertAlmostEquals(cg.LineSegment(10, 10, 10, 15))
lu.assertIsNil(p[5]:getExitEdge())
lu.assertAlmostEquals(p:getRadiusAt(1), 5)
lu.assertAlmostEquals(p:getRadiusAt(2), 5)
lu.assertAlmostEquals(p:getRadiusAt(3), 12.07)
lu.assertEquals(p:getRadiusAt(4), math.huge)


p = cg.Polyline({cg.Vertex(0, 0), cg.Vertex(0, 5), cg.Vertex(0, 10), cg.Vertex(5, 10), cg.Vertex(10, 10), cg.Vertex(15, 10), cg.Vertex(20, 10)})
p:calculateProperties()
lu.assertAlmostEquals(p[1]:getEntryHeading(), math.pi / 2)
lu.assertAlmostEquals(p[#p]:getExitHeading(), 0)
lu.assertAlmostEquals(p[3]:getRadius(), -3.53)