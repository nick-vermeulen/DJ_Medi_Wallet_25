//
//  ContentView.swift
//  DJMediWallet
//
//  Main navigation view
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            RecordsListView()
                .tabItem {
                    Label("Records", systemImage: "folder.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}

#Preview {
    ContentView()
}
