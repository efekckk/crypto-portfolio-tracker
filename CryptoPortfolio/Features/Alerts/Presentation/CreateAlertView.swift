import SwiftUI

struct CreateAlertView: View {
    private let container: AppContainer
    private let initialCoin: Coin?
    let onDone: (_ didCreate: Bool) -> Void

    init(container: AppContainer, initialCoin: Coin? = nil, onDone: @escaping (Bool) -> Void) {
        self.container = container
        self.initialCoin = initialCoin
        self.onDone = onDone
    }

    var body: some View {
        NavigationStack {
            root
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.cancel") { onDone(false) }
                    }
                }
        }
    }

    @ViewBuilder
    private var root: some View {
        if let coin = initialCoin {
            // CoinDetail shortcut: skip the chooser, jump straight to the
            // price-crossing form. Wrapping in a NavigationLink keeps the
            // back affordance consistent with the chooser path.
            PriceAlertFormView(coin: coin, container: container) { saved in onDone(saved) }
        } else {
            AlertTypeChooserView(container: container, onDone: onDone)
        }
    }
}
