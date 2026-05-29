import SwiftUI

/// Form pushed onto the AddCoin navigation stack once a coin is picked.
/// Calls `onSave(true)` when the holding is saved, `onSave(false)` if cancelled.
struct AmountEntryView: View {
    let coin: Coin
    @ObservedObject var viewModel: AddCoinViewModel
    let onSave: (Bool) -> Void

    @State private var amountText: String = ""
    @State private var buyPriceText: String = ""

    var body: some View {
        Form {
            Section {
                LabeledContent("addCoin.amount.label") {
                    TextField("addCoin.amount.placeholder", text: $amountText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("addCoin.buyPrice.label") {
                    TextField("addCoin.buyPrice.placeholder", text: $buyPriceText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text(coin.name)
            } footer: {
                if let error = viewModel.saveError {
                    Text(error).foregroundStyle(Theme.negative)
                }
            }
        }
        .navigationTitle("addCoin.amount.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("addCoin.save") { Task { await save() } }
                    .disabled(viewModel.isSaving || !canSave)
            }
        }
    }

    private var canSave: Bool {
        parsed(amountText) != nil && parsed(buyPriceText) != nil
    }

    private func parsed(_ text: String) -> Double? {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private func save() async {
        guard let amount = parsed(amountText), let buyPrice = parsed(buyPriceText) else { return }
        let saved = await viewModel.add(coinId: coin.id, amount: amount, buyPrice: buyPrice)
        if saved { onSave(true) }
    }
}
