//
//  CharacteristicView.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/17.
//
import SwiftUI
import CoreBluetooth


struct CharacteristicView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager // 传入管理器以获取缓存数据
    let peripheral: CBPeripheral
    
    var characteristic: CachedCharacteristic
    
    @State private var showPopover = false
    @State private var presentWriteEditor = false
    
    @State private var dataFormat: DataFormat = .hex
    
    var cbCharacteristic:CBCharacteristic?{
        let service = peripheral.services?.first { s in
            s.uuid == characteristic.service
        }
        let char = service?.characteristics?.first { c in
            c.uuid == characteristic.uuid
        }
        return char
    }
    
    var body: some View {
        let _ = Self._printChanges()
        
        List{
            Section{
                HStack{
                    VStack(alignment:.leading){
                        Text(characteristic.displayName)
                        if !characteristic.displayName.hasPrefix("0x"){
                            Text("UUID:\(characteristic.uuid.uuidString)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    Spacer()
                    ConnectStatusLabel(isConnected: peripheral.state == .connected)
                }
                .padding(.vertical, 8)
                .listRowBackground(Color(white:248/255.0))
            }
            VStack(alignment:.leading){
                Text("Device").font(.footnote).foregroundColor(.gray)
                Text(peripheral.name ?? "Unnamed").font(.body)
            }.padding(.vertical, 5)
            
            VStack(alignment:.leading){
                Text("Service UUID").font(.footnote).foregroundColor(.gray)
                Text(characteristic.service?.uuidString ?? "").font(.body)
            }.padding(.vertical, 5)
            
            if characteristic.properties.contains(.write) ||
                characteristic.properties.contains(.writeWithoutResponse)
            {
                Section{
                    VStack(alignment:.leading){
                        Text("Write")
                            .foregroundColor(.blue)
                        Button{
                            presentWriteEditor = true
                        } label: {
                            Text("Write New Value")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.lbSkyBlue)
                        .disabled(peripheral.state != .connected)
                    }.padding(EdgeInsets(top: 14, leading: 0, bottom: 12, trailing: 0))
                    
                    if let writeValues = bluetoothManager.writeValues[characteristic.uuid], !writeValues.isEmpty{
                        ForEach(writeValues){ value in
                            DataRecordRow(dataFormat: dataFormat, record: value){
                                if let characteristic = cbCharacteristic{
                                    bluetoothManager.writeValue(value.data, for: characteristic)
                                }
                            }
                        }
                    }else{
                        VStack(alignment:.leading){
                            Text("Written values will appear here")
                                .padding(.vertical, 5)
                                .font(.callout)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            
            if characteristic.properties.contains(.read) ||
                characteristic.properties.contains(.notify) ||
                characteristic.properties.contains(.indicate)
            {
                Section{
                    VStack(alignment:.leading){
                        //读取或通知
                        Text(characteristic.properties.intersection([.read, .notify , .indicate]).names.joined(separator: "/") + " values")
                            .padding(.top, 12)
                            .foregroundColor(.blue)
                        HStack{
                            if characteristic.properties.contains(.read){
                                Button{
                                    if let characteristic = cbCharacteristic{
                                        peripheral.readValue(for: characteristic)
                                    }
                                } label: {
                                    Text("Read")
                                }
                                Spacer()
                            }
                            
                            if !characteristic.properties.isDisjoint(with: [.notify, .indicate]){
                                Button{
                                    if let characteristic = cbCharacteristic{
                                        peripheral.setNotifyValue(!characteristic.isNotifying, for: characteristic)
                                    }
                                } label: {
                                    Text(cbCharacteristic?.isNotifying ?? false ? "Unsubscribe":"Subscribe")
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.lbSkyBlue)
                        .disabled(peripheral.state != .connected)
                    }.padding(.vertical, 5)
                    
                    if let readValues = bluetoothManager.readValues[characteristic.uuid],
                       !readValues.isEmpty{
                        ForEach(readValues){ value in
                            DataRecordRow(dataFormat: dataFormat, record: value)
                        }
                    }else{
                        VStack(alignment:.leading, spacing: 8){
                            Text("No value read recently")
                            Text("Tap on one of the buttons above to begin")
                                .font(.callout)
                                .foregroundColor(.gray)
                        }.padding(.vertical, 5)
                    }
                }
            }
            
            Section{
                Text("Descriptors")
                    .padding(.vertical, 12)
                    .foregroundColor(.blue)
                if let descriptors = cbCharacteristic?.descriptors,
                   !descriptors.isEmpty{
                    ForEach(descriptors, id:\.uuid){ descriptor in
                        VStack(alignment:.leading, spacing: 8){
                            Text(descriptor.uuid.displayName)
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(descriptor.valueString)
                        }.padding(.vertical, 5)
                    }
                }else{
                    Text("No Data").padding(.vertical, 5)
                }
            }
            
            Section{
                Text("Properties")
                    .padding(.vertical, 12)
                    .foregroundColor(.blue)
                
                //Read
                HStack{
                    if characteristic.properties.contains(.read){
                        Image(systemName: "checkmark").foregroundColor(.green)
                        VStack(alignment:.leading, spacing: 5){
                            Text("Readable")
                            Text("Able to be read from").font(.subheadline).foregroundColor(.gray)
                        }
                    }else{
                        Image(systemName: "xmark").foregroundColor(.red)
                        VStack(alignment:.leading, spacing: 5){
                            Text("Un-readable")
                            Text("Unable to be read from").font(.subheadline).foregroundColor(.gray)
                        }
                    }
                }.padding(.vertical, 5)
                
                //Write
                HStack{
                    if characteristic.properties.contains(.writeWithoutResponse){
                        Image(systemName: "checkmark").foregroundColor(.green)
                        VStack(alignment:.leading, spacing: 5){
                            Text("Writeable without Response[Write Command]")
                            Text("Able to be written to without a response").font(.subheadline).foregroundColor(.gray)
                        }
                    }else if characteristic.properties.contains(.write){
                        Image(systemName: "checkmark").foregroundColor(.green)
                        VStack(alignment:.leading, spacing: 5){
                            Text("Writeable")
                            Text("Able to be written to").font(.subheadline).foregroundColor(.gray)
                        }
                    }else{
                        Image(systemName: "xmark").foregroundColor(.red)
                        VStack(alignment:.leading, spacing: 5){
                            Text("Un-writeable")
                            Text("Unable to be written to").font(.subheadline).foregroundColor(.gray)
                        }
                    }
                }.padding(.vertical, 5)
                
            //Notification/indication
            HStack{
                if characteristic.properties.contains(.notify){
                    Image(systemName: "checkmark").foregroundColor(.green)
                    VStack(alignment:.leading, spacing: 5){
                        Text("Supports notifications")
                        Text("Able to be subscribed to for notifications on changes to the characteristic").font(.subheadline).foregroundColor(.gray)
                    }
                }else if characteristic.properties.contains(.indicate){
                    Image(systemName: "checkmark").foregroundColor(.green)
                    VStack(alignment:.leading, spacing: 5){
                        Text("Supports indications")
                        Text("Able to be subscribed to for indications on changes to the characteristic").font(.subheadline).foregroundColor(.gray)
                    }
                }
                else{
                    Image(systemName: "xmark").foregroundColor(.red)
                    VStack(alignment:.leading, spacing: 5){
                        Text("Does not support notifications/indications")
                        Text("Unable to be subscribed to for notifications/indications on changes to the characteristic").font(.subheadline).foregroundColor(.gray)
                    }
                }
            }.padding(.vertical, 5)
        }
    }
        .pushOnIOSSheetOnMac(isPresented: $showPopover){
            let readValues = bluetoothManager.readValues[characteristic.uuid]
            let value = readValues?.first?.data ?? Data()
            FormatSelectionView(data: value, dataFormat: $dataFormat)
        }
        .navigationDestination(isPresented: $presentWriteEditor){
            HexEditView(editType: .hexString, initialValue: "", onSave: { value in
                if let characteristic = cbCharacteristic{
                    bluetoothManager.writeValue(value.hexToData ?? Data(), for: characteristic)
                }
            })
        }
        .listStyle(.plain)
        .navigationTitle("Characteristic")
        .toolbar{
            ToolbarItem(placement: .primaryAction) {
                Button(dataFormat.rawValue, action: {
                    showPopover = true
                }).disabled(peripheral.state != .connected)
            }
        }
}
}

struct DataRecordRow: View {
    let dataFormat: DataFormat
    
    let record: BluetoothManager.DataRecord
    var onTap: (()->Void)?
    
    var body: some View {
        HStack{
            VStack(alignment: .leading, spacing: 6) {
                Text(formatTime(record.timestamp))
                    .font(.caption.monospaced())
                    .foregroundColor(.lbSkyBlue)
                //data为空 empty value，转换失败为空
                Text(record.data.formattedDataString(as: dataFormat))
                    .font(.callout.monospaced())
            }
            .padding(.vertical, 4)
            if record.type == 1{
                Spacer()
                LBInfoButton(tipMessage: "", learnMoreUrl: "")
            }
        }
        .contextMenu{
            Button(action: {
                // 复制 UUID 到剪贴板
                copyToClipboard(record.data.formattedDataString(as: dataFormat))
                // 可选：触发一个简单的触感反馈
                //let generator = UIImpactFeedbackGenerator(style: .medium)
                //generator.impactOccurred()
            }){
                Image(systemName: "square.on.square").tint(.black)
                Text("Copy")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture{
            onTap?()
        }
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}
