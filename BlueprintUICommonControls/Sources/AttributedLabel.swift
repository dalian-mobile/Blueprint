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

    /// A set of data types to detect and automatically link in the label.
    public var linkDetectionTypes: Set<LinkDetectionType>?

    /// A set of attributes to apply to links in the string.
    public var linkAttributes: [NSAttributedString.Key: AnyHashable] = [
        .foregroundColor: UIColor.systemBlue,
    ]

    /// A set of attributes to apply to links when they are touched.
    public var activeLinkAttributes: [NSAttributedString.Key: AnyHashable] = [
        .foregroundColor: UIColor.systemBlue.withAlphaComponent(0.3),
    ]

    public init(attributedText: NSAttributedString, configure: (inout Self) -> Void = { _ in }) {
        self.attributedText = attributedText

        configure(&self)
    }

    public var content: ElementContent {
        struct Measurer {
            private static let prototypeLabel = LabelView()

            func measure(model: AttributedLabel, in constraint: SizeConstraint, environment: Environment) -> CGSize {
                let label = Self.prototypeLabel
                label.update(model: model, environment: environment, isMeasuring: true)
                return label.sizeThatFits(constraint.maximum)
            }
        }

        return ElementContent(measurementCachingKey: .init(type: Self.self, input: self)) { sizeConstraint, environment -> CGSize in
            Measurer().measure(model: self, in: sizeConstraint, environment: environment)
        }
    }

    public func backingViewDescription(with context: ViewDescriptionContext) -> ViewDescription? {
        LabelView.describe { config in
            config.frameRoundingBehavior = .prioritizeSize
            config.apply { view in
                view.update(model: self, environment: context.environment, isMeasuring: false)
            }
        }
    }
}

// MARK: - Models

extension AttributedLabel {
    /// Types of data that can be detected and automatically turned into links.
    ///
    /// Corresponds to `NSTextCheckingResult.CheckingType` types.
    ///
    public enum LinkDetectionType: Equatable, Hashable {
        /// Detect date strings. Tapping a date opens the calendar to that date.
        case date
        /// Detect addresses. Tapping the address opens Maps with that address.
        case address
        /// Detect URLs. Tapping the link opens the URL.
        case link
        /// Detect phone numbers. Tapping the phone number prompts the user to call it.
        case phoneNumber

        var checkingType: NSTextCheckingResult.CheckingType {
            switch self {
            case .date: return .date
            case .address: return .address
            case .link: return .link
            case .phoneNumber: return .phoneNumber
            }
        }
    }
}

// MARK: View implementation

extension AttributedLabel {

    private final class LabelView: UILabel {
        /// The touch handling logic explicitly tracks the active links when touches begin, so if you drag outside
        /// the link and touch up over another link, it just cancels the tap rather than accidentally opening
        /// a different link.
        private var trackingLinks: [Link]?

        private var layoutDirection: Environment.LayoutDirection = .leftToRight
        private var linkDetectionTypes: Set<LinkDetectionType> = []
        private var linkAttributes: [NSAttributedString.Key: Any] = [:]
        private var activeLinkAttributes: [NSAttributedString.Key: Any] = [:]
        private var links: [Link] = []

        private var textRectOffset: UIOffset = .zero {
            didSet {
                if oldValue != textRectOffset {
                    setNeedsDisplay()
                }
            }
        }

        /// The view needs to keep track of the current index for the accessibility rotor.
        private var accessibilityLinkIndex = -1

        /// These elements need to be retained by the view, and cannot be created inside the
        /// `accessibilityCustomRotors` getter.
        private var accessibilityLinks: [LinkAccessibilityElement] = []

        override var accessibilityCustomRotors: [UIAccessibilityCustomRotor]? {
            set { fatalError() }
            get {
                [
                    UIAccessibilityCustomRotor(systemType: .link) { [weak self] predicate in
                        guard let self = self else {
                            return nil
                        }

                        self.accessibilityLinkIndex += predicate.searchDirection == .next ? 1 : -1
                        self.accessibilityLinkIndex = min(self.accessibilityLinks.count - 1, self.accessibilityLinkIndex)
                        self.accessibilityLinkIndex = max(0, self.accessibilityLinkIndex)

                        let link = self.accessibilityLinks[self.accessibilityLinkIndex]
                        return UIAccessibilityCustomRotorItemResult(targetElement: link, targetRange: nil)
                    },
                ]
            }
        }

        var urlHandler: URLHandler?

        func update(model: AttributedLabel, environment: Environment, isMeasuring: Bool) {
            let previousAttributedText = attributedText

            linkAttributes = model.linkAttributes
            activeLinkAttributes = model.activeLinkAttributes
            linkDetectionTypes = model.linkDetectionTypes ?? []
            attributedText = model.attributedText
                .applyingDefaultFont()
                .replacingLinkAttributes()
            numberOfLines = model.numberOfLines
            textRectOffset = model.textRectOffset
            isAccessibilityElement = model.isAccessibilityElement
            urlHandler = environment.urlHandler
            layoutDirection = environment.layoutDirection

            if !isMeasuring, previousAttributedText != attributedText {
                links = attributedLinks(in: model.attributedText) + detectedDataLinks(in: model.attributedText)
            }

            applyLinkColors()
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

        func makeTextStorage() -> NSTextStorage? {
            guard let attributedText = attributedText, attributedText.length > 0 else {
                return nil
            }

            let textStorage = NSTextStorage()
            let layoutManager = NSLayoutManager()
            let textContainer = NSTextContainer()

            textContainer.lineFragmentPadding = 0
            textContainer.lineBreakMode = lineBreakMode
            textContainer.maximumNumberOfLines = numberOfLines
            textContainer.size = textRect(forBounds: bounds, limitedToNumberOfLines: numberOfLines).size

            layoutManager.usesFontLeading = false
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

            func alignmentMultiplier() -> CGFloat {
                var alignment: NSTextAlignment = .natural

                textStorage.enumerateAttribute(
                    .paragraphStyle,
                    in: textStorage.entireRange,
                    options: []
                ) { style, range, continuePointer in
                    if let style = style as? NSParagraphStyle, range == textStorage.entireRange {
                        alignment = style.alignment
                        continuePointer.pointee = false
                    }
                }

                switch (alignment, layoutDirection) {
                case (.left, _),
                     (.justified, _),
                     (.natural, .leftToRight):
                    return 0
                case (.right, _),
                     (.natural, .rightToLeft):
                    return 1
                case (.center, _):
                    return 0.5
                @unknown default:
                    return 0
                }
            }

            let labelSize = bounds.size
            let alignmentMultiplier = alignmentMultiplier()
            let textBoundingBox = layoutManager.usedRect(for: textContainer).offsetBy(
                dx: textRectOffset.horizontal,
                dy: textRectOffset.vertical
            )
            let textContainerOffset = CGPoint(
                x: (labelSize.width - textBoundingBox.size.width) * alignmentMultiplier - textBoundingBox.origin.x,
                y: (labelSize.height - textBoundingBox.size.height) * alignmentMultiplier - textBoundingBox.origin.y
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

        private func attributedLinks(in string: NSAttributedString) -> [Link] {
            var links: [Link] = []

            string.enumerateAttribute(
                .link,
                in: string.entireRange,
                options: []
            ) { link, range, _ in
                if let link = link as? URL {
                    links.append(.init(url: link, range: range))
                } else if let link = link as? String, let url = URL(string: link) {
                    links.append(.init(url: url, range: range))
                }
            }

            return links
        }

        private func detectedDataLinks(in string: NSAttributedString) -> [Link] {
            guard !linkDetectionTypes.isEmpty else {
                return []
            }

            let types = NSTextCheckingResult.CheckingType(linkDetectionTypes)

            guard let detector = try? NSDataDetector(types: types.rawValue) else {
                return []
            }

            var links: [Link] = []

            detector.enumerateMatches(
                in: string.string,
                options: [],
                range: string.entireRange
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
                            links.append(.init(url: url, range: result.range))
                        }
                    }

                case .link:
                    if let url = result.url {
                        links.append(.init(url: url, range: result.range))
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
                            links.append(.init(url: url, range: result.range))
                        }
                    }

                case .date:
                    if let date = result.date,
                       let url = URL(string: "calshow:\(date.timeIntervalSinceReferenceDate)")
                    {
                        links.append(.init(url: url, range: result.range))
                    }

                default:
                    break
                }
            }

            return links
        }

        private func accessibilityLinks(for links: [Link], in string: NSAttributedString) -> [LinkAccessibilityElement] {
            links
                .sorted(by: { $0.range.location < $1.range.location })
                .compactMap { link in
                    guard NSIntersectionRange(string.entireRange, link.range).length > 0 else {
                        return nil
                    }

                    return LinkAccessibilityElement(
                        container: self,
                        label: string.attributedSubstring(from: link.range).string,
                        link: link
                    )
                }
        }

        func applyLinkColors(activeLinks: [Link] = []) {
            let mutableString = NSMutableAttributedString(attributedString: attributedText ?? .init(string: ""))

            for link in links {
                mutableString.addAttributes(linkAttributes, range: link.range)
            }

            for link in activeLinks {
                mutableString.addAttributes(activeLinkAttributes, range: link.range)
            }

            attributedText = mutableString
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let first = touches.first else { return }
            let touchedLinks = links(at: first.location(in: self))
            trackingLinks = touchedLinks
            applyLinkColors(activeLinks: touchedLinks)
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let first = touches.first, let trackingLinks = trackingLinks else { return }
            let touchedLinks = links(at: first.location(in: self))
            let activeLinks = Set(touchedLinks).intersection(trackingLinks)
            applyLinkColors(activeLinks: Array(activeLinks))
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let first = touches.first, let trackingLinks = trackingLinks else { return }
            let touchedLinks = links(at: first.location(in: self))
            let activeLinks = Set(touchedLinks).intersection(trackingLinks)
            for link in activeLinks {
                urlHandler?.onTap(url: link.url)
            }

            self.trackingLinks = nil
            applyLinkColors()
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            trackingLinks = nil
            applyLinkColors()
        }
    }

}

extension AttributedLabel {
    struct Link: Equatable, Hashable {
        var url: URL
        var range: NSRange
    }

    private final class LinkAccessibilityElement: UIAccessibilityElement {
        private let link: AttributedLabel.Link
        private var container: LabelView? { accessibilityContainer as? LabelView }

        init(
            container: LabelView,
            label: String,
            link: AttributedLabel.Link
        ) {
            self.link = link
            super.init(accessibilityContainer: container)
            accessibilityLabel = label
        }

        override var accessibilityFrameInContainerSpace: CGRect {
            set { fatalError() }
            get {
                guard let container = container,
                      let textStorage = container.makeTextStorage(),
                      let layoutManager = textStorage.layoutManagers.first,
                      let textContainer = layoutManager.textContainers.first
                else {
                    return .zero
                }

                let glyphRange = layoutManager.glyphRange(forCharacterRange: link.range, actualCharacterRange: nil)
                return layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            }
        }

        override func accessibilityActivate() -> Bool {
            container?.urlHandler?.onTap(url: link.url)
            return true
        }
    }
}

extension AttributedLabel {
    /// Handle links opened in the receiver using the provided closure.
    ///
    public func onLinkTapped(_ onTap: @escaping (URL) -> Void) -> Element {
        adaptedEnvironment(keyPath: \.urlHandler, value: ClosureURLHandler(onTap: onTap))
    }
}

// MARK: Extensions

extension UIOffset: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(horizontal)
        hasher.combine(vertical)
    }
}

extension NSAttributedString.Key {
    fileprivate static var labelLink: NSAttributedString.Key {
        NSAttributedString.Key(rawValue: "BlueprintUICommonControls.AttributedLabel.Link")
    }
}

extension NSAttributedString {
    fileprivate var entireRange: NSRange {
        NSRange(location: 0, length: length)
    }

    /// Apply the default label font to any runs with no font attribute. This ensures the NSTextStorage is rendering
    /// the same attributes as the label.
    fileprivate func applyingDefaultFont() -> NSAttributedString {
        let mutableString = NSMutableAttributedString(attributedString: self)

        mutableString.enumerateAttribute(
            .font,
            in: NSRange(location: 0, length: mutableString.length),
            options: [.longestEffectiveRangeNotRequired]
        ) { font, range, _ in
            if font == nil {
                mutableString.addAttribute(.font, value: UIFont.systemFont(ofSize: UIFont.labelFontSize), range: range)
            }
        }

        return mutableString
    }

    fileprivate func replacingLinkAttributes() -> NSAttributedString {
        let mutableString = NSMutableAttributedString(attributedString: self)

        mutableString.enumerateAttribute(
            .link,
            in: NSRange(location: 0, length: mutableString.length),
            options: [.longestEffectiveRangeNotRequired]
        ) { link, range, _ in
            if let link = link {
                mutableString.removeAttribute(.link, range: range)
                mutableString.addAttribute(.labelLink, value: link, range: range)
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
