//
//  DTXIPCConnection.m
//  DetoxIPC
//
//  Created by Leo Natan (Wix) on 9/24/19.
//  Copyright © 2019 LeoNatan. All rights reserved.
//

#import "DTXIPCConnection.h"
#import "NSConnection.h"
#import "ObjCRuntime.h"
#import "_DTXIPCDistantObject.h"
@import ObjectiveC;

@interface DTXIPCInterface ()

@property (nonatomic, readwrite) Protocol* protocol;
@property (nonatomic, strong) NSDictionary<NSString*, NSMethodSignature*>* selectoToSignature;
@property (nonatomic, strong, readwrite) NSArray<NSMethodSignature*>* methodSignatures;

@end

@implementation DTXIPCInterface
{
	struct objc_method_description* _methodList;
	unsigned int _methodListCount;
}

static void _DTXAddSignatures(Protocol* protocol, NSMutableArray* signatures, NSMutableDictionary* map)
{
	unsigned int count = 0;
	{
		objc_property_t* unsupported = protocol_copyPropertyList2(protocol, &count, YES, YES);
		dtx_defer {
			free_if_needed(unsupported);
		};
		if(count > 0)
		{
			[NSException raise:NSInvalidArgumentException format:@"Properties are not suppoerted."];
		}
	}
	{
		objc_property_t* unsupported = protocol_copyPropertyList2(protocol, &count, NO, YES);
		dtx_defer {
			free_if_needed(unsupported);
		};
		if(count > 0)
		{
			[NSException raise:NSInvalidArgumentException format:@"Properties are not suppoerted."];
		}
	}
	{
		objc_property_t* unsupported = protocol_copyPropertyList2(protocol, &count, YES, NO);
		dtx_defer {
			free_if_needed(unsupported);
		};
		if(count > 0)
		{
			[NSException raise:NSInvalidArgumentException format:@"Properties are not suppoerted."];
		}
	}
	{
		objc_property_t* unsupported = protocol_copyPropertyList2(protocol, &count, NO, NO);
		dtx_defer {
			free_if_needed(unsupported);
		};
		if(count > 0)
		{
			[NSException raise:NSInvalidArgumentException format:@"Properties are not suppoerted."];
		}
	}
	
	{
		struct objc_method_description * unsupported = protocol_copyMethodDescriptionList(protocol, YES, NO, &count);
		dtx_defer {
			free_if_needed(unsupported);
		};
		if(count > 0)
		{
			[NSException raise:NSInvalidArgumentException format:@"Class methods are not supported."];
		}
	}
	
	{
		struct objc_method_description * unsupported = protocol_copyMethodDescriptionList(protocol, NO, NO, &count);
		dtx_defer {
			free_if_needed(unsupported);
		};
		if(count > 0)
		{
			[NSException raise:NSInvalidArgumentException format:@"Class methods are not supported."];
		}
	}
	{
		struct objc_method_description * unsupported = protocol_copyMethodDescriptionList(protocol, NO, YES, &count);
		dtx_defer {
			free_if_needed(unsupported);
		};
		if(count > 0)
		{
			[NSException raise:NSInvalidArgumentException format:@"Optional methods are not supported."];
		}
	}
	{
		struct objc_method_description * supported = protocol_copyMethodDescriptionList(protocol, YES, YES, &count);
		dtx_defer {
			free_if_needed(supported);
		};
		
		for(unsigned int idx = 0; idx < count; idx++)
		{
			const char* types = _protocol_getMethodTypeEncoding(protocol, supported[idx].name, YES, YES);
			
			NSMethodSignature* methodSignature = [NSMethodSignature signatureWithObjCTypes:types];
			
			if(strncmp(methodSignature.methodReturnType, "v", 2))
			{
				[NSException raise:NSInvalidArgumentException format:@"Methods must have 'void' return type."];
			}
			
			map[NSStringFromSelector(supported[idx].name)] = methodSignature;
			[signatures addObject:methodSignature];
		}
	}
}

static void _DTXIterateProtocols(Protocol* protocol, NSMutableArray* signatures, NSMutableDictionary* map)
{
	if(protocol_isEqual(protocol, @protocol(NSObject)))
	{
		return;
	}
	
	unsigned int adoptedCount = 0;
	Protocol* __unsafe_unretained * adoptedProtocols = protocol_copyProtocolList(protocol, &adoptedCount);
	dtx_defer {
		free_if_needed(adoptedProtocols);
	};
	
	for(unsigned int idx = 0; idx < adoptedCount; idx++)
	{
		_DTXIterateProtocols(adoptedProtocols[idx], signatures, map);
	}
	
	_DTXAddSignatures(protocol, signatures, map);
}

+ (instancetype)interfaceWithProtocol:(Protocol *)protocol
{
	DTXIPCInterface* rv = [DTXIPCInterface new];
	rv.protocol = protocol;

	NSMutableArray<NSMethodSignature*>* signatures = [NSMutableArray new];
	NSMutableDictionary<NSString*, NSMethodSignature*>* map = [NSMutableDictionary new];
	
	_DTXIterateProtocols(rv.protocol, signatures, map);
	
	rv.selectoToSignature = map;
	rv.methodSignatures = signatures;

	return rv;
}

- (NSUInteger)numberOfMethods
{
	return _methodListCount;
}

- (NSMethodSignature *)protocolMethodSignatureForSelector:(SEL)aSelector
{
	return _selectoToSignature[NSStringFromSelector(aSelector)];
}

@end

@implementation DTXIPCConnection
{
	BOOL _slave;
	
	NSConnection* _connection;
	NSConnection* _otherConnection;
}

- (instancetype)initWithServiceName:(NSString *)serviceName
{
	self = [super init];
	if(self)
	{
		_serviceName = serviceName;
		_slave = NO;
		
		_connection = [NSConnection connectionWithReceivePort:NSPort.port sendPort:nil];
		_connection.rootObject = self;
		[_connection registerName:_serviceName];
		[_connection runInNewThread];
	}
	return self;
}

- (instancetype)initWithRegisteredServiceName:(NSString *)serviceName
{
	self = [super init];
	if(self)
	{
		_serviceName = [NSString stringWithFormat:@"%@.slave", serviceName];
		_slave = YES;
		
		_connection = [NSConnection connectionWithReceivePort:NSPort.port sendPort:nil];
		_connection.rootObject = self;
		[_connection registerName:_serviceName];
		[_connection runInNewThread];
		
		_otherConnection = [NSConnection connectionWithRegisteredName:serviceName host:nil];
		[(id)_otherConnection.rootProxy _slaveDidConnectWithName:_serviceName];
	}
	return self;
}

- (void)invalidate
{
	[_connection invalidate];
	[(id)_otherConnection.rootProxy _remoteDidInvalidate];
	[_otherConnection invalidate];
}

- (id)remoteObjectProxy
{
	return [_DTXIPCDistantObject _distantObjectWithConnection:self remoteInterface:self.remoteObjectInterface synchronous:NO errorBlock:nil];
}

- (id)remoteObjectProxyWithErrorHandler:(void (^)(NSError * _Nonnull))handler
{
	return [_DTXIPCDistantObject _distantObjectWithConnection:self remoteInterface:self.remoteObjectInterface synchronous:NO errorBlock:handler];
}

- (id)synchronousRemoteObjectProxyWithErrorHandler:(void (^)(NSError * _Nonnull))handler
{
	return [_DTXIPCDistantObject _distantObjectWithConnection:self remoteInterface:self.remoteObjectInterface synchronous:YES errorBlock:handler];
}

#pragma mark Slave notifications

- (oneway void)_slaveDidConnectWithName:(NSString*)slaveServiceName
{
	_otherConnection = [NSConnection connectionWithRegisteredName:slaveServiceName host:nil];
}

#pragma 

- (oneway void)_remoteDidInvalidate
{
	_otherConnection = nil;
	[_connection invalidate];
}

@end
