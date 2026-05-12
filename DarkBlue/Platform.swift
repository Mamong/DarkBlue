//
//  Platform.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/24.
//

import SwiftUI

#if os(iOS)
import UIKit // 确保在文件顶部或此处可用
#elseif os(macOS)
import AppKit
#endif

extension View {
    func iosNavigationInline() -> some View {
#if os(iOS)
        return self.navigationBarTitleDisplayMode(.inline)
#else
        return self
#endif
    }
    
    func adaptiveListStyle() -> some View {
#if os(iOS)
        return self.listStyle(.insetGrouped) // iOS 推荐用 insetGrouped，比 grouped 更现代
#else
        return self.listStyle(.inset)        // macOS 推荐
#endif
    }
    
    func adaptiveFullScreenCover<Content>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View where Content : View{
#if os(iOS)
        self.fullScreenCover(isPresented: isPresented, content: content)
#else
        self.sheet(isPresented: isPresented, content: content)
#endif
    }
}

extension Color {
    static var adaptiveSystemGray6: Color {
#if os(iOS)
        return Color(uiColor: .systemGray6)
#else
        // macOS 下使用最接近的窗口背景色
        return Color(nsColor: .windowBackgroundColor)
#endif
    }
}


func copyToClipboard(_ text: String) {
#if os(iOS)
    UIPasteboard.general.string = text
#elseif os(macOS)
    let pasteboard = NSPasteboard.general
    pasteboard.declareTypes([.string], owner: nil)
    pasteboard.setString(text, forType: .string)
#endif
    
    print("已复制到剪贴板: \(text)")
}


struct AdaptiveHeaderModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
#if os(iOS)
            .toolbarBackground(Color.blue, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(.white) // 控制 iOS/Catalyst 的返回按钮颜色
#endif
            .navigationTitle("Detail")
    }
}


extension View {
    @ViewBuilder
    func adaptiveSheet<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        self.sheet(isPresented: isPresented) {
            NavigationStack {
                content()
#if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
#endif
            }
#if os(macOS)
            .frame(minWidth: 400, minHeight: 500) // 确保 Mac 弹窗不会缩成一团
#endif
        }
    }
}


struct AdaptiveNavigationModifier<Destination: View>: ViewModifier {
    @Binding var isPresented: Bool
    @ViewBuilder var destination: () -> Destination
    
    func body(content: Content) -> some View {
#if os(iOS)
        // iOS 方案：使用隐藏的 NavigationLink 触发 Push
        content
            .navigationDestination(isPresented: $isPresented) {
                destination()
            }
#else
        // macOS 方案：触发带尺寸限制的 Sheet
        content
            .sheet(isPresented: $isPresented) {
                NavigationStack {
                    destination()
                }
                .frame(minWidth: 500, minHeight: 400) // Mac 弹窗固定尺寸
            }
#endif
    }
}

// 包装成扩展方便调用
extension View {
    func pushOnIOSSheetOnMac<Destination: View>(isPresented: Binding<Bool>, @ViewBuilder destination: @escaping () -> Destination) -> some View {
        self.modifier(AdaptiveNavigationModifier(isPresented: isPresented, destination: destination))
    }
}
