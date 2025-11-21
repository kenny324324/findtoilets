//
//  PurchaseManager.swift
//  Toilet
//
//  Created by AI Assistant on 2025/10/01.
//

import Foundation
import StoreKit

@MainActor
class PurchaseManager: ObservableObject {
    // App Store Connect 的非消耗性商品 ID
    private let premiumProductId = "com.kenny.toilet.premium"

    @Published var premiumProduct: Product?
    @Published var isPurchased: Bool = false
    @Published var isLoading: Bool = false
    @Published var purchaseInProgress: Bool = false
    @Published var lastErrorMessage: String?

    init() {
        Task {
            await self.loadProducts()
            await self.refreshPurchasedState()
            self.startTransactionListener()
        }
    }

    var priceString: String {
        premiumProduct?.displayPrice ?? ""
    }

    // 載入產品資訊
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let products = try await Product.products(for: [premiumProductId])
            self.premiumProduct = products.first
        } catch {
            self.lastErrorMessage = "載入商品失敗：\(error.localizedDescription)"
        }
    }

    // 重新整理已購買狀態（買斷）
    func refreshPurchasedState() async {
        do {
            if let latest = try await Transaction.latest(for: premiumProductId) {
                switch latest {
                case .verified(let transaction):
                    // 若已退款會有 revocationDate
                    self.isPurchased = transaction.revocationDate == nil
                case .unverified:
                    self.isPurchased = false
                }
            } else {
                self.isPurchased = false
            }
        } catch {
            self.lastErrorMessage = "查詢購買狀態失敗：\(error.localizedDescription)"
        }
    }

    // 購買
    func purchasePremium() async {
        guard let product = premiumProduct else {
            await loadProducts()
            if premiumProduct == nil {
                lastErrorMessage = "無法取得商品資訊"
                return
            }
            return await purchasePremium()
        }

        purchaseInProgress = true
        defer { purchaseInProgress = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    self.isPurchased = transaction.revocationDate == nil
                    await transaction.finish()
                case .unverified:
                    self.isPurchased = false
                    self.lastErrorMessage = "交易驗證失敗"
                }
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            self.lastErrorMessage = "購買失敗：\(error.localizedDescription)"
        }
    }

    // 回復購買
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshPurchasedState()
        } catch {
            self.lastErrorMessage = "回復購買失敗：\(error.localizedDescription)"
        }
    }

    // 監聽交易更新
    private func startTransactionListener() {
        Task.detached { [weak self] in
            guard let self else { return }
            for await result in Transaction.updates {
                await self.handle(transactionResult: result)
            }
        }
    }

    private func handle(transactionResult: VerificationResult<Transaction>) async {
        switch transactionResult {
        case .verified(let transaction):
            if transaction.productID == premiumProductId {
                await MainActor.run {
                    self.isPurchased = transaction.revocationDate == nil
                }
            }
            await transaction.finish()
        case .unverified:
            await MainActor.run {
                self.lastErrorMessage = "交易未通過驗證"
            }
        }
    }
}


