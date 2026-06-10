import XCTest
@testable import CryptoPortfolio

final class VirtualPortfolioDTOTests: XCTestCase {

    // MARK: - Helpers

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try VirtualJSONCoder.decoder().decode(T.self, from: Data(json.utf8))
    }

    // MARK: - Summary

    func test_summary_roundTrip() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "name": "Aggressive",
          "starting_balance": 10000,
          "cash_balance": 2500,
          "total_value": 12300,
          "total_pnl": 2300,
          "total_pnl_percent": 23.0,
          "trade_count": 4,
          "created_at": "2026-06-09T10:00:00Z",
          "updated_at": "2026-06-09T11:00:00Z"
        }
        """
        let dto = try decode(VirtualPortfolioSummaryDTO.self, json)
        let domain = try XCTUnwrap(dto.toDomain())
        XCTAssertEqual(domain.name, "Aggressive")
        XCTAssertEqual(domain.startingBalance, 10000)
        XCTAssertEqual(domain.cashBalance, 2500)
        XCTAssertEqual(domain.totalPnL, 2300)
        XCTAssertEqual(domain.tradeCount, 4)
    }

    func test_summary_rejectsInvalidUUID() throws {
        let json = """
        {
          "id": "not-a-uuid", "name":"X", "starting_balance":1, "cash_balance":1,
          "total_value":1, "total_pnl":0, "total_pnl_percent":0, "trade_count":0,
          "created_at":"2026-06-09T10:00:00Z", "updated_at":"2026-06-09T10:00:00Z"
        }
        """
        let dto = try decode(VirtualPortfolioSummaryDTO.self, json)
        XCTAssertNil(dto.toDomain())
    }

    // MARK: - Detail

    func test_detail_roundTrip_withHoldings() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000002",
          "name": "Conservative",
          "starting_balance": 10000,
          "cash_balance": 3000,
          "total_value": 11000,
          "realized_pnl": 0,
          "unrealized_pnl": 1000,
          "total_pnl_percent": 10,
          "holdings": [
            {
              "coin_id":"bitcoin","amount":0.1,"average_buy_price":70000,
              "current_price":80000,"current_value":8000,
              "unrealized_pnl":1000,"unrealized_pnl_percent":14.28
            },
            {
              "coin_id":"ethereum","amount":2,"average_buy_price":3000,
              "current_price":null,"current_value":null,
              "unrealized_pnl":null,"unrealized_pnl_percent":null
            }
          ],
          "created_at":"2026-06-09T10:00:00Z",
          "updated_at":"2026-06-09T11:00:00Z"
        }
        """
        let dto = try decode(VirtualPortfolioDetailDTO.self, json)
        let domain = try XCTUnwrap(dto.toDomain())
        XCTAssertEqual(domain.holdings.count, 2)
        let btc = try XCTUnwrap(domain.holdings.first { $0.coinId == "bitcoin" })
        XCTAssertEqual(btc.currentPrice, 80000)
        XCTAssertEqual(btc.unrealizedPnL, 1000)
        let eth = try XCTUnwrap(domain.holdings.first { $0.coinId == "ethereum" })
        XCTAssertNil(eth.currentPrice)
        XCTAssertNil(eth.unrealizedPnL)
    }

    // MARK: - Quote

    func test_quote_roundTrip() throws {
        let json = """
        {
          "coin_id":"bitcoin","coin_name":"Bitcoin","price":80000,
          "fetched_at":"2026-06-09T10:00:00.123Z",
          "max_buy_amount":1.5,"max_sell_amount":0.25
        }
        """
        let dto = try decode(VirtualQuoteDTO.self, json)
        let domain = dto.toDomain()
        XCTAssertEqual(domain.coinId, "bitcoin")
        XCTAssertEqual(domain.coinName, "Bitcoin")
        XCTAssertEqual(domain.price, 80000)
        XCTAssertEqual(domain.maxBuyAmount, 1.5)
        XCTAssertEqual(domain.maxSellAmount, 0.25)
    }

    // MARK: - Trades

    func test_trade_roundTrip_buy() throws {
        let json = """
        { "id":12345, "side":"buy", "coin_id":"bitcoin",
          "amount":0.1, "price":75000,
          "executed_at":"2026-06-09T10:00:00Z" }
        """
        let dto = try decode(VirtualTradeDTO.self, json)
        let domain = try XCTUnwrap(dto.toDomain())
        XCTAssertEqual(domain.side, .buy)
        XCTAssertEqual(domain.coinId, "bitcoin")
        XCTAssertEqual(domain.amount, 0.1)
    }

    func test_trade_roundTrip_sell() throws {
        let json = """
        { "id":12346, "side":"sell", "coin_id":"ethereum",
          "amount":2, "price":3500,
          "executed_at":"2026-06-09T10:01:00Z" }
        """
        let dto = try decode(VirtualTradeDTO.self, json)
        let domain = try XCTUnwrap(dto.toDomain())
        XCTAssertEqual(domain.side, .sell)
    }

    func test_trade_rejectsUnknownSide() throws {
        let json = """
        { "id":1, "side":"hodl", "coin_id":"btc", "amount":1, "price":1,
          "executed_at":"2026-06-09T10:00:00Z" }
        """
        let dto = try decode(VirtualTradeDTO.self, json)
        XCTAssertNil(dto.toDomain())
    }

    func test_tradeHistoryPage_roundTrip() throws {
        let json = """
        {
          "trades": [
            { "id":2, "side":"buy", "coin_id":"btc", "amount":1, "price":1,
              "executed_at":"2026-06-09T10:00:00Z" },
            { "id":1, "side":"buy", "coin_id":"btc", "amount":1, "price":1,
              "executed_at":"2026-06-09T09:00:00Z" }
          ],
          "next_cursor": null
        }
        """
        let dto = try decode(VirtualTradeHistoryPageDTO.self, json)
        let page = dto.toDomain()
        XCTAssertEqual(page.trades.count, 2)
        XCTAssertNil(page.nextCursor)
    }

    func test_tradeHistoryPage_carriesCursor() throws {
        let json = """
        { "trades": [], "next_cursor": 12289 }
        """
        let dto = try decode(VirtualTradeHistoryPageDTO.self, json)
        XCTAssertEqual(dto.toDomain().nextCursor, 12289)
    }

    // MARK: - Execute trade response

    func test_executeTrade_roundTrip() throws {
        let json = """
        {
          "trade": { "id":1, "side":"buy", "coin_id":"bitcoin",
                    "amount":0.05, "price":80000,
                    "executed_at":"2026-06-09T10:00:00Z" },
          "portfolio": {
            "id":"00000000-0000-0000-0000-000000000010",
            "name":"P", "starting_balance":10000, "cash_balance":6000,
            "total_value":10000, "realized_pnl":0, "unrealized_pnl":0,
            "total_pnl_percent":0, "holdings":[],
            "created_at":"2026-06-09T10:00:00Z",
            "updated_at":"2026-06-09T10:00:01Z"
          }
        }
        """
        let dto = try decode(ExecuteTradeResponseDTO.self, json)
        XCTAssertEqual(dto.trade.id, 1)
        XCTAssertEqual(dto.portfolio.cashBalance, 6000)
    }

    // MARK: - Create response

    func test_create_roundTrip() throws {
        let json = """
        { "id":"00000000-0000-0000-0000-000000000011","name":"X",
          "starting_balance":1000, "created_at":"2026-06-09T10:00:00Z" }
        """
        let dto = try decode(VirtualPortfolioCreateResponseDTO.self, json)
        XCTAssertEqual(dto.name, "X")
        XCTAssertEqual(dto.startingBalance, 1000)
    }
}
