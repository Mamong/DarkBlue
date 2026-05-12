//
//  ConnectStatusLabel.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/27.
//

import SwiftUI

struct ConnectStatusLabel: View {
    var isConnected = false
    
    var body: some View {
        Text(isConnected ? "Connected":"Disconnected")
            .padding(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            .font(.caption)
            .foregroundStyle(.tint)
            .background(
                Capsule()
                    .fill(.tint.opacity(0.1)) // 按钮背景色
            )
            .overlay(
                Capsule()
                    .stroke(.tint.opacity(0.2), lineWidth: 2) // 外边框
            )
            .tint(isConnected ? .lbSkyBlue:.red)
    }
}

#Preview {
    ConnectStatusLabel()
}
