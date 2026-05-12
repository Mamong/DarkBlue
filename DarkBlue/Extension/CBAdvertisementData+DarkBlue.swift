//
//  CBAdvertisementData+DarkBlue.swift
//  SwiftUIDarkBlue
//
//  Created by tryao on 3/11/25.
//

import Foundation
import CoreBluetooth

struct AdvertisementItem: Identifiable {
    let id = UUID()
    let name: String
    let value: String
    let isOriginalKey: Bool // 标记是否为原始 kCB 开头的键
}

class CBAdvertisementData {
    
    // 1. 常见 Key 的翻译字典
    static let commonKeys: [String: String] = [
        CBAdvertisementDataLocalNameKey: "Local Name",
        CBAdvertisementDataServiceUUIDsKey: "Service UUIDs",
        CBAdvertisementDataTxPowerLevelKey: "Tx Power Level",
        CBAdvertisementDataManufacturerDataKey: "Manufacturer Data",
        CBAdvertisementDataServiceDataKey: "Service Data",
        CBAdvertisementDataIsConnectable: "Device is Connectable",
        CBAdvertisementDataOverflowServiceUUIDsKey: "Overflow UUIDs",
        CBAdvertisementDataSolicitedServiceUUIDsKey: "Solicited UUIDs",
        "kCBAdvDataTimestamp": "Advertisement Data Timestamp"
    ]
    
    static func parseAdvertisementData(_ dict: [String: Any]) -> [AdvertisementItem] {
        var items = dict.filter({ (key: String, value: Any) in
            !["kCBAdvDataRxPrimaryPHY","kCBAdvDataRxSecondaryPHY","CBAdvertisementDataOverflowServiceUUIDsKey","CBAdvertisementDataSolicitedServiceUUIDsKey",""].contains(key)
        }).map { (key, value) -> AdvertisementItem in
            let displayKey = commonKeys[key] ?? key // 没在字典里的保持原样
            
            let formattedValue = CBAdvertisementData.getAdvertisementDataStringValue(from: value, with: key)
            // 判断是否保持了原样（通常以 'kCB' 开头）
            let isOriginal = displayKey.hasPrefix("kCB")
            return AdvertisementItem(name: displayKey, value: formattedValue, isOriginalKey: isOriginal)
        }
        
        // 排序逻辑：
        items.sort { lhs, rhs in
            // 1. 如果一个属于常用名，一个属于原始键，常用名排在前
            if lhs.isOriginalKey != rhs.isOriginalKey {
                return !lhs.isOriginalKey // false (常用名) 会排在 true (kCB) 前面
            }
            // 2. 如果同类，则按字母顺序排
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
        
        return items
    }
    
    // 2. 核心格式化方法
    private static func getAdvertisementDataStringValue(from data: Any, with key: String) -> String {
        var resultString : String?
        if key == CBAdvertisementDataLocalNameKey {
            resultString = data as? String
        } else if key == CBAdvertisementDataTxPowerLevelKey {
            let level = data as? Int
            resultString = "\(level ?? 0)"
        } else if key == CBAdvertisementDataServiceUUIDsKey {
            guard let serviceUUIDs = data as? [CBUUID] else {
                return ""
            }
            let multiple = serviceUUIDs.count > 1
            resultString = serviceUUIDs.map { (multiple ? "·":"")+$0.uuidString }.joined(separator: "\n")
        } else if key == CBAdvertisementDataServiceDataKey {
            guard let data = data as? [CBUUID: Data] else {
                return ""
            }
            print("\(data)")
            resultString = data.map{item in "·\(item.key.uuidString):\n0x\(item.value.map { String(format: "%02x", $0).uppercased() }.joined())"}.joined(separator: ",\n")
        } else if key == CBAdvertisementDataManufacturerDataKey {
            resultString = parseManufacturerData(data as? Data)
        } else if key == CBAdvertisementDataOverflowServiceUUIDsKey {
            resultString = ""
        } else if key == CBAdvertisementDataSolicitedServiceUUIDsKey {
            resultString = ""
        } else if key == CBAdvertisementDataIsConnectable{
            if let connectable = data as? Bool {
                resultString = connectable ? "Yes" : "No"
            }
        } else if key == "kCBAdvDataTimestamp"{//double:763460589.170577
            let date = Date(timeIntervalSinceReferenceDate: data as! TimeInterval)
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            resultString = formatter.string(from: date)
        } else{
            if let data = data as? NSValue {
                resultString = "\(data)"
            }
        }
        return resultString ?? ""
    }
    
    
    /*
     1. 数据内容与格式
     数据类型：在代码中表现为 NSData 对象。
     结构组成：根据蓝牙标准（GAP 协议），这部分数据的前两个字节必须是 Company Identifier（公司标识符），由蓝牙技术联盟（SIG）分配。
     例如，Apple 设备的标识符通常是 0x004C。
     自定义内容：在公司标识符之后，制造商可以放置任何自定义数据（如传感器数值、设备状态、自定义协议 ID 等）。
     */
    // 使用示例：
    // let data = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
    // print(parseManufacturerData(data))
    // 输出示例: [0x4C00]:0x0215...
    private static func parseManufacturerData(_ data: Data?) -> String {
        // 确保数据至少包含 2 字节的公司标识符
        guard let data = data, data.count >= 2 else { return "Data too short" }
        
        // 提取前两个字节（十六进制字符串）
        let companyIdRange = 0..<2
        let companyIdHex = data.subdata(in: companyIdRange).map { String(format: "%02x", $0) }.joined()
        
        // 提取剩余字节
        let customData = data.subdata(in: 2..<data.count).map { String(format: "%02x", $0) }.joined()
        
        return "[0x\(companyIdHex.uppercased())]:0x\(customData.uppercased())"
    }
    
    private static func formatServiceData(_ service:CBUUID, _ data: Data) -> String{
        let hexData = data.map { String(format: "%02x", $0) }.joined()
        return "·\(service.uuidString):\n0x\(hexData.uppercased())"
    }
}
