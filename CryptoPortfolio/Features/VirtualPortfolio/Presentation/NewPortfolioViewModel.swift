import Foundation

/// Backs the "create virtual portfolio" sheet.
///
/// The user picks a starting-balance preset (or Custom + types an amount)
/// and a name. `save()` posts to the API and returns the created summary
/// so the caller can prepend it to the list without re-fetching.
@MainActor
final class NewPortfolioViewModel: ObservableObject {
    /// Starting-balance presets shown as segments. `.custom` reveals the
    /// `customBalanceText` field.
    enum BalancePreset: Equatable, CaseIterable {
        case k1
        case k10
        case k100
        case custom

        var fixedAmount: Double? {
            switch self {
            case .k1: return 1_000
            case .k10: return 10_000
            case .k100: return 100_000
            case .custom: return nil
            }
        }
    }

    @Published var nameText: String = ""
    @Published var balancePreset: BalancePreset = .k10
    @Published var customBalanceText: String = ""
    @Published private(set) var isSaving: Bool = false
    @Published private(set) var saveError: String?

    private let api: VirtualPortfolioAPI

    init(api: VirtualPortfolioAPI) {
        self.api = api
    }

    /// Resolved starting balance. Nil when Custom is selected with an
    /// empty/invalid amount.
    var resolvedBalance: Double? {
        if let fixed = balancePreset.fixedAmount { return fixed }
        let normalized = customBalanceText.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value > 0 else { return nil }
        return value
    }

    /// Trimmed name. Empty when only whitespace was entered.
    var trimmedName: String {
        nameText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True when the user has typed a valid 1–50 char name and a positive
    /// starting balance. UI uses this to enable the Save button.
    var canSave: Bool {
        guard !isSaving else { return false }
        let trimmed = trimmedName
        guard !trimmed.isEmpty, trimmed.count <= 50 else { return false }
        guard let balance = resolvedBalance, balance > 0 else { return false }
        return true
    }

    /// Submits the new portfolio. Returns the created summary on success
    /// (caller can prepend to the list); nil on failure (`saveError` set).
    func save() async -> VirtualPortfolioSummary? {
        guard !isSaving else { return nil }
        let trimmed = trimmedName
        guard !trimmed.isEmpty, trimmed.count <= 50 else {
            saveError = String(localized: "virtual.new.error.invalid_name",
                               defaultValue: "Name must be 1–50 characters.")
            return nil
        }
        guard let balance = resolvedBalance, balance > 0 else {
            saveError = String(localized: "virtual.new.error.invalid_balance",
                               defaultValue: "Enter a positive starting balance.")
            return nil
        }
        isSaving = true
        saveError = nil
        defer { isSaving = false }

        do {
            return try await api.createPortfolio(name: trimmed, startingBalance: balance)
        } catch let error as VirtualAPIError {
            saveError = mapCreateError(error)
            return nil
        } catch {
            saveError = error.localizedDescription
            return nil
        }
    }

    private func mapCreateError(_ error: VirtualAPIError) -> String {
        if case .conflict = error {
            return String(localized: "virtual.new.error.name_taken",
                          defaultValue: "A portfolio with this name already exists.")
        }
        return error.userFacingMessage
    }
}
