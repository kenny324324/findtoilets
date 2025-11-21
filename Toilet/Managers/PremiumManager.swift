//
//  PremiumManager.swift
//  Toilet
//
//  Created by Kenny's Macbook on 2024/11/27.
//

import Foundation
import SwiftUI

class PremiumManager: ObservableObject {
    // 付費狀態（由 StoreKit 交易結果決定）
    @Published var isPremium: Bool = false
    
    init() {}
    
    // 與 StoreKit 同步權益
    func updateFromPurchaseState(isPurchased: Bool) {
        if self.isPremium != isPurchased {
            self.isPremium = isPurchased
            print("Premium 狀態同步：\(isPurchased)")
        }
    }
}
