import SwiftUI

struct PortfolioAlertFormView: View {
    @StateObject private var viewModel: CreatePortfolioAlertViewModel
    let onSave: (Bool) -> Void

    init(metric: CreatePortfolioAlertViewModel.Metric,
         container: AppContainer,
         onSave: @escaping (Bool) -> Void) {
        _viewModel = StateObject(wrappedValue: CreatePortfolioAlertViewModel(
            metric: metric,
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

                LabeledContent("alerts.form.threshold") {
                    TextField("0.0", text: $viewModel.thresholdText)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text(viewModel.metric == .value
                     ? "alerts.metric.value"
                     : "alerts.metric.pnlPercent")
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
