//
//  ContentView.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/16.
//

import SwiftUI
import CoreBluetooth

import UserNotifications

struct ContentView: View {
    //@StateObject var bluetoothManager = BluetoothManager()
    
    @State private var selectedTab = 1
    
    var body: some View {
        
        TabView{
            BluetoothListView()
                .tabItem{
                    Label("Peripherals", systemImage: "house")
                }
            VirtualDevicesListView()
                .tabItem{
                    Label("Virtual Devices", systemImage: "dot.radiowaves.left.and.right")
                }
            LogView()
                .tabItem{
                    Label("Log", systemImage: "list.bullet")
                }
            
            LearnView().tabItem{
                Label("Learn", systemImage: "lightbulb.fill")
            }
            SettingsView().tabItem{
                Label("Settings", systemImage: "gear")
            }
        }
    }
}



#Preview {
    ContentView()
}
