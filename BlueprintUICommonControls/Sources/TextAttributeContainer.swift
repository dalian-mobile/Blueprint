import UIKit

public struct TextAttributeContainer {
    public static let empty = Self()

    internal var storage: [NSAttributedString.Key: Any]

    /// Private empty initializer to make the `empty` environment explicit.
    private init() {
        storage = [:]
    }

    /// Get or set for the given `AttributedTextKey`.
    public subscript<Key>(key: Key.Type) -> Key.Value? where Key: AttributedTextKey {
        get {
            if let value = storage[key.name] as? Key.Value {
                return value
            } else {
                return nil
            }
        }
        set {
            storage[key.name] = newValue
        }
    }
}

public protocol AttributedTextKey {
    associatedtype Value: Equatable
    static var name: NSAttributedString.Key { get }
}

// MARK: - Built-in attribute keys

// MARK: Font

public enum FontKey: AttributedTextKey {
    public typealias Value = UIFont
    public static var name: NSAttributedString.Key { .font }
}

extension TextAttributeContainer {
    public var font: UIFont? {
        get { self[FontKey.self] }
        set { self[FontKey.self] = newValue }
    }
}

// MARK: Color

public enum ColorKey: AttributedTextKey {
    public typealias Value = UIColor
    public static var name: NSAttributedString.Key { .foregroundColor }
}

extension TextAttributeContainer {
    public var color: UIColor? {
        get { self[ColorKey.self] }
        set { self[ColorKey.self] = newValue }
    }
}

// MARK: Kern

public enum KernKey: AttributedTextKey {
    public typealias Value = CGFloat
    public static var name: NSAttributedString.Key { .kern }
}

extension TextAttributeContainer {
    public var kern: CGFloat? {
        get { self[KernKey.self] }
        set { self[KernKey.self] = newValue }
    }
}

// MARK: Underline

public enum UnderlineStyleKey: AttributedTextKey {
    public typealias Value = Int
    public static var name: NSAttributedString.Key { .underlineStyle }
}

extension TextAttributeContainer {
    public var underlineStyle: NSUnderlineStyle? {
        get { self[UnderlineStyleKey.self].flatMap { NSUnderlineStyle(rawValue: $0) } }
        set { self[UnderlineStyleKey.self] = newValue?.rawValue }
    }
}

public enum UnderlineColorKey: AttributedTextKey {
    public typealias Value = UIColor
    public static var name: NSAttributedString.Key { .underlineColor }
}

extension TextAttributeContainer {
    public var underlineColor: UIColor? {
        get { self[UnderlineColorKey.self] }
        set { self[UnderlineColorKey.self] = newValue }
    }
}

// MARK: Link

public enum LinkKey: AttributedTextKey {
    public typealias Value = AttributedLabel.Link
    public static var name: NSAttributedString.Key { .init(rawValue: "AttributedLabelLink") }
}

extension TextAttributeContainer {
    public var link: AttributedLabel.Link? {
        get { self[LinkKey.self] }
        set { self[LinkKey.self] = newValue }
    }
}

// TODO: More keys
