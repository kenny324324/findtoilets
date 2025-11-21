import SwiftUI
import MapKit
import UIKit

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
    var shouldEnableClustering: Bool = true // 是否啟用聚合功能
    
    // 用於追蹤上一次的聚類狀態
    static var lastClusteringState: Bool? = nil

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
            minCenterCoordinateDistance: 150, // 最小距離 150m（允許聚合展開）
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
        
        // 檢查聚類狀態是否改變
        let clusteringChanged = MapView.lastClusteringState != shouldEnableClustering
        if clusteringChanged {
            MapView.lastClusteringState = shouldEnableClustering
            // 聚類狀態改變時，移除所有標記以強制重新創建
            let annotationsToRemove = uiView.annotations.filter { 
                $0 is ToiletAnnotation || $0 is ToiletLocationAnnotation 
            }
            uiView.removeAnnotations(annotationsToRemove)
        }
        
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
        
        let existingLocationAnnotations = existingAnnotations.compactMap { $0 as? ToiletLocationAnnotation }
        let existingToiletAnnotations = existingAnnotations.compactMap { $0 as? ToiletAnnotation }
        
        // 優先使用群組後的地點資料
        if !locations.isEmpty {
            // 移除所有個別廁所標記（因為我們要顯示地點標記）
            mapView.removeAnnotations(existingToiletAnnotations)
            
            // 更新地點標記
            let existingLocationIds = Set(existingLocationAnnotations.map { $0.location.id })
            let newLocationIds = Set(locations.map { $0.id })
            
            // 移除不再需要的地點標記
            let locationsToRemove = existingLocationAnnotations.filter { !newLocationIds.contains($0.location.id) }
            mapView.removeAnnotations(locationsToRemove)
            
            // 添加新的地點標記
            let locationsToAdd = locations.filter { !existingLocationIds.contains($0.id) }
            for location in locationsToAdd {
                let annotation = ToiletLocationAnnotation(location: location)
                mapView.addAnnotation(annotation)
            }
        } else if !toilets.isEmpty {
            // 移除所有地點標記（因為我們要顯示個別廁所）
            mapView.removeAnnotations(existingLocationAnnotations)
            
            // 更新個別廁所標記
            let existingToiletIds = Set(existingToiletAnnotations.map { $0.toilet.id })
            let newToiletIds = Set(toilets.map { $0.id })
            
            // 移除不再需要的廁所標記
            let toiletsToRemove = existingToiletAnnotations.filter { !newToiletIds.contains($0.toilet.id) }
            mapView.removeAnnotations(toiletsToRemove)
            
            // 添加新的廁所標記
            let toiletsToAdd = toilets.filter { !existingToiletIds.contains($0.id) }
            for toilet in toiletsToAdd {
                let annotation = ToiletAnnotation(toilet: toilet)
                mapView.addAnnotation(annotation)
            }
        } else {
            // 兩者都為空，移除所有標記
            mapView.removeAnnotations(existingAnnotations)
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
                
                if let cluster = view.annotation as? MKClusterAnnotation {
                    let annotations = cluster.memberAnnotations
                    
                    // 輸出聚類包含的所有地點資訊
                    print("\n🎯 點擊了聚類標記，包含 \(annotations.count) 個地點：")
                    print(String(repeating: "=", count: 50))
                    
                    for (index, annotation) in annotations.enumerated() {
                        if let locationAnnotation = annotation as? ToiletLocationAnnotation {
                            let location = locationAnnotation.location
                            print("\n[\(index + 1)] \(location.name)")
                            print("   📍 地址：\(location.address)")
                            print("   🚽 廁所數量：\(location.totalToiletCount) 間")
                            print("   🏢 樓層：\(location.toiletsByFloor.map { $0.floorName }.joined(separator: ", "))")
                            
                            // 顯示該地點的所有廁所
                            for floor in location.toiletsByFloor {
                                print("      ↳ \(floor.floorName): \(floor.toilets.count) 間")
                                for toilet in floor.toilets {
                                    print("         - \(toilet.name) (\(toilet.type))")
                                }
                            }
                        } else if let toiletAnnotation = annotation as? ToiletAnnotation {
                            let toilet = toiletAnnotation.toilet
                            print("\n[\(index + 1)] \(toilet.name)")
                            print("   📍 地址：\(toilet.address)")
                            print("   🚽 類型：\(toilet.type)")
                        }
                    }
                    print("\n" + String(repeating: "=", count: 50) + "\n")
                    
                    let coordinates = annotations.compactMap { annotation -> CLLocationCoordinate2D? in
                        if let toiletAnnotation = annotation as? ToiletAnnotation {
                            return toiletAnnotation.coordinate
                        }
                        if let locationAnnotation = annotation as? ToiletLocationAnnotation {
                            return locationAnnotation.coordinate
                        }
                        return nil
                    }
                    
                    if !coordinates.isEmpty {
                        var zoomRect = MKMapRect.null
                        for coordinate in coordinates {
                            let point = MKMapPoint(coordinate)
                            let rect = MKMapRect(
                                x: point.x,
                                y: point.y,
                                width: 200,
                                height: 200
                            )
                            zoomRect = zoomRect.union(rect)
                        }
                        
                        let padding = UIEdgeInsets(top: 80, left: 60, bottom: 220, right: 60)
                        DispatchQueue.main.async {
                            mapView.setVisibleMapRect(zoomRect, edgePadding: padding, animated: true)
                        }
                    }
                } else if let locationAnnotation = view.annotation as? ToiletLocationAnnotation {
                    // 通知父視圖有地點被選中
                    self.parent.onLocationSelected?(locationAnnotation.location)
                } else if let toiletAnnotation = view.annotation as? ToiletAnnotation {
                    // 通知父視圖有公廁被選中
                    self.parent.onToiletSelected?(toiletAnnotation.toilet)
                }
            }
        }
        
        // 創建標記視圖（支援聚合與個別標記）
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 聚合標記
            if let cluster = annotation as? MKClusterAnnotation {
                let identifier = "ToiletClusterMarker"
                let markerView: MKMarkerAnnotationView
                
                if let dequeued = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView {
                    markerView = dequeued
                    markerView.annotation = cluster
                } else {
                    markerView = MKMarkerAnnotationView(annotation: cluster, reuseIdentifier: identifier)
                    markerView.canShowCallout = true
                }
                
                markerView.markerTintColor = UIColor(red: 0.45, green: 0.35, blue: 0.87, alpha: 1)
                markerView.glyphText = "\(cluster.memberAnnotations.count)"
                markerView.glyphTintColor = .white
                markerView.titleVisibility = .hidden
                markerView.subtitleVisibility = .hidden
                markerView.displayPriority = .required
                
                let tint = markerView.markerTintColor ?? UIColor(red: 0.45, green: 0.35, blue: 0.87, alpha: 1)
                markerView.layer.shadowColor = tint.withAlphaComponent(0.35).cgColor
                markerView.layer.shadowOpacity = 0.9
                markerView.layer.shadowOffset = CGSize(width: 0, height: 2)
                markerView.layer.shadowRadius = 8
                addHaloHighlight(to: markerView)
                
                return markerView
            }
            
            // 處理地點標記
            if let locationAnnotation = annotation as? ToiletLocationAnnotation {
                let identifier = "ToiletLocationMarker"
                let markerView: MKMarkerAnnotationView
                
                if let dequeued = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView {
                    markerView = dequeued
                    markerView.annotation = locationAnnotation
                } else {
                    markerView = MKMarkerAnnotationView(annotation: locationAnnotation, reuseIdentifier: identifier)
                    markerView.canShowCallout = true
                }
                
                // 根據地點的廁所類型選擇顏色
                markerView.markerTintColor = markerTintForLocation(locationAnnotation.location)
                
                // 顯示該地點的圖標
                let symbolConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
                
                if locationAnnotation.location.totalToiletCount == 1 {
                    // 單一廁所：顯示普通廁所圖標
                    markerView.glyphImage = UIImage(systemName: "toilet", withConfiguration: symbolConfig)
                } else {
                    // 多間廁所：顯示建築/堆疊圖標（不顯示數字）
                    // 您可以更換成其他圖標：building.2.fill, square.stack.fill, square.3.layers.3d
                    markerView.glyphImage = UIImage(systemName: "building.2.fill", withConfiguration: symbolConfig)
                }
                
                markerView.glyphTintColor = .white
                markerView.titleVisibility = .hidden
                markerView.subtitleVisibility = .hidden
                markerView.clusteringIdentifier = parent.shouldEnableClustering ? "ToiletCluster" : nil
                markerView.displayPriority = .required
                markerView.detailCalloutAccessoryView = calloutView(for: locationAnnotation.location)
                
                let tint = markerView.markerTintColor ?? markerTintForLocation(locationAnnotation.location)
                markerView.layer.shadowColor = tint.withAlphaComponent(0.3).cgColor
                markerView.layer.shadowOpacity = 0.9
                markerView.layer.shadowOffset = CGSize(width: 0, height: 2)
                markerView.layer.shadowRadius = 8
                addHaloHighlight(to: markerView)
                
                return markerView
            }
            
            // 處理個別廁所標記
            if let toiletAnnotation = annotation as? ToiletAnnotation {
                let identifier = "ToiletMarker"
                let markerView: MKMarkerAnnotationView
                
                if let dequeued = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView {
                    markerView = dequeued
                    markerView.annotation = toiletAnnotation
                } else {
                    markerView = MKMarkerAnnotationView(annotation: toiletAnnotation, reuseIdentifier: identifier)
                    markerView.canShowCallout = true
                }
                
                markerView.markerTintColor = markerTintForToilet(toiletAnnotation.toilet)
                let iconName = getIconName(for: toiletAnnotation.toilet.type)
                let symbolConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
                markerView.glyphImage = UIImage(systemName: iconName, withConfiguration: symbolConfig)
                markerView.glyphTintColor = .white
                markerView.titleVisibility = .hidden
                markerView.subtitleVisibility = .hidden
                markerView.clusteringIdentifier = parent.shouldEnableClustering ? "ToiletCluster" : nil
                markerView.displayPriority = .defaultHigh
                markerView.detailCalloutAccessoryView = calloutView(for: toiletAnnotation.toilet)
                
                let tint = markerView.markerTintColor ?? markerTintForToilet(toiletAnnotation.toilet)
                markerView.layer.shadowColor = tint.withAlphaComponent(0.3).cgColor
                markerView.layer.shadowOpacity = 0.9
                markerView.layer.shadowOffset = CGSize(width: 0, height: 2)
                markerView.layer.shadowRadius = 8
                addHaloHighlight(to: markerView)
                
                return markerView
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

// MARK: - 標記樣式工具
private func markerTintForLocation(_ location: ToiletLocation) -> UIColor {
    // 優先根據地點的主要廁所類型來選擇顏色
    let availableTypes = location.availableTypes
    
    // 如果有無障礙廁所，用灰色
    if availableTypes.contains("無障礙廁所") {
        return UIColor(red: 0.41, green: 0.41, blue: 0.46, alpha: 1)
    }
    
    // 如果有親子廁所，用綠色
    if availableTypes.contains("親子廁所") {
        return UIColor(red: 0.22, green: 0.73, blue: 0.55, alpha: 1)
    }
    
    // 如果有性別友善廁所，用紫色
    if availableTypes.contains("性別友善廁所") {
        return UIColor(red: 0.53, green: 0.40, blue: 0.95, alpha: 1)
    }
    
    // 如果是混合廁所，用橘色
    if availableTypes.contains("混合廁所") {
        return UIColor(red: 0.98, green: 0.67, blue: 0.28, alpha: 1)
    }
    
    // 如果有多樓層，用暖橘
    if location.hasMultipleFloors {
        return UIColor(red: 0.99, green: 0.55, blue: 0.27, alpha: 1)
    }
    
    // 預設用品牌藍
    return UIColor(red: 0.24, green: 0.53, blue: 0.96, alpha: 1)
}

private func markerTintForToilet(_ toilet: ToiletInfo) -> UIColor {
    switch toilet.type {
    case "女廁所":
        return UIColor(red: 0.94, green: 0.36, blue: 0.53, alpha: 1)
    case "男廁所":
        return UIColor(red: 0.29, green: 0.52, blue: 0.97, alpha: 1)
    case "親子廁所":
        return UIColor(red: 0.22, green: 0.73, blue: 0.55, alpha: 1)
    case "無障礙廁所":
        return UIColor(red: 0.41, green: 0.41, blue: 0.46, alpha: 1)
    case "性別友善廁所":
        return UIColor(red: 0.53, green: 0.40, blue: 0.95, alpha: 1)
    default:
        return UIColor(red: 0.98, green: 0.67, blue: 0.28, alpha: 1)
    }
}

private func calloutView(for location: ToiletLocation) -> UIView {
    let container = UIStackView()
    container.axis = .vertical
    container.alignment = .leading
    container.spacing = 6
    container.layoutMargins = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
    container.isLayoutMarginsRelativeArrangement = true
    
    let infoLabel = UILabel()
    let floorInfo = location.hasMultipleFloors ? "多樓層" : "單層"
    infoLabel.text = "\(location.totalToiletCount) 間 • \(floorInfo)"
    infoLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
    infoLabel.textColor = UIColor.secondaryLabel
    
    container.addArrangedSubview(infoLabel)
    container.backgroundColor = .clear
    
    return container
}

private func calloutView(for toilet: ToiletInfo) -> UIView {
    let container = UIStackView()
    container.axis = .vertical
    container.alignment = .leading
    container.spacing = 6
    container.layoutMargins = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
    container.isLayoutMarginsRelativeArrangement = true
    
    let metaLabel = UILabel()
    metaLabel.text = "\(toilet.type) • \(toilet.grade)"
    metaLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
    metaLabel.textColor = UIColor.secondaryLabel
    
    let addressLabel = UILabel()
    addressLabel.text = toilet.address
    addressLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
    addressLabel.textColor = UIColor.tertiaryLabel
    addressLabel.numberOfLines = 2
    
    container.addArrangedSubview(metaLabel)
    container.addArrangedSubview(addressLabel)
    container.backgroundColor = .clear
    
    return container
}

private func addHaloHighlight(to markerView: MKMarkerAnnotationView) {
    let haloName = "haloLayer"
    markerView.layoutIfNeeded()
    
    markerView.layer.sublayers?
        .filter { $0.name == haloName }
        .forEach { $0.removeFromSuperlayer() }
    
    let haloDiameter = max(max(markerView.bounds.width, markerView.bounds.height) + 12, 32)
    let haloLayer = CALayer()
    haloLayer.name = haloName
    let tint = markerView.markerTintColor ?? UIColor.systemBlue
    haloLayer.backgroundColor = tint.withAlphaComponent(0.22).cgColor
    haloLayer.cornerRadius = haloDiameter / 2
    haloLayer.frame = CGRect(
        x: (markerView.bounds.width - haloDiameter) / 2,
        y: (markerView.bounds.height - haloDiameter) / 2,
        width: haloDiameter,
        height: haloDiameter
    )
    haloLayer.shadowColor = tint.withAlphaComponent(0.6).cgColor
    haloLayer.shadowOpacity = 0.45
    haloLayer.shadowOffset = .zero
    haloLayer.shadowRadius = 8
    
    markerView.layer.insertSublayer(haloLayer, at: 0)
}
