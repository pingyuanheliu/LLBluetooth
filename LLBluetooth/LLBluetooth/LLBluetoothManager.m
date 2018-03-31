//
//  LLBluetoothManager.m
//  LLBluetooth
//
//  Created by pro on 2018/1/22.
//  Copyright © 2018年 LL. All rights reserved.
//

#import "LLBluetoothManager.h"

@interface LLBluetoothManager ()<CBCentralManagerDelegate,CBPeripheralDelegate>

@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) CBPeripheral *peripheral;

@property (nonatomic, strong) CBUUID *sUUID;
@property (nonatomic, strong) CBUUID *cUUID1;
@property (nonatomic, strong) CBUUID *cUUID2;

@property (nonatomic, strong) CBCharacteristic *characteristic;

@property (nonatomic, strong) NSMutableArray *deviceArray;

//搜索状态
@property (nonatomic, assign) BOOL isScaning;
//重连状态
@property (nonatomic, assign) BOOL isRetrieve;
//重连设备UUID
@property (nonatomic, strong) NSString *willConnectUUID;

@end

//单例静态对象
static LLBluetoothManager *sInstance = nil;

@implementation LLBluetoothManager

#pragma mark - 单列模式
/**
 单例对象
 */
+ (LLBluetoothManager *)sharedInstance {
    static dispatch_once_t  onceToken;
    dispatch_once(&onceToken, ^{
        sInstance = [[LLBluetoothManager alloc] init];
    });
    return sInstance;
}

#pragma mark - Life Cycle

- (id)init {
    self = [super init];
    if (self) {
        [self customInit];
    }
    return self;
}

#pragma mark - Custom Init
/**
 自定义初始化
 */
- (void)customInit {
    //中央管理
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:queue];
    
    // 初始化 蓝牙 服务UUID
    uint8_t cmd[3];
    cmd[0] = 0x00;
    cmd[1] = 0x01;
    NSData *data1 = [NSData dataWithBytes:cmd length:2];
    _sUUID = [CBUUID UUIDWithData:data1];
    
    // 初始化 蓝牙 特征UUID (Read,Write)
    cmd[1] = 0x01;
    NSData *data2 = [NSData dataWithBytes:cmd length:2];
    _cUUID1 = [CBUUID UUIDWithData:data2];
    // 初始化 蓝牙 特征UUID (Notify)
    cmd[1] = 0x02;
    NSData *data3 = [NSData dataWithBytes:cmd length:2];
    _cUUID2 = [CBUUID UUIDWithData:data3];
    
    //
    _deviceArray = [[NSMutableArray alloc] initWithCapacity:0];
    //
    _isScaning = NO;
    _isRetrieve = NO;
    _willConnectUUID = nil;
}

#pragma mark - 搜索

/**
 开始搜索
 */
- (void)startScan {
    //判断是否在搜索中
    if (!self.isScaning) {
        switch (self.centralManager.state) {
            case CBCentralManagerStatePoweredOn:
            {
                //设置搜索状态
                self.isScaning = YES;
                //更新搜索设备列表
                {
                    [self.deviceArray removeAllObjects];
                    //
                    id delegate = self.delegate;
                    if (delegate && [delegate respondsToSelector:@selector(didDiscoverPeripheral:)]) {
                        [delegate didDiscoverPeripheral:self.deviceArray];
                    }
                }
                //是否重连
                if (self.isRetrieve) {
                    BOOL isHave = NO;
                    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:self.willConnectUUID];
                    if (uuid != nil) {
                        NSArray *array = [self.centralManager retrievePeripheralsWithIdentifiers:@[uuid]];
                        if (array.count > 0) {
                            isHave = YES;
                            [self connectWithPeripheral:array[0]];
                        }
                    }
                    //没有重连设备
                    if (!isHave) {
                        //
                        [self.centralManager scanForPeripheralsWithServices:nil options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
                    }
                }else {
                    //
                    [self.centralManager scanForPeripheralsWithServices:nil options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
                }
            }
                break;
            case CBCentralManagerStatePoweredOff:
            {
                id delegate = self.delegate;
                if (delegate && [delegate respondsToSelector:@selector(didUpdateBluetoothState:)]) {
                    [delegate didUpdateBluetoothState:NO];
                }
            }
                break;
            case CBCentralManagerStateUnsupported:
            {
                id delegate = self.delegate;
                if (delegate && [delegate respondsToSelector:@selector(didUpdateBluetoothState:)]) {
                    [delegate didUpdateBluetoothState:NO];
                }
            }
                break;
            default:
                break;
        }
    }
}

/**
 停止搜索
 */
- (void)stopScan {
    if (self.isScaning) {
        self.isScaning = NO;
        self.isRetrieve = NO;
        //
        self.willConnectUUID = nil;
        //
        if (self.centralManager != nil) {
            [self.centralManager stopScan];
        }
    }
}

#pragma mark - 连接

/**
 是否连接
 */
- (BOOL)isConnect {
    BOOL result = NO;
    if (self.peripheral == nil) {
        result = NO;
    }else {
        if (self.peripheral.state == CBPeripheralStateConnected && self.characteristic != nil) {
            result = YES;
        }else {
            result = NO;
        }
    }
    return result;
}

#pragma mark -
/**
 通过设备连接
 @param peripheral 外围设备
 */
- (void)connectWithPeripheral:(CBPeripheral *)peripheral {
    if (self.peripheral == nil || self.peripheral.state != CBPeripheralStateConnected) {
        //停止搜索
        [self stopScan];
        //
        self.peripheral = peripheral;
        //连接蓝牙
        [self.centralManager connectPeripheral:self.peripheral options:nil];
    }
}

/**
 通过UUID连接
 @param uuid 外围设备UUID
 */
- (void)retrievePeripheralsWithUUID:(NSString *)uuid {
    if (uuid != nil) {
        //停止搜索
        [self stopScan];
        //
        self.isRetrieve = YES;
        self.willConnectUUID = uuid;
        //重连，先搜索
        [self startScan];
    }
}

#pragma mark -

/**
 断开连接
 */
- (void)disconnect {
    if (self.peripheral && (self.peripheral.state == CBPeripheralStateConnected)) {
        [self.centralManager cancelPeripheralConnection:self.peripheral];
    }
}

#pragma mark -
/**
 清除连接
 */
- (void)cleanUpConnect {
    // Don't do anything if we're not connected
    if (self.peripheral == nil) {
        return;
    }
    if (self.peripheral.state != CBPeripheralStateConnected) {
        return;
    }
    
    // See if we are subscribed to a characteristic on the peripheral
    if (self.peripheral.services != nil) {
        for (CBService *service in self.peripheral.services) {
            if (service.characteristics != nil) {
                for (CBCharacteristic *characteristic in service.characteristics) {
                    if ([characteristic.UUID isEqual:self.cUUID2]) {
                        if (characteristic.isNotifying) {
                            // It is notifying, so unsubscribe
                            [self.peripheral setNotifyValue:NO forCharacteristic:characteristic];
                            
                            // And we're done.
                            return;
                        }
                    }
                }
            }
        }
    }
    
    // If we've got this far, we're connected, but we're not subscribed, so we just disconnect
    [self.centralManager cancelPeripheralConnection:self.peripheral];
}

#pragma mark - 读写

/**
 写数据
 @param data 写入数据
 */
- (void)writeValue:(NSData *)data {
    if ([self isConnect]) {
        [self.peripheral writeValue:data forCharacteristic:self.characteristic type:CBCharacteristicWriteWithResponse];
    }
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    switch (central.state) {
        case CBCentralManagerStateUnknown:
        {
        }
            break;
        case CBCentralManagerStateResetting:
        {
        }
            break;
        case CBCentralManagerStateUnsupported:
        {
        }
            break;
        case CBCentralManagerStateUnauthorized:
        {
        }
            break;
        case CBCentralManagerStatePoweredOff:
        {
            //关闭蓝牙
            id delegate = self.delegate;
            if (delegate && [delegate respondsToSelector:@selector(didUpdateBluetoothState:)]) {
                [delegate didUpdateBluetoothState:NO];
            }
        }
            break;
        case CBCentralManagerStatePoweredOn:
        {
            //开启蓝牙
            id delegate = self.delegate;
            if (delegate && [delegate respondsToSelector:@selector(didUpdateBluetoothState:)]) {
                [delegate didUpdateBluetoothState:YES];
            }
        }
            break;
        default:
            break;
    }
}

#pragma mark -
/**
 * 发现外围设备
 */
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *, id> *)advertisementData RSSI:(NSNumber *)RSSI {
    if (self.isRetrieve && self.willConnectUUID != nil) {
        if ([[peripheral.identifier UUIDString] isEqualToString:self.willConnectUUID]) {
            [self connectWithPeripheral:peripheral];
        }
    }else {
        if (![self.deviceArray containsObject:peripheral]) {
            //
            [self.deviceArray addObject:peripheral];
            //
            id delegate = self.delegate;
            if (delegate && [delegate respondsToSelector:@selector(didDiscoverPeripheral:)]) {
                [delegate didDiscoverPeripheral:self.deviceArray];
            }
        }
    }
}

/**
 * 已连接
 */
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    //停止搜索
    [self stopScan];
    
    //
    id delegate = self.delegate;
    if (delegate && [delegate respondsToSelector:@selector(didConnectPeripheral:)]) {
        [delegate didConnectPeripheral:peripheral];
    }
    //
    [self.peripheral setDelegate:self];
    [self.peripheral discoverServices:@[self.sUUID]];
}
/**
 * 连接失败
 */
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error{
    //停止搜索
    [self stopScan];
    
    //
    id delegate = self.delegate;
    if (delegate && [delegate respondsToSelector:@selector(didFailToConnectPeripheral:error:)]) {
        [delegate didFailToConnectPeripheral:peripheral error:error];
    }
}
/**
 * 已断开
 */
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error {
    //停止搜索
    [self stopScan];
    
    //
    id delegate = self.delegate;
    if (delegate && [delegate respondsToSelector:@selector(didDisconnectPeripheral:error:)]) {
        [delegate didDisconnectPeripheral:peripheral error:error];
    }
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(nullable NSError *)error {
    if (error == nil) {
        for (CBService *service in peripheral.services) {
            // Discovers the characteristics for a given service
            if ([service.UUID isEqual:self.sUUID]) {
                //搜索特征值
                [self.peripheral discoverCharacteristics:@[self.cUUID1, self.cUUID2] forService:service];
                break;
            }
        }
    }else {
        //清除连接
        [self cleanUpConnect];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(nullable NSError *)error {
    if (error == nil) {
        if ([service.UUID isEqual:self.sUUID]) {
            for (CBCharacteristic *characteristic in service.characteristics) {
                //读取特征值
                if ([characteristic.UUID isEqual:self.cUUID1]) {
                    self.characteristic = characteristic;
                }
                //特征值
                if ([characteristic.UUID isEqual:self.cUUID2]) {
                    [peripheral setNotifyValue:YES forCharacteristic:characteristic];
                }
            }
        }
    }else {
        //清除连接
        [self cleanUpConnect];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error {
    if (error == nil) {
        id delegate = self.delegate;
        if (delegate && [delegate respondsToSelector:@selector(didReceivedData:)]) {
            [delegate didReceivedData:characteristic.value];
        }
    }else {
        //清除连接
        [self cleanUpConnect];
    }
}

@end
