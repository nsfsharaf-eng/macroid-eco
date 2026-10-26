import Foundation

/// Protocol for persisting application and mirroring settings.
public protocol PreferencesServicing: Sendable {
    func loadConfig() -> MirroringConfig
    func saveConfig(_ config: MirroringConfig)
    func resetToDefaults() -> MirroringConfig
}

/// Standard UserDefaults-backed preferences storage using Codable.
public final class PreferencesService: PreferencesServicing, @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let storageKey = "com.macroideco.config"
    private let legacyStorageKey = "com.macdroidmirror.config"

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func loadConfig() -> MirroringConfig {
        guard let data = userDefaults.data(forKey: storageKey) ?? userDefaults.data(forKey: legacyStorageKey) else {
            return .standard
        }
        do {
            return try JSONDecoder().decode(MirroringConfig.self, from: data)
        } catch {
            return .standard
        }
    }

    public func saveConfig(_ config: MirroringConfig) {
        if let data = try? JSONEncoder().encode(config) {
            userDefaults.set(data, forKey: storageKey)
        }
    }

    public func resetToDefaults() -> MirroringConfig {
        userDefaults.removeObject(forKey: storageKey)
        return .standard
    }
}
