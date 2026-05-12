# CBATTRequest

在 Core Bluetooth 框架中，CBATTRequest 是开发虚拟外设（Peripheral Mode）时最核心的类之一。它代表了中心设备（Central）向你的虚拟外设发出的 ATT（属性协议）读或写请求。
简单来说，当别人想读你的数据或写数据给你时，系统会把这个“意图”包装成一个 CBATTRequest 对象。
## 1. 核心属性
了解这个对象，主要看这四个关键字段：

| 属性 | 类型 | 描述 |
|---|---|---|
| central | CBCentral | 发起请求的远程设备（是谁在读写我？）。 |
| characteristic | CBCharacteristic | 目标特征值（它想操作我的哪个特征？）。 |
| offset | Int | 数据偏移量。如果数据很长，中心设备会分多次读取。 |
| value | Data? | 最重要：如果是写请求，这里是对方发来的数据；如果是读请求，你需要把数据填进去。 |

------------------------------
## 2. 交互流程：读与写## A. 处理读取请求 (Read)
当中心设备尝试读取你的某个特征值时，系统触发 didReceiveRead 回调。

   1. 检查偏移量：确保请求的 offset 没有超过你的数据长度。
   2. 填充数据：将你的数据切片后赋值给 request.value。
   3. 回应请求：调用 respond(to:withResult:)。

func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
    let fullData = "Hello".data(using: .utf8)!
    
    // 检查偏移量，防止越界
    if request.offset > fullData.count {
        peripheral.respond(to: request, withResult: .invalidOffset)
        return
    }
    
    // 截取数据并填充给 request
    request.value = fullData.subdata(in: request.offset..<fullData.count)
    
    // 必须回复成功！
    peripheral.respond(to: request, withResult: .success)
}

## B. 处理写入请求 (Write)
当对方发送数据过来时，触发 didReceiveWrite。

   1. 获取数据：从 request.value 中提取原始数据。
   2. 应用逻辑：更新你本地的状态。
   3. 回应请求：即便只是为了确认，也必须调用 respond。

------------------------------
## 3. 为什么它很重要？

* 超时控制：CBATTRequest 是一次“会话”。如果你不通过 respond 结束它，中心设备会卡住（显示连接中或读取中），直到触发 ATT Timeout（通常是 30 秒）导致断开连接。
* 权限拦截：你可以通过查看 request.central 来实现黑名单功能。如果不允许特定设备访问，可以直接回复 .writeNotPermitted 或 .insufficientAuthentication。

## 4. 易错点

* 不要在 updateValue 时查找它：当你主动推送通知（Notify）时，不需要用到 CBATTRequest，那是单向推送。CBATTRequest 只用于“一问一答”的交互。
* 分片读取：初学者常忽略 offset。如果你返回的数据超过 20 字节（MTU 限制），中心设备可能会发起多次 offset 不为 0 的请求。

在你的 VirtualManager 中，你是否遇到了点击读取却没有数据返回的情况？ 这通常是因为 request.value 赋值后忘了调用 respond。
下一步建议：我们可以给 VirtualManager 增加一个 “请求日志（Request Logger）”，在 Mac 界面上实时显示每一个 CBATTRequest 的来源和内容，非常方便调试。需要这个日志功能吗？ [1] [2] [3]




在 Core Bluetooth 框架中，当中央设备（Central）向外围设备（Peripheral）发起读取特征值（Characteristic Value）的请求时，会触发 `peripheralManager(_:didReceiveRead:)` 回调。该回调携带一个 `CBATTRequest` 对象，其中包含 `offset` 属性，用于支持 分块读取（Read Blob Request）。

---

`offset` 的作用

- `offset` 表示从特征值的第几个字节开始读取数据。
- 它允许中央设备分多次读取一个较长的特征值，每次指定起始偏移量。
- 例如：若特征值长度为 500 字节，中央设备可先请求 `offset=0` 读前 20 字节，再请求 `offset=20` 读接下来 20 字节，依此类推。

---

如何处理 `offset`

在实现 `peripheralManager(_:didReceiveRead:)` 时，应检查 `request.offset` 是否超出特征值的有效范围：

```swift
func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
    guard let characteristic = request.characteristic else { return }
    
    // 检查偏移量是否越界
    if request.offset >= characteristic.value?.count ?? 0 {
        peripheral.respond(to: request, withResult: .invalidOffset)
        return
    }
    
    // 截取从 offset 开始的数据
    let data = characteristic.value ?? Data()
    let range = Range(uncheckedBounds: (request.offset, data.count))
    request.value = data.subdata(in: range)
    
    // 响应成功
    peripheral.respond(to: request, withResult: .success)
}
```

> ⚠️ 注意：必须对每个收到的读请求调用一次 `respond(to:withResult:)`，否则连接可能超时或异常 。

---

关键点总结

- `offset` 是 `CBATTRequest` 的属性，表示读取起始位置。
- 必须验证 `offset` 不超过特征值长度，否则返回 `.invalidOffset`。
- 响应时可返回从 `offset` 到末尾的全部数据，或按需截取指定长度。
- 该机制适用于大体积数据（如固件、日志等）的分块传输。

如需进一步了解 `CBATTRequest` 或 BLE 特征读写机制，可参考 [Apple 官方文档](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanagerdelegate/peripheralmanager(_:didreceiveread:)) 。


# 写入
在处理蓝牙写入请求时，情况比读取请求稍微复杂一些，结论是：取决于写入的类型（Write Type）。
## 1. Write Without Response (不需要回复的写入)
不需要处理分片。
在这种模式下，数据传输受 MTU（最大传输单元） 的限制。如果中心设备（Central）发送的数据超过了 MTU（通常 iOS 之间约为 185~233 字节），系统会自动丢弃超出的部分，或者在发送端就报错。你收到的 request.value 就是那一包能传过来的最大数据量。
## 2. Write With Response (需要回复的写入)
通常不需要，但取决于客户端是否使用了 "Prepared Write"。

* 普通写入：绝大多数 App（包括 LightBlue）在写入时，如果数据超过 MTU，系统会直接分包发送多次独立的 didReceiveWrite 请求。每一包的 offset 通常都是 0。你只需要像处理普通数据一样 respond(to: request, withResult: .success) 即可。
* 长数据写入 (Long Write / Prepared Write)：
如果中心设备明确发起了一个“长数据写入”过程，你会发现 CBATTRequest 的 offset 属性不为 0。
* 这时你需要手动处理分片拼接：将每一包 request.value 根据其 offset 拼接在一起，直到收到最后一包。

## 3. 为什么在 VirtualManager 开发中很少处理分片？
对于 99% 的自定义蓝牙协议，开发者会遵循以下潜规则，从而避开分片逻辑：

   1. 限制包大小：确保单次发送的数据小于 MTU。
   2. 应用层分包：如果数据真的很长（比如固件升级），通常在 App 层面把数据切成 20 字节一包，分多次调用 writeValue，每一包对硬件来说都是一个独立的 offset: 0 的请求。

## 4. 必须注意的代码细节
即使你不处理拼接逻辑，你也应该在代码中加入 offset 校验，以防万一：

func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
    for request in requests {
        // 健壮性检查：如果对方发起的 offset 异常，直接拒绝
        if request.offset > 0 {
            peripheral.respond(to: request, withResult: .invalidOffset)
            continue
        }
        
        if let data = request.value {
            // 处理你的业务逻辑...
            print("收到数据: \(data.hexString)")
            
            // 必须回应
            peripheral.respond(to: request, withResult: .success)
        }
    }
}

## 总结

* 如果你只是做普通的蓝牙指令交互（几个字节到几十个字节），不需要处理分片。
* 如果你发现 request.offset 出现了大于 0 的情况，说明对方正在尝试发送一个跨包的长数据，这时你才需要建立一个临时缓冲区来拼接 value。

你在调试过程中遇到了数据被截断（只有前 20 字节）的情况吗？ 这通常是 MTU 限制导致的，而不是因为没处理分片。
下一步建议：我们可以实现一个 “自动 MTU 探测” 的显示，让你的 Mac App 能看到当前连接的协商 MTU 是多少，这样你就知道单包发送多少数据最安全。需要这个功能吗？[1][2][3][4]


# peripheralManager(_:didReceiveWrite:)参数为什么是个数组？

这是一个非常核心的设计细节。在蓝牙 GATT 协议中，didReceiveWrite 参数被设计为 [CBATTRequest] 数组，主要是为了处理 “原子性写入”（Atomic Writes） 场景。
简单来说，有以下两个原因：
## 1. 原子性操作 (Prepared Writes)
这是最重要的原因。当中心设备（Central）发起一个“准备写入（Prepared Write）”序列时，它可能会一次性发送多个写请求，要求外设将这些请求作为一个整体单元来处理。

* 场景：比如你需要同时修改两个相互关联的特征值，或者写入一个超长的配置字符串。
* 系统行为：iOS 会将这一系列相关的写操作打包进一个数组传递给你。系统希望你：要么全部接受并回复成功，要么全部拒绝。 这保证了数据的连贯性，不会出现“只改了一半”的情况。

## 2. 性能优化（批量处理）
在极短的时间内，如果有多个写请求到达，Core Bluetooth 底层会将它们合并到一个回调周期内。

* 通过数组一次性处理，可以减少主线程与蓝牙子系统之间的上下文切换次数，提高高频写入时的响应效率。

------------------------------
## 开发中如何正确处理这个数组？
虽然 99% 的普通蓝牙交互（如 LightBlue 手动写入）数组里只有 一个 request，但作为健壮的代码，你必须使用循环：

func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
    // 1. 遍历数组处理每一个请求
    for request in requests {
        let data = request.value ?? Data()
        let offset = request.offset
        
        // 拼接或处理逻辑...
        print("处理来自 \(request.central.identifier) 的请求，数据长度: \(data.count)")
    }
    
    // 2. 统一回应（通常针对数组中的第一个请求进行 respond 即可代表整个批次）
    if let firstRequest = requests.first {
        peripheral.respond(to: firstRequest, withResult: .success)
    }
}

## 避坑指南

* 不要只取 .first：虽然常见，但如果真的遇到了多请求数组，忽略掉后面的请求会导致数据丢失。
* 统一结果：如果数组中有一个请求不合法（比如 Offset 越界），你应该对整个批次返回错误码，而不是部分成功。

你目前的 VirtualManager 是直接在处理第一个请求吗？ 建议改成 for...in 循环，这样以后处理长数据或复杂协议时就不会出 Bug。
下一步建议：我们可以给 VirtualManager 实现一个 “十六进制监控器”，将数组中收到的所有请求数据拼接后实时打印在 Mac 屏幕上。需要这个可视化调试的代码吗？


# [CBATTRequest]是否会包括多个characteristic？

简单直接的回答是：不会。
在一个 didReceiveWrite 回调中，requests 数组里的所有 CBATTRequest 对象 必然是指向同一个 Characteristic 的。
以下是更深入的解释和原因：
## 1. 为什么是数组而不是单个对象？
虽然数组中的请求都属于同一个特征，但 Core Bluetooth 将其设计为数组是为了支持 “执行写入序列” (Execute Write Sequence)：

* 长数据分片：当 Central 发送的数据超过 MTU 时，它会将数据拆分成多个分段。
* 原子性操作：这些分段会作为一组请求（Prepared Writes）同时到达，确保这一组数据要么全部处理成功，要么全部失败。

## 2. 官方文档的约束
根据苹果的官方逻辑，系统会将针对同一个特征的一组操作打包。如果 Central 尝试同时写入两个不同的特征，Core Bluetooth 会触发 两次 独立的 didReceiveWrite 调用，而不是把它们混在一个数组里。
## 3. 安全的处理习惯
虽然协议保证了特征的单一性，但在编写代码时，通常建议以第一个请求为准来判断业务逻辑：

guard let firstRequest = requests.first else { return }
// 所有的 request.characteristic 其实都是一样的let targetUUID = firstRequest.characteristic.uuid 
if targetUUID == myConfigUUID {
    // 处理配置信息的逻辑
}

## 总结
你不需要担心在循环处理 requests 时会突然跳到另一个特征的 UUID 上。这个数组的深度是为了解决 “一条长数据被拆成几块” 的问题，而不是“一次性写入多个不同功能点”的问题。
你是否遇到了需要同时更新多个特征值的业务场景？这种情况通常需要 Central 分开调用写入方法。



# 对于CBCharacteristicWriteType，如何理解“When you write with a response, you can write a characteristic value that’s longer than permitted when you write without a response.”

在 Core Bluetooth 中，理解 CBCharacteristicWriteType.withResponse（带响应写入）比 withoutResponse 支持更长数据的关键在于 “长特征值写过程”（Write Long Characteristic Values） 这一蓝牙底层机制。 [1] 
## 1. 核心机制：自动拆分与排队

* Write Without Response (.withoutResponse)：这种方式受限于设备的 MTU（最大传输单元）。如果数据超过了 MTU 减去协议开销（通常为 MTU - 3 字节），多余的数据会被丢弃或导致错误。它是一种“发后即忘”的机制，没有底层反馈来处理超长数据的分片重组。
* Write With Response (.withResponse)：当使用此类型发送长数据时，iOS 的 Core Bluetooth 框架会自动执行蓝牙协议栈中的 Prepare Write 和 Execute Write 序列。
* 自动分段：系统会将长数据拆分成多个较小的包（Chunks）。
   * 确认机制：每一段发送后，外设都会返回确认信息。只有在收到确认后，系统才会发送下一段。
   * 事务处理：所有分段传输完成后，系统发送一个“执行”指令，外设一次性将这些暂存的数据应用到特征值上。 [2, 3, 4, 5, 6, 7, 8] 

## 2. 写入限制的具体差异
根据 [Apple 开发者文档](https://developer.apple.com/documentation/corebluetooth/cbcharacteristicproperties/write) 和社区测试结果：

* 长度上限：在带响应写入的情况下，通常可以写入高达 512 字节 的数据（这是蓝牙标准定义的特征值最大长度），而无需手动分包。
* MTU 影响：不带响应的写入长度严格受当前连接协商的 MTU 限制（通常在 20 到 200+ 字节之间）；而带响应写入可以透明地跨越 MTU 限制，由系统处理分段。 [3, 7, 9, 10] 

## 3. 性能与可靠性的权衡

| 特性 [3, 4, 6, 7, 11, 12, 13] | .withResponse (Write Request) | .withoutResponse (Write Command) |
|---|---|---|
| 最大长度 | 最高可达 512 字节（系统自动处理） | 严格受当前 MTU 限制（需手动分包） |
| 可靠性 | 高。有协议级确认，确保数据完整到达 | 较低。可能因缓冲区溢出而丢包 |
| 速度 | 较慢。每个包都需要往返确认 | 快。适合高频率、实时性要求高的数据 |

开发建议：
如果你需要发送超过 MTU 长度的数据（例如固件升级或配置信息）且不希望手动编写复杂的拆分逻辑，应优先使用 .withResponse。你可以通过调用 peripheral.maximumWriteValueLength(for:) 方法来动态获取当前环境下两种模式各自支持的最大字节数。 [6, 14, 15] 
你想了解如何获取当前设备的具体 MTU 限制，还是想看看手动分包发送的代码示例？

[1] [https://stackoverflow.com](https://stackoverflow.com/questions/65586100/rate-limiting-a-corebluetooth-write-without-response)
[2] [https://e2e.ti.com](https://e2e.ti.com/support/wireless-connectivity/bluetooth-group/bluetooth/f/bluetooth-forum/640836/cc2540-writing-to-large-characteristic-on-cc2540)
[3] [https://stackoverflow.com](https://stackoverflow.com/questions/63568637/why-is-the-mtu-different-for-with-response-vs-without-response)
[4] [https://github.com](https://github.com/deviceplug/btleplug/issues/111)
[5] [https://github.com](https://github.com/hbldh/bleak/discussions/1589)
[6] [https://punchthrough.com](https://punchthrough.com/ble-write-requests-vs-write-commands/)
[7] [https://stackoverflow.com](https://stackoverflow.com/questions/34728227/corebluetooth-cbcharacteristicwritewithoutresponse-do-requests-return-instantly)
[8] [https://community.renesas.com](https://community.renesas.com/wireles-connectivity/f/bluetooth-low-energy/23790/writing-to-a-variable-length-characteristic)
[9] [https://stackoverflow.com](https://stackoverflow.com/questions/20852558/corebluetooth-characteristic-value)
[10] [https://github.com](https://github.com/don/cordova-plugin-ble-central/issues/55)
[11] [https://stackoverflow.com](https://stackoverflow.com/questions/41289783/what-does-peripheral-maximumwritevaluelengthfortypecbcharacteristicwritewithre)
[12] [https://github.com](https://github.com/capacitor-community/bluetooth-le/discussions/751)
[13] [https://zenn.dev](https://zenn.dev/shu223/articles/corebluetooth_opt)
[14] [https://developer.apple.com](https://developer.apple.com/documentation/corebluetooth/cbperipheral/maximumwritevaluelength%28for:%29)
[15] [https://developer.apple.com](https://developer.apple.com/documentation/corebluetooth/cbperipheral/maximumwritevaluelength%28for:%29?language=objc)




# peripheralManager(_:didReceiveWrite:)

在 peripheralManager(_:didReceiveWrite:) 方法中，requests 数组中可能会存在多个针对不同特征（Characteristics）的写入请求。 [1, 2, 3] 
虽然在大多数普通场景下，数组中通常只有一个请求，但理解其设计逻辑对处理复杂蓝牙通信非常重要：
## 1. 数组中出现多个请求的常见场景

* 长特征值写入 (Long Write)：当 Central 端发送的数据量超过 MTU 时，系统会将其自动拆分为多个 CBATTRequest。此时，数组中包含的是同一个特征的多个分片，通过 offset 属性来标识数据位置。
* 原子化可靠写入 (Reliable Write)：如果 Central 端使用了蓝牙协议中的“可靠写入”事务（Prepare Write + Execute Write），它可以一次性对多个不同的特征发起写入操作。在这种情况下，requests 数组中会包含指向不同 CBCharacteristic 的请求对象。 [1, 4, 5, 6, 7, 8, 9] 

## 2. 关键处理原则
根据 [Apple 官方文档](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanagerdelegate/peripheralmanager%28_:didreceivewrite:%29)，你必须遵循以下逻辑处理该数组：

* 原子性处理：如果数组包含多个请求，你应该将其视为一个整体事务。如果其中任何一个请求无法满足（例如格式错误或权限不足），你应该拒绝所有请求，而不是只执行成功的那部分。
* 只回复一次：无论数组中有多少个请求，你只需调用一次 respond(to:withResult:)。
* 回复对象：调用回复方法时，参数应传入 requests 数组中的第一个请求（即 requests[0] 或 requests.first）。 [2, 4, 10, 11] 

## 3. 代码示例参考
当你处理该数组时，通常需要遍历它来解析数据或区分特征：

func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
    for request in requests {
        // 区分不同的特征
        if request.characteristic.uuid == myCharacteristicUUID {
            // 处理写入逻辑，注意使用 request.offset 处理长数据
            let data = request.value
            // ...
        }
    }
    
    // 无论处理了多少个特征，只对第一个 request 进行一次性响应
    peripheral.respond(to: requests[0], withResult: .success)
}

你需要了解如何正确处理长数据中的 offset（偏移量），还是想知道如何在 Central 端发起这种多请求的写入？

[1] [https://developer.apple.com](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanagerdelegate/peripheralmanager%28_:didreceivewrite:%29)
[2] [https://developer.apple.com](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanagerdelegate/peripheralmanager%28_:didreceivewrite:%29)
[3] [https://developer.apple.com](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanagerdelegate/peripheralmanager%28_:didreceivewrite:%29)
[4] [https://stackoverflow.com](https://stackoverflow.com/questions/15143453/what-is-the-correct-way-to-respond-to-peripheralmanagerdidreceivewriterequests)
[5] [https://stackoverflow.com](https://stackoverflow.com/questions/15143453/what-is-the-correct-way-to-respond-to-peripheralmanagerdidreceivewriterequests)
[6] [https://developer.apple.com](https://developer.apple.com/documentation/corebluetooth/cbattrequest?language=objc)
[7] [https://stackoverflow.com](https://stackoverflow.com/questions/15143453/what-is-the-correct-way-to-respond-to-peripheralmanagerdidreceivewriterequests)
[8] [https://stackoverflow.com](https://stackoverflow.com/questions/15143453/what-is-the-correct-way-to-respond-to-peripheralmanagerdidreceivewriterequests)
[9] [https://developer.apple.com](https://developer.apple.com/documentation/corebluetooth/cbattrequest)
[10] [https://developer.apple.com](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanagerdelegate/peripheralmanager%28_:didreceivewrite:%29)
[11] [https://developer.apple.com](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanagerdelegate/peripheralmanager%28_:didreceiveread:%29?language=objc)



在 Core Bluetooth 的外设模式下，peripheralManager(_:didReceiveWrite:) 的 requests 参数之所以被设计为数组，主要是为了支持 原子操作（Atomic Operations）。
虽然在大多数普通的数据写入场景中，该数组只包含一个 CBATTRequest，但在以下特定情况下，它会出现多个请求：
## 1. 可靠写入（Reliable Writes / Queued Writes）
这是出现多个请求最常见的原因。当中心设备（Central）发起“可靠写入”序列时：

* 中心设备会先发送多个“准备写入”请求（Prepare Write Requests）。
* 这些请求会被暂存在外设的队列中，此时它们并不会立即生效。
* 一旦中心设备发送“执行写入”指令（Execute Write Request），系统就会通过该回调将队列中所有的请求一次性传递给你。
* 目的：确保一组数据要么全部写入成功，要么全部取消，保证数据的完整性和一致性。 [1, 2] 

## 2. 写入长数据（Long Writes）
当中心设备尝试向一个特征（Characteristic）写入超过最大传输单元（MTU）限制的数据时：

* 数据会被拆分成多个较小的分段（Chunks）发送。
* 系统可能会将这些分段作为多个连续的 CBATTRequest 放入数组中传递给你的代理方法，以便你按顺序拼接这些数据。 [3, 4] 

## 3. 同时对多个特征进行原子写入
在某些高级用法中，中心设备可以在同一个“可靠写入”事务中包含对不同特征的多个写入操作。 [1] 

* 当你收到回调时，数组中的每个 CBATTRequest 可能指向不同的 CBCharacteristic。
* 你必须确保能够同时处理所有特征的更新，或者在其中任何一个失败时拒绝全部请求。 [5, 6] 

## ⚠️ 开发建议
即使目前你的业务逻辑只涉及单次短数据写入，也应当养成处理数组的习惯：

* 始终检查数组长度：不要假设数组里只有一个对象。
* 遵守“全成或全败”原则：如果数组中有 3 个请求，而第 2 个请求因为 Offset 错误无法处理，你应该直接返回错误响应，并且不执行第 1 个和第 3 个请求的写入操作。
* 只响应一次：无论数组里有多少请求，只需调用一次 [respond(to:withResult:)](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanagerdelegate)，且传入的 request 必须是数组中的第一个（即 requests[0]）。 [4, 5, 7] 

你是否在处理大数据包传输，或者遇到了数据被拆分的情况？

[1] [https://devzone.nordicsemi.com](https://devzone.nordicsemi.com/f/nordic-q-a/6489/ble-long-write/22656)
[2] [https://stackoverflow.com](https://stackoverflow.com/questions/24485536/what-is-reliable-write-in-ble)
[3] [https://issuetracker.google.com](https://issuetracker.google.com/issues/37031096)
[4] [https://zenn.dev](https://zenn.dev/oka_yuuji/articles/d749e0b5045c98)
[5] [https://developer.apple.com](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanagerdelegate/peripheralmanager%28_:didreceivewrite:%29)
[6] [https://developer.apple.com](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanagerdelegate/peripheralmanager%28_:didreceivewrite:%29)
[7] [https://developer.apple.com](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanagerdelegate/peripheralmanager%28_:didreceivewrite:%29)
