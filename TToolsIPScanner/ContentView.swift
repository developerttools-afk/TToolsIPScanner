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
        #else
        NavigationStack {
            DesktopLayout(scanner: scanner)
        }
        #endif
    }
}

#Preview {
    ContentView()
}
