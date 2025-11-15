//
//  ContentView.swift
//  DJMediWallet
//
//  Main navigation view
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            RecordsListView()
                .tabItem {
                    Label("Records", systemImage: "folder.fill")
                }
                .tag(0)
            
            AddRecordView {
                selectedTab = 0
            }
                .tabItem {
                    Label("Add", systemImage: "plus.circle.fill")
                }
                .tag(1)
        }
    }
}

#Preview {
    ContentView()
}
