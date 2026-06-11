import Foundation
import Combine
import CoreGraphics

@MainActor
final class SettingsStore: ObservableObject {
    private let defaults: UserDefaults

    @Published var plan: PlanType {
        didSet { defaults.set(plan.rawValue, forKey: "plan") }
    }
    @Published var includeCacheTokens: Bool {
        didSet { defaults.set(includeCacheTokens, forKey: "includeCacheTokens") }
    }
    /// nil = auto-ranging; otherwise index into SpeedoScaler.multipliers.
    @Published var speedoScaleLock: Int? {
        didSet { defaults.set(speedoScaleLock.map { $0 + 1 } ?? 0, forKey: "speedoScaleLock") }
    }
    @Published var designId: String {
        didSet { defaults.set(designId, forKey: "designId") }
    }
    @Published var configDirOverride: String {
        didSet { defaults.set(configDirOverride, forKey: "configDirOverride") }
    }
    @Published var statuslinePromptShown: Bool {
        didSet { defaults.set(statuslinePromptShown, forKey: "statuslinePromptShown") }
    }
    var windowOrigin: CGPoint? {
        get {
            guard let raw = defaults.string(forKey: "windowOrigin") else { return nil }
            let parts = raw.split(separator: ",").compactMap { Double($0) }
            guard parts.count == 2 else { return nil }
            return CGPoint(x: parts[0], y: parts[1])
        }
        set {
            if let p = newValue {
                defaults.set("\(p.x),\(p.y)", forKey: "windowOrigin")
            } else {
                defaults.removeObject(forKey: "windowOrigin")
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.plan = PlanType(rawValue: defaults.string(forKey: "plan") ?? "") ?? .maxOrPro
        self.includeCacheTokens = defaults.bool(forKey: "includeCacheTokens")
        let lock = defaults.integer(forKey: "speedoScaleLock")
        self.speedoScaleLock = lock > 0 ? lock - 1 : nil
        self.designId = defaults.string(forKey: "designId") ?? "gt3"
        self.configDirOverride = defaults.string(forKey: "configDirOverride") ?? ""
        self.statuslinePromptShown = defaults.bool(forKey: "statuslinePromptShown")
    }
}
