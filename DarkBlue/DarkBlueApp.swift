//
//  DarkBlueApp.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/16.
//

import SwiftUI

@main
struct DarkBlueApp: App {
    @StateObject var virtualManager = VirtualManager()
    
#if os(iOS)
init() {
    let appearance = UINavigationBarAppearance()
    appearance.configureWithOpaqueBackground()
    appearance.backgroundColor = UIColor(.lbSkyBlue)
    appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
    appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
    
    UINavigationBar.appearance().tintColor = .white
    
    let barButtonAppearance = UIBarButtonItemAppearance()
    // 强制将返回按钮的文字也设为白色
    barButtonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white]
    appearance.backButtonAppearance = barButtonAppearance

    UINavigationBar.appearance().standardAppearance = appearance
    UINavigationBar.appearance().scrollEdgeAppearance = appearance
    UINavigationBar.appearance().compactAppearance = appearance

    // 核心：设置状态栏文字为白色
    UINavigationBar.appearance().overrideUserInterfaceStyle = .dark
    
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
        // 处理授权结果
    }
}
#endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(virtualManager)
                //.preferredColorScheme(.dark) // 强制状态栏和系统组件为白色
        }
    }
}
