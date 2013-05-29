//
//  DCBluetooth.m
//  Hardbox
//
//  Created by Dalmo Cirne on 4/6/13.
//  Copyright (c) 2013 Dalmo Cirne. All rights reserved.
//

#import "DCBluetooth.h"
#import <dispatch/dispatch.h>
#import <CoreBluetooth/CoreBluetooth.h>

#define BLE_DEVICE_SERVICE_UUID "713D0000-503E-4C75-BA94-3148F18D941E"
#define BLE_DEVICE_TX_UUID "713D0003-503E-4C75-BA94-3148F18D941E"

@interface DCBluetooth() <CBCentralManagerDelegate, CBPeripheralDelegate> {
    CBCentralManager *centralManager;
    dispatch_queue_t bluetoothManagerQueue;
}

@end


@implementation DCBluetooth

- (id)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    bluetoothManagerQueue = dispatch_queue_create("com.dalmocirne.bluetoothManagerQueue", DISPATCH_QUEUE_SERIAL);
    centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:bluetoothManagerQueue];
    
    return self;
}

#pragma mark Private methods
- (CBService *)findServiceWithUUID:(CBUUID *)UUID {
    __block CBService *service = nil;
    [_peripheral.services enumerateObjectsUsingBlock:^(CBService *serv, NSUInteger idx, BOOL *stop) {
        if ([serv.UUID isEqual:UUID]) {
            service = serv;
            *stop = YES;
        }
    }];
    
    return service;
}

- (CBCharacteristic *)findCharacteristicWithUUID:(CBUUID *)UUID service:(CBService*)service {
    __block CBCharacteristic *characteristic = nil;
    [service.characteristics enumerateObjectsUsingBlock:^(CBCharacteristic *charact, NSUInteger idx, BOOL *stop) {
        if ([charact.UUID isEqual:UUID]) {
            characteristic = charact;
            *stop = YES;
        }
    }];
    
    return characteristic;
}

#pragma mark CBCentralManagerDelegate
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    [self.peripheral discoverServices:nil];
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    self.peripheral = peripheral;
    [self.peripheral setDelegate:self];
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    [self.delegate bluetoothDidDisconnect];
}

#pragma mark CBPeripheralDelegate
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    [peripheral.services enumerateObjectsUsingBlock:^(CBService *service, NSUInteger idx, BOOL *stop) {
        [peripheral discoverCharacteristics:nil forService:service];
    }];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    CBService *serv = [peripheral.services lastObject];
    if ([service.UUID isEqual:serv.UUID]) {
        [self.delegate bluetoothDidConnect];
    }
}

#pragma mark Public methods
- (void)findBluetoothPeripherals:(NSTimeInterval)timeout {
    [centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:@BLE_DEVICE_SERVICE_UUID]]
                                                options:nil];
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^{
        [centralManager stopScan];
    });
}

- (void)connect:(CBPeripheral *)peripheral {
    if (![peripheral isEqual:self.peripheral]) {
        [self setPeripheral:peripheral];
        [self.peripheral setDelegate:self];
    }
    
    [centralManager connectPeripheral:self.peripheral
                              options:@{CBConnectPeripheralOptionNotifyOnDisconnectionKey:@(YES)}];

}

- (void)disconnect {
    if (_peripheral && _peripheral.isConnected) {
        [centralManager cancelPeripheralConnection:_peripheral];
    }
}

- (void)write:(NSData *)data {
    CBUUID *serviceUUID = [CBUUID UUIDWithString:@BLE_DEVICE_SERVICE_UUID];
    CBUUID *characteristicUUID = [CBUUID UUIDWithString:@BLE_DEVICE_TX_UUID];
    
    CBService *service = [self findServiceWithUUID:serviceUUID];
    if (!service) {
        return;
    }
    
    CBCharacteristic *characteristic = [self findCharacteristicWithUUID:characteristicUUID service:service];
    if (!characteristic) {
        return;
    }
    
    [_peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithoutResponse];
}

@end
