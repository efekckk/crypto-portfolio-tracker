import SwiftUI

struct AlertConditionView: View {
    let coin: Coin
    @ObservedObject var viewModel: CreateAlertViewModel
    let onSave: (Bool) -> Void

    @State private var direction: PriceAlert.Direction = .above
    @State private var targetPriceText: String = ""

    var body: some View {
        Form {
            Section {
                Picker("alerts.create.direction", selection: $direction) {
                    Text("alerts.direction.above").tag(PriceAlert.Direction.above)
                    Text("alerts.direction.below").tag(PriceAlert.Direction.below)
                }
                .pickerStyle(.segmented)

                LabeledContent("alerts.create.targetPrice") {
                    TextField("0.00", text: $targetPriceText)
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
        .navigationTitle("alerts.create.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("alerts.create.save") {
                    Task {
                        let saved = await viewModel.save(coin: coin, direction: direction, targetPriceText: targetPriceText)
                        if saved { onSave(true) }
                    }
                }
                .disabled(viewModel.isSaving || targetPriceText.isEmpty)
            }
        }
        .onAppear { viewModel.clearSaveError() }
    }
}
