import Foundation

extension NetworkScanner {
    func sortDevices() {
        sortDevices(by: sortOption, ascending: sortAscending)
    }
    
    func sortDevices(by option: SortOption, ascending: Bool = true) {
        var sorted = devices
        sorted.sort { first, second in
            let result: Bool
            
            switch option {
            case .ip:
                let firstComponents = first.ipAddress.split(separator: ".").compactMap { Int($0) }
                let secondComponents = second.ipAddress.split(separator: ".").compactMap { Int($0) }
                
                if firstComponents.count == secondComponents.count {
                    for (a, b) in zip(firstComponents, secondComponents) {
                        if a != b {
                            result = a < b
                            return ascending ? result : !result
                        }
                    }
                    result = true
                } else {
                    result = firstComponents.count < secondComponents.count
                }
                
            case .hostname:
                result = first.hostName.localizedCompare(second.hostName) == .orderedAscending
                
            case .manufacturer:
                result = first.manufacturer.localizedCompare(second.manufacturer) == .orderedAscending
            }
            
            return ascending ? result : !result
        }
        // Assign a new array so @Published notifies observers.
        devices = sorted
    }
}
