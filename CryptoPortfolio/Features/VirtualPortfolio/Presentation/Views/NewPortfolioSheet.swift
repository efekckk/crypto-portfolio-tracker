import SwiftUI

/// Modal sheet for creating a new virtual portfolio.
/// On success, `onCreated` delivers the new summary to the caller (which
/// can prepend it to its list) and the sheet dismisses.
struct NewPortfolioSheet: View {
    @StateObject private var viewModel: NewPortfolioViewModel
    @Environment(\.dismiss) private var dismiss

    let onCreated: (VirtualPortfolioSummary) -> Void

    init(api: VirtualPortfolioAPI, onCreated: @escaping (VirtualPortfolioSummary) -> Void) {
        _viewModel = StateObject(wrappedValue: NewPortfolioViewModel(api: api))
        self.onCreated = onCreated
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        String(localized: "virtual.new.name.placeholder",
                               defaultValue: "Portfolio name"),
                        text: $viewModel.nameText
                    )
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
                } header: {
                    Text(String(localized: "virtual.new.name.header", defaultValue: "NAME"))
                }

                Section {
                    Picker(
                        String(localized: "virtual.new.balance.picker.label",
                               defaultValue: "Starting balance"),
                        selection: $viewModel.balancePreset
                    ) {
                        Text(String(localized: "virtual.new.preset.1k", defaultValue: "$1k"))
                            .tag(NewPortfolioViewModel.BalancePreset.k1)
                        Text(String(localized: "virtual.new.preset.10k", defaultValue: "$10k"))
                            .tag(NewPortfolioViewModel.BalancePreset.k10)
                        Text(String(localized: "virtual.new.preset.100k", defaultValue: "$100k"))
                            .tag(NewPortfolioViewModel.BalancePreset.k100)
                        Text(String(localized: "virtual.new.preset.custom", defaultValue: "Custom"))
                            .tag(NewPortfolioViewModel.BalancePreset.custom)
                    }
                    .pickerStyle(.segmented)

                    if viewModel.balancePreset == .custom {
                        TextField(
                            String(localized: "virtual.new.custom.placeholder",
                                   defaultValue: "Amount in USD"),
                            text: $viewModel.customBalanceText
                        )
                        .keyboardType(.decimalPad)
                    }
                } header: {
                    Text(String(localized: "virtual.new.balance.header",
                                defaultValue: "STARTING BALANCE"))
                }

                if let error = viewModel.saveError {
                    Section {
                        Text(error)
                            .foregroundStyle(Theme.negative)
                            .font(.subheadline)
                    }
                }

                Section {
                    Button {
                        Task { await handleSave() }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isSaving {
                                ProgressView()
                            } else {
                                Text(String(localized: "common.save", defaultValue: "Save"))
                                    .font(.body.weight(.semibold))
                            }
                            Spacer()
                        }
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .navigationTitle(
                String(localized: "virtual.new.title", defaultValue: "New Portfolio")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(
                        String(localized: "common.cancel", defaultValue: "Cancel")
                    ) { dismiss() }
                }
            }
        }
    }

    private func handleSave() async {
        guard let summary = await viewModel.save() else { return }
        onCreated(summary)
        dismiss()
    }
}
