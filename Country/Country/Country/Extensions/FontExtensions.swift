//
//  FontExtensions.swift
//  Country
//
//  Created by Kenny's Macbook on 2024/11/27.
//

import SwiftUI

extension Font {
    // 標題字體
    static func titleRounded(_ weight: Font.Weight = .regular) -> Font {
        return .system(.title, design: .rounded, weight: weight)
    }
    
    // 大標題字體
    static func largeTitleRounded(_ weight: Font.Weight = .regular) -> Font {
        return .system(.largeTitle, design: .rounded, weight: weight)
    }
    
    // 標題2字體
    static func title2Rounded(_ weight: Font.Weight = .regular) -> Font {
        return .system(.title2, design: .rounded, weight: weight)
    }
    
    // 標題3字體
    static func title3Rounded(_ weight: Font.Weight = .regular) -> Font {
        return .system(.title3, design: .rounded, weight: weight)
    }
    
    // 標題頭字體
    static func headlineRounded(_ weight: Font.Weight = .regular) -> Font {
        return .system(.headline, design: .rounded, weight: weight)
    }
    
    // 子標題字體
    static func subheadlineRounded(_ weight: Font.Weight = .regular) -> Font {
        return .system(.subheadline, design: .rounded, weight: weight)
    }
    
    // 正文字體
    static func bodyRounded(_ weight: Font.Weight = .regular) -> Font {
        return .system(.body, design: .rounded, weight: weight)
    }
    
    // 呼叫字體
    static func calloutRounded(_ weight: Font.Weight = .regular) -> Font {
        return .system(.callout, design: .rounded, weight: weight)
    }
    
    // 註腳字體
    static func footnoteRounded(_ weight: Font.Weight = .regular) -> Font {
        return .system(.footnote, design: .rounded, weight: weight)
    }
    
    // 說明字體
    static func captionRounded(_ weight: Font.Weight = .regular) -> Font {
        return .system(.caption, design: .rounded, weight: weight)
    }
    
    // 小說明字體
    static func caption2Rounded(_ weight: Font.Weight = .regular) -> Font {
        return .system(.caption2, design: .rounded, weight: weight)
    }
    
    // 自定義大小字體
    static func customRounded(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .system(size: size, weight: weight, design: .rounded)
    }
}
