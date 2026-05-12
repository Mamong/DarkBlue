//
//  String+DarkBlue.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/20.
//

import Foundation
import CoreBluetooth.CBUUID

/*
 在蓝牙开发中，将 16 位（或 32 位）短 UUID 补全为标准的 128 位 蓝牙基准 UUID (Bluetooth Base UUID) 是非常常见的需求。
 蓝牙基准 UUID 是：0000XXXX-0000-1000-8000-00805F9B34FB。
 1. 实现逻辑
 我们需要判断输入的字符串长度：
 如果是 4 位（如 180D）：插入到基准 UUID 的第 5 到第 8 位。
 如果是 8 位（较少见）：替换基准 UUID 的前 8 位。
 如果是 32 位（带或不带连字符）：直接格式化为 8-4-4-4-12 形式。
*/

extension String {
    /// 将十六进制字符串转换为 Data
    /// 支持格式： "AABB01", "AA BB 01", "0xAA 0xBB"
    var hexToData: Data? {
        // 1. 清理字符串：去除空格、换行符和 0x 前缀
        var cleaned = self.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "0x", with: "")
            .filter { "0123456789abcdef".contains($0) }
        
        // 2. 处理非偶数长度：在前面补 0
        if cleaned.count % 2 != 0 {
            cleaned = "0" + cleaned
        }
        
        // 3. 校验：确保此时不为空
        guard !cleaned.isEmpty else { return nil }
        
        var data = Data()
        var index = cleaned.startIndex
        
        // 3. 步进 2 个字符进行转换
        while index < cleaned.endIndex {
            let nextIndex = cleaned.index(index, offsetBy: 2)
            let byteString = cleaned[index..<nextIndex]
            
            // 将 2 位字符转为 16 进制的 UInt8
            if let byte = UInt8(byteString, radix: 16) {
                data.append(byte)
            } else {
                return nil // 转换失败
            }
            index = nextIndex
        }
        
        return data
    }
    
    var uuidToHex:String{
        let hex = self.replacingOccurrences(of: " ", with: "")
                      .replacingOccurrences(of: "-", with: "")
                      .replacingOccurrences(of: "0x", with: "")
                      .uppercased()
        return hex
    }
}

extension String {
    var displayName: String {
        let uuid = CBUUID(string: self)
        return uuid.displayName
    }
    
    var prefixUUID: String {
        return "0x"+self
    }
}

extension String {
    /// 将 Hex 字符串转换为 8-4-4-4-12 格式的 UUID 字符串
    var toFullUUIDFormat: String {
        // 1. 清理非 Hex 字符
        var hex = self.replacingOccurrences(of: " ", with: "")
                      .replacingOccurrences(of: "-", with: "")
                      .replacingOccurrences(of: "0x", with: "")
                      .uppercased()
        
        // 2. 补齐逻辑：如果是 4 位短 UUID，补全为蓝牙基准格式
        if hex.count == 4 {
            hex = "0000\(hex)00001000800000805F9B34FB"
        }
        //let base = "0000-0000-1000-8000-00805F9B34FB"
        
        // 2. 根据长度补全
        if hex.count == 4 {
            hex = "0000\(hex)00001000800000805F9B34FB"
        } else if hex.count == 8 {
            hex = "\(hex)00001000800000805F9B34FB"
        }
        
        // 3. 校验长度（必须为 32 位才能格式化）
        guard hex.count == 32 else { return "Invalid Hex" }
        
        // 4. 插入横杠 (在索引 8, 13, 18, 23 处插入)
        var result = hex
        result.insert("-", at: result.index(result.startIndex, offsetBy: 20))
        result.insert("-", at: result.index(result.startIndex, offsetBy: 16))
        result.insert("-", at: result.index(result.startIndex, offsetBy: 12))
        result.insert("-", at: result.index(result.startIndex, offsetBy: 8))
        
        return result
    }
}

extension String {
    /// 仅格式化 32 位 Hex 为 UUID 格式（不补齐）
    var hexToUUID: String {
        // 1. 过滤掉空格和现有的横杠
        let hex = self.replacingOccurrences(of: " ", with: "")
                      .replacingOccurrences(of: "-", with: "")
                      .uppercased()
        
        // 2. 必须正好是 32 位才能进行标准 UUID 格式化
        guard hex.count == 32 else {
            return hex// 或者返回原字符串
        }
        
        var result = hex
        // 3. 从后往前插入横杠，避免索引位移干扰
        result.insert("-", at: result.index(result.startIndex, offsetBy: 20))
        result.insert("-", at: result.index(result.startIndex, offsetBy: 16))
        result.insert("-", at: result.index(result.startIndex, offsetBy: 12))
        result.insert("-", at: result.index(result.startIndex, offsetBy: 8))
        
        return result
    }
}

