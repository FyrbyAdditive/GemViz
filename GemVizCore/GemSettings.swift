import Foundation
import AppKit

public class GemSettings {
    public static let shared = GemSettings()

    private let defaults: UserDefaults
    private static let groupID = "group.com.fyrbyadditive.gemviz.shared"

    private init() {
        // Try to use App Group, fall back to standard if not available
        defaults = UserDefaults(suiteName: Self.groupID) ?? .standard
    }

    // MARK: - Surface Opacity

    private static let surfaceOpacityKey = "surfaceOpacity"
    private static let defaultSurfaceOpacity: Double = 0.3

    public var surfaceOpacity: Double {
        get {
            let value = defaults.double(forKey: Self.surfaceOpacityKey)
            // Return default if value is 0 (not set)
            if value == 0 {
                return Self.defaultSurfaceOpacity
            }
            return max(0.05, min(1.0, value))
        }
        set {
            defaults.set(max(0.05, min(1.0, newValue)), forKey: Self.surfaceOpacityKey)
        }
    }

    // MARK: - Surface Color

    private static let surfaceColorKey = "surfaceColor"

    public var surfaceColor: NSColor {
        get {
            guard let data = defaults.data(forKey: Self.surfaceColorKey),
                  let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
            else {
                return NSColor(white: 0.95, alpha: 1.0)
            }
            return color
        }
        set {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: true) {
                defaults.set(data, forKey: Self.surfaceColorKey)
            }
        }
    }

    // MARK: - Surface Reflectivity

    private static let surfaceReflectivityKey = "surfaceReflectivity"
    private static let defaultSurfaceReflectivity: Double = 0.7

    public var surfaceReflectivity: Double {
        get {
            let value = defaults.double(forKey: Self.surfaceReflectivityKey)
            // Return default if value is 0 (not set)
            if value == 0 && defaults.object(forKey: Self.surfaceReflectivityKey) == nil {
                return Self.defaultSurfaceReflectivity
            }
            return max(0.0, min(1.0, value))
        }
        set {
            defaults.set(max(0.0, min(1.0, newValue)), forKey: Self.surfaceReflectivityKey)
        }
    }

    // MARK: - Edge Wireframe

    private static let edgeEnabledKey = "edgeEnabled"
    private static let edgeColorKey = "edgeColor"
    private static let edgeOpacityKey = "edgeOpacity"

    private static let defaultEdgeEnabled: Bool = true
    private static let defaultEdgeOpacity: Double = 0.6

    public var edgeEnabled: Bool {
        get {
            if defaults.object(forKey: Self.edgeEnabledKey) == nil {
                return Self.defaultEdgeEnabled
            }
            return defaults.bool(forKey: Self.edgeEnabledKey)
        }
        set {
            defaults.set(newValue, forKey: Self.edgeEnabledKey)
        }
    }

    public var edgeColor: NSColor {
        get {
            guard let data = defaults.data(forKey: Self.edgeColorKey),
                  let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
            else {
                // Default to a subtle blue-grey that complements most gem colors
                return NSColor(red: 0.4, green: 0.5, blue: 0.6, alpha: 1.0)
            }
            return color
        }
        set {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: true) {
                defaults.set(data, forKey: Self.edgeColorKey)
            }
        }
    }

    public var edgeOpacity: Double {
        get {
            let value = defaults.double(forKey: Self.edgeOpacityKey)
            if value == 0 && defaults.object(forKey: Self.edgeOpacityKey) == nil {
                return Self.defaultEdgeOpacity
            }
            return max(0.1, min(1.0, value))
        }
        set {
            defaults.set(max(0.1, min(1.0, newValue)), forKey: Self.edgeOpacityKey)
        }
    }

    // MARK: - Reset

    public func resetToDefaults() {
        defaults.removeObject(forKey: Self.surfaceOpacityKey)
        defaults.removeObject(forKey: Self.surfaceColorKey)
        defaults.removeObject(forKey: Self.surfaceReflectivityKey)
        defaults.removeObject(forKey: Self.edgeEnabledKey)
        defaults.removeObject(forKey: Self.edgeColorKey)
        defaults.removeObject(forKey: Self.edgeOpacityKey)
    }
}
