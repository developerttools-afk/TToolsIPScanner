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
        openURL("http://\(ip)")
    }
    
    func openInSSH(ip: String) {
        openURL("ssh://\(ip)")
    }
} 