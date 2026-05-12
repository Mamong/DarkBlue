//
//  VirtualDevicesListView.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/20.
//

import SwiftUI

struct VirtualDevicesListView: View {
    
    @EnvironmentObject var virtualManager: VirtualManager
    
    @State private var showPopover = false
    
    
    var body: some View {
        let _ = Self._printChanges()
        
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
                            showPopover = true
                        }){
                            Image(systemName: "plus")
                                .font(.title3)
                        }
                    }
                    .padding(.horizontal)
                }
                .foregroundColor(.white)
                .frame(height: 44)
                
                // 2. 列表标题
                HStack {
                    Text("Virtual Devices")
                        .font(.title3)
                        .foregroundColor(.gray)
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundColor(Color(white: 0.8))
                    Spacer()
                }
                .padding(12)
                
                // 3. 设备列表
                List {
                    ForEach($virtualManager.savedDevices) { $device in
                        NavigationLink(destination: VirtualPeripheralDetailView(peripheral: $device)){
                            VirtualRow(device: device) {
                                toggleAdvertising(for: device)
                            }
                        }
                    }
                    .onDelete { offsets in
                        virtualManager.removeDevice(virtualManager.savedDevices[offsets.first!])
                    }
                    .listRowBackground(Color.white)
                }
                .listStyle(PlainListStyle())
            }
            .adaptiveSheet(isPresented: $showPopover){
                NewVirtualPeripheralView(){ device in
                    virtualManager.addDevice(device)
                }
            }
            // 绑定到 virtualManager 的状态
            .alert(isPresented: $virtualManager.showErrorAlert) {
                Alert(
                    title: Text(""),
                    message: Text(virtualManager.errorMessage ?? "An unknown error occurred."),
                    dismissButton: .default(Text("OK")) {
                        // 点击 OK 后清理错误信息
                        virtualManager.errorMessage = nil
                    }
                )
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
        .environmentObject(virtualManager)
    }
    
    // 处理开关逻辑
    func toggleAdvertising(for device: VirtualPeripheral) {
        let index = virtualManager.savedDevices.firstIndex(of: device) ?? 0
        // 先停止所有正在进行的广播（模拟 DarkBlue 单选行为）
        for i in virtualManager.savedDevices.indices {
            if i != index { virtualManager.savedDevices[i].isAdvertising = false }
        }
        
        // 切换当前选中项
        virtualManager.savedDevices[index].isAdvertising.toggle()
        
        if virtualManager.savedDevices[index].isAdvertising {
            virtualManager.startAdvertising(
                peripheral: virtualManager.savedDevices[index]
            )
        } else {
            virtualManager.stopAdvertising()
        }
    }
}

struct VirtualRow: View {
    let device: VirtualPeripheral
    var onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 15) {
            // 1. 使用 Button 替代原始的 Circle + onTapGesture
            Button(action: {
                onToggle()
            }) {
                // 左侧状态圆圈
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        .frame(width: 24, height: 24)
                    
                    if device.isAdvertising {
                        Circle()
                            .fill(Color.lbSkyBlue)
                            .frame(width: 14, height: 14)
                    }
                }
                .padding(10) // 增加按钮内部边距，让热区更大
                .contentShape(Rectangle()) // 关键：让整个 44x44 的区域都变的可点击
            }
            .buttonStyle(.plain) // 关键：防止点击这个按钮时触发整行的 Highlight
            
            
            // 中间信息
            VStack(alignment: .leading, spacing: 6) {
                Text(device.name)
                    .font(.callout.weight(.medium))
                Text("\(device.services.count) service")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle()) // 使整行可点击
    }
}
