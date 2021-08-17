import BlueprintUI
import UIKit

public extension NSObject {
    
     enum AccessibilityRole {
        case container(Array<AccessibilityRole>)
        case element(Accessible)
        case none
    }
    
    var accessibilityRepresentation: AccessibilityRole {
        switch self.isAccessibilityElement {
        case true:
            var identifier: String? = nil
            if let identifiable = self as? UIAccessibilityIdentification {
                identifier = identifiable.accessibilityIdentifier
            }
            return .element(AccessibilityRepresentation(
                label: accessibilityLabel,
                value: accessibilityValue,
                hint: accessibilityHint,
                identifier: identifier,
                traits: accessibilityTraits.blueprintTraits))
            
        case false:
            if let elements = accessibilityElements {
                return .container(elements.compactMap({ any in
                    guard let obj = any as? NSObject else { return nil }
                    return obj.accessibilityRepresentation
                }))
            } else {
                return .none
            }
        }
    }
    
    func apply(accessibility: Accessible) {
        if let label = accessibility.label {
            accessibilityLabel = label
        }
        
        if let value = accessibility.value {
            accessibilityValue = value
        }
        
        if let hint = accessibility.hint {
            accessibilityHint = hint
        }
        
        if let identifier = accessibility.identifier {
            if let identifiable = self as? UIAccessibilityIdentification {
                identifiable.accessibilityIdentifier = identifier
            }
        }
        
        // Some UIKit controls have custom UIAccessibilityTraits, we don't want to stomp them when applying our traits so we'll pull them out first and then union them with ours.
        if let traits = accessibility.traits {
            let privateTraits = accessibilityTraits.subtracting(UIAccessibilityTraits(withSet: AccessibilityTrait.allTraits))
            accessibilityTraits = privateTraits.union(.init(withSet: traits))
        }
        
    }
}

public enum AccessibilityTrait: Hashable {
    case button
    case link
    case header
    case searchField
    case image
    case selected
    case playsSound
    case keyboardKey
    case staticText
    case summaryElement
    case notEnabled
    case updatesFrequently
    case startsMediaSession
    case adjustable
    case allowsDirectInteraction
    case causesPageTurn
    case tabBar
    
    static var allTraits: Set<AccessibilityTrait> {
        return [.button, .link, .header, .searchField,
                .image,.selected, .playsSound, .keyboardKey,
                .staticText, .summaryElement, .notEnabled,
                .updatesFrequently, .staticText, .adjustable,
                .allowsDirectInteraction, .causesPageTurn, .tabBar]
    }
}

public protocol Accessible {
    var label: String? { get set}
    var value: String? { get set}
    var hint: String? { get set}
    var identifier: String? { get set}
    var traits: Set<AccessibilityTrait>? { get set}
}

public struct AccessibilityRepresentation: Accessible, Equatable, Hashable {
    
    public var label: String?
    public var value: String?
    public var hint: String?
    public var identifier: String?
    public var traits: Set<AccessibilityTrait>?
    
    public init(
        label: String? = nil,
        value: String? = nil,
        hint: String? = nil,
        identifier: String? = nil,
        traits: Set<AccessibilityTrait> = []
    ) {
        self.label = label
        self.value = value
        self.hint = hint
        self.identifier = identifier
        self.traits = traits
    }
}

public struct AccessibilityElement: Element {

    public var accessibility: AccessibilityRepresentation
    public var accessibilityFrameSize: CGSize?
    public var wrappedElement: Element

    public init(
        accessibility: AccessibilityRepresentation,
        accessibilityFrameSize: CGSize? = nil,
        wrapping element: Element
    ) {
        self.accessibility = accessibility
        self.accessibilityFrameSize = accessibilityFrameSize
        self.wrappedElement = element
    }

    private var accessibilityTraits: UIAccessibilityTraits {
        return UIAccessibilityTraits(withSet: accessibility.traits ?? [])
    }

    public var content: ElementContent {
        return ElementContent(child: wrappedElement)
    }

    public func backingViewDescription(with context: ViewDescriptionContext) -> ViewDescription? {
        return AccessibilityView.describe { config in
            config[\.accessibilityLabel] = accessibility.label
            config[\.accessibilityValue] = accessibility.value
            config[\.accessibilityHint] = accessibility.hint
            config[\.accessibilityIdentifier] = accessibility.identifier
            config[\.accessibilityTraits] = accessibilityTraits
            config[\.isAccessibilityElement] = true
            config[\.accessibilityFrameSize] = self.accessibilityFrameSize
        }
    }

    private final class AccessibilityView: UIView {

        var accessibilityFrameSize: CGSize?

        override var accessibilityFrame: CGRect {
            get {
                guard let accessibilityFrameSize = accessibilityFrameSize else {
                    return UIAccessibility.convertToScreenCoordinates(bounds, in: self)
                }

                let adjustedFrame = bounds.insetBy(
                    dx: bounds.width - accessibilityFrameSize.width,
                    dy: bounds.height - accessibilityFrameSize.height
                )

                return UIAccessibility.convertToScreenCoordinates(adjustedFrame, in: self)
            }
            set {
                fatalError("accessibilityFrame is not settable on AccessibilityView")
            }
        }
    }
}


public extension Element {

    /// Wraps the element to provide the passed accessibility
    /// options to the accessibility system.
    func accessibility(
        label: String? = nil,
        value: String? = nil,
        hint: String? = nil,
        identifier: String? = nil,
        traits: Set<AccessibilityTrait> = [],
        accessibilityFrameSize: CGSize? = nil
    ) -> AccessibilityElement {
         AccessibilityElement(
            accessibility:AccessibilityRepresentation(label: label,
                                        value: value,
                                        hint: hint,
                                        identifier: identifier,
                                        traits: traits),
            accessibilityFrameSize: accessibilityFrameSize,
            wrapping: self
        )
    }
}


public extension UIAccessibilityTraits {
    
    init(withSet set:Set<AccessibilityTrait>) {
         self.init(rawValue: UIAccessibilityTraits.none.rawValue)
             for trait in set {
                 switch trait {
                 case .button:
                     self.formUnion(.button)
                 case .link:
                     self.formUnion(.link)
                 case .header:
                     self.formUnion(.header)
                 case .searchField:
                     self.formUnion(.searchField)
                 case .image:
                     self.formUnion(.image)
                 case .selected:
                     self.formUnion(.selected)
                 case .playsSound:
                     self.formUnion(.playsSound)
                 case .keyboardKey:
                     self.formUnion(.keyboardKey)
                 case .staticText:
                     self.formUnion(.staticText)
                 case .summaryElement:
                     self.formUnion(.summaryElement)
                 case .notEnabled:
                     self.formUnion(.notEnabled)
                 case .updatesFrequently:
                     self.formUnion(.updatesFrequently)
                 case .startsMediaSession:
                     self.formUnion(.startsMediaSession)
                 case .adjustable:
                     self.formUnion(.adjustable)
                 case .allowsDirectInteraction:
                     self.formUnion(.allowsDirectInteraction)
                 case .causesPageTurn:
                     self.formUnion(.causesPageTurn)
                 case .tabBar:
                     self.formUnion(.tabBar)
                 }
             }
         }
    
    var blueprintTraits: Set<AccessibilityTrait> {
        var set:Set<AccessibilityTrait> = []
        if self.contains(.button) {
            set.insert(.button)
        }
        if self.contains(.link) {
            set.insert(.link)
        }
        if self.contains(.header) {
            set.insert(.header)
        }
        if self.contains(.searchField) {
            set.insert(.searchField)
        }
        if self.contains(.image) {
            set.insert(.image)
        }
        if self.contains(.selected) {
            set.insert(.selected)
        }
        if self.contains(.playsSound) {
            set.insert(.playsSound)
        }
        if self.contains(.keyboardKey) {
            set.insert(.keyboardKey)
        }
        if self.contains(.staticText) {
            set.insert(.staticText)
        }
        if self.contains(.summaryElement) {
            set.insert(.summaryElement)
        }
        if self.contains(.searchField) {
            set.insert(.searchField)
        }
        if self.contains(.notEnabled) {
            set.insert(.notEnabled)
        }
        if self.contains(.updatesFrequently) {
            set.insert(.updatesFrequently)
        }
        if self.contains(.startsMediaSession) {
            set.insert(.startsMediaSession)
        }
        if self.contains(.adjustable) {
            set.insert(.adjustable)
        }
        if self.contains(.allowsDirectInteraction) {
            set.insert(.allowsDirectInteraction)
        }
        if self.contains(.causesPageTurn) {
            set.insert(.causesPageTurn)
        }
        if self.contains(.tabBar) {
            set.insert(.tabBar)
        }
        return set
    }
}
