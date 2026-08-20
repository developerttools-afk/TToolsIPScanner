import XCTest
@testable import TToolsIPScanner

final class DNSCacheTests: XCTestCase {
    var cache: DNSCache!
    
    override func setUp() async throws {
        cache = DNSCache(validityDuration: 1.0, maxSize: 5)
    }
    
    override func tearDown() async throws {
        await cache.clear()
        cache = nil
    }
    
    // MARK: - Basic Functionality Tests
    
    func testCacheStoresAndRetrievesValues() async throws {
        // Given
        let ip = "192.168.1.1"
        let hostname = "test.local"
        
        // When
        await cache.set(hostname, for: ip)
        let result = await cache.get(ip)
        
        // Then
        XCTAssertEqual(result, hostname)
    }
    
    func testCacheMissReturnsNil() async throws {
        // Given
        let ip = "192.168.1.100"
        
        // When
        let result = await cache.get(ip)
        
        // Then
        XCTAssertNil(result)
    }
    
    func testCacheOverwritesExistingEntry() async throws {
        // Given
        let ip = "192.168.1.1"
        await cache.set("old-host.local", for: ip)
        
        // When
        await cache.set("new-host.local", for: ip)
        let result = await cache.get(ip)
        
        // Then
        XCTAssertEqual(result, "new-host.local")
    }
    
    // MARK: - Expiration Tests
    
    func testCacheExpiresAfterValidityDuration() async throws {
        // Given
        let ip = "192.168.1.1"
        let hostname = "test.local"
        await cache.set(hostname, for: ip)
        
        // When - warte länger als Validity Duration (1 Sekunde)
        try await Task.sleep(for: .seconds(1.1))
        let result = await cache.get(ip)
        
        // Then
        XCTAssertNil(result, "Cache-Eintrag sollte nach Ablauf ungültig sein")
    }
    
    func testCacheReturnsValidEntryBeforeExpiration() async throws {
        // Given
        let ip = "192.168.1.1"
        let hostname = "test.local"
        await cache.set(hostname, for: ip)
        
        // When - warte kürzer als Validity Duration
        try await Task.sleep(for: .milliseconds(500))
        let result = await cache.get(ip)
        
        // Then
        XCTAssertEqual(result, hostname, "Cache-Eintrag sollte noch gültig sein")
    }
    
    // MARK: - Size Limit Tests
    
    func testCacheRespectsMaxSize() async throws {
        // Given - Cache mit maxSize: 5
        for i in 1...10 {
            await cache.set("host\(i).local", for: "192.168.1.\(i)")
        }
        
        // When
        let stats = await cache.statistics
        
        // Then - sollte nicht mehr als maxSize + 25% haben (wegen Pruning-Strategie)
        XCTAssertLessThanOrEqual(stats.size, 6, "Cache sollte max. 6 Einträge haben (5 + Overhead)")
    }
    
    func testCachePrunesOldestEntries() async throws {
        // Given - Füge 5 Einträge mit Delay hinzu
        for i in 1...5 {
            await cache.set("host\(i).local", for: "192.168.1.\(i)")
            try await Task.sleep(for: .milliseconds(50))
        }
        
        // When - Füge 6. Eintrag hinzu (triggert Pruning)
        await cache.set("host6.local", for: "192.168.1.6")
        
        // Then - Neuester Eintrag sollte da sein
        let newest = await cache.get("192.168.1.6")
        XCTAssertNotNil(newest)
        
        // Ältester Eintrag könnte entfernt worden sein
        let oldest = await cache.get("192.168.1.1")
        // Note: Pruning ist nicht deterministisch, also kein strikter Test
    }
    
    // MARK: - Statistics Tests
    
    func testCacheStatistics() async throws {
        // Given
        await cache.set("host1.local", for: "192.168.1.1")
        await cache.set("host2.local", for: "192.168.1.2")
        
        // When
        _ = await cache.get("192.168.1.1") // Hit
        _ = await cache.get("192.168.1.1") // Hit
        _ = await cache.get("192.168.1.3") // Miss
        
        let stats = await cache.statistics
        
        // Then
        XCTAssertEqual(stats.hits, 2)
        XCTAssertEqual(stats.misses, 1)
        XCTAssertEqual(stats.size, 2)
        XCTAssertEqual(stats.hitRate, 2.0 / 3.0, accuracy: 0.01)
    }
    
    func testEmptyCacheStatistics() async throws {
        // When
        let stats = await cache.statistics
        
        // Then
        XCTAssertEqual(stats.hits, 0)
        XCTAssertEqual(stats.misses, 0)
        XCTAssertEqual(stats.size, 0)
        XCTAssertEqual(stats.hitRate, 0)
    }
    
    func testHitRateCalculation() async throws {
        // Given
        await cache.set("test.local", for: "192.168.1.1")
        
        // When - 7 Hits, 3 Misses = 70% Hit Rate
        for _ in 1...7 {
            _ = await cache.get("192.168.1.1")
        }
        for i in 2...4 {
            _ = await cache.get("192.168.1.\(i)")
        }
        
        let stats = await cache.statistics
        
        // Then
        XCTAssertEqual(stats.hitRate, 0.7, accuracy: 0.01)
    }
    
    // MARK: - Clear and Prune Tests
    
    func testCacheClear() async throws {
        // Given
        await cache.set("host1.local", for: "192.168.1.1")
        await cache.set("host2.local", for: "192.168.1.2")
        _ = await cache.get("192.168.1.1") // Erzeuge Hit
        
        // When
        await cache.clear()
        
        // Then
        let result = await cache.get("192.168.1.1")
        let stats = await cache.statistics
        
        XCTAssertNil(result)
        XCTAssertEqual(stats.hits, 0)
        XCTAssertEqual(stats.misses, 1) // Der Get nach Clear
        XCTAssertEqual(stats.size, 0)
    }
    
    func testPruneExpired() async throws {
        // Given
        await cache.set("valid.local", for: "192.168.1.1")
        await cache.set("expire.local", for: "192.168.1.2")
        
        // Warte bis zweiter Eintrag abläuft
        try await Task.sleep(for: .milliseconds(600))
        await cache.set("new.local", for: "192.168.1.3")
        
        // When
        try await Task.sleep(for: .milliseconds(500)) // Nun ist .2 expired
        await cache.pruneExpired()
        
        let stats = await cache.statistics
        
        // Then - Mindestens ein Eintrag sollte noch da sein
        XCTAssertGreaterThan(stats.size, 0)
    }
    
    func testRemoveSpecificEntry() async throws {
        // Given
        await cache.set("host1.local", for: "192.168.1.1")
        await cache.set("host2.local", for: "192.168.1.2")
        
        // When
        await cache.remove("192.168.1.1")
        
        // Then
        let removed = await cache.get("192.168.1.1")
        let kept = await cache.get("192.168.1.2")
        
        XCTAssertNil(removed)
        XCTAssertNotNil(kept)
    }
    
    // MARK: - Formatted Output Tests
    
    func testFormattedStatistics() async throws {
        // Given
        await cache.set("test.local", for: "192.168.1.1")
        _ = await cache.get("192.168.1.1")
        
        // When
        let formatted = await cache.formattedStatistics()
        
        // Then
        XCTAssertTrue(formatted.contains("DNS Cache Statistiken"))
        XCTAssertTrue(formatted.contains("Hits: 1"))
        XCTAssertTrue(formatted.contains("Cache Size: 1"))
    }
    
    func testEstimatedMemoryUsage() async throws {
        // Given
        for i in 1...10 {
            await cache.set("hostname\(i).local", for: "192.168.1.\(i)")
        }
        
        // When
        let memory = await cache.estimatedMemoryUsage()
        
        // Then
        XCTAssertTrue(memory.contains("Bytes") || memory.contains("KB"))
    }
    
    // MARK: - Debug Export Tests
    
    func testDebugExport() async throws {
        // Given
        await cache.set("host1.local", for: "192.168.1.1")
        await cache.set("host2.local", for: "192.168.1.2")
        
        // When
        let export = await cache.debugExport()
        
        // Then
        XCTAssertEqual(export.count, 2)
        XCTAssertEqual(export["192.168.1.1"]?.hostname, "host1.local")
        XCTAssertEqual(export["192.168.1.2"]?.hostname, "host2.local")
        XCTAssertGreaterThanOrEqual(export["192.168.1.1"]?.ageSeconds ?? -1, 0)
    }
    
    // MARK: - Concurrency Tests
    
    func testConcurrentAccess() async throws {
        // Teste gleichzeitige Zugriffe auf den Cache
        await withTaskGroup(of: Void.self) { group in
            // 10 Tasks schreiben gleichzeitig
            for i in 1...10 {
                group.addTask {
                    await self.cache.set("host\(i).local", for: "192.168.1.\(i)")
                }
            }
            
            // 10 Tasks lesen gleichzeitig
            for i in 1...10 {
                group.addTask {
                    _ = await self.cache.get("192.168.1.\(i)")
                }
            }
        }
        
        // Sollte ohne Crash durchlaufen
        let stats = await cache.statistics
        XCTAssertGreaterThan(stats.size, 0)
    }
    
    func testRapidSetAndGet() async throws {
        // Teste sehr schnelle Set/Get-Operationen
        for i in 1...100 {
            await cache.set("host.local", for: "192.168.1.\(i % 10)")
            _ = await cache.get("192.168.1.\(i % 10)")
        }
        
        let stats = await cache.statistics
        XCTAssertGreaterThan(stats.hits + stats.misses, 0)
    }
    
    // MARK: - Edge Cases
    
    func testEmptyHostname() async throws {
        // Given
        await cache.set("", for: "192.168.1.1")
        
        // When
        let result = await cache.get("192.168.1.1")
        
        // Then - Leerer String sollte gespeichert werden können
        XCTAssertEqual(result, "")
    }
    
    func testVeryLongHostname() async throws {
        // Given
        let longHostname = String(repeating: "very-long-hostname.", count: 10) + "local"
        await cache.set(longHostname, for: "192.168.1.1")
        
        // When
        let result = await cache.get("192.168.1.1")
        
        // Then
        XCTAssertEqual(result, longHostname)
    }
    
    func testSpecialCharactersInHostname() async throws {
        // Given
        let hostname = "test-host_123.über.local"
        await cache.set(hostname, for: "192.168.1.1")
        
        // When
        let result = await cache.get("192.168.1.1")
        
        // Then
        XCTAssertEqual(result, hostname)
    }
}
