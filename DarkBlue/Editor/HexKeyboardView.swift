//
//  HexKeyboardView.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/20.
//

import SwiftUI

struct HexKeyboardView: View {
    @Binding var text: String
    var onDone: () -> Void
    
    let keys = [
        ["D", "E", "F"],
        ["A", "B", "C"],
        ["7", "8", "9"],
        ["4", "5", "6"],
        ["1", "2", "3"]
    ]
    
    var body: some View {
        VStack(spacing: 1) {
            ForEach(keys, id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(row, id: \.self) { key in
//                        Button(key) {
//                            text += key
//                        }
//                        .buttonStyle(HexKeyButtonStyle())
                        keyboardButton(key)
                    }
                }
            }
            
            // 最后一排：删除、0、完成
            HStack(spacing: 1) {
                // 功能按键
//                Button("Clear") { text = "" }.buttonStyle(HexKeyButtonStyle(color: .red))
//                
//                Button("0") { text += "0" }.buttonStyle(HexKeyButtonStyle(color: .red))
//                
//                Button(action: { if !text.isEmpty { text.removeLast() } }) {
//                    Image(systemName: "delete.left")
//                }.buttonStyle(HexKeyButtonStyle(color: .orange))
                
                Button(action: { if !text.isEmpty { text.removeLast() } }) {
                    Image(systemName: "delete.left.fill")
                        .frame(maxWidth: .infinity, minHeight: 55)
                        .background(Color.white)
                        .foregroundColor(.lbSkyBlue)
                }
                
                keyboardButton("0")
                
                Button(action: onDone) {
                    Text("Done")
                        .frame(maxWidth: .infinity, minHeight: 55)
                        .background(Color.lbSkyBlue)
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                }
            }
        }
        .background(Color(white: 0.9)) // 网格线颜色
        .padding(.bottom, 30) // 适配底部安全区域
    }
    
    func keyboardButton(_ char: String) -> some View {
        Button(action: {
            text.append(char)
        }) {
            Text(char)
                .font(.title3)
                .frame(maxWidth: .infinity, minHeight: 55)
                .background(Color.white)
                .foregroundColor(.lbSkyBlue)
        }
    }
}

// 统一的按键样式
struct HexKeyButtonStyle: ButtonStyle {
    var color: Color = .blue
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.title3, design: .monospaced).bold())
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(color.opacity(configuration.isPressed ? 0.3 : 0.1))
            .foregroundColor(color)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.2)))
    }
}
