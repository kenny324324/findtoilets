import SwiftUI

struct CountryView: View {
    @Binding var sheetPresented: Bool
    @Binding var selectedDetent: PresentationDetent
    @State private var searchText: String = ""
    @State private var suggestions: [ToiletInfo] = [] // 儲存建議公廁資訊
    @State private var selectedToilet: ToiletInfo?   // 儲存選中的公廁
    @FocusState private var isSearchFieldFocused: Bool // 控制鍵盤焦點
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 固定的標題和搜尋區域
            VStack(spacing: 16) {
                // 標題 + 關閉按鈕
                HStack {
                    Text("找廁所")
                        .font(.title.weight(.semibold))
                        .fontDesign(.rounded)
                        .bold()
                    Spacer()
                    /*
                    Button(action: {
                        withAnimation { sheetPresented = false }
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.gray)
                            .padding()
                            .background(Circle().fill(Color.gray.opacity(0.2)))
                    }*/
                }

                // 搜尋框
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .font(.body.weight(.bold))
                        .fontDesign(.rounded)
                    TextField("輸入您的位置", text: $searchText)
                        .focused($isSearchFieldFocused)
                            .onChange(of: searchText) { query in
                                // 暫時使用示範資料
                                loadDemoSuggestions(for: query)
                            }
                        .font(.body.weight(.bold))
                        .textFieldStyle(PlainTextFieldStyle())
                        .fontDesign(.rounded)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(18)
                }
                .padding(.horizontal, 5)
                .padding(.top)
                .padding(.leading)
                .padding(.trailing)
                .padding(.bottom, 16)
                .background(Color(.systemBackground))
                
                // 分格線
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 0.5)

                // 可捲動的內容區域 - 使用 GeometryReader 確保獨立捲動
                GeometryReader { geometry in
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                    } else if !suggestions.isEmpty {
                        List(suggestions, id: \.id) { suggestion in
                            NavigationLink(destination: ToiletDetailView(toilet: suggestion)) {
                                ToiletRowView(toilet: suggestion, distance: getDemoDistance(for: suggestion))
                            }
                        }
                        .listStyle(.plain)
                    } else if !searchText.isEmpty {
                        VStack {
                            Spacer()
                            Text("找不到相關公廁")
                                .foregroundColor(.gray)
                                .font(.body)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // 預設顯示附近公廁
                        List(getDemoNearbyToilets(), id: \.id) { toilet in
                            NavigationLink(destination: ToiletDetailView(toilet: toilet)) {
                                ToiletRowView(toilet: toilet, distance: getDemoDistance(for: toilet))
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // 示範搜尋功能
    private func loadDemoSuggestions(for query: String) {
        guard !query.isEmpty else {
            suggestions = []
            return
        }
        
        // 模擬載入狀態
        isLoading = true
        
        // 延遲模擬網路請求
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoading = false
            
            // 示範搜尋結果
            let demoToilets = getDemoToilets()
            suggestions = demoToilets.filter { toilet in
                toilet.name.lowercased().contains(query.lowercased()) ||
                toilet.address.lowercased().contains(query.lowercased()) ||
                toilet.type2.lowercased().contains(query.lowercased())
            }
        }
    }
    
    // 示範距離計算
    private func getDemoDistance(for toilet: ToiletInfo) -> Int {
        switch toilet.number {
        case "DEMO001": return 150  // 台北101最近
        case "DEMO002": return 280  // 台北車站
        case "DEMO003": return 350  // 大安森林公園
        case "DEMO004": return 420  // 中正紀念堂
        case "DEMO005": return 580  // 龍山寺
        case "DEMO006": return 680  // 松山機場
        case "DEMO007": return 200  // 西門町
        case "DEMO008": return 320  // 台北市政府
        case "DEMO009": return 450  // 信義威秀
        case "DEMO010": return 520  // 象山步道
        case "DEMO011": return 620  // 台北醫學大學
        case "DEMO012": return 380  // 松山文創園區
        default: return 500
        }
    }
    
    // 示範公廁資料
    private func getDemoToilets() -> [ToiletInfo] {
        return [
            ToiletInfo(
                county: "10001",
                city: "1000101",
                village: "信義區",
                number: "DEMO001",
                name: "台北101-女廁",
                address: "台北市信義區信義路五段7號",
                administration: "台北101",
                latitude: "25.0330",
                longitude: "121.5654",
                grade: "特優級",
                type2: "商業營業場所",
                type: "女廁所",
                exec: "台北101",
                diaper: "1"
            ),
            ToiletInfo(
                county: "10001",
                city: "1000101",
                village: "信義區",
                number: "DEMO002",
                name: "台北車站-男廁",
                address: "台北市中正區北平西路3號",
                administration: "台灣鐵路管理局",
                latitude: "25.0478",
                longitude: "121.5170",
                grade: "優級",
                type2: "交通運輸場站",
                type: "男廁所",
                exec: "台灣鐵路管理局",
                diaper: "0"
            ),
            ToiletInfo(
                county: "10001",
                city: "1000102",
                village: "大安區",
                number: "DEMO003",
                name: "大安森林公園-親子廁所",
                address: "台北市大安區新生南路二段1號",
                administration: "台北市政府公園路燈工程管理處",
                latitude: "25.0264",
                longitude: "121.5361",
                grade: "特優級",
                type2: "觀光遊憩場所",
                type: "親子廁所",
                exec: "台北市政府",
                diaper: "1"
            ),
            ToiletInfo(
                county: "10001",
                city: "1000103",
                village: "中正區",
                number: "DEMO004",
                name: "中正紀念堂-無障礙廁所",
                address: "台北市中正區中山南路21號",
                administration: "國立中正紀念堂管理處",
                latitude: "25.0360",
                longitude: "121.5199",
                grade: "特優級",
                type2: "觀光遊憩場所",
                type: "無障礙廁所",
                exec: "國立中正紀念堂管理處",
                diaper: "1"
            ),
            ToiletInfo(
                county: "10001",
                city: "1000104",
                village: "萬華區",
                number: "DEMO005",
                name: "龍山寺-通用廁所",
                address: "台北市萬華區廣州街211號",
                administration: "龍山寺",
                latitude: "25.0371",
                longitude: "121.4995",
                grade: "優級",
                type2: "宗教禮儀場所",
                type: "通用廁所",
                exec: "龍山寺",
                diaper: "0"
            ),
            ToiletInfo(
                county: "10001",
                city: "1000105",
                village: "松山區",
                number: "DEMO006",
                name: "松山機場-女廁",
                address: "台北市松山區敦化北路340之9號",
                administration: "交通部民用航空局",
                latitude: "25.0697",
                longitude: "121.5519",
                grade: "特優級",
                type2: "交通運輸場站",
                type: "女廁所",
                exec: "交通部民用航空局",
                diaper: "1"
            ),
            ToiletInfo(
                county: "10001",
                city: "1000106",
                village: "士林區",
                number: "DEMO007",
                name: "士林夜市-男廁",
                address: "台北市士林區基河路101號",
                administration: "台北市政府市場處",
                latitude: "25.0881",
                longitude: "121.5255",
                grade: "良級",
                type2: "商業營業場所",
                type: "男廁所",
                exec: "台北市政府市場處",
                diaper: "0"
            ),
            ToiletInfo(
                county: "10001",
                city: "1000107",
                village: "北投區",
                number: "DEMO008",
                name: "北投溫泉博物館-親子廁所",
                address: "台北市北投區中山路2號",
                administration: "台北市政府文化局",
                latitude: "25.1364",
                longitude: "121.5085",
                grade: "特優級",
                type2: "觀光遊憩場所",
                type: "親子廁所",
                exec: "台北市政府文化局",
                diaper: "1"
            ),
            ToiletInfo(
                county: "10001",
                city: "1000108",
                village: "內湖區",
                number: "DEMO009",
                name: "內湖科技園區-通用廁所",
                address: "台北市內湖區瑞光路399號",
                administration: "內湖科技園區服務中心",
                latitude: "25.0797",
                longitude: "121.5752",
                grade: "優級",
                type2: "商業營業場所",
                type: "通用廁所",
                exec: "內湖科技園區服務中心",
                diaper: "1"
            ),
            ToiletInfo(
                county: "10001",
                city: "1000109",
                village: "文山區",
                number: "DEMO010",
                name: "貓空纜車站-無障礙廁所",
                address: "台北市文山區指南路三段38巷",
                administration: "台北大眾捷運股份有限公司",
                latitude: "24.9667",
                longitude: "121.5833",
                grade: "特優級",
                type2: "交通運輸場站",
                type: "無障礙廁所",
                exec: "台北大眾捷運股份有限公司",
                diaper: "1"
            ),
            ToiletInfo(
                county: "10001",
                city: "1000110",
                village: "南港區",
                number: "DEMO011",
                name: "南港展覽館-女廁",
                address: "台北市南港區經貿二路1號",
                administration: "台北市政府產業發展局",
                latitude: "25.0556",
                longitude: "121.6167",
                grade: "特優級",
                type2: "商業營業場所",
                type: "女廁所",
                exec: "台北市政府產業發展局",
                diaper: "1"
            ),
            ToiletInfo(
                county: "10001",
                city: "1000111",
                village: "大同區",
                number: "DEMO012",
                name: "迪化街-男廁",
                address: "台北市大同區迪化街一段",
                administration: "台北市政府商業處",
                latitude: "25.0583",
                longitude: "121.5083",
                grade: "良級",
                type2: "商業營業場所",
                type: "男廁所",
                exec: "台北市政府商業處",
                diaper: "0"
            )
        ].sorted { first, second in
            let firstDistance = getDemoDistance(for: first)
            let secondDistance = getDemoDistance(for: second)
            return firstDistance < secondDistance
        }
    }
    
    // 示範附近公廁
    private func getDemoNearbyToilets() -> [ToiletInfo] {
        return getDemoToilets()
    }
}

// 廁所列表項目視圖
struct ToiletRowView: View {
    let toilet: ToiletInfo
    let distance: Int
    
    var body: some View {
        HStack(spacing: 16) {
            // 左邊的廁所圖示
            Image(systemName: toilet.typeIcon)
                .font(.title3)
                .foregroundColor(toilet.typeColor)
                .frame(width: 50, height: 50)
                .background(toilet.typeColor.opacity(0.2))
                .cornerRadius(10)
            
            // 中間 VStack
            VStack(alignment: .leading, spacing: 8) {
                // 廁所名稱
                Text(getCleanToiletName(toilet.name))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .fontDesign(.rounded)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                
                // 三個小項目
                HStack(spacing: 8) {
                    // 星星評分（固定最小寬度）
                    HStack(spacing: 1) {
                        ForEach(0..<getStarCount(for: toilet.grade), id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }
                        ForEach(0..<(3 - getStarCount(for: toilet.grade)), id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.gray.opacity(0.3))
                        }
                    }
                    .frame(width: 40, alignment: .leading)
                    
                    // 場所圖標（固定寬度）
                    Image(systemName: toilet.type2Icon)
                        .font(.caption2)
                        .foregroundColor(toilet.type2Color)
                        .frame(width: 20, alignment: .center)
                    
                    // 類型膠囊（彈性寬度，優先級最高）
                    Text(toilet.type)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            
            Spacer(minLength: 8)
            
            // 右邊距離徽章
            Text("\(distance)m")
                .font(.subheadline)
                .foregroundColor(getDistanceTextColor(for: distance))
                .fontWeight(.semibold)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(getDistanceBackgroundColor(for: distance))
                .cornerRadius(6)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
    }
    
    // 清理廁所名稱，移除類型後綴
    private func getCleanToiletName(_ name: String) -> String {
        let suffixes = ["-女廁", "-男廁", "-親子廁所", "-無障礙廁所", "-通用廁所"]
        var cleanName = name
        for suffix in suffixes {
            if cleanName.hasSuffix(suffix) {
                cleanName = String(cleanName.dropLast(suffix.count))
                break
            }
        }
        return cleanName
    }
    
    // 根據等級返回星級數量
    private func getStarCount(for grade: String) -> Int {
        switch grade {
        case "特優級":
            return 3
        case "優級":
            return 2
        case "良級":
            return 1
        case "普級":
            return 1
        default:
            return 1
        }
    }
    
    // 根據距離返回文字顏色
    private func getDistanceTextColor(for distance: Int) -> Color {
        if distance <= 200 {
            return .green
        } else if distance <= 500 {
            return .orange
        } else {
            return .gray
        }
    }
    
    // 根據距離返回背景顏色
    private func getDistanceBackgroundColor(for distance: Int) -> Color {
        if distance <= 200 {
            return Color.green.opacity(0.2)
        } else if distance <= 500 {
            return Color.orange.opacity(0.2)
        } else {
            return Color.gray.opacity(0.2)
        }
    }
}

#Preview {
    CountryView(sheetPresented: .constant(true), selectedDetent: .constant(.medium))
}
