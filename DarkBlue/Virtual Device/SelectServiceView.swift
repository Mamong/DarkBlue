//
//  SelectServiceView.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/22.
//

import SwiftUI

struct SelectServiceView: View {
    @Environment(\.dismiss) private var dismiss
    
    // 传入当前正在编辑的虚拟外设
    let peripheral: VirtualPeripheral
    
    // 回调：当用户选定某个 Service 后，触发下一步操作
    var onSelect: (VirtualService) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. 自定义顶部蓝色导航栏
            ZStack {
                Color.lbSkyBlue.ignoresSafeArea(edges: .top)
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("Add a Characteristic")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // 占位，保持标题居中
                    Text("Cancel").opacity(0)
                }
                .padding(.horizontal)
            }
            .frame(height: 50)
            
            // 2. 服务选择列表
            List {
                Section(header: Text("Services")
                    .font(.title3)
                    .foregroundColor(.gray)
                    .textCase(nil)
                    .padding(.vertical, 8)
                ) {
                    ForEach(peripheral.services) { service in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(service.uuid.displayName)
                                .font(.callout.weight(.semibold))
                                .foregroundColor(.primary)
                            if !service.uuid.displayName.hasPrefix("0x"){
                                Text(service.uuid.prefixUUID)
                                    .font(.footnote.monospaced())
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        .onTapGesture {
                            onSelect(service)
                            dismiss()
                        }
                    }
                }
            }
            .listStyle(.plain) // 使用平铺样式对齐图片效果
        }
    }
}
