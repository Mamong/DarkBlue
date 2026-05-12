//
//  SwiftUIView.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/26.
//

import SwiftUI

enum LoadingPhase: CaseIterable {
    case rotating   // 旋转阶段
    case stopRotate // 缓冲：旋转归零，准备缩放
    case pulsing    // 缩放阶段
    case initial   // 旋转阶段
}

struct ConnectionOverlay: View {
    let title: String
    let subtitle: String

    var onCancel: (() -> Void)
    
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // 1. 全屏半透明背景蒙版
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            // 2. 中间白色圆角正方形
            VStack(spacing: 20) {
                // 上方文本
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.black)
                // 中间持续运动的图片
                
                if #available(iOS 17.0,macOS 14.0, *) {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                    // 顺序动画核心逻辑
                        .phaseAnimator(LoadingPhase.allCases) { content, phase in
                            content
                                .rotationEffect(.degrees(phase == .rotating ? 360 : 0))
                                .scaleEffect(phase == .pulsing ? 1.2 : 1.0)
                        } animation: { phase in
                            switch phase {
                            case .rotating: return .linear(duration: 1.0) // 旋转5圈耗时2秒
                            case .stopRotate: return .none // 瞬间重置角度，不产生往回转的动画
                            case .pulsing: return .easeInOut(duration: 0.4) // 放大缩回耗时0.6秒
                            case .initial: return .easeInOut(duration: 0.1) // 加一个停顿感
                            }
                        }
                } else {
                    // Fallback on earlier versions
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                        .scaleEffect(scale)           // 应用缩放
                        .rotationEffect(.degrees(rotation)) // 应用旋转
                        .onAppear {
                            startSequentialAnimation()
                        }
                }
                
                // 下方取消按钮
                Button(action: {
                    onCancel()
                }) {
                    Text("Cancel")
                        .fontWeight(.medium)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 8)
                        .foregroundStyle(Color.lbSkyBlue)
                        .cornerRadius(8)
                }
            }
            .padding(30)
            .frame(width: 200, height: 200) // 固定正方形
            .background(.white) // 适配 Mac/iOS 背景色
            .cornerRadius(20)
            .shadow(radius: 10)
        }
    }
    
    private func startSequentialAnimation() {
        Task {
            while true {
                // 第一步：旋转 360 度
                withAnimation(.linear(duration: 1.0)) {
                    rotation += 360
                }
                // 等待旋转完成（略多留一点点时间确保动画衔接）
                try? await Task.sleep(nanoseconds: 1500_000_000)
                
                // 第二步：放大
                withAnimation(.easeInOut(duration: 0.2)) {
                    scale = 1.2
                }
                try? await Task.sleep(nanoseconds: 200_000_000)
                
                // 第三步：缩小（回到初始）
                withAnimation(.easeInOut(duration: 0.2)) {
                    scale = 1.0
                }
                try? await Task.sleep(nanoseconds: 200_000_000)
                // 可选：在这里加一个停顿感
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }
}



//#Preview {
//    ConnectionOverlay()
//}
