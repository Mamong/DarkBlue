//
//  Data+DarkBlue.swift
//  SwiftUIDarkBlue
//
//  Created by tryao on 3/13/25.
//

import CoreBluetooth

enum ByteLimit: String, CaseIterable, Identifiable {
    case none = "None"
    case one = "1"
    case two = "2"
    case four = "4"
    case eight = "8"
    
    var id: String { self.rawValue }
    
    // 获取对应的字节数
    var count: Int? {
        switch self {
        case .none: return nil
        default: return Int(self.rawValue)
        }
    }
}

enum Endianness: String, CaseIterable, Identifiable {
    case big = "Big"
    case little = "Little"
    
    var id: String { self.rawValue }
}

// 将此枚举定义放在你的代码库中
enum DataFormat: String, CaseIterable, Identifiable {
    case utf8 = "UTF-8 String"
    case binary = "Binary"
    case hex = "Hex"
    case octal = "Octal"
    
    case uInt = "Unsigned Integer"
    case sInt = "Signed Integer"
    
    case float = "Float"
    
    case double = "Double"
    
    // 1 bit unsigned/signed
    // 2 bit unsigned/signed
    // 4 bit unsigned/signed Float
    // 8 bit unsigned/signed Double
    
    var id: String { self.rawValue }
    
    static func allCases(for byteLimit:ByteLimit)->[DataFormat]{
        var cases:[DataFormat] = [.utf8,.binary,.hex,.octal]
        if let count = byteLimit.count {
            cases.append(contentsOf: [.uInt, .sInt])
            if count == 4{
                cases.append(.float)
            }else if count == 8{
                cases.append(.double)
            }
        }
        return cases
    }
}


extension Data {
    func formattedDataString(as format: DataFormat) -> String {
        guard !self.isEmpty else { return "Empty Value" }
        return formattedString(as: format, endian: .little, limit: .none) ?? ""
    }
    
    func formattedString(as format: DataFormat, endian: Endianness, limit: ByteLimit) -> String? {
        guard !self.isEmpty else { return "No Value" }
        
        let byteCount = limit.count
        
        switch format {
        case .hex:
            return self.toStreamingHexString()
        case .octal:
            return self.toStreamingOctalString()
        case .utf8:
            return String(data: self, encoding: .utf8)
        case .binary:
            return self.toBinaryStream()
        case .float:
            return self.toFloatString(endian: endian)
        case .double:
            return self.toDoubleString(endian: endian)
        case .uInt:
            if let byteCount {
                let limitedData = self.paddedPrefix(byteCount)
                if byteCount == 8 {
                    return "\(limitedData.toUInt64(endian: endian)!)"
                } else if byteCount == 4 {
                    return "\(limitedData.toUInt32(endian: endian)!)"
                } else if byteCount == 2 {
                    return "\(limitedData.toUInt16(endian: endian)!)"
                } else {
                    return "\(limitedData.toUInt8()!)"
                }
            }
        case .sInt:
            if let byteCount {
                let limitedData = self.paddedPrefix(byteCount)
                if byteCount == 8 {
                    return "\(limitedData.toInt64(endian: endian)!)"
                } else if byteCount == 4 {
                    return "\(limitedData.toInt32(endian: endian)!)"
                } else if byteCount == 2 {
                    return "\(limitedData.toInt16(endian: endian)!)"
                } else {
                    return "\(limitedData.toInt8()!)"
                }
            }
        }
        return nil
    }
}

extension Data {
    /// 获取前 n 字节，不足则在末尾补 0
    func paddedPrefix(_ n: Int?) -> Data {
        if let n {
            if self.count >= n {
                // 如果长度足够或超出，直接截取
                return self.prefix(n)
            } else {
                // 如果长度不足，先取全部，再补齐剩余的 0
                var paddedData = Data(count: n - self.count)
                paddedData.append(self)
                return paddedData
            }
        } else {
            return self
        }
    }
}

extension Data {
    func toStreamingOctalString() -> String? {
        guard !self.isEmpty else { return "0o0" }
        //lightblue限制4字节
        guard self.count <= 4 else { return nil}
        
        var result = ""
        var buffer: UInt16 = 0 // 缓冲区，用于暂存跨字节的位
        var bitsInBuffer = 0   // 当前缓冲区里有多少位
        // 从低地址字节（低位）开始处理
        for byte in self {
            // 将字节放入缓冲区的高位
            buffer |= (UInt16(byte) << bitsInBuffer)
            bitsInBuffer += 8
            
            // 每次提取 3 位
            while bitsInBuffer >= 3 {
                let digit = buffer & 0x07 // 提取最低处的 3 位
                result += String(digit)
                
                bitsInBuffer -= 3
                buffer >>= 3
            }
        }
        
        // 高位补齐：处理最后不足 3 位的比特
        if bitsInBuffer > 0 {
            // 直接读取剩余位即可（高位已经是0了）
            let digit = buffer & 0x07
            result += String(digit)
        }
        
        return "0o" + result.reversed()
    }
}

extension Data {
    var dataToHex: String {
        guard !self.isEmpty else { return "" }
        let hexBody = self.map { String(format: "%02X", $0) }.joined(separator: "")
        return hexBody
    }
    
    /// 转换为每4字节一个空格，超过32字节显示省略号的格式
    var hexSummary: String {
        // 1. 处理空数据
        if self.isEmpty { return "" }
        
        // 2. 限制处理长度，最多取前33字节（多取1位用于判断是否需要省略号）
        let limit = 32
        let displayData = self.prefix(limit)
        
        // 3. 将字节转为 16 进制字符串数组
        let hexArray = displayData.map { String(format: "%02X", $0) }
        
        // 4. 每 4 字节插入一个空格进行拼接
        var result = ""
        for (index, hex) in hexArray.enumerated() {
            if index > 0 && index % 4 == 0 {
                result += " "
            }
            result += hex
        }
        
        // 5. 如果原始数据超过 32 字节，在末尾添加省略号
        if self.count > limit {
            result += "..."
        }
        
        return result
    }

    
    func toStreamingHexString() -> String {
        guard !self.isEmpty else { return "0x00" }
        let hexBody = self.map { String(format: "%02X", $0) }.joined(separator: "")
        return "0x" + hexBody
    }
    
    func toBitwiseHexString() -> String {
        var result = "0x"
        for byte in self {
            // 提取高 4 位 (0-15)
            let highNibble = (byte >> 4) & 0x0F
            // 提取低 4 位 (0-15)
            let lowNibble = byte & 0x0F
            
            result += String(highNibble, radix: 16).uppercased()
            result += String(lowNibble, radix: 16).uppercased()
        }
        return result.trimmingCharacters(in: .whitespaces)
    }
}

extension Data {
    func toBinaryStream() -> String {
        var result = "0b"
        for byte in self {
            for i in (0...7).reversed() {
                result += ((byte >> i) & 1) == 1 ? "1" : "0"
            }
        }
        return result
    }
    
    func toBinaryString() -> String {
        guard !self.isEmpty else { return "0b0" }
        
        // 1. 将每个字节转为二进制字符串，并使用 0 补齐 8 位
        let binaryBody = self.map { byte in
            String(byte, radix: 2).padding(toLength: 8, withPad: "0", startingAt: 0)
            //            return String(repeating: "0", count: 8 - s.count) + s
        }.joined(separator: "") // 字节间加空格方便阅读
        
        // 2. 开头加 0b 前缀
        return "0b" + binaryBody
    }
}

extension Data {
    // 转为 UInt8 (0 到 255)
    func toUInt8() -> UInt8? {
        return self.first // Data 实际上是一个字节集合，first 拿到的就是第一个 UInt8
    }
    
    // 转为 Int8 (-128 到 127)
    func toInt8() -> Int8? {
        guard let byte = self.first else { return nil }
        // 使用位模式转换（bitPattern），确保原始二进制位不变
        return Int8(bitPattern: byte)
    }
}

extension Data {
    // 转换为 UInt16
    func toUInt16(endian: Endianness) -> UInt16? {
        guard self.count == 2 else { return nil }
        
        // 1. 从 Data 中提取两个字节并转为原始 UInt16
        // withUnsafeBytes 是处理此类转换最高效且安全的方法
        let value = self.withUnsafeBytes { $0.load(as: UInt16.self) }
        
        // 2. 根据用户选择的端序进行转换
        // Swift 内置了对大端 (bigEndian) 和小端 (littleEndian) 的原生支持
        return (endian == .big) ? UInt16(bigEndian: value) : UInt16(littleEndian: value)
    }
    
    // 转换为 Int16
    func toInt16(endian: Endianness) -> Int16? {
        guard self.count == 2 else { return nil }
        
        let value = self.withUnsafeBytes { $0.load(as: Int16.self) }
        
        return (endian == .big) ? Int16(bigEndian: value) : Int16(littleEndian: value)
    }
}

extension Data {
    // 转换为 UInt32
    func toUInt32(endian: Endianness) -> UInt32? {
        // 确保至少有 4 字节数据
        guard self.count == 4 else { return nil }
        
        // 从内存加载 4 字节并映射为 UInt32
        let value = self.withUnsafeBytes { $0.load(as: UInt32.self) }
        
        // 根据端序进行转换
        return (endian == .big) ? UInt32(bigEndian: value) : UInt32(littleEndian: value)
    }
    
    // 转换为 Int32
    func toInt32(endian: Endianness) -> Int32? {
        guard self.count == 4 else { return nil }
        
        let value = self.withUnsafeBytes { $0.load(as: Int32.self) }
        
        return (endian == .big) ? Int32(bigEndian: value) : Int32(littleEndian: value)
    }
    
    // 更稳健的读取方式（防止对齐错误）
    func toUInt32Safe(endian: Endianness) -> UInt32? {
        guard self.count == 4 else { return nil }
        // 将 Data 前 4 字节转为固定长度数组
        let bytes = [UInt8](self.prefix(4))
        
        let value: UInt32
        if endian == .big {
            value = UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
        } else {
            value = UInt32(bytes[3]) << 24 | UInt32(bytes[2]) << 16 | UInt32(bytes[1]) << 8 | UInt32(bytes[0])
        }
        return value
    }
}

extension Data {
    func toFloatString2(endian: Endianness) -> String? {
        // 1. 检查长度，Float 必须是 4 字节
        guard self.count >= 4 else { return nil }
        
        // 2. 将前 4 字节读取为 UInt32 以便处理端序
        let bitPattern = self.withUnsafeBytes { $0.load(as: UInt32.self) }
        
        // 3. 根据选择的端序调整字节顺序
        let adjustedPattern = (endian == .big) ? UInt32(bigEndian: bitPattern) : UInt32(littleEndian: bitPattern)
        
        // 4. 将调整后的位模式解析为 Float
        let floatValue = Float(bitPattern: adjustedPattern)
        
        // 5. 转换为字符串
        // 如果数值是无穷大或非数字（NaN），返回提示
        if floatValue.isNaN { return "NaN" }
        if floatValue.isInfinite { return "Infinite" }
        
        // 按照 DarkBlue 的习惯，通常保留 8 位有效数字或直接转为字符串
        return String(format: "%.8g", floatValue)
    }
    
    //light blue大端序下会截取最后4字节
    func toFloatString(endian: Endianness) -> String? {
        // 1. 检查长度，Float 必须是 4 字节
        guard self.count >= 4 else { return nil }
        
        // 2. 将前 4 字节读取为 UInt32 以便处理端序
        let bitPattern = self.withUnsafeBytes {
            $0.load(fromByteOffset: (endian == .big) ? self.count-4:0 ,as: UInt32.self) }

        // 3. 根据选择的端序调整字节顺序
        let adjustedPattern = (endian == .big) ? UInt32(bigEndian: bitPattern) : UInt32(littleEndian: bitPattern)
        
        // 4. 将调整后的位模式解析为 Float
        let floatValue = Float(bitPattern: adjustedPattern)
        
        // 5. 转换为字符串
        // 如果数值是无穷大或非数字（NaN），返回提示
        if floatValue.isNaN { return "NaN" }
        if floatValue.isInfinite { return "Infinite" }
        
        // 按照 DarkBlue 的习惯，通常保留 8 位有效数字或直接转为字符串
        return String(format: "%.8g", floatValue)
    }
}

extension Data {
    // 转换为 UInt64 字符串
    func toUInt64(endian: Endianness) -> UInt64? {
        guard self.count == 8 else { return nil }
        let bitPattern = self.withUnsafeBytes { $0.load(as: UInt64.self) }
        return (endian == .big) ? UInt64(bigEndian: bitPattern) : UInt64(littleEndian: bitPattern)
    }
    
    // 转换为 Int64 字符串
    func toInt64(endian: Endianness) -> Int64? {
        guard self.count == 8 else { return nil }
        let bitPattern = self.withUnsafeBytes { $0.load(as: Int64.self) }
        return (endian == .big) ? Int64(bigEndian: bitPattern) : Int64(littleEndian: bitPattern)
    }
    
    // 转换为 Double 字符串
    func toDoubleString2(endian: Endianness) -> String? {
        guard self.count >= 8 else { return nil }
        // 1. 先按 64 位整数加载位模式以处理端序
        let bitPattern = self.withUnsafeBytes { $0.load(as: UInt64.self) }
        // 2. 调整端序
        let adjustedPattern = (endian == .big) ? UInt64(bigEndian: bitPattern) : UInt64(littleEndian: bitPattern)
        // 3. 将位模式解析为 Double
        let doubleValue = Double(bitPattern: adjustedPattern)
        
        // 4. 处理特殊浮点状态
        if doubleValue.isNaN { return "NaN" }
        if doubleValue.isInfinite { return "Infinite" }
        
        // 使用 %g 自动选择最优显示格式（科学计数法或普通小数）
        return String(format: "%.17g", doubleValue)
    }
    
    //light blue大端序下会截取最后8字节
    func toDoubleString(endian: Endianness) -> String? {
        guard self.count >= 8 else { return nil }
        // 1. 先按 64 位整数加载位模式以处理端序
        let bitPattern = self.withUnsafeBytes {
            $0.load(fromByteOffset: (endian == .big) ? self.count-8:0 ,as: UInt64.self) }
        // 2. 调整端序
        let adjustedPattern = (endian == .big) ? UInt64(bigEndian: bitPattern) : UInt64(littleEndian: bitPattern)
        // 3. 将位模式解析为 Double
        let doubleValue = Double(bitPattern: adjustedPattern)
        
        // 4. 处理特殊浮点状态
        if doubleValue.isNaN { return "NaN" }
        if doubleValue.isInfinite { return "Infinite" }
        
        // 使用 %g 自动选择最优显示格式（科学计数法或普通小数）
        return String(format: "%.17g", doubleValue)
    }
}

