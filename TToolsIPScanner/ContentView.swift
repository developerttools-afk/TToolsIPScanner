//
//  ContentView.swift
//  TToolsIPScanner
//
//  Created by Thorsten Albers on 10.12.24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var scanner = NetworkScanner()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        #if os(iOS)
        if horizontalSizeClass == .compact {
            // iPhone Layout
            MobileLayout(scanner: scanner)
        } else {
            // iPad Layout
            NavigationStack {
                MobileLayout(scanner: scanner)
            }
        }
        #else
        // macOS Layout
        NavigationStack {
            DesktopLayout(scanner: scanner)
        }
        #endif
    }
}

#Preview {
    ContentView()
}
