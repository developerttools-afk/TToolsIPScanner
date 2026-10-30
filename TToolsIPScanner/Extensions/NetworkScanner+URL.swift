import Foundation
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension NetworkScanner {
    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        #if os(macOS)
        DispatchQueue.main.async {
            NSWorkspace.shared.open(url)
        }
        #else
        DispatchQueue.main.async {
            if #available(iOS 10.0, *) {
                UIApplication.shared.open(url, options: [:]) { success in
                    if !success {
                        self.log("Konnte URL nicht öffnen: \(urlString)")
                    }
                }
            } else {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.openURL(url)
                } else {
                    self.log("Konnte URL nicht öffnen: \(urlString)")
                }
            }
        }
        #endif
    }
    
    func openInBrowser(ip: String) {
        if let action = NetworkConstants.openAction(ip: ip, port: 80) {
            openService(action)
        } else {
            openURL("http://\(ip)")
        }
    }
    
    func openInSSH(ip: String) {
        if let action = NetworkConstants.openAction(ip: ip, port: 22) {
            openService(action)
        } else {
            openURL("ssh://\(ip)")
        }
    }
    
    func openService(_ action: NetworkConstants.ServiceOpenAction) {
        openURL(action.urlString)
    }
    
    #if os(macOS)
    func pingInTerminal(ip: String) {
        guard IPAddressValidator.isValidIPv4(ip) else {
            log("Ping abgebrochen: keine gültige IPv4-Adresse")
            return
        }
        let script = """
        tell application "Terminal"
            activate
            do script "ping \(ip)"
        end tell
        """
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
        if let error {
            log("Ping im Terminal fehlgeschlagen: \(error)")
        }
    }
    #endif
} 