//
//  HexTextField.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/28.
//

import SwiftUI

#if os(macOS) && !targetEnvironment(macCatalyst)
// MARK: - 原生 macOS (AppKit) 实现
struct HexTextField: NSViewRepresentable {
    let placeholder: String?
    @Binding var text: String
    var onDone: () -> Void
    var autoFocus: Bool = true
    
    init(_ placeholder: String?, text: Binding<String>, onDone: @escaping () -> Void) {
        self.placeholder = placeholder
        self._text = text
        self.onDone = onDone
    }
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.delegate = context.coordinator
        textField.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textField.isBordered = false // 禁用 Mac 原生边框，方便 SwiftUI 自定义外框
        textField.drawsBackground = false // 禁用原生背景色
        
        if autoFocus {
            DispatchQueue.main.async {
                // 原生 Mac 自动聚焦关键代码
                textField.window?.makeFirstResponder(textField)
            }
        }
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: HexTextField
        init(_ parent: HexTextField) { self.parent = parent }
        
        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            let rawText = textField.stringValue
            let filtered = rawText.filter { $0.isHexDigit }.uppercased()
            
            if rawText != filtered {
                textField.stringValue = filtered
            }
            parent.text = filtered
        }
        
        // 🚀 Mac 端核心：拦截物理回车键 (Enter)
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onDone() // 触发统一的提交闭包
                return true // 告诉系统我们已经处理了该回车事件
            }
            return false
        }
    }
}
#else
// MARK: - iOS / Mac Catalyst (UIKit) 实现
struct HexTextField: UIViewRepresentable {
    let placeholder: String?
    @Binding var text: String
    var onDone: () -> Void
    var autoFocus: Bool = true // 👈 增加一个控制开关，默认开启自动聚焦
    
    init(_ placeholder: String?, text: Binding<String>, onDone: @escaping () -> Void) {
        self.placeholder = placeholder
        self._text = text
        self.onDone = onDone
    }
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.delegate = context.coordinator
        textField.font = UIFont.monospacedSystemFont(ofSize: 16, weight: .regular)

#if os(iOS) && !targetEnvironment(macCatalyst)
        // 1. 只有在纯 iOS 设备上才将 SwiftUI 视图包装成键盘
        let hostingController = UIHostingController(rootView: HexKeyboardView(text: $text, onDone: onDone))
        
        // 2. 必须设置一个明确的 Frame 告知系统键盘的高度
        let screenWidth = UIScreen.main.bounds.width
        hostingController.view.frame = CGRect(x: 0, y: 0, width: screenWidth, height: 40)
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // 3. 赋值给 inputView 彻底拦截原生键盘
        textField.inputView = hostingController.view
#endif
        // 4. 关键修改：实现自动聚焦逻辑
        if autoFocus {
            DispatchQueue.main.async {
                // 必须在异步队列中触发，等待 UIKit 视图树完全准备就绪
                textField.becomeFirstResponder()
            }
        }
        return textField
    }
    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text{
            uiView.text = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: HexTextField
        
        init(_ parent: HexTextField) {
            self.parent = parent
        }
        
        // 监听文本框物理或虚拟输入的变化
        func textFieldDidChangeSelection(_ textField: UITextField) {
            DispatchQueue.main.async {
                let rawText = textField.text ?? ""
                // 实时过滤非16进制字符并转大写
                let filtered = rawText.filter { $0.isHexDigit }.uppercased()
                
                if rawText != filtered {
                    textField.text = filtered
                }
                self.parent.text = filtered
            }
        }
    }
}
#endif
