import UIKit

extension AttributedLabel {
    public enum LinkDetectionType: Equatable, Hashable {
        case date
        case address
        case link
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

    public struct Link: Equatable, Hashable {
        internal var perform: () -> Void

        public private(set) var hashValue: Int
        public var range: NSRange

        public init(url: URL, range: NSRange) {
            hashValue = url.hashValue
            self.range = range

            perform = {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }

        public init(range: NSRange, onTap: @escaping () -> Void) {
            hashValue = UUID().hashValue
            perform = onTap
            self.range = range
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(hashValue)
        }

        public static func == (lhs: AttributedLabel.Link, rhs: AttributedLabel.Link) -> Bool {
            rhs.hashValue == lhs.hashValue
        }
    }
}
