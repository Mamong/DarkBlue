//
//  VirtualCharDetailView.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/20.
//

import SwiftUI
import CoreBluetooth

struct VirtualCharDetailView: View {
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var virtualManager: VirtualManager
    
    let peripheral: VirtualPeripheral
    let service: VirtualService
    
    @Binding var characteristic: VirtualCharacteristic
    
    @State private var presentWriteEditor = false
    @State private var showPopover = false
    
    @State private var writeText = ""
    @State private var dataFormat: DataFormat = .hex
    
    @State private var notifyValues: [BluetoothManager.DataRecord] = [] // 存储通知历史
    
    var body: some View {
        let _ = Self._printChanges()
        
        VStack(spacing: 0) {
            
            List {
                // General Section
                Section(header: sectionHeader(title: "General")) {
                    readOnlyRow(label: "Device", value: peripheral.name)
                    
                    readOnlyRow(label: "Service", value: service.uuid.displayName)
                    
                    editableRow(label: "Characteristic UUID", value: characteristic.uuid, destination: HexEditView(editType: .charUUID, initialValue: characteristic.uuid.uuidToHex, onSave: { value in
                        characteristic.uuid = value.hexToUUID
                        if peripheral.isAdvertising{
                            virtualManager.updateAndRestartAdvertising(with: peripheral)
                        }
                    }))
                    
                    editableRow(label: "Characteristic User Description", value: characteristic.userDescription, destination: PropertyEditView(editType: .desc, initialValue: characteristic.userDescription, onSave: { value in
                        characteristic.userDescription = value
                        if peripheral.isAdvertising{
                            virtualManager.updateAndRestartAdvertising(with: peripheral)
                        }
                    }))
                    
                    //Set a value for the remote device to read.
                    if characteristic.properties.contains(.read){
                        editableRow(label: "Hex Value", value: (characteristic.value.isEmpty ? "":"0x") + characteristic.value, destination: HexEditView(editType: .hexString, initialValue: characteristic.value, onSave: { value in
                            characteristic.value = value
                        }))
                    }else if !characteristic.properties.isDisjoint(with: [.write, .writeWithoutResponse]){
                        //Show incoming data from the remote device.
                        readOnlyRow(label: "Hex Value", value: (characteristic.value.isEmpty ? "":"0x") + characteristic.value)
                    }
                }
                
                // Permissions Section
                Section(header: sectionHeader(title: "Permissions")) {
                    NavigationLink(destination: CharPropertiesEditView(properties: $characteristic.properties)) {
                        Text(characteristic.properties.names.joined(separator: ", "))
                            .font(.callout).padding(.vertical, 6)
                    }
                }
                
                // Notify/Indicate Section
                if !characteristic.properties.isDisjoint(with: [.notify, .indicate]){
                    Section {
                        sectionHeader(title: "Notify/Indicate", notify: true)
                        if !isSubscribed {
                            Text("Establish a connection and subscribe to the characteristic to send notifications/indications")
                                .font(.subheadline)
                                .padding(.vertical, 5)
                        }else{
                            //value list
                            if notifyValues.isEmpty{
                                Text("Notified/Indicated values will appear here")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 5)
                            }else{
                                ForEach(notifyValues){ value in
                                    DataRecordRow(dataFormat: dataFormat, record: value){
                                        notifyValue(hexString: value.hexString)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .adaptiveListStyle()
            .adaptiveSheet(isPresented: $showPopover){
                FormatSelectionView(data: characteristic.value.hexToData ?? Data(),dataFormat: Binding.constant(.hex))
            }
            .navigationDestination(isPresented: $presentWriteEditor){
                HexEditView(editType: .hexString, initialValue: writeText, onSave: { value in
                    notifyValue(hexString: value)
                })
            }
        }
        .navigationTitle("Virtual Characteristic")
        .toolbar{
            ToolbarItemGroup(placement: .primaryAction){
                Button(action: {
                    virtualManager.removeCharacteristic(characteristic, from: peripheral)
                    dismiss()
                }) {
                    Image(systemName: "trash.slash.fill")
                }
                Button("Hex", action: {
                    showPopover = true
                })
            }
        }
    }
    
    // 计算属性：检查当前特征是否有活跃订阅者
    private var isSubscribed: Bool {
        let uuid = CBUUID(string: characteristic.uuid)
        return !(virtualManager.subscribedCentrals[uuid]?.isEmpty ?? true)
    }
    
    private func notifyValue(hexString:String){
        if let data = hexString.hexToData {
            virtualManager.notifyValueUpdate(
                for: characteristic,
                with: data)
            
            characteristic.value = hexString
            let newRecord = BluetoothManager.DataRecord(timestamp: Date(), data: data, type: 1)
            notifyValues.insert(newRecord, at: 0)
            
            // 可选：只保留最近 5-10 条记录以节省空间
            if notifyValues.count > 5 {
                notifyValues.removeLast()
            }
        }
    }
    
    // --- 子组件 ---
    
    func sectionHeader(title: String, notify: Bool = false) -> some View {
        VStack(alignment: .leading){
            HStack(spacing: 5) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundColor(.lbSkyBlue)
                    .textCase(nil) // 保持大小写
                Image(systemName: "info.circle.fill")
                    .font(.body)
                    .foregroundColor(Color(white: 0.8))
            }
            //only show when subscribed
            if notify && isSubscribed{
                Button{
                    presentWriteEditor = true
                } label: {
                    Text("Notify/Indicate New Value")
                }
                .buttonStyle(.borderedProminent)
                .tint(.lbSkyBlue)
            }
        }
        .padding(.vertical, 6)
    }
    
    // 不可编辑行
    func readOnlyRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundColor(Color(white: 0.8))
            }
            Text(value.isEmpty ? "No Value": value)
                .font(.callout)
        }
        .padding(.vertical, 4)
    }
    
    
    func editableRow<Destination: View>(label: String, value: String, destination: Destination) -> some View {
        // 2. 放在上层的自定义 UI
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(label).font(.caption).foregroundColor(.secondary)
                    Image(systemName: "info.circle.fill").font(.caption).foregroundColor(Color(white: 0.8))
                }
                Text(value.isEmpty ? "<unset>": value).font(.callout).foregroundColor(.primary)
            }
            Spacer()
            // 只有铅笔，没有箭头
            Image(systemName: "pencil")
                .font(.subheadline)
        }
        .padding(.vertical, 4)
        .background{
            NavigationLink(destination: destination) {
                EmptyView()
            }
            .opacity(0)
        }
    }
}
