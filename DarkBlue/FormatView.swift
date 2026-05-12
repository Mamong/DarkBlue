//
//  FormatView.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/19.
//

import SwiftUI

struct FormatSelectionView: View {
    let data:Data
    @Environment(\.dismiss) private var dismiss

    // 状态变量
    @Binding var dataFormat: DataFormat
    @State private var selectedFormat: DataFormat = .hex
    @State private var byteLimit: ByteLimit = .none
    @State private var endianness: Endianness = .little
    
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. 自定义顶部 Header (还原图片蓝色渐变感)
//            ZStack {
//                Color.lbSkyBlue.ignoresSafeArea(edges: .top)
//                HStack {
//                    Button("Cancel") {
//                        dismiss()
//                    }
//                    .foregroundColor(.white)
//                    
//                    Spacer()
//                    
//                    Text("Format Selection")
//                        .font(.system(size: 17, weight: .semibold))
//                        .foregroundColor(.white)
//                    
//                    Spacer()
//                    
//                    Button("Save") {
//                        dataFormat = selectedFormat
//                        dismiss()
//                    }
//                    .foregroundColor(.white)
//                    .fontWeight(.semibold)
//                }
//                .padding(.horizontal)
//            }
//            .frame(height: 50)
            
            List {
                // 1. 格式选择列表
                Section {
                    ForEach(DataFormat.allCases(for: byteLimit), id: \.self) { format in
                        formatRow(format:format)
                    }
                }
                
                // 2. 底部配置选项
                Section {
                    // Byte Limit
                    VStack(alignment: .leading, spacing: 8) {
                        headerWithInfo("Byte Limit:")
                        Picker("Byte Limit", selection: $byteLimit) {
                            ForEach(ByteLimit.allCases, id: \.self) { Text($0.rawValue) }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 4)
                    
                    // Endianness
                    VStack(alignment: .leading, spacing: 8) {
                        headerWithInfo("Endianness:")
                        Picker("Endianness", selection: $endianness) {
                            ForEach(Endianness.allCases, id: \.self) { Text($0.rawValue) }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 4)
                }
            }
//            .adaptiveListStyle()
            .navigationTitle("Format Selection")
//            .iosNavigationInline()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        dataFormat = selectedFormat
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
#if os(iOS)
            .toolbarBackground(Color.lbSkyBlue, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar) // Makes title white
#endif
        }
        //.tint(.white)
        .onAppear {
            // 只在进入页面时同步一次
            selectedFormat = dataFormat
        }
    }
    
    func formatRow(format:DataFormat) -> some View{
        var title = format.rawValue
        if let count = byteLimit.count{
            if format == .sInt || format == .uInt{
                title = "\(count) Byte " + title
            }
        }
        //data为空 no value,转换失败 empty value
        return FormatRow(
            title: title,
            value: data.formattedString(as: format, endian: endianness, limit: byteLimit) ?? "Empty Value",
            isSelected: selectedFormat == format
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedFormat = format
        }
    }

    
    // 辅助视图：带感叹号图标的标题
     func headerWithInfo(_ title: String) -> some View {
         HStack {
             Text(title)
                 .font(.body)
                 .foregroundColor(.secondary)
             Image(systemName: "info.circle.fill")
                 .foregroundColor(.gray) // 自定义灰色
                 .font(.caption)
         }
     }
    
}
    // MARK: - 单个格式行组件
    struct FormatRow: View {
        let title: String
        let value: String
        let isSelected: Bool
        
        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(title)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Image(systemName: "info.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.lbSkyBlue)
                    }
                    
                    Text(value)
                        .font(.body)
                        .foregroundColor(value == "Empty Value" ? .secondary : .primary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .font(.subheadline.weight(.semibold))
                }
            }
            .padding(.vertical, 2)
        }
    }
