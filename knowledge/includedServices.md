在蓝牙 GATT 协议（以及 Core Bluetooth 框架）中，includedServices（包含服务）是一种描述 “服务之间层级或依赖关系” 的机制。
你可以把它理解为：一个服务（Service）引用了另一个现有的服务作为其功能的一部分。
以下是其核心特性和应用场景：
## 1. 核心定义

* 服务复用：如果一个复杂的服务（父服务）需要使用另一个简单服务（子服务）的功能，它可以直接将其“包含”进来，而不需要在自己的服务定义里重复创建那些特征（Characteristics）。
* 层级关系：被包含的服务通常是预先定义好的独立服务。例如，一个“跑步机服务”可能会包含一个“心率服务”。

## 2. 开发中的实际行为
在 iOS 开发中，当你发现一个外设的 CBService 时，你可以通过以下方式探索它的包含关系：

// 1. 发现服务后，探索它的包含服务
peripheral.discoverIncludedServices([includedServiceUUID], for: service)
// 2. 在代理方法中获取func peripheral(_ peripheral: CBPeripheral, didDiscoverIncludedServicesFor service: CBService, error: Error?) {
    if let includedServices = service.includedServices {
        for s in includedServices {
            print("该服务包含子服务: \(s.uuid)")
        }
    }
}

## 3. 常见应用场景

* 组合功能：一些复杂的医疗设备或运动器材会将“电池服务 (Battery Service)”包含在主功能服务中。
* 逻辑分组：帮助开发者理解哪些服务是协同工作的。

## 4. 在你的虚拟外设（Virtual Peripheral）中
虽然 CBMutableService 允许设置 includedServices，但在实际的模拟测试中：

* 较少用到：大多数自定义协议直接将所有特征放在同一个 Service 下，简单明了。
* 兼容性注意：如果你正在模仿一个非常复杂的工业设备，它可能使用了这种结构。如果你的虚拟外设没有正确设置包含关系，某些特定的 Central App 可能会因为找不到预期的层级结构而无法工作。

## 总结
includedServices 就是 “服务里的服务”。
既然你的架构已经支持了 Service 和 Characteristic，我们需要在 VirtualPeripheralDetailView 中显示这种“包含关系”吗？ 绝大多数情况下，保持平铺的服务列表（即你目前的做法）就已经能覆盖 99% 的调试需求了。
下一步： 我们需要实现 “长按 Service 复制其完整的解析 JSON” 吗？这样你可以快速把配置好的服务结构发给同事。[1]


