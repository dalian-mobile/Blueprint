import UIKit

/// `AttributedText` allows you to add attributes to strings with strong types - just like the `AttributedString` type
/// introduced in Swift 5.5.
///
@dynamicMemberLookup struct AttributedText {
    let text: String

    private let mutableAttributedString: NSMutableAttributedString

    init(text: String) {
        self.text = text
        self.mutableAttributedString = NSMutableAttributedString(string: text)
    }

    init(attributedText: NSAttributedString) {
        self.text = attributedText.string
        self.mutableAttributedString = NSMutableAttributedString(attributedString: attributedText)
    }

    var entireRange: Range<String.Index> {
        text.startIndex..<text.endIndex
    }

    var foundationString: NSAttributedString {
        mutableAttributedString
    }

    subscript<Value>(dynamicMember keyPath: WritableKeyPath<TextAttributeContainer, Value>) -> Value {
        get {
            self[entireRange][keyPath: keyPath]
        }
        set {
            self[entireRange][keyPath: keyPath] = newValue
        }
    }

    subscript(range: Range<String.Index>) -> TextAttributeContainer {
        get {
            let range = NSRange(range, in: text)
            return makeAttributeStore(range: range)
        }
        set {
            let range = NSRange(range, in: text)
            mutableAttributedString.addAttributes(newValue.storage, range: range)
        }
    }

    func makeAttributeStore(range: NSRange) -> TextAttributeContainer {
        var store = TextAttributeContainer.empty

        mutableAttributedString.enumerateAttributes(
            in: range,
            options: []
        ) { attributes, attributesRange, _ in
            if attributesRange == range {
                store.storage.merge(attributes, uniquingKeysWith: { $1 })
            }
        }

        return store
    }

    static func + (lhs: AttributedText, rhs: AttributedText) -> AttributedText {
        let newString = NSMutableAttributedString(attributedString: lhs.mutableAttributedString)
        newString.append(rhs.mutableAttributedString)
        return AttributedText(attributedText: newString)
    }
}
