//
//  LearnView.swift
//  DarkBlue
//
//  Created by Marco on 2026/5/6.
//

import SwiftUI

struct LearnView: View {
    var body: some View {
        NavigationStack{
            VStack(spacing: 0) {
                // 1. 自定义顶部 Header
                ZStack {
                    Color.lbSkyBlue.ignoresSafeArea(edges: .top)
                    HStack {
                        Text("DarkBlue")
                            .font(.title)
                        Spacer()
                        Button(action:{
                            //showPopover = true
                        }){
                            Text("about us")
                                .font(.title3)
                        }
                    }
                    .padding(.horizontal)
                }
                .foregroundColor(.white)
                .frame(height: 44)
                WebViewWrapper(url: URL(string: "https://punchthrough.com/resources/")!)
            }
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

#Preview {
    LearnView()
}
