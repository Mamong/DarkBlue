//
//  PeripheralFilteringView.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/22.
//

import SwiftUI

// 将 RSSI 转换为信号格数（0-4）
func rssiToBars(_ rssi: Int) -> Int {
    if rssi >= -41 { return 5 }
    if rssi >= -53 { return 4 }
    if rssi >= -65 { return 3 }
    if rssi >= -77 { return 2 }
    if rssi >= -89 { return 1 }
    return 0
}

struct PeripheralFilteringView: View {
    @AppStorage("isRssiFilterEnabled") var isEnabled = false
    @AppStorage("minRssiThreshold") var threshold: Double = -100

    //@StateObject var vm = FilterViewModel()
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(spacing: 0) {
            List {
                // 第一行：标题和 Info 图标
                HStack {
                    Text("Peripheral Filtering")
                        .font(.headline)
                        .foregroundColor(.gray)
                    LBInfoButton(tipMessage: "Only devices stronger than the selected RSSI will be shown.", learnMoreUrl: "https://...")
                    Spacer()
                }
                .listRowSeparator(.hidden)
                .padding(.top, 10)

                // 第二行：开关
                Section {
                    Toggle(isOn: $isEnabled) {
                        Text("Filter by RSSI")
                            .font(.callout)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .lbSkyBlue))
                }

                // 第三行：滑动条区域
                Section {
                    VStack(alignment: .leading, spacing: 15) {
                        let bars = rssiToBars(Int(threshold))
                        Text("Min RSSI: \(Int(threshold)) dB (\(bars) \(bars <= 1 ? "bar" : "bars"))")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Slider(value: $threshold, in: -100...(-30), step: 1)
                            .tint(.lbSkyBlue)
                            .disabled(!isEnabled)
                    }
                    .padding(.vertical, 10)
                }
                
            }
            .listStyle(.plain)
            
            Spacer()
        }
    }
}
