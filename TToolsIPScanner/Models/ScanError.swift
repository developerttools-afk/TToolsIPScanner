import Foundation

/// Strukturierte Fehler für Netzwerk-Scanning-Operationen
///
/// Diese Enum definiert alle möglichen Fehler, die während des
/// Netzwerk-Scans auftreten können, mit benutzerfreundlichen
/// Beschreibungen und Lösungsvorschlägen.
enum ScanError: LocalizedError {
    // MARK: - Network Errors
    
    /// Ungültige IP-Adresse wurde angegeben
    case invalidIPAddress(String)
    
    /// Netzwerk ist nicht erreichbar
    case networkUnreachable
    
    /// Keine aktive Netzwerkverbindung
    case noNetworkConnection
    
    // MARK: - Scan Errors
    
    /// Scan wurde vom Benutzer abgebrochen
    case scanCancelled
    
    /// Scan ist bereits aktiv
    case scanAlreadyRunning
    
    /// Timeout beim Scannen
    case scanTimeout(ip: String)
    
    // MARK: - Socket Errors
    
    /// Socket konnte nicht erstellt werden
    case socketCreationFailed(errno: Int32)
    
    /// Verbindung zum Port fehlgeschlagen
    case connectionFailed(ip: String, port: Int, errno: Int32)
    
    /// Verbindungstimeout
    case connectionTimeout(ip: String, port: Int)
    
    // MARK: - Port Errors
    
    /// Ungültige Port-Nummer
    case invalidPortNumber(Int)
    
    /// Keine Ports zum Scannen angegeben
    case noPortsSpecified
    
    // MARK: - Permission Errors
    
    /// Berechtigung für lokales Netzwerk verweigert
    case localNetworkPermissionDenied
    
    /// Allgemeine Berechtigungsverweigerung
    case permissionDenied(reason: String)
    
    // MARK: - DNS Errors
    
    /// DNS-Lookup fehlgeschlagen
    case dnsLookupFailed(ip: String)
    
    /// DNS-Timeout
    case dnsTimeout(ip: String)
    
    // MARK: - OUI Database Errors
    
    /// OUI-Datenbank konnte nicht geladen werden
    case ouiDatabaseLoadFailed(underlying: Error)
    
    /// OUI-Datenbank-Download fehlgeschlagen
    case ouiDatabaseDownloadFailed(statusCode: Int)
    
    /// OUI-Datenbank ungültig oder beschädigt
    case ouiDatabaseCorrupted
    
    // MARK: - Configuration Errors
    
    /// Ungültige Konfiguration
    case invalidConfiguration(reason: String)
    
    /// Zu viele gleichzeitige Verbindungen
    case tooManyConnections
    
    // MARK: - LocalizedError Implementation
    
    var errorDescription: String? {
        switch self {
        // Network Errors
        case .invalidIPAddress(let ip):
            return "Ungültige IP-Adresse: \(ip)"
            
        case .networkUnreachable:
            return "Netzwerk nicht erreichbar"
            
        case .noNetworkConnection:
            return "Keine aktive Netzwerkverbindung"
            
        // Scan Errors
        case .scanCancelled:
            return "Scan wurde abgebrochen"
            
        case .scanAlreadyRunning:
            return "Ein Scan läuft bereits"
            
        case .scanTimeout(let ip):
            return "Timeout beim Scannen von \(ip)"
            
        // Socket Errors
        case .socketCreationFailed(let errno):
            return "Socket-Erstellung fehlgeschlagen (Fehlercode: \(errno))"
            
        case .connectionFailed(let ip, let port, let errno):
            return "Verbindung zu \(ip):\(port) fehlgeschlagen (Fehlercode: \(errno))"
            
        case .connectionTimeout(let ip, let port):
            return "Verbindungstimeout bei \(ip):\(port)"
            
        // Port Errors
        case .invalidPortNumber(let port):
            return "Ungültige Port-Nummer: \(port)"
            
        case .noPortsSpecified:
            return "Keine Ports zum Scannen angegeben"
            
        // Permission Errors
        case .localNetworkPermissionDenied:
            return "Zugriff auf lokales Netzwerk verweigert"
            
        case .permissionDenied(let reason):
            return "Berechtigung verweigert: \(reason)"
            
        // DNS Errors
        case .dnsLookupFailed(let ip):
            return "DNS-Lookup für \(ip) fehlgeschlagen"
            
        case .dnsTimeout(let ip):
            return "DNS-Timeout bei \(ip)"
            
        // OUI Database Errors
        case .ouiDatabaseLoadFailed(let error):
            return "OUI-Datenbank konnte nicht geladen werden: \(error.localizedDescription)"
            
        case .ouiDatabaseDownloadFailed(let statusCode):
            return "OUI-Datenbank-Download fehlgeschlagen (HTTP \(statusCode))"
            
        case .ouiDatabaseCorrupted:
            return "OUI-Datenbank ist beschädigt oder ungültig"
            
        // Configuration Errors
        case .invalidConfiguration(let reason):
            return "Ungültige Konfiguration: \(reason)"
            
        case .tooManyConnections:
            return "Zu viele gleichzeitige Verbindungen"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .invalidIPAddress:
            return "Die eingegebene IP-Adresse hat ein ungültiges Format."
            
        case .networkUnreachable:
            return "Das Netzwerk kann nicht erreicht werden."
            
        case .noNetworkConnection:
            return "Keine aktive WLAN- oder Ethernet-Verbindung gefunden."
            
        case .scanCancelled:
            return "Der Scan wurde vom Benutzer oder System abgebrochen."
            
        case .scanAlreadyRunning:
            return "Es kann nur ein Scan gleichzeitig ausgeführt werden."
            
        case .scanTimeout:
            return "Der Host hat nicht rechtzeitig geantwortet."
            
        case .socketCreationFailed:
            return "Das Betriebssystem konnte keinen Socket erstellen."
            
        case .connectionFailed:
            return "Die Verbindung zum Ziel-Port wurde abgelehnt oder ist nicht erreichbar."
            
        case .connectionTimeout:
            return "Der Port hat nicht innerhalb der Timeout-Zeit geantwortet."
            
        case .invalidPortNumber(let port):
            return "Port \(port) liegt außerhalb des gültigen Bereichs (1-65535)."
            
        case .noPortsSpecified:
            return "Es wurden keine Ports für den Scan ausgewählt."
            
        case .localNetworkPermissionDenied:
            return "Die App hat keine Berechtigung auf das lokale Netzwerk zuzugreifen."
            
        case .permissionDenied:
            return "Das System hat den Zugriff verweigert."
            
        case .dnsLookupFailed:
            return "Der Hostname konnte nicht aufgelöst werden."
            
        case .dnsTimeout:
            return "Der DNS-Server hat nicht rechtzeitig geantwortet."
            
        case .ouiDatabaseLoadFailed:
            return "Die lokale OUI-Datenbank konnte nicht gelesen werden."
            
        case .ouiDatabaseDownloadFailed:
            return "Der Download der OUI-Datenbank vom Server ist fehlgeschlagen."
            
        case .ouiDatabaseCorrupted:
            return "Die OUI-Datenbank ist beschädigt und muss neu heruntergeladen werden."
            
        case .invalidConfiguration:
            return "Die Scan-Konfiguration ist ungültig."
            
        case .tooManyConnections:
            return "Zu viele gleichzeitige Verbindungen würden das System überlasten."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidIPAddress:
            return "Bitte geben Sie eine gültige IPv4-Adresse im Format xxx.xxx.xxx.xxx ein (z.B. 192.168.1.1)."
            
        case .networkUnreachable, .noNetworkConnection:
            return "Prüfen Sie Ihre Netzwerkverbindung und versuchen Sie es erneut."
            
        case .scanCancelled:
            return "Sie können den Scan jederzeit erneut starten."
            
        case .scanAlreadyRunning:
            return "Warten Sie, bis der aktuelle Scan abgeschlossen ist, oder brechen Sie ihn ab."
            
        case .scanTimeout:
            return "Prüfen Sie die Netzwerkverbindung oder erhöhen Sie den Timeout-Wert."
            
        case .socketCreationFailed:
            return "Starten Sie die App neu oder prüfen Sie die Systemressourcen."
            
        case .connectionFailed, .connectionTimeout:
            return "Der Port ist möglicherweise geschlossen oder durch eine Firewall blockiert."
            
        case .invalidPortNumber:
            return "Port-Nummern müssen zwischen 1 und 65535 liegen."
            
        case .noPortsSpecified:
            return "Wählen Sie mindestens einen Port in den Port-Einstellungen aus."
            
        case .localNetworkPermissionDenied:
            return "Gehen Sie zu Einstellungen > Datenschutz > Lokales Netzwerk und aktivieren Sie die Berechtigung für diese App."
            
        case .permissionDenied:
            return "Überprüfen Sie die App-Berechtigungen in den Systemeinstellungen."
            
        case .dnsLookupFailed, .dnsTimeout:
            return "Prüfen Sie die DNS-Einstellungen oder verwenden Sie einen anderen DNS-Server."
            
        case .ouiDatabaseLoadFailed, .ouiDatabaseCorrupted:
            return "Laden Sie die OUI-Datenbank in den Einstellungen neu herunter."
            
        case .ouiDatabaseDownloadFailed:
            return "Prüfen Sie Ihre Internetverbindung und versuchen Sie es erneut."
            
        case .invalidConfiguration:
            return "Setzen Sie die Scan-Einstellungen auf die Standardwerte zurück."
            
        case .tooManyConnections:
            return "Reduzieren Sie die Anzahl der gleichzeitigen Verbindungen in den Einstellungen."
        }
    }
    
    var helpAnchor: String? {
        switch self {
        case .invalidIPAddress:
            return "ip-address-format"
        case .localNetworkPermissionDenied:
            return "local-network-permission"
        case .noPortsSpecified:
            return "port-configuration"
        case .ouiDatabaseLoadFailed, .ouiDatabaseDownloadFailed, .ouiDatabaseCorrupted:
            return "oui-database"
        default:
            return nil
        }
    }
}

// MARK: - Error Severity

extension ScanError {
    /// Schweregrad des Fehlers
    enum Severity {
        case info       // Informativ, kein echter Fehler
        case warning    // Warnung, Operation kann teilweise fortgesetzt werden
        case error      // Fehler, Operation fehlgeschlagen
        case critical   // Kritischer Fehler, App-Funktionalität beeinträchtigt
    }
    
    var severity: Severity {
        switch self {
        case .scanCancelled:
            return .info
            
        case .dnsLookupFailed, .dnsTimeout, .scanTimeout, .connectionTimeout:
            return .warning
            
        case .invalidIPAddress, .invalidPortNumber, .noPortsSpecified,
             .scanAlreadyRunning, .connectionFailed, .ouiDatabaseDownloadFailed:
            return .error
            
        case .networkUnreachable, .noNetworkConnection, .localNetworkPermissionDenied,
             .permissionDenied, .socketCreationFailed, .tooManyConnections,
             .ouiDatabaseLoadFailed, .ouiDatabaseCorrupted, .invalidConfiguration:
            return .critical
        }
    }
}

// MARK: - User-Friendly Formatting

extension ScanError {
    /// Formatiert den Fehler für UI-Anzeige
    var userFriendlyMessage: String {
        var message = errorDescription ?? "Ein unbekannter Fehler ist aufgetreten."
        
        if let reason = failureReason {
            message += "\n\n" + reason
        }
        
        if let suggestion = recoverySuggestion {
            message += "\n\n💡 " + suggestion
        }
        
        return message
    }
    
    /// Icon für UI-Anzeige basierend auf Severity
    var icon: String {
        switch severity {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.circle"
        case .critical:
            return "xmark.octagon"
        }
    }
}
