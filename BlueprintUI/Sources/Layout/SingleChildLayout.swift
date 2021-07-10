import UIKit

/// Conforming types can calculate layout attributes for an array of children.
public protocol SingleChildLayout {
    
    /// Computes the size that this layout requires
    ///
    /// - parameter constraint: The size constraint in which measuring should occur.
    /// - parameter child: A `Measurable` representing the single child of this layout.
    ///
    /// - returns: The measured size.
    func measure(
        child: Measurable,
        in constraint : SizeConstraint,
        with context: LayoutContext
    ) -> CGSize

    /// Generates layout attributes for the child.
    ///
    /// - parameter size: The size that layout attributes should be generated within.
    ///
    /// - parameter child: A `Measurable` representing the single child of this layout.
    ///
    /// - returns: Layout attributes for the child of this layout.
    func layout(
        child: Measurable,
        in size : CGSize,
        with context : LayoutContext
    ) -> LayoutAttributes
}


extension SingleChildLayout {
    
    /// The default implementation simply passes through the measured size of the layout.
    public func layout(
        child: Measurable,
        in size : CGSize,
        with context : LayoutContext
    ) -> LayoutAttributes
    {
        LayoutAttributes(size: size)
    }
}
