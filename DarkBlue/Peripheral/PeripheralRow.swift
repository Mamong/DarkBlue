//
//  PeripheralRow.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/16.
//
import SwiftUI
import CoreBluetooth

extension Color {
    static let lbSkyBlue = Color(red: 0.15, green: 0.55, blue: 0.9)
    static let lbSkyBlue2 = Color(red: 0.16, green: 0.71, blue: 0.96) // 顶部标题栏蓝色
    static let lbLightGray = Color(white: 0.96) // 搜索框背景色
    static let lbBorderGray = Color(white: 0.9) // 分割线颜色
}



struct PeripheralRow: View {
    let device: DiscoveredPeripheral
    @State private var isExpanded = false
    var onConnect: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // 1. 信号图标 (根据截图，未连接时是灰色或浅蓝色)
                VStack(spacing: 2) {
                    SignalStrengthView(rssi: device.isActive ? device.rssi:-127)
                    Text(device.isActive ? "\(device.rssi)":"--")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .frame(width: 30)
                
                // 2. 名称信息
                Text(device.name)
                    .font(.body)
                    .foregroundColor(device.isActive ? .primary: .gray)
                
                Spacer()
                
                // 3. Connect 按钮 (淡灰色细边框)
                Button(action: onConnect) {
                    Text("Connect")
                        .font(.subheadline)
                         // 根据是否按下改变文字透明度
                        .foregroundColor(device.isActive ? Color.lbSkyBlue : .gray)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                            // 截图中的边框非常浅，甚至带有一点阴影效果
                                .stroke(device.isActive ? Color(red: 246.0/255.0, green: 252.0/255.0, blue: 255.0/255.0):Color(white: 224.0/255.0), lineWidth: 1)
                                .background(device.isActive ? Color(red: 246.0/255.0, green: 252.0/255.0, blue: 255.0/255.0): Color(white: 237.0/255.0))
                                .shadow(color: Color.black.opacity(device.isActive ? 0.1 : 0), radius: 1, x: 0, y: 1)
                        )
                }.buttonStyle(.borderless)
                
                // 4. 旋转箭头
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundColor(.gray.opacity(device.isActive ? 1.0:0.3))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onTapGesture {
                isExpanded.toggle()
            }
            .contextMenu{
                Button(action: {
                    // 复制 UUID 到剪贴板
                    copyToClipboard(device.peripheral.identifier.uuidString)
                    // 可选：触发一个简单的触感反馈
                    //let generator = UIImpactFeedbackGenerator(style: .medium)
                    //generator.impactOccurred()
                }){
                    Image(systemName: "square.on.square").tint(.black)
                    Text("Copy UUID")
                }
            }
            
            // 展开内容
            if isExpanded {
                AdDataView(adData: device.advertisementData)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .disabled(!device.isActive)
    }
}
