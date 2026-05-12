//
//  CharPropertiesEditView.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/21.
//

import SwiftUI
import CoreBluetooth

struct CharPropertiesEditView: View {
    @EnvironmentObject var virtualManager: VirtualManager
    
    private let allProperties:[CBCharacteristicProperties] = [.read, .write, .writeWithoutResponse, .notify, .indicate]
    
    @Binding var properties:CBCharacteristicProperties
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 0) {
            Text("Characteristic Properties")
                .font(.headline)
                .foregroundColor(.gray)
                .padding(.horizontal)
                .padding(.top, 25)
                .padding(.bottom, 20)
            
            VStack(spacing: 0) {
                ForEach(allProperties, id: \.rawValue){ property in
                    CheckboxRow(isSelected: properties.contains(property), action: { selected in
                        if !selected {
                            properties.remove(property)
                        }else{
                            properties.insert(property)
                        }
                        if let peripheral = virtualManager.currentPeripheral{
                            virtualManager.updateAndRestartAdvertising(with: peripheral)
                        }
                    }){
                        Text(property.names.first!)
                            .font(.callout)
                            .foregroundColor(.primary)
                        
                        // 灰色的 info 图标
                        Image(systemName: "info.circle.fill")
                            .font(.subheadline)
                            .foregroundColor(Color(white: 0.8))
                    }
                    Divider().padding(.leading, 40)
                }
            }
            .padding(.horizontal)
            Spacer()
        }
    }
}


struct CheckboxRow<Content: View>: View {
    @State private var isSelected: Bool
    let action: (Bool) -> Void
    @ViewBuilder let content: Content
    
    // 使用 @ViewBuilder 接收自定义内容
    init(isSelected: Bool, action: @escaping (Bool) -> Void, @ViewBuilder content: () -> Content) {
        self._isSelected = State.init(initialValue: isSelected)
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        HStack(spacing: 15) {
            // 方框图标
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundColor(isSelected ? .lbSkyBlue : Color(white: 0.8))
            
            content
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isSelected.toggle()
            action(isSelected)
        }
        .padding(.vertical, 12)
    }
}
