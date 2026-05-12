//
//  HexEditView.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/20.
//
import SwiftUI

enum HexEditType {
    case serviceUUID, charUUID, hexString
}

struct HexEditView: View {
    let editType: HexEditType
    
    @State private var hexString: String
    @State private var showPopover = false
    @State private var showError = false
    
    @FocusState private var isFocused: Bool // iOS 15+
    
    // 定义保存回调
    var onSave: ((String) -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    
    init(editType:HexEditType = .hexString, initialValue: String = "", onSave: ((String) -> Void)? = nil) {
        self.editType = editType
        self._hexString = State(initialValue: initialValue)
        self.onSave = onSave
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 15) {
                Text("Property")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Text(title)
                    .font(.callout)
                
                // 2. 输入框 (显示用户输入的结果)
                TextField(placeholder,text: $hexString)
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
                    .onChange(of: hexString, perform: { newValue in
                        //输入校验
                        hexString = newValue.filter { $0.isHexDigit }.uppercased()

                        if editType != .hexString {
                            showError = !isUUIDValid(hexString)
                        }else{
                            showError = false
                        }
                    })
                    .submitLabel(.done)
#if os(iOS)
                    .keyboardType(.asciiCapable) // 使用 ASCII 键盘，避免中文输入法干扰
                    .textInputAutocapitalization(.characters) // 如果是输入UUID/Hex建议全大写
                    .disableAutocorrection(true)
#endif
                if showError{
                    if hexString.isEmpty{
                        Text("The field can not be empty").foregroundStyle(.red)
                    }else{
                        Text("The field contains an invalid UUID").foregroundStyle(.red)
                    }
                }
            }
            .padding()
            
            Spacer()
            
            // 3. 自定义十六进制键盘
            HexKeyboardView(text: $hexString) {
                // 点击 Done 后的动作
                if !showError{
                    onSave?(hexString)
                    dismiss()
                }
            }
        }
        .adaptiveSheet(isPresented: $showPopover){
            FormatSelectionView(data: hexString.hexToData ?? Data(), dataFormat: Binding.constant(.hex))
        }
        .toolbar{
            if editType == .hexString{
                ToolbarItem(placement: .primaryAction) {
                    Button("Hex", action: {
                        showPopover = true
                    })
                }
            }
        }
    }
    
    private var title:String{
        switch editType {
        case .serviceUUID:
            "Service UUID"
        case .charUUID:
            "Characteristic UUID"
        case .hexString:
            "Hex Value"
        }
    }
    
    private var placeholder:String{
        switch editType {
        case .serviceUUID:
            "The service identifier"
        case .charUUID:
            "The characteristic identifier"
        case .hexString:
            "Empty Value"
        }
    }
    
    // 简单的合法性检查
    func isUUIDValid(_ input: String) -> Bool {
        let cleaned = input.trimmingCharacters(in: .whitespaces)
        return [4, 8, 32].contains(cleaned.count)
    }
}


//#Preview {
//    HexEditView(initialValue: "63")
//}
