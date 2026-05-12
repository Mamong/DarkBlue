//
//  DiscoveredPeripheral.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/16.
//

import CoreBluetooth

struct DiscoveredPeripheral: Identifiable {
    var id: UUID { peripheral.identifier }
    let peripheral: CBPeripheral
    var rssi: Int
    var advertisementData: [String: Any] // 新增：保存原始广播数据
    var isConnectable: Bool // 新增：是否可连接
    var lastUpdatedTimeInterval = Date()
    
    static func == (lhs: DiscoveredPeripheral, rhs: DiscoveredPeripheral) -> Bool {
        return lhs.peripheral.isEqual(rhs.peripheral)
    }

    func hash(into hasher: inout Hasher){
        hasher.combine(peripheral.hash)
    }

    var name: String {
        if let name = peripheral.name {
            return name
        } else if let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
            return localName
        }
        return "Unnamed"
    }
    
    var isActive: Bool {
        Date().timeIntervalSince(lastUpdatedTimeInterval) < 5
    }
}
