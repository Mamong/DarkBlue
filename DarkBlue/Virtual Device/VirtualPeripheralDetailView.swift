//
//  VirtualPeripheralDetailView.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/20.
//

import SwiftUI
import CoreBluetooth

enum FlattenedRow: Identifiable {
    case service(VirtualService)
    case characteristic(VirtualCharacteristic, serviceIndex: Int)
    
    var id: UUID {
        switch self {
        case .service(let s): return s.id
        case .characteristic(let c, _): return c.id
        }
    }
}


struct VirtualPeripheralDetailView: View {
    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject private var virtualManager: VirtualManager

    @Binding var peripheral: VirtualPeripheral
    
    @State private var presentingActionSheet = false
    
    @State private var showSelect = false
    
    var body: some View {
        let _ = Self._printChanges()
        
        VStack(spacing: 0) {
            
            List {
                // Name Section
                Section {
                    ZStack {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Name")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(peripheral.name)
                                    .font(.callout.weight(.semibold))
                            }
                            Spacer()
                            Image(systemName: "pencil") // 编辑图标
                        }
                        .padding(.vertical, 4)
                        .background {
                            NavigationLink(destination: PropertyEditView(editType: .name, initialValue: peripheral.name, onSave: { value in
                                peripheral.name = value
                                if peripheral.isAdvertising{
                                    virtualManager.updateAndRestartAdvertising(with: peripheral)
                                }
                            })) {
                                EmptyView()
                            }.opacity(0)
                        }
                    }
                }
                
                // Services Section
                Section(header: serviceHeader) {
                    ForEach(flattenedRows) { row in
                        switch row {
                        case .service(let service):
                            // 关键点：为 Service 行添加跳转
                            // 由于是 Binding，我们需要通过索引从原数组中获取引用
                            if let sIndex = peripheral.services.firstIndex(where: { $0.uuid == service.uuid }) {
                                ServiceTitleRow(service: peripheral.services[sIndex])
                                    .background {
                                        NavigationLink(destination: HexEditView(editType: .serviceUUID, initialValue: peripheral.services[sIndex].uuid.uuidToHex, onSave: {value in
                                            virtualManager.updateService(peripheral.services[sIndex], to: peripheral, with: value.hexToUUID)
                                        })) {
                                            EmptyView()
                                        }.opacity(0)
                                    }
                            }
                            
                        case .characteristic(let char, let sIndex):
                            // 渲染特征行
                            if let cIndex = peripheral.services[sIndex].characteristics.firstIndex(where: { $0.uuid == char.uuid }) {
                                
                                NavigationLink(destination: VirtualCharDetailView(peripheral: peripheral, service: peripheral.services[sIndex], characteristic: $peripheral.services[sIndex].characteristics[cIndex])) {
                                    CharacteristicRowContent(char: peripheral.services[sIndex].characteristics[cIndex])
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteRow) // 统一处理删除
                }
            }
            .adaptiveListStyle()
        }
        .adaptiveSheet(isPresented: $showSelect){
            SelectServiceView(peripheral: peripheral) { service in
                addCharacteristicRow(to: service)
            }
        }
        .navigationTitle("Virtual Peripheral")
        .iosNavigationInline()
#if os(iOS)
        .toolbar(.visible, for: .navigationBar)
#endif
        .toolbar{
            ToolbarItemGroup(placement: .primaryAction){
                Button(action: {
                    removePeripheral()
                }) {
                    Image(systemName: "trash.slash.fill") // 添加 Service 的按钮
                }
                Button(action: { presentingActionSheet = true }) {
                    Image(systemName: "plus") // 添加 Service 的按钮
                }.confirmationDialog("Select an option", isPresented: $presentingActionSheet, titleVisibility: .visible){
                    Button("Add Service", action: addServiceRow)
                    if !peripheral.services.isEmpty  {
                        Button("Add Characteristic"){
                            if peripheral.services.count > 1{
                                showSelect = true
                            }else{
                                addCharacteristicRow(to: peripheral.services.first!)
                            }
                        }
                    }
                }
            }
        }
    }
    
    var flattenedRows: [FlattenedRow] {
        var rows: [FlattenedRow] = []
        for (sIndex, service) in peripheral.services.enumerated() {
            // 先加入服务行
            rows.append(.service(service))
            // 再加入该服务下的所有特征行
            for char in service.characteristics {
                rows.append(.characteristic(char, serviceIndex: sIndex))
            }
        }
        return rows
    }
    
    private func addServiceRow() {
        virtualManager.addService(to: peripheral)
    }
    
    private func removePeripheral(){
        virtualManager.removeDevice(peripheral)
        dismiss()
    }
    
    func addCharacteristicRow(to service: VirtualService) {
        virtualManager.addCharacteristic(in: service, to: peripheral)
    }
    
    // --- 删除逻辑 ---
    func deleteRow(at offsets: IndexSet) {
        for index in offsets {
            let row = flattenedRows[index]
            switch row {
            case .service(let service):
                // 如果删除了服务行，删除整个服务及其特征
                //peripheral.services.removeAll { $0.uuid == service.uuid }
                virtualManager.removeService(service, from: peripheral)
            case .characteristic(let char, _):
                // 如果删除了特征行，只删除该服务下的特定特征
                //peripheral.services[sIndex].characteristics.removeAll { $0.uuid == char.uuid }
                virtualManager.removeCharacteristic(char, from: peripheral)
            }
        }
    }
    
    
    // --- 子组件 ---
    var serviceHeader: some View {
        HStack {
            Text("Services")
                .font(.callout.weight(.medium))
                .foregroundColor(.lbSkyBlue)
                .textCase(nil)
            LBInfoButton(
                tipMessage: "Characteristics represent values that can be read, written, or notified.",
                learnMoreUrl: "https://bluetooth.com"
            )
        }
    }
}

struct ServiceTitleRow: View {
    let service: VirtualService
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(service.uuid.displayName)
                    .font(.callout.weight(.semibold))
                    .foregroundColor(.primary)
                if !service.uuid.displayName.hasPrefix("0x"){
                    Text(service.uuid.prefixUUID)
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 点击铅笔图标可以触发修改 UUID 的逻辑
            Image(systemName: "pencil")
        }
        .padding(.vertical, 8)
    }
}

struct CharacteristicRowContent: View {
    let char: VirtualCharacteristic
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(char.displayName)
                .font(.callout.weight(.semibold))
                .foregroundColor(.primary)
            
            HStack(spacing: 6) {
                Text("Properties:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                // 模拟 DarkBlue 的小标签样式
                Text(char.properties.names.joined(separator: ","))
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.lbSkyBlue)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.lbSkyBlue.opacity(0.1))
                    .cornerRadius(3)
            }
        }
        .padding(.leading, 20) // 关键：通过缩进体现归属于上方的 Service
        .padding(.vertical, 6)
    }
}
