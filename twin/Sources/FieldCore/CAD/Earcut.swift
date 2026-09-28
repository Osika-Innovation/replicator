import Foundation

/// Polygon-with-holes triangulation by ear clipping with hole bridging and a
/// z-order hash — a Swift port of the algorithm in Mapbox `earcut` (ISC
/// licence, © Mapbox; algorithm by V. Agafonkin). Nodes live in flat arrays
/// rather than as class instances, so a plate face with ~400 holes and ~7k
/// vertices triangulates without reference-counting traffic.
///
/// The machine's plate faces are the reason this exists: a disc carrying a
/// 380-site sunflower field, twelve spiral slots and a bore is one polygon
/// with ~390 holes, and it has to come out as a watertight cap that shares
/// its vertices with the hole walls.
public enum Earcut {

    /// Triangulate `outer` with `holes`. Returns index triples into the
    /// concatenation `outer + holes[0] + holes[1] + ...`. Winding of the
    /// output is not guaranteed; callers orient triangles to their face.
    public static func triangulate(outer: [P2], holes: [[P2]] = []) -> [Int32] {
        var data: [P2] = outer
        var holeStarts: [Int] = []
        for h in holes where h.count >= 3 {
            holeStarts.append(data.count)
            data.append(contentsOf: h)
        }
        var e = Engine(data: data)
        return e.run(outerLen: outer.count, holeStarts: holeStarts)
    }

    struct Engine {
        let data: [P2]
        // node storage
        var vi: [Int32] = []           // vertex index into data
        var nx: [Double] = [], ny: [Double] = []
        var prev: [Int32] = [], next: [Int32] = []
        var pz: [Int32] = [], nz: [Int32] = []
        var z: [Int32] = []
        var steiner: [Bool] = []
        var tris: [Int32] = []
        var minX = 0.0, minY = 0.0, invSize = 0.0

        init(data: [P2]) {
            self.data = data
            let cap = data.count * 2 + 16
            vi.reserveCapacity(cap); nx.reserveCapacity(cap); ny.reserveCapacity(cap)
            prev.reserveCapacity(cap); next.reserveCapacity(cap)
            pz.reserveCapacity(cap); nz.reserveCapacity(cap); z.reserveCapacity(cap)
            steiner.reserveCapacity(cap)
        }

        mutating func newNode(_ i: Int32, _ x: Double, _ y: Double) -> Int32 {
            vi.append(i); nx.append(x); ny.append(y)
            prev.append(-1); next.append(-1); pz.append(-1); nz.append(-1)
            z.append(0); steiner.append(false)
            return Int32(vi.count - 1)
        }

        mutating func insertNode(_ i: Int32, _ x: Double, _ y: Double, _ last: Int32) -> Int32 {
            let p = newNode(i, x, y)
            if last < 0 {
                prev[Int(p)] = p; next[Int(p)] = p
            } else {
                let ln = next[Int(last)]
                next[Int(p)] = ln
                prev[Int(p)] = last
                prev[Int(ln)] = p
                next[Int(last)] = p
            }
            return p
        }

        mutating func removeNode(_ p: Int32) {
            let pp = prev[Int(p)], pn = next[Int(p)]
            prev[Int(pn)] = pp
            next[Int(pp)] = pn
            if pz[Int(p)] >= 0 { nz[Int(pz[Int(p)])] = nz[Int(p)] }
            if nz[Int(p)] >= 0 { pz[Int(nz[Int(p)])] = pz[Int(p)] }
        }

        @inline(__always) func equals(_ a: Int32, _ b: Int32) -> Bool {
            nx[Int(a)] == nx[Int(b)] && ny[Int(a)] == ny[Int(b)]
        }

        @inline(__always) func area(_ p: Int32, _ q: Int32, _ r: Int32) -> Double {
            (ny[Int(q)] - ny[Int(p)]) * (nx[Int(r)] - nx[Int(q)])
                - (nx[Int(q)] - nx[Int(p)]) * (ny[Int(r)] - ny[Int(q)])
        }

        func signedAreaRange(_ start: Int, _ end: Int) -> Double {
            var sum = 0.0
            var j = end - 1
            for i in start..<end {
                sum += (data[j].x - data[i].x) * (data[i].y + data[j].y)
                j = i
            }
            return sum
        }

        mutating func linkedList(_ start: Int, _ end: Int, clockwise: Bool) -> Int32 {
            var last: Int32 = -1
            if clockwise == (signedAreaRange(start, end) > 0) {
                for i in start..<end {
                    last = insertNode(Int32(i), data[i].x, data[i].y, last)
                }
            } else {
                for i in stride(from: end - 1, through: start, by: -1) {
                    last = insertNode(Int32(i), data[i].x, data[i].y, last)
                }
            }
            if last >= 0 && equals(last, next[Int(last)]) {
                let n = next[Int(last)]
                removeNode(last)
                last = n
            }
            return last
        }

        mutating func filterPoints(_ start: Int32, _ endIn: Int32 = -1) -> Int32 {
            if start < 0 { return start }
            var end = endIn < 0 ? start : endIn
            var p = start
            var again: Bool
            repeat {
                again = false
                if !steiner[Int(p)] && (equals(p, next[Int(p)])
                        || area(prev[Int(p)], p, next[Int(p)]) == 0) {
                    let pp = prev[Int(p)]
                    removeNode(p)
                    p = pp; end = pp
                    if p == next[Int(p)] { break }
                    again = true
                } else {
                    p = next[Int(p)]
                }
            } while again || p != end
            return end
        }

        mutating func run(outerLen: Int, holeStarts: [Int]) -> [Int32] {
            var outer = linkedList(0, outerLen, clockwise: true)
            if outer < 0 || next[Int(outer)] == prev[Int(outer)] { return [] }
            if !holeStarts.isEmpty {
                outer = eliminateHoles(holeStarts, outer)
            }
            if data.count > 80 {
                var x0 = data[0].x, y0 = data[0].y, x1 = x0, y1 = y0
                for i in 0..<outerLen {
                    x0 = min(x0, data[i].x); y0 = min(y0, data[i].y)
                    x1 = max(x1, data[i].x); y1 = max(y1, data[i].y)
                }
                minX = x0; minY = y0
                let s = max(x1 - x0, y1 - y0)
                invSize = s != 0 ? 32767 / s : 0
            }
            earcutLinked(outer, pass: 0)
            return tris
        }

        mutating func earcutLinked(_ earIn: Int32, pass: Int) {
            var ear = earIn
            if ear < 0 { return }
            if pass == 0 && invSize != 0 { indexCurve(ear) }
            var stop = ear
            while prev[Int(ear)] != next[Int(ear)] {
                let pv = prev[Int(ear)], nv = next[Int(ear)]
                if invSize != 0 ? isEarHashed(ear) : isEar(ear) {
                    tris.append(vi[Int(pv)]); tris.append(vi[Int(ear)]); tris.append(vi[Int(nv)])
                    removeNode(ear)
                    ear = next[Int(nv)]
                    stop = next[Int(nv)]
                    continue
                }
                ear = nv
                if ear == stop {
                    if pass == 0 {
                        earcutLinked(filterPoints(ear), pass: 1)
                    } else if pass == 1 {
                        let e = cureLocalIntersections(filterPoints(ear))
                        earcutLinked(e, pass: 2)
                    } else if pass == 2 {
                        splitEarcut(ear)
                    }
                    break
                }
            }
        }

        func isEar(_ ear: Int32) -> Bool {
            let a = prev[Int(ear)], b = ear, c = next[Int(ear)]
            if area(a, b, c) >= 0 { return false }
            let ax = nx[Int(a)], bx = nx[Int(b)], cx = nx[Int(c)]
            let ay = ny[Int(a)], by = ny[Int(b)], cy = ny[Int(c)]
            let x0 = min(ax, bx, cx), y0 = min(ay, by, cy)
            let x1 = max(ax, bx, cx), y1 = max(ay, by, cy)
            var p = next[Int(c)]
            while p != a {
                let px = nx[Int(p)], py = ny[Int(p)]
                if px >= x0 && px <= x1 && py >= y0 && py <= y1
                    && Engine.pointInTriangle(ax, ay, bx, by, cx, cy, px, py)
                    && area(prev[Int(p)], p, next[Int(p)]) >= 0 { return false }
                p = next[Int(p)]
            }
            return true
        }

        func isEarHashed(_ ear: Int32) -> Bool {
            let a = prev[Int(ear)], b = ear, c = next[Int(ear)]
            if area(a, b, c) >= 0 { return false }
            let ax = nx[Int(a)], bx = nx[Int(b)], cx = nx[Int(c)]
            let ay = ny[Int(a)], by = ny[Int(b)], cy = ny[Int(c)]
            let x0 = min(ax, bx, cx), y0 = min(ay, by, cy)
            let x1 = max(ax, bx, cx), y1 = max(ay, by, cy)
            let minZ = zOrder(x0, y0), maxZ = zOrder(x1, y1)
            var p = pz[Int(ear)], n = nz[Int(ear)]
            @inline(__always) func blocks(_ q: Int32) -> Bool {
                let qx = nx[Int(q)], qy = ny[Int(q)]
                return qx >= x0 && qx <= x1 && qy >= y0 && qy <= y1 && q != a && q != c
                    && Engine.pointInTriangle(ax, ay, bx, by, cx, cy, qx, qy)
                    && area(prev[Int(q)], q, next[Int(q)]) >= 0
            }
            while p >= 0 && z[Int(p)] >= minZ && n >= 0 && z[Int(n)] <= maxZ {
                if blocks(p) { return false }
                p = pz[Int(p)]
                if blocks(n) { return false }
                n = nz[Int(n)]
            }
            while p >= 0 && z[Int(p)] >= minZ {
                if blocks(p) { return false }
                p = pz[Int(p)]
            }
            while n >= 0 && z[Int(n)] <= maxZ {
                if blocks(n) { return false }
                n = nz[Int(n)]
            }
            return true
        }

        mutating func cureLocalIntersections(_ startIn: Int32) -> Int32 {
            var start = startIn
            var p = start
            repeat {
                let a = prev[Int(p)], b = next[Int(next[Int(p)])]
                if !equals(a, b) && intersects(a, p, next[Int(p)], b)
                    && locallyInside(a, b) && locallyInside(b, a) {
                    tris.append(vi[Int(a)]); tris.append(vi[Int(p)]); tris.append(vi[Int(b)])
                    let pn = next[Int(p)]
                    removeNode(p)
                    removeNode(pn)
                    p = b; start = b
                }
                p = next[Int(p)]
            } while p != start
            return filterPoints(p)
        }

        mutating func splitEarcut(_ start: Int32) {
            var a = start
            repeat {
                var b = next[Int(next[Int(a)])]
                while b != prev[Int(a)] {
                    if vi[Int(a)] != vi[Int(b)] && isValidDiagonal(a, b) {
                        var c = splitPolygon(a, b)
                        let aa = filterPoints(a, next[Int(a)])
                        c = filterPoints(c, next[Int(c)])
                        earcutLinked(aa, pass: 0)
                        earcutLinked(c, pass: 0)
                        return
                    }
                    b = next[Int(b)]
                }
                a = next[Int(a)]
            } while a != start
        }

        mutating func eliminateHoles(_ holeStarts: [Int], _ outerIn: Int32) -> Int32 {
            var outer = outerIn
            var queue: [Int32] = []
            for (k, s) in holeStarts.enumerated() {
                let e = k + 1 < holeStarts.count ? holeStarts[k + 1] : data.count
                let list = linkedList(s, e, clockwise: false)
                if list < 0 { continue }
                if list == next[Int(list)] { steiner[Int(list)] = true }
                queue.append(leftmost(list))
            }
            queue.sort { nx[Int($0)] < nx[Int($1)] }
            for h in queue { outer = eliminateHole(h, outer) }
            return outer
        }

        mutating func eliminateHole(_ hole: Int32, _ outer: Int32) -> Int32 {
            guard let bridge = findHoleBridge(hole, outer) else { return outer }
            let bridgeReverse = splitPolygon(bridge, hole)
            _ = filterPoints(bridgeReverse, next[Int(bridgeReverse)])
            return filterPoints(bridge, next[Int(bridge)])
        }

        func findHoleBridge(_ hole: Int32, _ outer: Int32) -> Int32? {
            var p = outer
            let hx = nx[Int(hole)], hy = ny[Int(hole)]
            var qx = -Double.infinity
            var m: Int32 = -1
            repeat {
                let pn = next[Int(p)]
                let py = ny[Int(p)], pny = ny[Int(pn)]
                if hy <= py && hy >= pny && pny != py {
                    let x = nx[Int(p)] + (hy - py) * (nx[Int(pn)] - nx[Int(p)]) / (pny - py)
                    if x <= hx && x > qx {
                        qx = x
                        m = nx[Int(p)] < nx[Int(pn)] ? p : pn
                        if x == hx { return m }
                    }
                }
                p = pn
            } while p != outer
            if m < 0 { return nil }
            let stop = m
            let mx = nx[Int(m)], my = ny[Int(m)]
            var tanMin = Double.infinity
            p = m
            repeat {
                let px = nx[Int(p)], py = ny[Int(p)]
                if hx >= px && px >= mx && hx != px
                    && Engine.pointInTriangle(hy < my ? hx : qx, hy, mx, my,
                                              hy < my ? qx : hx, hy, px, py) {
                    let tan = abs(hy - py) / (hx - px)
                    if locallyInside(p, hole)
                        && (tan < tanMin || (tan == tanMin
                            && (px > nx[Int(m)] || (px == nx[Int(m)]
                                && sectorContainsSector(m, p))))) {
                        m = p
                        tanMin = tan
                    }
                }
                p = next[Int(p)]
            } while p != stop
            return m
        }

        func sectorContainsSector(_ m: Int32, _ p: Int32) -> Bool {
            area(prev[Int(m)], m, prev[Int(p)]) < 0 && area(next[Int(p)], m, next[Int(m)]) < 0
        }

        mutating func indexCurve(_ start: Int32) {
            var p = start
            repeat {
                if z[Int(p)] == 0 { z[Int(p)] = zOrder(nx[Int(p)], ny[Int(p)]) }
                pz[Int(p)] = prev[Int(p)]
                nz[Int(p)] = next[Int(p)]
                p = next[Int(p)]
            } while p != start
            nz[Int(pz[Int(p)])] = -1
            pz[Int(p)] = -1
            sortLinked(p)
        }

        mutating func sortLinked(_ listIn: Int32) {
            var list = listIn
            var inSize = 1
            var numMerges: Int
            repeat {
                var p = list
                list = -1
                var tail: Int32 = -1
                numMerges = 0
                while p >= 0 {
                    numMerges += 1
                    var q = p
                    var pSize = 0
                    for _ in 0..<inSize {
                        pSize += 1
                        q = nz[Int(q)]
                        if q < 0 { break }
                    }
                    var qSize = inSize
                    while pSize > 0 || (qSize > 0 && q >= 0) {
                        let e: Int32
                        if pSize != 0 && (qSize == 0 || q < 0 || z[Int(p)] <= z[Int(q)]) {
                            e = p; p = nz[Int(p)]; pSize -= 1
                        } else {
                            e = q; q = nz[Int(q)]; qSize -= 1
                        }
                        if tail >= 0 { nz[Int(tail)] = e } else { list = e }
                        pz[Int(e)] = tail
                        tail = e
                    }
                    p = q
                }
                if tail >= 0 { nz[Int(tail)] = -1 }
                inSize *= 2
            } while numMerges > 1
        }

        func zOrder(_ xIn: Double, _ yIn: Double) -> Int32 {
            var x = Int32(truncatingIfNeeded: Int((xIn - minX) * invSize))
            var y = Int32(truncatingIfNeeded: Int((yIn - minY) * invSize))
            x = (x | (x << 8)) & 0x00FF00FF
            x = (x | (x << 4)) & 0x0F0F0F0F
            x = (x | (x << 2)) & 0x33333333
            x = (x | (x << 1)) & 0x55555555
            y = (y | (y << 8)) & 0x00FF00FF
            y = (y | (y << 4)) & 0x0F0F0F0F
            y = (y | (y << 2)) & 0x33333333
            y = (y | (y << 1)) & 0x55555555
            return x | (y << 1)
        }

        func leftmost(_ start: Int32) -> Int32 {
            var p = start, l = start
            repeat {
                if nx[Int(p)] < nx[Int(l)] || (nx[Int(p)] == nx[Int(l)] && ny[Int(p)] < ny[Int(l)]) {
                    l = p
                }
                p = next[Int(p)]
            } while p != start
            return l
        }

        @inline(__always)
        static func pointInTriangle(_ ax: Double, _ ay: Double, _ bx: Double, _ by: Double,
                                    _ cx: Double, _ cy: Double, _ px: Double, _ py: Double) -> Bool {
            (cx - px) * (ay - py) >= (ax - px) * (cy - py)
                && (ax - px) * (by - py) >= (bx - px) * (ay - py)
                && (bx - px) * (cy - py) >= (cx - px) * (by - py)
        }

        func isValidDiagonal(_ a: Int32, _ b: Int32) -> Bool {
            vi[Int(next[Int(a)])] != vi[Int(b)] && vi[Int(prev[Int(a)])] != vi[Int(b)]
                && !intersectsPolygon(a, b)
                && ((locallyInside(a, b) && locallyInside(b, a) && middleInside(a, b)
                     && (area(prev[Int(a)], a, prev[Int(b)]) != 0 || area(a, prev[Int(b)], b) != 0))
                    || (equals(a, b) && area(prev[Int(a)], a, next[Int(a)]) > 0
                        && area(prev[Int(b)], b, next[Int(b)]) > 0))
        }

        @inline(__always) static func sign(_ v: Double) -> Int { v > 0 ? 1 : (v < 0 ? -1 : 0) }

        func onSegment(_ p: Int32, _ q: Int32, _ r: Int32) -> Bool {
            nx[Int(q)] <= max(nx[Int(p)], nx[Int(r)]) && nx[Int(q)] >= min(nx[Int(p)], nx[Int(r)])
                && ny[Int(q)] <= max(ny[Int(p)], ny[Int(r)]) && ny[Int(q)] >= min(ny[Int(p)], ny[Int(r)])
        }

        func intersects(_ p1: Int32, _ q1: Int32, _ p2: Int32, _ q2: Int32) -> Bool {
            let o1 = Engine.sign(area(p1, q1, p2)), o2 = Engine.sign(area(p1, q1, q2))
            let o3 = Engine.sign(area(p2, q2, p1)), o4 = Engine.sign(area(p2, q2, q1))
            if o1 != o2 && o3 != o4 { return true }
            if o1 == 0 && onSegment(p1, p2, q1) { return true }
            if o2 == 0 && onSegment(p1, q2, q1) { return true }
            if o3 == 0 && onSegment(p2, p1, q2) { return true }
            if o4 == 0 && onSegment(p2, q1, q2) { return true }
            return false
        }

        func intersectsPolygon(_ a: Int32, _ b: Int32) -> Bool {
            var p = a
            repeat {
                let pn = next[Int(p)]
                if vi[Int(p)] != vi[Int(a)] && vi[Int(pn)] != vi[Int(a)]
                    && vi[Int(p)] != vi[Int(b)] && vi[Int(pn)] != vi[Int(b)]
                    && intersects(p, pn, a, b) { return true }
                p = pn
            } while p != a
            return false
        }

        func locallyInside(_ a: Int32, _ b: Int32) -> Bool {
            area(prev[Int(a)], a, next[Int(a)]) < 0
                ? area(a, b, next[Int(a)]) >= 0 && area(a, prev[Int(a)], b) >= 0
                : area(a, b, prev[Int(a)]) < 0 || area(a, next[Int(a)], b) < 0
        }

        func middleInside(_ a: Int32, _ b: Int32) -> Bool {
            var p = a
            var inside = false
            let px = (nx[Int(a)] + nx[Int(b)]) / 2, py = (ny[Int(a)] + ny[Int(b)]) / 2
            repeat {
                let pn = next[Int(p)]
                let y0 = ny[Int(p)], y1 = ny[Int(pn)]
                if (y0 > py) != (y1 > py) && y1 != y0
                    && px < (nx[Int(pn)] - nx[Int(p)]) * (py - y0) / (y1 - y0) + nx[Int(p)] {
                    inside.toggle()
                }
                p = pn
            } while p != a
            return inside
        }

        mutating func splitPolygon(_ a: Int32, _ b: Int32) -> Int32 {
            let a2 = newNode(vi[Int(a)], nx[Int(a)], ny[Int(a)])
            let b2 = newNode(vi[Int(b)], nx[Int(b)], ny[Int(b)])
            let an = next[Int(a)], bp = prev[Int(b)]
            next[Int(a)] = b; prev[Int(b)] = a
            next[Int(a2)] = an; prev[Int(an)] = a2
            next[Int(b2)] = a2; prev[Int(a2)] = b2
            next[Int(bp)] = b2; prev[Int(b2)] = bp
            return b2
        }
    }
}
