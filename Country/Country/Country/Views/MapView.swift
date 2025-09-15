import SwiftUI
import MapKit

struct MapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var mapType: MKMapType
    var userLocation: CLLocation?
    var toilets: [ToiletInfo] = []
    @Binding var shouldJumpToLocation: Bool // 控制是否應該跳回位置
    var onRegionChanged: ((MKCoordinateRegion) -> Void)? = nil
    var shouldUpdateRegion: Bool = true // 控制是否應該更新地圖區域
    var onToiletSelected: ((ToiletInfo) -> Void)? = nil // 當公廁被選中時的回調

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
        
        return mapView
    }
    
    // 設置縮放限制
    private func setupZoomLimits(for mapView: MKMapView) {
        // 使用 MKMapView 的內建縮放限制
        mapView.cameraZoomRange = MKMapView.CameraZoomRange(
            minCenterCoordinateDistance: 1000, // 最小距離 1km（避免縮得太小）
            maxCenterCoordinateDistance: 10000  // 最大距離 10km（避免放得太大）
        )
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.mapType = mapType
        
        // 更新公廁標記
        updateToiletAnnotations(in: uiView)
        
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
    
    // 更新公廁標記（簡化版本，避免消失）
    private func updateToiletAnnotations(in mapView: MKMapView) {
        // 移除舊的公廁標記
        let existingAnnotations = mapView.annotations.filter { $0 is ToiletAnnotation }
        mapView.removeAnnotations(existingAnnotations)
        
        // 添加所有公廁標記（不限制數量，避免消失）
        for toilet in toilets {
            let annotation = ToiletAnnotation(toilet: toilet)
            mapView.addAnnotation(annotation)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView

        init(_ parent: MapView) {
            self.parent = parent
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
            // 使用 DispatchQueue 避免在視圖更新期間修改狀態
            DispatchQueue.main.async {
                self.parent.onRegionChanged?(mapView.region)
            }
        }
        
        // 處理標記點擊事件
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let toiletAnnotation = view.annotation as? ToiletAnnotation {
                // 通知父視圖有公廁被選中
                DispatchQueue.main.async {
                    self.parent.onToiletSelected?(toiletAnnotation.toilet)
                }
            }
        }
        
        // 創建標記視圖（最簡化版本）
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
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

