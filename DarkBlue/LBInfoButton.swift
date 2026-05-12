//
//  LBInfoButton.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/22.
//

import SwiftUI

struct LBInfoButton: View {
    let tipMessage: String
    let learnMoreUrl: String? // 传入相关的文档链接
    
    @State private var showPopover = false
    @State private var showWebView = false
    
    var body: some View {
        Button(action: { showPopover = true }) {
            Image(systemName: "info.circle.fill")
                .font(.subheadline)
                .foregroundColor(Color(white: 0.8))
        }
        .buttonStyle(PlainButtonStyle())
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            VStack(alignment: .center, spacing: 12) {
                Text(tipMessage)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                
                Divider()
                
                // Learn More 按钮
                if learnMoreUrl != nil{
                    Button(action: {
                        showPopover = false // 先关闭气泡
                        // 延迟一丁点时间弹出 WebView，防止弹窗冲突
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showWebView = true
                        }
                    }) {
                        Text("Learn More")
                            .foregroundColor(.lbSkyBlue)
                    }
                }
            }
            .padding()
            .frame(width: 280) // 限制宽度，更像气泡
            //.presentationCompactAdaptation(.popover)
        }
        // 弹出 WebView
        .adaptiveFullScreenCover(isPresented: $showWebView) {
            if let learnMoreUrl{
                LBWebView(urlString: learnMoreUrl)
            }
        }
    }
}
