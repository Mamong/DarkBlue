
https://stackoverflow.com/questions/19280429/reading-long-characteristic-values-using-corebluetooth


[Maximum data size when sending data via BTLE on iOS](https://stackoverflow.com/questions/24349945/maximum-data-size-when-sending-data-via-btle-on-ios/36176043)
The BLE standard requires 23 bytes as the minimum ATT_MTU (Attribute Protocol Maximum Transmission Unit) which all BLE devices must support. The maximum ATT_MTU is 255 bytes, however, and has been doubled again for BLE 4.2.

[BLUETOOTH SPECIFICATION](https://www.bluetooth.com/specifications/adopted-specifications) Version 4.2 [Vol 3, Part A]:

All L2CAP implementations shall support a minimum MTU of […] 23 octets over the LE-U logical link; however, some protocols and profiles explicitly require support for a larger MTU.

When establishing a connection, both devices will exchange their ATT_MTU size, and the smaller of both values is used. When Apple started with BLE, they would only support the minimum, but have since expanded the possible size. That is why your 124 bytes work, but the older documentation and sample code uses a much smaller ATT_MTU.


[CoreBluetooth 101 — your ultimate walkthrough](https://sidorov.tech/en/all/corebluetooth-101-ultimate-walkthrough/)
