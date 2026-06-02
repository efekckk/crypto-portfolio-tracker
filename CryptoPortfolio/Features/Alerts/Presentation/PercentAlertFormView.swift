import SwiftUI

struct PercentAlertFormView: View {
    @StateObject private var viewModel: CreatePercentAlertViewModel
    let onSave: (Bool) -> Void

    init(coin: Coin, container: AppContainer, onSave: @escaping (Bool) -> Void) {
        _viewModel = StateObject(wrappedValue: CreatePercentAlertViewModel(
            coin: coin,
            createAlert: container.makeCreateAlertUseCase()
        ))
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section {
                Picker("alerts.form.window", selection: $viewModel.window) {
                    Text("alerts.window.h24").tag(AlertCondition.PercentWindow.h24)
                    Text("alerts.window.d7").tag(AlertCondition.PercentWindow.d7)
                    Text("alerts.window.d30").tag(AlertCondition.PercentWindow.d30)
                }
                .pickerStyle(.segmented)

                Picker("alerts.form.direction", selection: $viewModel.direction) {
                    Text("alerts.direction.above").tag(AlertCondition.Direction.above)
                    Text("alerts.direction.below").tag(AlertCondition.Direction.below)
                }
                .pickerStyle(.segmented)

                LabeledContent("alerts.form.threshold") {
                    TextField("0.0", text: $viewModel.thresholdText)
                        .keyboardType(.numbersAndPunctuation)
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
                .disabled(viewModel.isSaving || viewModel.thresholdText.isEmpty)
            }
        }
        .onAppear { viewModel.clearSaveError() }
    }
}
