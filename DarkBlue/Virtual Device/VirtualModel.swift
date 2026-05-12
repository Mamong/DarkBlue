//
//  VirtualPeripheral.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/20.
//
import Foundation
import CoreBluetooth


extension CBCharacteristicProperties: @retroactive Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(UInt.self)
        self.init(rawValue: rawValue)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}


struct VirtualPeripheral: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var services: [VirtualService]

    // 1. 这个变量依然存在，但不会被保存到本地
    var isAdvertising = false
    
    // 2. 显式声明需要序列化的键
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case services
        // 注意：这里没有 isAdvertising
    }
}

struct VirtualService: Identifiable, Hashable, Equatable, Codable {
    var id = UUID()

    var uuid: String
    var characteristics: [VirtualCharacteristic]
    
    static func == (lhs: VirtualService, rhs: VirtualService) -> Bool {
        return lhs.uuid.isEqual(rhs.uuid) &&
        lhs.characteristics == lhs.characteristics
    }
}

struct VirtualCharacteristic: Identifiable, Hashable, Equatable, Codable {
    var id = UUID()

    var uuid: String
    var properties: CBCharacteristicProperties
    //var permissions: CBCharacteristicProperties
    
    var value: String = ""
    var serviceUUID: String
    
    var userDescription: String = ""
    
    var displayName:String{
        return userDescription.isEmpty ? uuid.displayName : userDescription
    }
    
    // 核心：使用 UInt 存储，因为它原生支持 Codable
    //    var propertiesRawValue: UInt
    //
    //    // 计算属性：方便在 UI 和 蓝牙逻辑中使用
    //    var properties: CBCharacteristicProperties {
    //        get { CBCharacteristicProperties(rawValue: propertiesRawValue) }
    //        set { propertiesRawValue = newValue.rawValue }
    //    }
    
    
    static func == (lhs: VirtualCharacteristic, rhs: VirtualCharacteristic) -> Bool {
        return lhs.uuid == rhs.uuid &&
        lhs.properties.rawValue == rhs.properties.rawValue &&
        lhs.value == rhs.value &&
        lhs.userDescription == rhs.userDescription &&
        lhs.serviceUUID == rhs.serviceUUID
    }
    
    func hash(into hasher: inout Hasher){
        hasher.combine(id)
    }
}

let allTemplates = [
    VirtualPeripheral(name: "Blank", services: [VirtualService(uuid: "1111", characteristics: [VirtualCharacteristic(uuid: "2222", properties: [.read], value: "FFFF0000F0F0F0F0", serviceUUID: "1111")])]),
    VirtualPeripheral(name: "Alert Notification", services: [
        VirtualService(uuid: "1811", characteristics: [
            VirtualCharacteristic(uuid: "2A45", properties: [.notify], serviceUUID: "1811"),
            VirtualCharacteristic(uuid: "2A47", properties: [.read], serviceUUID: "1811"),
            VirtualCharacteristic(uuid: "2A48", properties: [.read], serviceUUID: "1811"),
            VirtualCharacteristic(uuid: "2A46", properties: [.notify], serviceUUID: "1811"),
            VirtualCharacteristic(uuid: "2A44", properties: [.write], serviceUUID: "1811"),
        ])]),
    VirtualPeripheral(name: "Blood Pressure", services: [
        VirtualService(uuid: "1810", characteristics: [
            VirtualCharacteristic(uuid: "2A36", properties: [.notify], serviceUUID: "1810"),
            VirtualCharacteristic(uuid: "2A49", properties: [.read], value: "C97E7763622A082A3347402AA674E587", serviceUUID: "1810"),
            VirtualCharacteristic(uuid: "2A35", properties: [.indicate], serviceUUID: "1810"),
        ])]),
    VirtualPeripheral(name: "Cycling Power", services: [
        VirtualService(uuid: "1818", characteristics: [
            VirtualCharacteristic(uuid: "2A64", properties: [.notify], serviceUUID: "1818"),
            VirtualCharacteristic(uuid: "2A65", properties: [.read], value: "FF62499ECE60B9E238B5A23F8A668FC8FE9DA0E986F8AE75325B8A57E84782C1", serviceUUID: "1818"),
            VirtualCharacteristic(uuid: "2A63", properties: [.notify], serviceUUID: "1818"),
            VirtualCharacteristic(uuid: "2A5D", properties: [.read], value: "9A46ED38F8E88D44", serviceUUID: "1818"),
            VirtualCharacteristic(uuid: "2A66", properties: [.write, .indicate], serviceUUID: "1818"),
        ])]),
    VirtualPeripheral(name: "Cycling Speed and Cadence", services: [
        VirtualService(uuid: "1816", characteristics: [
            VirtualCharacteristic(uuid: "2A5C", properties: [.read], value: "A2CAD2F2429AEB8075F7588E3139EA3A", serviceUUID: "1816"),
            VirtualCharacteristic(uuid: "2A5B", properties: [.notify], serviceUUID: "1816"),
            VirtualCharacteristic(uuid: "2A55", properties: [.write, .notify], serviceUUID: "1816"),
            VirtualCharacteristic(uuid: "2A5D", properties: [.read], value: "2DC0FD1E1792F988", serviceUUID: "1816"),
        ])]),
    VirtualPeripheral(name: "Find Me", services: [
        VirtualService(uuid: "1802", characteristics: [
            VirtualCharacteristic(uuid: "2A06", properties: [.writeWithoutResponse], serviceUUID: "1802"),
        ])]),
    VirtualPeripheral(name: "Glucose", services: [
        VirtualService(uuid: "1808", characteristics: [
            VirtualCharacteristic(uuid: "2A18", properties: [.notify], serviceUUID: "1808"),
            VirtualCharacteristic(uuid: "2A34", properties: [.notify], serviceUUID: "1808"),
            VirtualCharacteristic(uuid: "2A51", properties: [.read], value: "020F29F7350DA68D64B4DC1C3C180588", serviceUUID: "1808"),
            VirtualCharacteristic(uuid: "2A52", properties: [.indicate, .write], serviceUUID: "1808"),
        ]),
    ]),
    VirtualPeripheral(name: "HID OVER GATT", services: [
        VirtualService(uuid: "1813", characteristics: [
            VirtualCharacteristic(uuid: "2A31", properties: [.notify], serviceUUID: "1813"),
            VirtualCharacteristic(uuid: "2A4F", properties: [.writeWithoutResponse], serviceUUID: "1813"),
        ])]),
    VirtualPeripheral(name: "Health Thermometer", services: [
        VirtualService(uuid: "1809", characteristics: [
            VirtualCharacteristic(uuid: "2A1C", properties: [.indicate], serviceUUID: "1809"),
            VirtualCharacteristic(uuid: "2A1D", properties: [.read], value: "05118FFA04D3ACC0", serviceUUID: "1809"),
            VirtualCharacteristic(uuid: "2A1E", properties: [.notify], serviceUUID: "1809"),
            VirtualCharacteristic(uuid: "2A21", properties: [.read], value: "3C1ED5A51D5C425D1669651399CC3F87", serviceUUID: "1809"),
        ])]),
    VirtualPeripheral(name: "Heart Rate", services: [
        VirtualService(uuid: "180D", characteristics: [
            VirtualCharacteristic(uuid: "2A37", properties: [.notify], serviceUUID: "180D"),
            VirtualCharacteristic(uuid: "2A38", properties: [.read], value: "40AD11648FBD788B", serviceUUID: "180D"),
            VirtualCharacteristic(uuid: "2A39", properties: [.write], serviceUUID: "180D"),
        ])]),
    VirtualPeripheral(name: "Location and Navigation", services: [
        VirtualService(uuid: "1819", characteristics: [
            VirtualCharacteristic(uuid: "2A67", properties: [.notify], serviceUUID: "1819"),
            VirtualCharacteristic(uuid: "2A68", properties: [.notify], serviceUUID: "1819"),

            VirtualCharacteristic(uuid: "2A69", properties: [.read], value: "E84D33BD5938C945415D098ED74DE61AAD2A331D36DD2BA1436143DE76DF84FE2A252ED1949B5A9C8AA89D1BAA3BB97DD48224712D4CE834C7B2B4D9DC2324403126911315B50DEAB89B8754A3A0138C5082AAED2B2E5EBD54A902AF72540E306B4A7E400D18BD84681611B57C02D4C34154AB30030165C6053E0F62DABCC505", serviceUUID: "1819"),
            VirtualCharacteristic(uuid: "2A6A", properties: [.read], value: "C666F403135513A1EA1BCC252AB01FA05B76FB0029E569389C46356BFAF4EFCE", serviceUUID: "1819"),
            VirtualCharacteristic(uuid: "2A68", properties: [.indicate, .write], serviceUUID: "1819"),
        ])]),
    VirtualPeripheral(name: "Phone Alert Status", services: [
        VirtualService(uuid: "180E", characteristics: [
            VirtualCharacteristic(uuid: "2A3F", properties: [.notify, .read], serviceUUID: "180E"),
            VirtualCharacteristic(uuid: "2A40", properties: [.writeWithoutResponse], serviceUUID: "180E"),
            VirtualCharacteristic(uuid: "2A41", properties: [.notify, .read], serviceUUID: "180E"),
        ])]),
    VirtualPeripheral(name: "Polar HR Sensor", services: [
        VirtualService(uuid: "180D", characteristics: [
            VirtualCharacteristic(uuid: "2A37", properties: [.notify], serviceUUID: "180D"),
            VirtualCharacteristic(uuid: "2A38", properties: [.read], value: "01", serviceUUID: "180D"),
        ]),
        VirtualService(uuid: "6217FF49-AC7B-547E-EECF-016A06970BA9", characteristics: [
            VirtualCharacteristic(uuid: "6217FF4A-B07D-5DEB-261E-2586752D942E", properties: [.read, .write], serviceUUID: "6217FF49-AC7B-547E-EECF-016A06970BA9"),
        ]),
    ]),
    VirtualPeripheral(name: "Proximity", services: [
        VirtualService(uuid: "1802", characteristics: [
            VirtualCharacteristic(uuid: "2A06", properties: [.writeWithoutResponse], serviceUUID: "1802"),
        ]),
        VirtualService(uuid: "1803", characteristics: [
            VirtualCharacteristic(uuid: "2A06", properties: [.read, .write], serviceUUID: "1803"),
        ]),
        VirtualService(uuid: "1804", characteristics: [
            VirtualCharacteristic(uuid: "2A07", properties: [.read], value: "8133F1FCD804701A",serviceUUID: "1804"),
        ]),
    ]),
    VirtualPeripheral(name: "Running Speed and Cadence", services: [
        VirtualService(uuid: "1814", characteristics: [
            VirtualCharacteristic(uuid: "2A53", properties: [.notify], serviceUUID: "1814"),
            VirtualCharacteristic(uuid: "2A54", properties: [.read], value: "080AFE75780552DAF6B257575ED182D4", serviceUUID: "1814"),
            VirtualCharacteristic(uuid: "2A55", properties: [.indicate, .write], serviceUUID: "1814"),
            VirtualCharacteristic(uuid: "2A5D", properties: [.read], value: "E39208FDD02A9131", serviceUUID: "1814"),
        ])]),
    VirtualPeripheral(name: "Scan Parameters", services: [
        VirtualService(uuid: "1813", characteristics: [
            VirtualCharacteristic(uuid: "2A31", properties: [.notify], serviceUUID: "1813"),
            VirtualCharacteristic(uuid: "2A4F", properties: [.writeWithoutResponse], serviceUUID: "1813"),
        ])]),
    VirtualPeripheral(name: "Temperature Alarm Service", services: [
        VirtualService(uuid: "DEADF154-0000-0000-0000-0000DEADF154", characteristics: [
            VirtualCharacteristic(uuid: "AAAAAAAA-DEAD-F154-1319-740381000000", properties: [.notify], serviceUUID: "DEADF154-0000-0000-0000-0000DEADF154"),
            VirtualCharacteristic(uuid: "C0C0C0C0-DEAD-F154-1319-740381000000", properties: [.read, .write], serviceUUID: "DEADF154-0000-0000-0000-0000DEADF154"),
            VirtualCharacteristic(uuid: "CCCCFFFF-DEAD-F154-1319-740381000000", properties: [.notify,.read], serviceUUID: "DEADF154-0000-0000-0000-0000DEADF154"),
            VirtualCharacteristic(uuid: "EDEDEDED-DEAD-F154-1319-740381000000", properties: [.read, .write], serviceUUID: "DEADF154-0000-0000-0000-0000DEADF154"),
        ])]),
    VirtualPeripheral(name: "Time", services: [
        VirtualService(uuid: "1806", characteristics: [
            VirtualCharacteristic(uuid: "2A16", properties: [.writeWithoutResponse], serviceUUID: "1806"),
            VirtualCharacteristic(uuid: "2A17", properties: [.read], value: "900424D557B3549917623B0FEE6C1F12", serviceUUID: "1806"),
        ]),
        VirtualService(uuid: "1807", characteristics: [
            VirtualCharacteristic(uuid: "2A11", properties: [.read], serviceUUID: "1807"),
        ]),
    ])
]
