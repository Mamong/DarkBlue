//
//  LBNavBar.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/21.
//

import SwiftUI

/*
 1. 创建通用导航组件 (LBNavBar)
 首先，封装一个可以接收左侧、中间和右侧内容的通用容器。
 */
struct LBNavBar<Left: View, Center: View, Right: View>: View {
    let left: Left
    let center: Center
    let right: Right
    
    init(@ViewBuilder left: () -> Left, @ViewBuilder center: () -> Center, @ViewBuilder right: () -> Right) {
        self.left = left()
        self.center = center()
        self.right = right()
    }

    var body: some View {
        VStack(spacing: 0) {
            // 状态栏背景延伸
            Color.lbSkyBlue.ignoresSafeArea(edges: .top)
                .frame(height: 0)
            
            HStack {
                ZStack {
                    HStack {
                        left
                        Spacer()
                        right
                    }
                    center // 居中标题
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color.lbSkyBlue)
            .foregroundColor(.white)
        }
    }
}

/*
 2. 封装成 ViewModifier
 通过 Modifier，我们可以统一处理“隐藏原生导航栏”和“白色状态栏”的逻辑。

 */
struct LBNavigationModifier<L: View, C: View, R: View>: ViewModifier {
    let left: L
    let center: C
    let right: R

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            LBNavBar(left: { left }, center: { center }, right: { right })
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        //.navigationBarHidden(true) // 全局隐藏原生栏
        .preferredColorScheme(.dark) // 确保状态栏为白色
    }
}

// 扩展 View 方便调用
extension View {
    func lbNavigation<L: View, C: View, R: View>(
        @ViewBuilder left: @escaping () -> L,
        @ViewBuilder center: @escaping () -> C,
        @ViewBuilder right: @escaping () -> R
    ) -> some View {
        self.modifier(LBNavigationModifier(left: left(), center: center(), right: right()))
    }
}

/*
 3. 在全局页面中使用
 现在，你可以在任何页面快速构建 DarkBlue 风格的顶栏，且代码非常整洁。

 场景 A：设备详情页 (带返回和 Hex 按钮)

 struct VirtualCharDetailView: View {
     @Environment(\.presentationMode) var presentationMode
     
     var body: some View {
         List {
             // 页面内容
         }
         .lbNavigation(
             left: {
                 Button(action: { presentationMode.wrappedValue.dismiss() }) {
                     HStack(spacing: 5) {
                         Image(systemName: "chevron.left")
                         Text("Back")
                     }
                 }
             },
             center: {
                 Text("Virtual Characteristic").fontWeight(.bold)
             },
             right: {
                 Button("Hex") { /* 切换逻辑 */ }
             }
         )
     }
 }

 
 场景 B：主列表页 (只有标题和加号)
 struct VirtualDevicesListView: View {
     var body: some View {
         ScrollView {
             // 列表内容
         }
         .lbNavigation(
             left: { Text("DarkBlue").font(.headline) },
             center: { EmptyView() },
             right: { Image(systemName: "plus") }
         )
     }
 }

 
 */
