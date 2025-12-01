import Foundation
import CoreLocation

// MARK: - Models

struct ToiletInfo: Codable, Identifiable, Equatable {
    let id = UUID()
    let county: String
    let city: String
    let village: String
    let number: String
    let name: String
    let address: String
    let administration: String
    let latitude: String
    let longitude: String
    let grade: String
    let type2: String
    let type: String
    let exec: String
    let diaper: String
    
    var latitudeDouble: Double { return Double(latitude) ?? 0.0 }
    var longitudeDouble: Double { return Double(longitude) ?? 0.0 }
    var hasDiaperStation: Bool { return diaper == "1" }
    
    var correctedCoordinate: CLLocationCoordinate2D? {
        guard var lat = Double(latitude), var lon = Double(longitude) else { return nil }
        let latRange = 18.0...27.5
        let lonRange = 116.0...124.5
        
        if !latRange.contains(lat) || !lonRange.contains(lon) {
            if latRange.contains(lon) && lonRange.contains(lat) {
                swap(&lat, &lon)
            }
        }
        guard latRange.contains(lat), lonRange.contains(lon) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

struct FloorInfo: Identifiable, Codable, Equatable {
    let id = UUID()
    let floorName: String
    let floorOrder: Int
    let toilets: [ToiletInfo]
    
    var availableTypes: Set<String> { return Set(toilets.map { $0.type }) }
    var toiletCount: Int { return toilets.count }
}

struct ToiletLocation: Identifiable, Codable, Equatable {
    let id = UUID()
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let administration: String
    let toiletsByFloor: [FloorInfo]
    
    var allToilets: [ToiletInfo] { return toiletsByFloor.flatMap { $0.toilets } }
    var availableTypes: Set<String> { return Set(allToilets.map { $0.type }) }
    var totalToiletCount: Int { return allToilets.count }
    var hasMultipleFloors: Bool { return toiletsByFloor.count > 1 }
    var hasDiaperStation: Bool { return allToilets.contains { $0.hasDiaperStation } }
    var placeType: String { return allToilets.first?.type2 ?? "" }
    var floorCount: Int { return toiletsByFloor.count }
    
    // MARK: - Static Logic
    static func createFromToilets(_ toilets: [ToiletInfo]) -> [ToiletLocation] {
        let addressGroups = Dictionary(grouping: toilets) { $0.address }
        var initialLocations: [ToiletLocation] = []
        
        for (address, addressToilets) in addressGroups {
            let validToilets = addressToilets.filter { $0.correctedCoordinate != nil }
            guard !validToilets.isEmpty else { continue }
            
            let coordinates = validToilets.compactMap { $0.correctedCoordinate }
            let centerLat = coordinates.map { $0.latitude }.reduce(0, +) / Double(coordinates.count)
            let centerLon = coordinates.map { $0.longitude }.reduce(0, +) / Double(coordinates.count)
            
            let floorGroups = groupByFloor(validToilets)
            
            let location = ToiletLocation(
                name: extractLocationName(from: validToilets),
                address: address,
                latitude: centerLat,
                longitude: centerLon,
                administration: validToilets.first?.administration ?? "",
                toiletsByFloor: floorGroups
            )
            initialLocations.append(location)
        }
        
        // Grid-based optimization for merging
        // Instead of O(N^2), we use a grid to find neighbors.
        // Grid size: approx 50m (0.0005 degrees)
        let gridSize = 0.0005
        var grid: [String: [Int]] = [:]
        
        for (i, loc) in initialLocations.enumerated() {
            let gridKey = "\(Int(loc.latitude / gridSize))_\(Int(loc.longitude / gridSize))"
            grid[gridKey, default: []].append(i)
        }
        
        let mergeThreshold = 20.0
        var mergedIndices: Set<Int> = []
        var finalLocations: [ToiletLocation] = []
        
        for i in 0..<initialLocations.count {
            if mergedIndices.contains(i) { continue }
            
            var currentLocation = initialLocations[i]
            var mergedToilets = currentLocation.allToilets
            mergedIndices.insert(i)
            
            // Check current grid and 8 neighbors
            let latIndex = Int(currentLocation.latitude / gridSize)
            let lonIndex = Int(currentLocation.longitude / gridSize)
            
            for dLat in -1...1 {
                for dLon in -1...1 {
                    let key = "\(latIndex + dLat)_\(lonIndex + dLon)"
                    if let neighbors = grid[key] {
                        for j in neighbors {
                            if i == j || mergedIndices.contains(j) { continue }
                            
                            let otherLocation = initialLocations[j]
                            let distance = calculateDistance(
                                lat1: currentLocation.latitude, lon1: currentLocation.longitude,
                                lat2: otherLocation.latitude, lon2: otherLocation.longitude
                            )
                            
                            if distance < mergeThreshold {
                                mergedToilets.append(contentsOf: otherLocation.allToilets)
                                mergedIndices.insert(j)
                            }
                        }
                    }
                }
            }
            
            if mergedToilets.count > currentLocation.allToilets.count {
                let floorGroups = groupByFloor(mergedToilets)
                let validToilets = mergedToilets.filter { $0.correctedCoordinate != nil }
                let coordinates = validToilets.compactMap { $0.correctedCoordinate }
                let newLat = coordinates.map { $0.latitude }.reduce(0, +) / Double(coordinates.count)
                let newLon = coordinates.map { $0.longitude }.reduce(0, +) / Double(coordinates.count)
                
                currentLocation = ToiletLocation(
                    name: extractLocationName(from: mergedToilets),
                    address: currentLocation.address,
                    latitude: newLat,
                    longitude: newLon,
                    administration: currentLocation.administration,
                    toiletsByFloor: floorGroups
                )
            }
            finalLocations.append(currentLocation)
        }
        
        return finalLocations
    }
    
    // MARK: - Helpers
    private static func groupByFloor(_ toilets: [ToiletInfo]) -> [FloorInfo] {
        var floorGroups: [String: [ToiletInfo]] = [:]
        for toilet in toilets {
            let floorInfo = extractFloorInfo(from: toilet.name)
            let key = "\(floorInfo.floorName)-\(floorInfo.floorOrder)"
            floorGroups[key, default: []].append(toilet)
        }
        return floorGroups.compactMap { (key, toilets) in
            let floorInfo = extractFloorInfo(from: toilets.first?.name ?? "")
            return FloorInfo(floorName: floorInfo.floorName, floorOrder: floorInfo.floorOrder, toilets: toilets)
        }.sorted { $0.floorOrder < $1.floorOrder }
    }
    
    static func extractFloorInfo(from name: String) -> (floorName: String, floorOrder: Int) {
        if let regex = try? NSRegularExpression(pattern: "(?:B|地下)([0-9]+)(?:樓|F)?"),
           let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
           let range = Range(match.range(at: 1), in: name),
           let floorNumber = Int(String(name[range])) {
            return (floorName: "B\(floorNumber)", floorOrder: -floorNumber)
        }
        
        let patterns = ["([0-9]+)F", "([0-9]+)樓", "([0-9]+)層"]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
               let range = Range(match.range(at: 1), in: name),
               let floorNumber = Int(String(name[range])) {
                return (floorName: "\(floorNumber)F", floorOrder: floorNumber)
            }
        }
        return (floorName: "1F", floorOrder: 1)
    }
    
    private static func extractLocationName(from toilets: [ToiletInfo]) -> String {
        let names = toilets.map { $0.name }
        let cleanNames = names.map { name in
            var cleanName = name
            for pattern in ["[0-9]+F", "[0-9]+樓", "B[0-9]+", "地下[0-9]+樓", "[0-9]+層"] {
                cleanName = cleanName.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
            }
            return cleanName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        if let commonPrefix = findCommonPrefix(cleanNames), !commonPrefix.isEmpty {
            return commonPrefix
        }
        return cleanNames.first ?? toilets.first?.name ?? "未知地點"
    }
    
    private static func findCommonPrefix(_ strings: [String]) -> String? {
        guard !strings.isEmpty else { return nil }
        var prefix = strings[0]
        for string in strings.dropFirst() {
            while !string.hasPrefix(prefix) && !prefix.isEmpty {
                prefix = String(prefix.dropLast())
            }
        }
        return prefix.isEmpty ? nil : prefix
    }
    
    private static func calculateDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let location1 = CLLocation(latitude: lat1, longitude: lon1)
        let location2 = CLLocation(latitude: lat2, longitude: lon2)
        return location1.distance(from: location2)
    }
}

// MARK: - Main Execution

func main() {
    let fileManager = FileManager.default
    let cwd = fileManager.currentDirectoryPath
    let inputPath = cwd + "/Toilet/Models/toilet.json"
    let outputPath = cwd + "/Toilet/Models/toilet_locations.json"
    
    print("Reading from: \(inputPath)")
    
    guard let data = fileManager.contents(atPath: inputPath) else {
        print("Error: Could not read input file.")
        exit(1)
    }
    
    do {
        let decoder = JSONDecoder()
        let toilets = try decoder.decode([ToiletInfo].self, from: data)
        print("Loaded \(toilets.count) toilets.")
        
        print("Processing locations...")
        let start = Date()
        let locations = ToiletLocation.createFromToilets(toilets)
        let duration = Date().timeIntervalSince(start)
        print("Processed \(locations.count) locations in \(String(format: "%.2f", duration)) seconds.")
        
        let encoder = JSONEncoder()
        // encoder.outputFormatting = .prettyPrinted // Optional, makes file larger but readable
        let jsonData = try encoder.encode(locations)
        
        if fileManager.createFile(atPath: outputPath, contents: jsonData, attributes: nil) {
            print("Successfully wrote to: \(outputPath)")
            print("File size: \(ByteCountFormatter.string(fromByteCount: Int64(jsonData.count), countStyle: .file))")
        } else {
            print("Error: Could not write output file.")
            exit(1)
        }
        
    } catch {
        print("Error: \(error)")
        exit(1)
    }
}

main()

