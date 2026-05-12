//
//  AdDataView.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/17.
//

import SwiftUI
import CoreBluetooth

struct AdDataView: View {
    let adData: [String: Any]

    var body: some View {
        if adData.isEmpty {
            Text("No Advertising Data Found")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                // 1. 表头
                HStack {
                    Text("Properties")
                    Spacer()
                    Text("Values")
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(.gray)
                .padding(.bottom, 4)
                
                Divider()
                // 遍历常见的广播键
                ForEach(CBAdvertisementData.parseAdvertisementData(adData)) { item in
                    dataRow(key: item.name, value:  item.value)
                }
            }
            .padding()
            .background(Color(white: 0.98))
        }
    }

    func dataRow(key: String, value: String) -> some View {
        HStack(alignment: .center) {
            Text(key)
                .font(.caption)
                .foregroundColor(.gray)
                .frame(width: 200, alignment: .leading)
            
            Text(value)
                .font(.caption.monospaced())
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}


#Preview {
    AdDataView(adData: [:])
}
