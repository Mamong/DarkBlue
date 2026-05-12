//
//  LogView.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/18.
//
import SwiftUI

struct LogView: View {
    @StateObject private var engine = LogEngine.shared
    
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
                            Image(systemName: "square.and.arrow.up")
                                .font(.title3)
                        }
                    }
                    .padding(.horizontal)
                }
                .foregroundColor(.white)
                .frame(height: 44)
                
                // 2. 列表标题
                HStack {
                    Text("Logs")
                        .font(.title3)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(12)
                
                ScrollViewReader { proxy in
                    List(engine.entries) { entry in
                        HStack(alignment: .top, spacing: 4) {
                            Text(entry.timeString)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.gray)
                            Text(entry.message)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(entry.level.color)
                        }
                        .listRowSeparator(.visible)
                        .id(entry.id)
                    }
                    .listStyle(.plain)
                    // 监听条目变化，自动滚到底部
                    .onChange(of: engine.entries.count) { _ in
                        if let lastId = engine.entries.last?.id {
                            withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                        }
                    }
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
    
    // 将日志转为纯文本用于导出
    func generateLogExport() -> String {
        engine.entries.map { "[\($0.timestamp)] \($0.message)" }.joined(separator: "\n")
    }
}
