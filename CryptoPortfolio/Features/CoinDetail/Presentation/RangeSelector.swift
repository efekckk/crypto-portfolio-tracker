import SwiftUI

struct RangeSelector: View {
    @Binding var selection: PriceRange

    var body: some View {
        Picker("priceRange.label", selection: $selection) {
            ForEach(PriceRange.allCases) { range in
                Text(range.displayLabelKey).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }
}
