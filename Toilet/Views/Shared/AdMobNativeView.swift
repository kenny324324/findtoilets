import SwiftUI
import GoogleMobileAds

struct AdMobNativeView: UIViewRepresentable {
    let nativeAd: GoogleMobileAds.NativeAd
    
    func makeUIView(context: Context) -> NativeAdView {
            // 建立一個 NativeAdView，給予一個初始 frame
            let adView = NativeAdView(frame: CGRect(x: 0, y: 0, width: 375, height: 300))
        
        // 設置 UI 元件
        setupAdView(adView)
        
        return adView
    }
    
    func updateUIView(_ uiView: NativeAdView, context: Context) {
        // 將廣告資料綁定到視圖
        uiView.nativeAd = nativeAd
        
        // 更新 UI 內容
        (uiView.headlineView as? UILabel)?.text = nativeAd.headline
        (uiView.bodyView as? UILabel)?.text = nativeAd.body
        (uiView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
        (uiView.iconView as? UIImageView)?.image = nativeAd.icon?.image
        (uiView.advertiserView as? UILabel)?.text = nativeAd.advertiser
        
        // 更新 Media View
        uiView.mediaView?.mediaContent = nativeAd.mediaContent
        
        // 處理星級評分或廣告主
        if let starRating = nativeAd.starRating {
            (uiView.starRatingView as? UILabel)?.text = "\(starRating) ★"
            uiView.starRatingView?.isHidden = false
            (uiView.advertiserView as? UILabel)?.isHidden = true
        } else if let advertiser = nativeAd.advertiser {
            (uiView.advertiserView as? UILabel)?.text = advertiser
            (uiView.advertiserView as? UILabel)?.isHidden = false
            uiView.starRatingView?.isHidden = true
        } else {
            uiView.starRatingView?.isHidden = true
            (uiView.advertiserView as? UILabel)?.isHidden = true
        }
    }
    
    private func setupAdView(_ adView: NativeAdView) {
        // 設置容器樣式 - 卡片風格
        // 跟列表一樣的半透明背景 (Color.black.opacity(0.03))
        adView.backgroundColor = UIColor.black.withAlphaComponent(0.03)
        adView.layer.cornerRadius = 16 // 圓角
        adView.clipsToBounds = true
        
        // 1. Icon
        let iconView = UIImageView()
        iconView.contentMode = .scaleAspectFit
        iconView.layer.cornerRadius = 8
        iconView.clipsToBounds = true
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.backgroundColor = UIColor.systemGray5
        adView.addSubview(iconView)
        adView.iconView = iconView
        
        // 2. Headline
        let headlineLabel = UILabel()
        headlineLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        headlineLabel.textColor = .label
        headlineLabel.numberOfLines = 1
        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(headlineLabel)
        adView.headlineView = headlineLabel
        
        // 4. Advertiser / Star Rating Row (Using StackView for auto layout)
        let adBadge = UILabel()
        adBadge.text = "廣告"
        adBadge.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        adBadge.textColor = .secondaryLabel
        adBadge.layer.borderColor = UIColor.secondaryLabel.cgColor
        adBadge.layer.borderWidth = 1
        adBadge.layer.cornerRadius = 3
        adBadge.textAlignment = .center
        adBadge.translatesAutoresizingMaskIntoConstraints = false
        // adBadge Width constraint: 32
        adBadge.widthAnchor.constraint(equalToConstant: 32).isActive = true
        adBadge.heightAnchor.constraint(equalToConstant: 16).isActive = true
        
        let advertiserLabel = UILabel()
        advertiserLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        advertiserLabel.textColor = .secondaryLabel
        advertiserLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.advertiserView = advertiserLabel
        
        let starRatingLabel = UILabel()
        starRatingLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        starRatingLabel.textColor = .systemOrange
        starRatingLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.starRatingView = starRatingLabel
        
        // Info Stack: Badge + Advertiser + StarRating
        let infoStack = UIStackView(arrangedSubviews: [adBadge, advertiserLabel, starRatingLabel])
        infoStack.axis = .horizontal
        infoStack.spacing = 8
        infoStack.alignment = .center
        infoStack.distribution = .fill
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(infoStack)
        
        // 5. Media View (圖片調小一點)
        let mediaView = MediaView()
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        mediaView.contentMode = .scaleAspectFill
        mediaView.clipsToBounds = true
        mediaView.layer.cornerRadius = 8
        // 移除背景陰影，改用半透明灰色背景
        mediaView.backgroundColor = UIColor.systemGray.withAlphaComponent(0.1)
        adView.addSubview(mediaView)
        adView.mediaView = mediaView
        
        // 6. Body
        let bodyLabel = UILabel()
        bodyLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 2
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(bodyLabel)
        adView.bodyView = bodyLabel
        
        // 7. Call to Action Button
        let ctaButton = UIButton(type: .custom)
        // 按鈕背景：淺藍色底 (0.2 opacity)
        ctaButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
        // 按鈕文字：藍色字
        ctaButton.setTitleColor(.systemBlue, for: .normal)
        ctaButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        ctaButton.layer.cornerRadius = 18
        ctaButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 20, bottom: 8, right: 20)
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        ctaButton.isUserInteractionEnabled = false 
        adView.addSubview(ctaButton)
        adView.callToActionView = ctaButton
        
        // Layout Constraints - 左右擺放 (Body + CTA)
        
        NSLayoutConstraint.activate([
            // Icon: 左上角
            iconView.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 16),
            iconView.topAnchor.constraint(equalTo: adView.topAnchor, constant: 16),
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40),
            
            // Headline: Icon 右側
            headlineLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            headlineLabel.topAnchor.constraint(equalTo: iconView.topAnchor),
            headlineLabel.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -16),
            
            // Info Stack (Badge + Advertiser/Rating): Headline 下方
            infoStack.leadingAnchor.constraint(equalTo: headlineLabel.leadingAnchor),
            infoStack.bottomAnchor.constraint(equalTo: iconView.bottomAnchor),
            infoStack.trailingAnchor.constraint(lessThanOrEqualTo: adView.trailingAnchor, constant: -16),
            
            // MediaView: Icon 下方，寬度填滿 (稍微縮減高度 160 -> 150)
            mediaView.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 16),
            mediaView.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 16),
            mediaView.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -16),
            mediaView.heightAnchor.constraint(equalToConstant: 150),
            
            // CTA Button: MediaView 下方，靠右
            ctaButton.topAnchor.constraint(equalTo: mediaView.bottomAnchor, constant: 16),
            ctaButton.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -16),
            ctaButton.heightAnchor.constraint(equalToConstant: 36),
            ctaButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80), // 最小寬度
            ctaButton.bottomAnchor.constraint(lessThanOrEqualTo: adView.bottomAnchor, constant: -16),
            
            // Body: MediaView 下方，在 CTA 左側
            bodyLabel.topAnchor.constraint(equalTo: mediaView.bottomAnchor, constant: 16),
            bodyLabel.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 16),
            bodyLabel.trailingAnchor.constraint(equalTo: ctaButton.leadingAnchor, constant: -12), // 與按鈕保持距離
            bodyLabel.centerYAnchor.constraint(equalTo: ctaButton.centerYAnchor) // 垂直置中對齊
        ])
    }
}

struct AdMobNativeCard: View {
    @StateObject private var adManager = NativeAdManager()
    @EnvironmentObject var premiumManager: PremiumManager
    
    var body: some View {
        if !premiumManager.isPremium {
            Group {
                if let nativeAd = adManager.nativeAd {
                    AdMobNativeView(nativeAd: nativeAd)
                        .frame(height: 300) // 調整高度
                        .background(Color.clear)
                        .padding(.horizontal, 20) // 增加水平 Padding 讓它變成獨立區塊
                        .padding(.vertical, 10)   // 增加垂直 Padding
                        // 移除陰影
                        // .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2) 
                } else {
                    Color.clear
                        .frame(height: 0)
                        .onAppear {
                            adManager.loadAd()
                        }
                }
            }
        }
    }
}

// MARK: - NativeAdManager
class NativeAdManager: NSObject, ObservableObject, NativeAdLoaderDelegate {
    @Published var nativeAd: GoogleMobileAds.NativeAd?
    @Published var isAdLoaded: Bool = false
    
    private var adLoader: AdLoader?
    // 暫時使用測試 ID 以驗證 UI
    // private let adUnitID = "ca-app-pub-3940256099942544/3986624511" // 測試 ID
    // 正式 ID
    private let adUnitID = "ca-app-pub-9616816354780961/3981943771"
    
    override init() {
        super.init()
    }
    
    func loadAd() {
        if nativeAd != nil { return }
        
        let multipleAdsOptions = MultipleAdsAdLoaderOptions()
        multipleAdsOptions.numberOfAds = 1
        
        // 明確設置 AdChoices 位置
        let adViewOptions = NativeAdViewAdOptions()
        adViewOptions.preferredAdChoicesPosition = .topRightCorner
        
        adLoader = AdLoader(
            adUnitID: adUnitID,
            rootViewController: nil,
            adTypes: [.native],
            options: [multipleAdsOptions, adViewOptions]
        )
        adLoader?.delegate = self
        adLoader?.load(Request())
    }
    
    // MARK: - NativeAdLoaderDelegate
    
    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: GoogleMobileAds.NativeAd) {
        self.nativeAd = nativeAd
        self.isAdLoaded = true
        print("AdMob: 原生廣告載入成功")
    }
    
    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        print("AdMob: 原生廣告載入失敗 - \(error.localizedDescription)")
        self.isAdLoaded = false
    }
}
