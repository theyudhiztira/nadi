import NadiCore

/// Fan speeds from SMC `FNum` and `F<n>Ac`. Macs without fans report an empty list.
public final class FanReader: FanSensor, @unchecked Sendable {
    private let smc: SMC?
    private let count: Int

    public init() {
        smc = SMC()
        count = smc?.readUInt("FNum").map(Int.init) ?? 0
    }

    public func rpm() -> [Double]? {
        guard let smc else { return nil }
        let speeds = (0..<count).compactMap { smc.readDouble("F\($0)Ac") }
        return speeds.count == count ? speeds : nil
    }
}
