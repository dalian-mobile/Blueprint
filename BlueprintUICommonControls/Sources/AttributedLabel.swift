import BlueprintUI
import Foundation
import UIKit

public struct AttributedLabel: Element, Hashable {

    public var attributedText: NSAttributedString
    public var numberOfLines: Int = 0

    /// An offset that will be applied to the rect used by `drawText(in:)`.
    ///
    /// This can be used to adjust the positioning of text within each line's frame, such as adjusting
    /// the way text is distributed within the line height.
    public var textRectOffset: UIOffset = .zero

    /// Determines if the label should be included when navigating the UI via accessibility.
    public var isAccessibilityElement = true

    /// A set of accessibility traits that should be applied to the label, these will be merged with any existing traits.
    public var accessibilityTraits: Set<AccessibilityElement.Trait>?

    public var linkDetectionTypes: Set<LinkDetectionType> = []

    public var links: [Link] = []

    public var linkColor: UIColor = .systemBlue

    public var activeLinkColor: UIColor = UIColor.systemBlue.withAlphaComponent(0.3)

    public init(attributedText: NSAttributedString, configure: (inout Self) -> Void = { _ in }) {
        self.attributedText = attributedText

        configure(&self)
    }

    public var content: ElementContent {
        struct Measurer: Measurable {
            private static let prototypeLabel = LabelView()

            var model: AttributedLabel

            func measure(in constraint: SizeConstraint) -> CGSize {
                let label = Self.prototypeLabel
                label.update(model: model, isMeasuring: true)
                return label.sizeThatFits(constraint.maximum)
            }
        }

        return ElementContent(
            measurable: Measurer(model: self),
            measurementCachingKey: .init(type: Self.self, input: self)
        )
    }

    public func backingViewDescription(with context: ViewDescriptionContext) -> ViewDescription? {
        LabelView.describe { config in
            config.frameRoundingBehavior = .prioritizeSize
            config.apply { view in
                view.update(model: self, isMeasuring: false)
            }
        }
    }
}

extension AttributedLabel {

    private final class LabelView: UILabel, UIGestureRecognizerDelegate {
        var linkDetectionTypes: Set<LinkDetectionType> = []

        var linkColor: UIColor = .systemBlue
        var activeLinkColor: UIColor = UIColor.systemBlue.withAlphaComponent(0.3)

        var userLinks: [Link] = [] {
            didSet {
                isUserInteractionEnabled = !links.isEmpty
            }
        }

        var detectedLinks: [Link] = [] {
            didSet {}
        }

        var links: [Link] {
            userLinks + detectedLinks
        }

        var textRectOffset: UIOffset = .zero {
            didSet {
                if oldValue != textRectOffset {
                    setNeedsDisplay()
                }
            }
        }

        func update(model: AttributedLabel, isMeasuring: Bool) {
            let previousString = attributedText?.string
            let previousLinks = links

            userLinks = model.links
            linkColor = model.linkColor
            activeLinkColor = model.activeLinkColor
            linkDetectionTypes = model.linkDetectionTypes
            attributedText = model.attributedText.applyingDefaultFont()
            numberOfLines = model.numberOfLines
            textRectOffset = model.textRectOffset
            isAccessibilityElement = model.isAccessibilityElement
            updateAccessibilityTraits(model)

            if !isMeasuring, previousString != attributedText?.string || previousLinks != links {
                detectDataLinks()
            }

            resetText()
        }

        private func updateAccessibilityTraits(_ model: AttributedLabel) {
            if let traits = model.accessibilityTraits {
                var union = accessibilityTraits.union(UIAccessibilityTraits(with: traits))
                // UILabel has the `.staticText` trait by default. If we explicitly set `.updatesFrequently` this should be removed.
                if traits.contains(.updatesFrequently) && accessibilityTraits.contains(.staticText) {
                    union.subtract(.staticText)
                }
                accessibilityTraits = union
            }
        }

        override func drawText(in rect: CGRect) {
            super.drawText(in: rect.offsetBy(dx: textRectOffset.horizontal, dy: textRectOffset.vertical))
        }

        private func makeTextStorage() -> NSTextStorage? {
            guard let attributedText = attributedText, attributedText.length > 0 else {
                return nil
            }

            let textStorage = NSTextStorage()
            let layoutManager = NSLayoutManager()
            let textContainer = NSTextContainer()

            textContainer.lineFragmentPadding = 0
            textContainer.lineBreakMode = lineBreakMode
            textContainer.size = textRect(forBounds: bounds, limitedToNumberOfLines: numberOfLines).size

            layoutManager.addTextContainer(textContainer)
            textStorage.addLayoutManager(layoutManager)
            textStorage.setAttributedString(attributedText)

            return textStorage
        }

        private func links(at location: CGPoint) -> [Link] {
            guard let textStorage = makeTextStorage(),
                  let layoutManager = textStorage.layoutManagers.first,
                  let textContainer = layoutManager.textContainers.first
            else {
                return []
            }

            let labelSize = bounds.size
            let textBoundingBox = layoutManager.usedRect(for: textContainer).offsetBy(
                dx: textRectOffset.horizontal,
                dy: textRectOffset.vertical
            )
            let textContainerOffset = CGPoint(
                x: (labelSize.width - textBoundingBox.size.width) * 0.5 - textBoundingBox.origin.x,
                y: (labelSize.height - textBoundingBox.size.height) * 0.5 - textBoundingBox.origin.y
            )
            let locationInTextContainer = CGPoint(
                x: location.x - textContainerOffset.x,
                y: location.y - textContainerOffset.y
            )

            guard textBoundingBox.contains(locationInTextContainer) else {
                return []
            }

            let indexOfCharacter = layoutManager.characterIndex(
                for: locationInTextContainer,
                in: textContainer,
                fractionOfDistanceBetweenInsertionPoints: nil
            )

            return links.filter { $0.range.contains(indexOfCharacter) }
        }

        private func detectDataLinks() {
            detectedLinks = []

            guard let attributedText = attributedText, !linkDetectionTypes.isEmpty else {
                return
            }

            let types = NSTextCheckingResult.CheckingType(linkDetectionTypes)

            guard let detector = try? NSDataDetector(types: types.rawValue) else {
                return
            }

            detector.enumerateMatches(
                in: attributedText.string,
                options: [],
                range: attributedText.entireRange
            ) { result, _, _ in
                guard let result = result else {
                    return
                }

                switch result.resultType {
                case .phoneNumber:
                    if let phoneNumber = result.phoneNumber {
                        let charactersToRemove = CharacterSet.decimalDigits.inverted
                        let trimmedPhoneNumber = phoneNumber.components(separatedBy: charactersToRemove).joined()
                        if let url = URL(string: "tel:\(trimmedPhoneNumber)") {
                            detectedLinks.append(.init(url: url, range: result.range))
                        }
                    }

                case .link:
                    if let url = result.url {
                        detectedLinks.append(.init(url: url, range: result.range))
                    }

                case .address:
                    if let addressComponents = result.addressComponents {
                        let components = [
                            addressComponents[.name],
                            addressComponents[.organization],
                            addressComponents[.street],
                            addressComponents[.city],
                            addressComponents[.zip],
                            addressComponents[.country],
                        ]

                        let address = components
                            .compactMap { $0 }
                            .joined(separator: " ")

                        if let urlQuery = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                           let url = URL(string: "https://maps.apple.com/?address=\(urlQuery)")
                        {
                            detectedLinks.append(.init(url: url, range: result.range))
                        }
                    }

                case .date:
                    if let date = result.date,
                       let url = URL(string: "calshow:\(date.timeIntervalSinceReferenceDate)")
                    {
                        detectedLinks.append(.init(url: url, range: result.range))
                    }

                default:
                    break
                }
            }
        }

        private func handleTouch(at location: CGPoint) {
            let activeLinks = links(at: location)
            let mutableString = NSMutableAttributedString(attributedString: attributedText ?? .init(string: ""))

            for link in links {
                mutableString.addAttributes(
                    [.foregroundColor: linkColor],
                    range: link.range
                )
            }

            for link in activeLinks {
                mutableString.addAttributes(
                    [.foregroundColor: activeLinkColor],
                    range: link.range
                )
            }

            attributedText = mutableString
        }

        func resetText() {
            let mutableString = NSMutableAttributedString(attributedString: attributedText ?? .init(string: ""))
            for link in links {
                mutableString.addAttributes(
                    [.foregroundColor: linkColor],
                    range: link.range
                )
            }
            attributedText = mutableString
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let first = touches.first else { return }
            handleTouch(at: first.location(in: self))
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let first = touches.first else { return }
            handleTouch(at: first.location(in: self))
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            resetText()

            if let first = touches.first {
                let links = links(at: first.location(in: self))
                for link in links {
                    link.perform()
                }
            }
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            resetText()
        }
    }
}

extension UIOffset: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(horizontal)
        hasher.combine(vertical)
    }
}

extension NSAttributedString {
    var entireRange: NSRange {
        NSRange(location: 0, length: length)
    }

    func applyingDefaultFont() -> NSAttributedString {
        let mutableString = NSMutableAttributedString(attributedString: self)

        mutableString.enumerateAttribute(
            .font,
            in: NSRange(location: 0, length: mutableString.length),
            options: []
        ) { font, range, _ in
            if font == nil {
                mutableString.addAttribute(.font, value: UIFont.systemFont(ofSize: 17) as Any, range: range)
            }
        }

        return mutableString
    }
}

extension NSTextCheckingResult.CheckingType {
    init(_ types: Set<AttributedLabel.LinkDetectionType>) {
        var checkingType = NSTextCheckingResult.CheckingType()

        for type in types {
            checkingType.formUnion(type.checkingType)
        }

        self = checkingType
    }
}
