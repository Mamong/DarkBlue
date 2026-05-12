//
//  SignalStrengthView.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/17.
//

import SwiftUI

struct SignalStrengthView: View {
    let rssi: Int
    var body: some View {
        HStack(alignment: .bottom, spacing: 1) {
            ForEach(0..<5) { index in
                Rectangle()
                    .fill(index < level ? .lbSkyBlue : Color(white: 0.9))
                    .frame(width: 2, height: CGFloat(index + 1) * 4)
            }
        }
    }
    
    var level: Int {
        if rssi >= -41 { return 5 }
        if rssi >= -53 { return 4 }
        if rssi >= -65 { return 3 }
        if rssi >= -77 { return 2 }
        if rssi >= -89 { return 1 }
        return 0
    }
}


#Preview {
    SignalStrengthView(rssi: -50)
}
