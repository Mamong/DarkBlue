//
//  SettingsView.swift
//  DarkBlue
//
//  Created by Marco on 2026/5/6.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 1. 自定义顶部 Header
                ZStack {
                    Color.lbSkyBlue.ignoresSafeArea(edges: .top)
                    HStack {
                        Text("DarkBlue")
                            .font(.title)
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                .foregroundColor(.white)
                .frame(height: 44)
                // 2. 列表标题
                HStack {
                    Text("Settings")
                        .font(.title3)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(12)
                
                List {
                    // Section 1: Settings
                    Section() {
                        NavigationLink(destination: Text("Onboarding Content")) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Show Onboarding Interface").font(.body)
                                Text("Learn more about DarkBlue® and why we made it.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0))
                    
                    
                    // Section 2: App Support
                    Section(header: Text("App Support").foregroundColor(.blue)) {
                        NavigationLink(destination: Text("Help")){
                            Text("Help & Guides")
                        }
                        NavigationLink(destination: Text("Feedback")){
                            Text("Feedback & Bug Reports")
                        }
                        HStack {
                            Text("App Version")
                            Spacer()
                            Text("v5.3.2").foregroundColor(.secondary)
                        }
                        NavigationLink("Acknowledgements", destination: Text("Acknowledgements"))
                        NavigationLink("Privacy Policy", destination: Text("Privacy"))
                    }.font(.body)
                        .padding(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0))
                    
                    
                    // Section 3
                    Section(header: Text("Paw At").foregroundColor(.blue)) {
                        NavigationLink("About Us", destination: Text("About Us"))
                        NavigationLink("Services & Capabilities", destination: Text("Services"))
                        NavigationLink("Project Inquiry", destination: Text("Inquiry"))
                    }.font(.body)
                        .padding(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0))
                    
                }
                // 关键：还原图片中的分组样式
                .listStyle(.plain)
                .iosNavigationInline()
                // 核心：在这一级页面彻底隐藏 macOS 的原生工具栏
#if os(iOS)
                .toolbar(.hidden, for: .navigationBar)
#endif
            }
#if os(iOS)
            .toolbarBackground(Color.lbSkyBlue, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            //.toolbarColorScheme(.dark, for: .navigationBar) // Makes title white
#endif
            .tint(.white)
        }
    }
}


#Preview {
    SettingsView()
}
