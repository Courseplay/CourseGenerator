require('include')

---@type cg.Polyline
local p = cg.Polyline({cg.Vertex(0, 0), cg.Vertex(0, 1), cg.Vertex(0, 2), cg.Vertex(1, 2)})
lu.assertEquals(p[1], cg.Vertex(0, 0))
lu.assertEquals(#p, 4)
lu.assertEquals(p:getLength(), 3)
p:append(cg.Vertex(2, 2))
p:calculateProperties()
lu.assertEquals(p:getLength(), 4)
lu.assertEquals(p[5], cg.Vertex(2, 2))
local e = {}
for _, edge in p:edges() do
    table.insert(e, edge)
end
lu.assertEquals(e[1], cg.LineSegment(0, 0, 0, 1))
lu.assertEquals(e[2], cg.LineSegment(0, 1, 0, 2))
lu.assertEquals(e[3], cg.LineSegment(0, 2, 1, 2))

e = {}
for _, edge in p:edgesBackwards() do
    table.insert(e, edge)
end
lu.assertEquals(e[1], cg.LineSegment(2, 2, 1, 2))
lu.assertEquals(e[2], cg.LineSegment(1, 2, 0, 2))
lu.assertEquals(e[3], cg.LineSegment(0, 2, 0, 1))


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


p = cg.Polyline({cg.Vertex(0, 0), cg.Vertex(0, 5), cg.Vertex(0, 10), cg.Vertex(5, 10), cg.Vertex(10, 10), cg.Vertex(15, 10), cg.Vertex(20, 10)})
p:calculateProperties()
lu.assertAlmostEquals(p[1]:getEntryHeading(), math.pi / 2)
lu.assertAlmostEquals(p[#p]:getExitHeading(), 0)

lu.EPS = 0.01
-- straight
p = cg.Polyline({cg.Vertex(0, 0), cg.Vertex(0, 6)})
p:ensureMaximumEdgeLength(5, math.rad(45))
lu.assertEquals(#p, 3)
p[1]:getExitEdge():assertAlmostEquals(cg.LineSegment(0, 0, 0, 3))
p:ensureMaximumEdgeLength(5, math.rad(45))
lu.assertEquals(#p, 3)
-- left turn
p = cg.Polyline({cg.Vertex(-1, 0), cg.Vertex(0, 0), cg.Vertex(5, 5)})
p:ensureMaximumEdgeLength(5, math.rad(46))
lu.assertEquals(#p, 4)
p[3]:assertAlmostEquals(cg.Vector(3.27, 1.35))
-- right turn
p = cg.Polyline({cg.Vertex(-1, 0), cg.Vertex(0, 0), cg.Vertex(5, -5)})
p:ensureMaximumEdgeLength(5, math.rad(46))
lu.assertEquals(#p, 4)
p[3]:assertAlmostEquals(cg.Vector(3.27, -1.35))
-- limit
p = cg.Polyline({cg.Vertex(-1, 0), cg.Vertex(0, 0), cg.Vertex(5, -5)})
p:ensureMaximumEdgeLength(5, math.rad(45))
lu.assertEquals(#p, 4)
p[3]:assertAlmostEquals(cg.Vector(2.5, -2.5))
p = cg.Polyline({cg.Vertex(-1, 0), cg.Vertex(0, 0), cg.Vertex(5, 5)})
p:ensureMaximumEdgeLength(5, math.rad(45))
lu.assertEquals(#p, 4)
p[3]:assertAlmostEquals(cg.Vector(2.5, 2.5))

-- getNextIntersection()
p = cg.Polyline({cg.Vertex(-5, 0), cg.Vertex(0, 0), cg.Vertex(5, 0)})
o = cg.Polyline({cg.Vertex(1, 1), cg.Vertex(1, -1)})
local x, y, is, path = p:getNextIntersection(o)
is:assertAlmostEquals(cg.Vector(1, 0))
o = cg.Polyline({cg.Vertex(0, 1), cg.Vertex(0, -1)})
x, y, is = p:getNextIntersection(o)
is:assertAlmostEquals(cg.Vector(0, 0))
o = cg.Polyline({cg.Vertex(-5, 1), cg.Vertex(-2, -1), cg.Vertex(0, 1), cg.Vertex(3, -1)})
x, y, is = p:getNextIntersection(o, 2)
is:assertAlmostEquals(cg.Vector(1.5, 0))
x, y, is, path = p:getNextIntersection(o, 2, true)
is:assertAlmostEquals(cg.Vector(-3.5, 0))

-- _getPathBetween()
p = cg.Polyline({cg.Vertex(0, 0), cg.Vertex(0, 5), cg.Vertex(0, 10), cg.Vertex(5, 10), cg.Vertex(10, 10), cg.Vertex(15, 10), cg.Vertex(20, 10)})
o = p:_getPathBetween(1, 2)
lu.assertEquals(#o, 1)
o[1]:assertAlmostEquals(p[2])
o = p:_getPathBetween(2, 4)
lu.assertEquals(#o, 2)
o[1]:assertAlmostEquals(p[3])
o[2]:assertAlmostEquals(p[4])

o = p:_getPathBetween(2, 1)
lu.assertEquals(#o, 1)
o[1]:assertAlmostEquals(p[2])
o = p:_getPathBetween(4, 2)
lu.assertEquals(#o, 2)
o[1]:assertAlmostEquals(p[4])
o[2]:assertAlmostEquals(p[3])


-- getIntersections()
p = cg.Polyline({cg.Vertex(-5, 0), cg.Vertex(0, 0), cg.Vertex(5, 0)})
o = cg.Polyline({cg.Vertex(3, -1), cg.Vertex(0, 1), cg.Vertex(-2, -1),  cg.Vertex(-5, 1)})
local iss = p:getIntersections(o)
is = iss[1]
lu.assertEquals(is.ixA, 1)
lu.assertEquals(is.ixB, 3)
is.is:assertAlmostEquals(cg.Vector(-3.5, 0))
is.edgeA:assertAlmostEquals(cg.LineSegment(-5, 0, 0, 0))
is = iss[2]
lu.assertEquals(is.ixA, 1)
lu.assertEquals(is.ixB, 2)
is.is:assertAlmostEquals(cg.Vector(-1, 0))
is.edgeA:assertAlmostEquals(cg.LineSegment(-5, 0, 0, 0))
is = iss[3]
lu.assertEquals(is.ixA, 2)
lu.assertEquals(is.ixB, 1)
is.is:assertAlmostEquals(cg.Vector(1.5, 0))
is.edgeA:assertAlmostEquals(cg.LineSegment(0, 0, 5, 0))
-- same intersections just different index on o (b)
o = cg.Polyline({cg.Vertex(-5, 1), cg.Vertex(-2, -1), cg.Vertex(0, 1), cg.Vertex(3, -1)})
iss = p:getIntersections(o)
is = iss[1]
lu.assertEquals(is.ixA, 1)
lu.assertEquals(is.ixB, 1)
is.is:assertAlmostEquals(cg.Vector(-3.5, 0))
is.edgeA:assertAlmostEquals(cg.LineSegment(-5, 0, 0, 0))
is = iss[2]
lu.assertEquals(is.ixA, 1)
lu.assertEquals(is.ixB, 2)
is.is:assertAlmostEquals(cg.Vector(-1, 0))
is.edgeA:assertAlmostEquals(cg.LineSegment(-5, 0, 0, 0))
is = iss[3]
lu.assertEquals(is.ixA, 2)
lu.assertEquals(is.ixB, 3)
is.is:assertAlmostEquals(cg.Vector(1.5, 0))
is.edgeA:assertAlmostEquals(cg.LineSegment(0, 0, 5, 0))
-- goAround()
-- disable smoothing so assertions are easier
local minSmoothingAngle = cg.cMinSmoothingAngle
cg.cMinSmoothingAngle = math.huge
p:goAround(o)
p[1]:assertAlmostEquals(cg.Vector(-5, 0))
p[2]:assertAlmostEquals(cg.Vector(-3.5, 0))
p[3]:assertAlmostEquals(cg.Vector(-2, -1))
p[4]:assertAlmostEquals(cg.Vector(-1, 0))
p[6]:assertAlmostEquals(cg.Vector(5, 0))

p = cg.Polyline({cg.Vertex(-5, 0), cg.Vertex(0, 0), cg.Vertex(5, 0)})
-- same line just from the other direction should result in the same go around path
o = cg.Polyline({cg.Vertex(3, -1), cg.Vertex(0, 1), cg.Vertex(-2, -1),  cg.Vertex(-5, 1)})
p:goAround(o)
p[1]:assertAlmostEquals(cg.Vector(-5, 0))
p[2]:assertAlmostEquals(cg.Vector(-3.5, 0))
p[3]:assertAlmostEquals(cg.Vector(-2, -1))
p[4]:assertAlmostEquals(cg.Vector(-1, 0))
p[6]:assertAlmostEquals(cg.Vector(5, 0))
-- restore smoothing angle to re-enable smoothing
cg.cMinSmoothingAngle = minSmoothingAngle
