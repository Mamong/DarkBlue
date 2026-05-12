//
//  PeripheralDetailView.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/17.
//

import SwiftUI
import CoreBluetooth

struct PeripheralDetailView: View {
    @EnvironmentObject var virtualManager: VirtualManager

    @EnvironmentObject var bluetoothManager: BluetoothManager
    
    let peripheral: CBPeripheral
    
    @State private var isExpanded = false
    
    var body: some View {
        let _ = Self._printChanges()
        List{
            Section{
                HStack{
                    VStack(alignment:.leading){
                        Text(peripheral.name ?? "Unnamed")
                        Text("UUID:\(peripheral.identifier)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    ConnectStatusLabel(isConnected: peripheral.state == .connected)
                }
                .padding(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0))
                .listRowBackground(Color(white:248/255.0))
            }
            
            Section{
                HStack{
                    Text("Advertisement Data")
                        .padding(EdgeInsets(top: 16, leading: 0, bottom: 8, trailing: 0))
                        .foregroundColor(.lbSkyBlue)
                    Spacer()
                    // 4. 旋转箭头
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    isExpanded.toggle()
                }
                
                // 2. 广播数据 (Advertisement Data)
                // 从 manager 的 deviceCache 中根据 ID 获取之前扫描到的 adData
                if let adData = bluetoothManager.getAdData(for: peripheral.identifier), !adData.isEmpty {
                    if isExpanded{
                        ForEach(CBAdvertisementData.parseAdvertisementData(adData)){ item in
                            VStack(alignment:.leading, spacing: 6){
                                Text(item.name)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    //.background(.blue, in: Rectangle())
                                Text(item.value).font(.callout)
                                    //.background(.blue, in: Rectangle())
                            }
                            //.background(.red, in: Rectangle())
                        }
                        .listRowInsets(.none)
                    }
                }else{
                    Text("No Advertisement Data Received.")
                }
            }
            
            Text("Services")
                .padding(EdgeInsets(top: 12, leading: 0, bottom: 8, trailing: 0))
                .foregroundColor(.lbSkyBlue)
                .font(.title2)
                .fontWeight(.medium)
            
            ForEach(bluetoothManager.myCachedServices, id: \.uuid){ service in
                Section{
                    Text(service.uuid.displayName)
                        .padding(EdgeInsets(top: 16, leading: 0, bottom: 8, trailing: 0))
                        .fontWeight(.medium)
                        .foregroundColor(.lbSkyBlue)
                    
                    if let characteristics = service.characteristics {
                        ForEach(characteristics, id: \.uuid){ characteristic in
                            NavigationLink {
                                CharacteristicView(peripheral: peripheral,characteristic: characteristic)
                            } label: {
                                VStack(alignment:.leading, spacing: 6){
                                    Text(characteristic.displayName).font(.body)
                                    
                                    if characteristic.uuid == CBUUID.batteryLevelUUID,
                                       let v = characteristic.value?.toUInt8(){
                                            Text("\(v)%")
                                                .foregroundColor(.gray).font(.subheadline)
                                    } else if characteristic.value != nil,
                                              characteristic.uuid == CBUUID.modelNumberStringUUID ||
                                                characteristic.uuid == CBUUID.manufacturerNameStringUUID{
                                        if let v = String(data: characteristic.value!, encoding: .utf8){
                                            Text(v)
                                                .foregroundColor(.gray).font(.subheadline)
                                        }
                                    }else{
                                        Text("Properties: \(characteristic.properties.names.joined(separator: ", "))")
                                            .foregroundColor(.gray).font(.subheadline)
                                    }
                                }.padding(.vertical,6)
                            }
                        }
                    }
                }
            }
        }
//#if os(iOS)
.listStyle(.plain)
//#else
//// macOS 下使用 inset 样式，效果最接近 iPad 的 plain
//.listStyle(.inset)
//#endif
        .iosNavigationInline()
        .navigationTitle("Peripheral")
        .toolbar{
            ToolbarItem(placement:.primaryAction){
                Menu{
                    Button("Add Virtual Peripheral"){
                        addVirtualPeripheral()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                
            }
        }
    }
    
    private func addVirtualPeripheral(){
        let services = bluetoothManager.myCachedServices.map { service in
            let chars = service.characteristics?.map { char in
                VirtualCharacteristic(uuid: char.uuid.uuidString, properties: char.properties, value: (char.value != nil) ? char.value!.dataToHex : "", serviceUUID: service.uuid.uuidString)
            }
            return VirtualService(uuid: service.uuid.uuidString, characteristics: chars ?? [])
        }
        let peri = VirtualPeripheral(name: peripheral.name ?? "Unnamed", services: services)
        virtualManager.addDevice(peri)
    }
}



