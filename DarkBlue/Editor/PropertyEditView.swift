//
//  PropertyEditView.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/20.
//

import SwiftUI

enum PropertyEditType {
    case name, desc
}

struct PropertyEditView: View {
    let editType: PropertyEditType
    
    @State private var content: String
    
    @State private var showError = false
    
    @FocusState private var isFocused: Bool // iOS 15+
    
    @Environment(\.dismiss) private var dismiss
    
    var onSave: ((String) -> Void)?
    
    init(editType: PropertyEditType = .name, initialValue: String, onSave: ((String) -> Void)? = nil) {
        self.editType = editType
        self.onSave = onSave
        self._content = State(initialValue: initialValue)
    }
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 15) {
            Text("Property")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Text(title)
                .font(.callout)
            
            // 2. 输入框 (显示用户输入的结果)
            TextField(placeholder,text: $content)
                .focused($isFocused)
            // 1. 关键：在 Mac 上必须设为 .plain 才能自定义背景，iOS 默认即为 plain
#if os(macOS)
                .textFieldStyle(.plain)
#endif
                .font(.body.monospaced())
                .padding(12)
            // 2. 背景适配：使用平台语义色
                .background(
                    RoundedRectangle(cornerRadius: 4)
                    #if os(iOS)
                        .fill(Color(.systemBackground))
                    #else
                        .fill(Color(nsColor: .textBackgroundColor))
                    #endif
                )
            
            // 3. 边框适配：Mac 增加焦点动态变色
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            isFocused ? Color.blue : Color.gray.opacity(0.2),
                            lineWidth: isFocused ? 1.5 : 1
                        )
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .onSubmit {
                    if !showError{
                        onSave?(content)
                        dismiss()
                    }
                }
                .onChange(of: content, perform: { newValue in
                    if editType == .name {
                        showError = newValue.isEmpty
                    }else{
                        showError = false
                    }
                })
                .submitLabel(.done)
            if showError{
                Text("The field can not be empty").foregroundStyle(.red)
            }
            Spacer()
        }
        .padding()
        .onAppear {
            isFocused = true // 自动聚焦键盘
        }
    }
    
    private var title:String{
        switch editType {
        case .name:
            "Name"
        case .desc:
            "Characteristic User Description"
        }
    }
    
    private var placeholder:String{
        switch editType {
        case .name:
            "The name of the peripheral"
        case .desc:
            "The name to display for the characteristic"
        }
    }
}


#Preview {
    PropertyEditView(editType: .name, initialValue: "")
}
