import SwiftUI
import MapKit

// 廁所地點標記
class ToiletLocationAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let location: ToiletLocation
    
    init(location: ToiletLocation) {
        self.coordinate = location.coordinate
        self.title = location.name
        self.subtitle = "\(location.totalToiletCount)間廁所"
        self.location = location
        super.init()
    }
}

struct MapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var mapType: MKMapType
    var userLocation: CLLocation?
    var toilets: [ToiletInfo] = []
    var locations: [ToiletLocation] = [] // 新增：群組後的地點資料
    @Binding var shouldJumpToLocation: Bool // 控制是否應該跳回位置
    var onRegionChanged: ((MKCoordinateRegion) -> Void)? = nil
    var shouldUpdateRegion: Bool = true // 控制是否應該更新地圖區域
    var onToiletSelected: ((ToiletInfo) -> Void)? = nil // 當公廁被選中時的回調
    var onLocationSelected: ((ToiletLocation) -> Void)? = nil // 當地點被選中時的回調

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.region = region
        mapView.mapType = mapType
        
        // 啟用用戶位置顯示，同時使用自定義標記
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        
        // 調整地圖邊距，讓 Apple logo 顯示得比 sheet 更高
        mapView.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 200, right: 0)
        
        // 設置縮放限制
        setupZoomLimits(for: mapView)
        
        // 添加手勢識別來區分點擊和滑動
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapTap(_:)))
        tapGesture.numberOfTapsRequired = 1
        mapView.addGestureRecognizer(tapGesture)
        
        return mapView
    }
    
    // 設置縮放限制
    private func setupZoomLimits(for mapView: MKMapView) {
        // 使用 MKMapView 的內建縮放限制
        mapView.cameraZoomRange = MKMapView.CameraZoomRange(
            minCenterCoordinateDistance: 500, // 最小距離 500m（避免縮得太小）
            maxCenterCoordinateDistance: 15000  // 最大距離 15km（避免放得太大）
        )
        
        // 設置地圖的滾動和縮放行為
        mapView.isScrollEnabled = true
        mapView.isZoomEnabled = true
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        
        // 設置地圖的滾動邊界
        mapView.cameraBoundary = MKMapView.CameraBoundary(coordinateRegion: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 25.0, longitude: 121.5),
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        ))
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.mapType = mapType
        
        // 使用動畫更新公廁標記，減少閃爍
        UIView.animate(withDuration: 0.2, animations: {
            self.updateToiletAnnotations(in: uiView)
        })
        
        // 檢查是否需要跳回位置（有動畫）
        if shouldJumpToLocation {
            // 確保區域參數有效
            let validRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: max(-90, min(90, region.center.latitude)),
                    longitude: max(-180, min(180, region.center.longitude))
                ),
                span: MKCoordinateSpan(
                    latitudeDelta: max(0.001, min(180, region.span.latitudeDelta)),
                    longitudeDelta: max(0.001, min(360, region.span.longitudeDelta))
                )
            )
            
            // 使用 setRegion 的內建動畫，讓地圖平滑平移
            uiView.setRegion(validRegion, animated: true)
            
            // 重置跳回標記
            DispatchQueue.main.async {
                self.shouldJumpToLocation = false
            }
        }
    }
    
    // 更新公廁標記（使用群組後的地點資料）
    private func updateToiletAnnotations(in mapView: MKMapView) {
        // 獲取現有標記
        let existingAnnotations = mapView.annotations.filter { 
            $0 is ToiletAnnotation || $0 is ToiletLocationAnnotation 
        }
        
        // 優先使用群組後的地點資料
        if !locations.isEmpty {
            // 檢查是否需要更新地點標記
            let existingLocationAnnotations = existingAnnotations.compactMap { $0 as? ToiletLocationAnnotation }
            let existingLocationIds = Set(existingLocationAnnotations.map { $0.location.id })
            let newLocationIds = Set(locations.map { $0.id })
            
            // 只移除不再需要的標記
            let annotationsToRemove = existingLocationAnnotations.filter { !newLocationIds.contains($0.location.id) }
            mapView.removeAnnotations(annotationsToRemove)
            
            // 只添加新的標記
            let locationsToAdd = locations.filter { !existingLocationIds.contains($0.id) }
            for location in locationsToAdd {
                let annotation = ToiletLocationAnnotation(location: location)
                mapView.addAnnotation(annotation)
            }
        } else {
            // 如果沒有地點資料，使用個別廁所資料
            let existingToiletAnnotations = existingAnnotations.compactMap { $0 as? ToiletAnnotation }
            let existingToiletIds = Set(existingToiletAnnotations.map { $0.toilet.id })
            let newToiletIds = Set(toilets.map { $0.id })
            
            // 只移除不再需要的標記
            let annotationsToRemove = existingToiletAnnotations.filter { !newToiletIds.contains($0.toilet.id) }
            mapView.removeAnnotations(annotationsToRemove)
            
            // 只添加新的標記
            let toiletsToAdd = toilets.filter { !existingToiletIds.contains($0.id) }
            for toilet in toiletsToAdd {
                let annotation = ToiletAnnotation(toilet: toilet)
                mapView.addAnnotation(annotation)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        private var isMapMoving = false
        private var lastTapTime: Date = Date()
        private var mapMoveTimer: Timer?
        private var lastRegion: MKCoordinateRegion?

        init(_ parent: MapView) {
            self.parent = parent
        }
        
        // 處理地圖點擊手勢
        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            let now = Date()
            // 如果距離上次點擊時間太短，忽略
            if now.timeIntervalSince(lastTapTime) < 0.3 {
                return
            }
            lastTapTime = now
            
            // 如果地圖正在移動，忽略點擊
            if isMapMoving {
                return
            }
            
            let mapView = gesture.view as! MKMapView
            let tapPoint = gesture.location(in: mapView)
            let coordinate = mapView.convert(tapPoint, toCoordinateFrom: mapView)
            
            // 檢查是否點擊了標記
            let hitTestView = mapView.hitTest(tapPoint, with: nil)
            if hitTestView is MKAnnotationView {
                // 如果點擊了標記，讓系統處理
                return
            }
        }
        
        // 根據廁所類型獲取圖示名稱
        private func getIconName(for type: String) -> String {
            switch type {
            case "女廁所":
                return "person.fill"
            case "男廁所":
                return "person.fill"
            case "親子廁所":
                return "figure.and.child.holdinghands"
            case "無障礙廁所":
                return "figure.roll"
            case "混合廁所":
                return "toilet"
            case "性別友善廁所":
                return "person.2.fill"
            default:
                return "toilet"
            }
        }
        
        // 監聽地圖區域變化（用於動態載入公廁）
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // 檢查區域是否真的發生了變化
            if let lastRegion = lastRegion {
                let centerDistance = CLLocation(latitude: lastRegion.center.latitude, longitude: lastRegion.center.longitude)
                    .distance(from: CLLocation(latitude: mapView.region.center.latitude, longitude: mapView.region.center.longitude))
                
                // 如果移動距離很小，不視為移動
                if centerDistance < 10 { // 10公尺
                    return
                }
            }
            
            // 標記地圖正在移動
            isMapMoving = true
            lastRegion = mapView.region
            
            // 取消之前的計時器
            mapMoveTimer?.invalidate()
            
            // 使用 DispatchQueue 避免在視圖更新期間修改狀態
            DispatchQueue.main.async {
                self.parent.onRegionChanged?(mapView.region)
            }
            
            // 使用計時器來更精確地控制移動狀態
            mapMoveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                DispatchQueue.main.async {
                    self.isMapMoving = false
                }
            }
        }
        
        // 監聽地圖開始移動
        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            isMapMoving = true
            // 取消之前的計時器
            mapMoveTimer?.invalidate()
        }
        
        // 處理標記點擊事件
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            // 如果地圖正在移動，忽略點擊
            if isMapMoving {
                return
            }
            
            // 添加更長的延遲，確保地圖完全停止移動
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                // 再次檢查地圖是否還在移動
                if self.isMapMoving {
                    return
                }
                
                if let locationAnnotation = view.annotation as? ToiletLocationAnnotation {
                    // 通知父視圖有地點被選中
                    self.parent.onLocationSelected?(locationAnnotation.location)
                } else if let toiletAnnotation = view.annotation as? ToiletAnnotation {
                    // 通知父視圖有公廁被選中
                    self.parent.onToiletSelected?(toiletAnnotation.toilet)
                }
            }
        }
        
        // 創建標記視圖（支援地點和個別廁所）
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 處理地點標記
            if annotation is ToiletLocationAnnotation {
                let identifier = "ToiletLocationAnnotation"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                
                if annotationView == nil {
                    annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                } else {
                    annotationView?.annotation = annotation
                }
                
                if let locationAnnotation = annotation as? ToiletLocationAnnotation {
                    // 檢查是否需要重新創建視圖
                    let needsUpdate = annotationView?.subviews.isEmpty ?? true
                    
                    if needsUpdate {
                        // 清除舊的視圖
                        annotationView?.subviews.forEach { $0.removeFromSuperview() }
                        
                        // 創建地點標記
                        let size: CGFloat = 28
                        let view = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
                        
                        // 背景圓形
                        if locationAnnotation.location.hasMultipleFloors {
                            view.backgroundColor = UIColor.systemOrange
                        } else {
                            view.backgroundColor = UIColor.systemBlue
                        }
                        view.layer.cornerRadius = size / 2
                        view.layer.borderWidth = 3
                        view.layer.borderColor = UIColor.white.cgColor
                        view.layer.masksToBounds = true
                        
                        // 添加圖示
                        let iconSize: CGFloat = 16
                        let iconView = UIImageView(frame: CGRect(
                            x: (size - iconSize) / 2,
                            y: (size - iconSize) / 2,
                            width: iconSize,
                            height: iconSize
                        ))
                        
                        // 根據是否為多樓層選擇圖示
                        if locationAnnotation.location.hasMultipleFloors {
                            iconView.image = UIImage(systemName: "building.2.fill")
                        } else {
                            iconView.image = UIImage(systemName: "toilet")
                        }
                        iconView.tintColor = .white
                        iconView.contentMode = .scaleAspectFit
                        
                        view.addSubview(iconView)
                        
                        annotationView?.addSubview(view)
                        annotationView?.frame = view.frame
                        annotationView?.centerOffset = CGPoint(x: 0, y: -size/2)
                    }
                }
                
                return annotationView
            }
            
            // 處理個別廁所標記
            if annotation is ToiletAnnotation {
                let identifier = "ToiletAnnotation"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                
                if annotationView == nil {
                    annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                } else {
                    annotationView?.annotation = annotation
                }
                
                if let toiletAnnotation = annotation as? ToiletAnnotation {
                    // 檢查是否需要重新創建視圖
                    let needsUpdate = annotationView?.subviews.isEmpty ?? true
                    
                    if needsUpdate {
                        // 清除舊的視圖
                        annotationView?.subviews.forEach { $0.removeFromSuperview() }
                        
                        // 創建簡化的標記 - 優化效能
                        let size: CGFloat = 24
                        let view = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
                        
                        // 背景圓形 - 移除陰影以提升效能
                        view.backgroundColor = UIColor(toiletAnnotation.toilet.typeColor)
                        view.layer.cornerRadius = size / 2
                        view.layer.borderWidth = 2
                        view.layer.borderColor = UIColor.white.cgColor
                        view.layer.masksToBounds = true
                        
                        // 添加簡單的圖示 - 適中的圖示大小
                        let iconSize: CGFloat = 15
                        let iconView = UIImageView(frame: CGRect(
                            x: (size - iconSize) / 2,
                            y: (size - iconSize) / 2,
                            width: iconSize,
                            height: iconSize
                        ))
                        
                        // 根據廁所類型選擇圖示
                        let iconName = getIconName(for: toiletAnnotation.toilet.type)
                        iconView.image = UIImage(systemName: iconName)
                        iconView.tintColor = .white
                        iconView.contentMode = .scaleAspectFit
                        
                        view.addSubview(iconView)
                        
                        annotationView?.addSubview(view)
                        annotationView?.frame = view.frame
                        annotationView?.centerOffset = CGPoint(x: 0, y: -size/2)
                    }
                }
                
                return annotationView
            }
            
            return nil
        }
    }
}

// 公廁標記類
class ToiletAnnotation: NSObject, MKAnnotation {
    let toilet: ToiletInfo
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    
    init(toilet: ToiletInfo) {
        self.toilet = toilet
        self.coordinate = CLLocationCoordinate2D(
            latitude: toilet.latitudeDouble,
            longitude: toilet.longitudeDouble
        )
        self.title = toilet.name
        self.subtitle = "\(toilet.type) • \(toilet.grade)"
        super.init()
    }
}

