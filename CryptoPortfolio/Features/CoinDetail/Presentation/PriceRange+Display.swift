import SwiftUI

extension PriceRange {
    /// Localized short label used by the segmented selector.
    var displayLabelKey: LocalizedStringKey {
        switch self {
        case .h24: return "priceRange.h24"
        case .d7:  return "priceRange.d7"
        case .d30: return "priceRange.d30"
        case .y1:  return "priceRange.y1"
        }
    }
}
