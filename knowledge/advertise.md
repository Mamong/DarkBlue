在 Core Bluetooth 的开发逻辑中，stopAdvertising() 不需要、也不应该自动移除 Service。
两者在硬件层面的职责是分离的：
## 1. 核心区别

* stopAdvertising()：相当于关掉店门。别人在外面搜不到你了，但店里的货架（Services/GATT Table）依然摆在那里。如果此时有设备已经连接在你的外设上，连接不会断开，它依然可以继续读写你的特征。
* removeAllServices()：相当于撤掉货架。这会彻底清空内存中的 GATT 表。

## 2. 什么时候需要同时调用？
在你的 DarkBlue 项目中，如果你遇到了以下场景，建议先 stop 再 remove：

* 场景 A：修改外设配置
如果你修改了 UUID、特征数量或权限，必须先 stopAdvertising()，然后 removeAllServices()，重新 add(service)，最后再 startAdvertising()。不移除旧 Service 就添加新 Service 会导致系统报错或数据缓存混乱。
* 场景 B：彻底关闭虚拟设备
当用户在 VirtualDevicesListView 中关掉开关时，通常只需要 stopAdvertising() 即可，这样可以保留 GATT 表，方便下次一键开启。

## 3. 最佳实践建议
在你的 VirtualManager 中，建议将这两个动作明确分开：

// 仅仅是停止广播（适合暂时关闭，或保持连接但不再让新设备搜索）func stopOnly() {
    peripheralManager.stopAdvertising()
}
// 彻底重置（适合切换虚拟设备、修改特征属性）func resetHardware() {
    peripheralManager.stopAdvertising()
    peripheralManager.removeAllServices()
    self.registeredServices.removeAll() // 别忘了清理我们之前做的内存缓存
}

## 总结
不需要。 除非你打算改变服务的结构，否则仅仅停止广播是不需要移除服务的。
现在的逻辑中，你是希望在关闭开关时依然保持当前已建立的连接吗？ 如果是，那么千万不要调用 removeAllServices()，否则对方的 App 会因为找不到服务而产生错误。
下一步建议： 我们要不要实现一个 “广播状态监听”？当 isAdvertising 改变时，在 UI 上实时显示一个“正在广播”的呼吸灯动画。需要这个视觉增强吗？



在蓝牙广播中，CBAdvertisementDataServiceUUIDsKey 的设置与否取决于你希望如何被其他设备“发现”。在 DarkBlue 的虚拟设备功能中，强烈建议设置它。
以下是详细的原因和策略：
## 1. 为什么要设置？（可见性与过滤）

* 快速识别：大多数中心设备（如另一台手机）在扫描时会根据 Service UUID 进行过滤。如果你不广播这个 Key，对方只能通过设备名（Local Name）来肉眼寻找。
* 后台发现：如果你希望在 iOS 设备处于后台时仍能发现你的虚拟外设，中心设备必须通过特定的 withServices: [CBUUID] 调用扫描，此时如果你没广播对应的 UUID，你是绝对不会被搜到的。
* DarkBlue 风格：在 DarkBlue 中，扫描列表的每个设备下方通常会显示它包含的主服务 UUID。设置这个 Key 能让你的虚拟设备看起来更真实、更专业。

## 2. 设置时的限制（31字节挑战）
虽然设置它是好事，但要注意它会显著消耗广播包的空间：

* 16位 UUID（4字符）：占用空间极小（2字节+头部）。
* 128位 UUID（32字符）：占用空间极大（16字节+头部）。
* 后果：如果你广播了一个 128位的 UUID，你的 Local Name 往往只能剩下不到 8 个字符。如果超过限制，iOS 就会报你之前遇到的 One or more parameters were invalid 错误。

## 3. 最佳实践建议
在 VirtualManager 的 startAdvertising 中，你可以根据虚拟设备的配置来决定：

var advertisementData: [String: Any] = [
    CBAdvertisementDataLocalNameKey: device.name
]
// 建议：只取第一个服务 UUID 进行广播，以节省空间if let firstService = device.services.first {
    advertisementData[CBAdvertisementDataServiceUUIDsKey] = [CBUUID(string: firstService.uuidString)]
}

peripheralManager.startAdvertising(advertisementData)

## 4. 总结：什么时候可以不设置？

* 如果你只想做一个简单的“蓝牙信标”，仅靠名字识别，可以不设。
* 如果你的虚拟设备没有定义任何服务（空的 GATT 表），则不需要设置。

你的虚拟外设目前是有一个主服务（比如心率或电池）还是多个服务？ 如果是多个，建议只把最核心的一个放入广播包，剩下的服务在连接建立后再让对方去发现。
下一步： 需要我帮你写一个“广播包空间预估”函数吗？它能帮你判断当前的名字长度加上 UUID 是否会超过 31 字节，从而提前在 UI 上给用户警告。

