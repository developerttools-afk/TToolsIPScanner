//
//  ContentView.swift
//  TToolsIPScanner
//
//  Created by Thorsten Albers on 10.12.24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var scanner = NetworkScanner()
    
    var body: some View {
        #if os(iOS)
        MobileLayout(scanner: scanner)
            .onAppear { scanner.startBackgroundPrefetchIfNeeded() }
        #else
        NavigationStack {
            DesktopLayout(scanner: scanner)
        }
        .onAppear { scanner.startBackgroundPrefetchIfNeeded() }
        #endif
    }
}

#Preview {
    ContentView()
}
