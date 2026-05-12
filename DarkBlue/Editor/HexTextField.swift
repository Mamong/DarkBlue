//
//  HexTextField.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/28.
//

import SwiftUI

#if os(iOS)
struct HexTextField: UIViewRepresentable {
    @Binding var text: String
    var onDone: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        // 这里创建你的自定义键盘视图 (UIHostingController 包装的 SwiftUI View)
        let customInput = UIHostingController(rootView: HexKeyboardView(text: $text, onDone: onDone)).view
        customInput?.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
        
        textField.inputView = customInput // 👈 核心代码
        return textField
    }
    func updateUIView(_ uiView: UITextField, context: Context) {}
}
#endif
