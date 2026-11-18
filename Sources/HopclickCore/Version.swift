/// `x.y.z` version comparison; a leading `v` and anything after `-` are ignored.
public enum Version {
    public static func compare(_ a: String, _ b: String) -> Int {
        let pa = parts(a), pb = parts(b)
        for i in 0..<max(pa.count, pb.count) {
            let diff = (i < pa.count ? pa[i] : 0) - (i < pb.count ? pb[i] : 0)
            if diff != 0 { return diff }
        }
        return 0
    }

    public static func isNewer(_ candidate: String, than current: String) -> Bool {
        compare(candidate, current) > 0
    }

    private static func parts(_ v: String) -> [Int] {
        var s = Substring(v)
        if s.hasPrefix("v") { s = s.dropFirst() }
        let core = s.split(separator: "-", maxSplits: 1).first ?? ""
        return core.split(separator: ".").map { Int($0) ?? 0 }
    }
}
