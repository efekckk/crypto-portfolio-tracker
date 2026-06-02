import SwiftUI

struct PriceAlertFormView: View {
    @StateObject private var viewModel: CreatePriceAlertViewModel
    let onSave: (Bool) -> Void

    init(coin: Coin, container: AppContainer, onSave: @escaping (Bool) -> Void) {
        _viewModel = StateObject(wrappedValue: CreatePriceAlertViewModel(
            coin: coin,
            createAlert: container.makeCreateAlertUseCase()
        ))
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section {
                Picker("alerts.form.direction", selection: $viewModel.direction) {
                    Text("alerts.direction.above").tag(AlertCondition.Direction.above)
                    Text("alerts.direction.below").tag(AlertCondition.Direction.below)
                }
                .pickerStyle(.segmented)

                LabeledContent("alerts.create.targetPrice") {
                    TextField("0.00", text: $viewModel.targetPriceText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text(viewModel.coin.name)
            } footer: {
                if let error = viewModel.saveError {
                    Text(error).foregroundStyle(Theme.negative)
                }
            }

            RecurrencePickerView(state: $viewModel.recurrence)
        }
        .navigationTitle("alerts.create.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("alerts.create.save") {
                    Task {
                        let saved = await viewModel.save()
                        if saved { onSave(true) }
                    }
                }
                .disabled(viewModel.isSaving || viewModel.targetPriceText.isEmpty)
            }
        }
        .onAppear { viewModel.clearSaveError() }
    }
}
