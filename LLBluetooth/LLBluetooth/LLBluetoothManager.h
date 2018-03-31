//
//  LLBluetoothManager.h
//  LLBluetooth
//
//  Created by pro on 2018/1/22.
//  Copyright © 2018年 LL. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

/**
 * 蓝牙连接协议
 */
@protocol LLBluetoothManagerDelegate;

@interface LLBluetoothManager : NSObject

//代理
@property (nonatomic, assign) id<LLBluetoothManagerDelegate>delegate;


/**
 开始搜索
 */
- (void)startScan;
/**
 停止搜索
 */
- (void)stopScan;

/**
 是否连接
 */
- (BOOL)isConnect;
/**
 通过设备连接
 @param peripheral 外围设备
 */
- (void)connectWithPeripheral:(CBPeripheral *)peripheral;
/**
 通过UUID连接
 @param uuid 外围设备UUID
 */
- (void)retrievePeripheralsWithUUID:(NSString *)uuid;
/**
 断开连接
 */
- (void)disconnect;

/**
 写数据
 @param data 写入数据
 */
- (void)writeValue:(NSData *)data;

@end


/**
 * 蓝牙连接协议
 */
@protocol BFBluetoothManagerDelegate <NSObject>

@optional
/**
 蓝牙连接状态
 @param state 连接状态
 */
- (void)didUpdateBluetoothState:(BOOL)state;

/**
 发现外围设备
 @param array 搜索到的外围设备数组
 */
- (void)didDiscoverPeripheral:(NSArray<CBPeripheral *> *)array;

/**
 已连接外围设备
 @param peripheral 外围设备
 */
- (void)didConnectPeripheral:(CBPeripheral *)peripheral;

/**
 连接外围设备失败
 @param peripheral 外围设备
 @param error 错误
 */
- (void)didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error;

/**
 断开外围设备连接
 @param peripheral 外围设备
 @param error 错误
 */
- (void)didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error;

/**
 收到蓝牙数据
 @param data 收到的数据
 */
- (void)didReceivedData:(NSData *)data;

@end
