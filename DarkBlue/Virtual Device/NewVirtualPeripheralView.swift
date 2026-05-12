//
//  NewVirtualPeripheralView.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/20.
//

import SwiftUI

struct NewVirtualPeripheralView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedID: UUID? = nil
    
    // 回调：将选中的模板传回给列表页
    var onSave: (VirtualPeripheral) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 1. 自定义顶部 Header (还原图片蓝色渐变感)
            ZStack {
                Color.lbSkyBlue.ignoresSafeArea(edges: .top)
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("New Virtual Peripheral")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button("Save") {
                        if let selected = allTemplates.first(where: { $0.id == selectedID }) {
                            onSave(selected)
                            dismiss()
                        }
                    }
                    .foregroundColor(selectedID == nil ? .white.opacity(0.5) : .white)
                    .disabled(selectedID == nil)
                }
                .padding(.horizontal)
            }
            .frame(height: 44)

            // 2. 模板列表
            List(allTemplates) { template in
                HStack {
                    Text(template.name)
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                    if selectedID == template.id {
                        Image(systemName: "checkmark")
                            .foregroundColor(.lbSkyBlue)
                    }
                }
                .padding(.horizontal, 16) // 👈 手动添加水平边距
                .padding(.vertical, 8)   // 👈 手动添加垂直间距
                .listRowInsets(EdgeInsets()) // 移除系统默认可能存在的干预
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedID = template.id
                }
            }
            .listStyle(.plain)
        }
    }
}
