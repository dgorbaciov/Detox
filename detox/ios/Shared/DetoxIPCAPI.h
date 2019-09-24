//
//  DetoxIPCAPI.h
//  Detox
//
//  Created by Leo Natan (Wix) on 9/18/19.
//

#ifndef DetoxHelperAPI_h
#define DetoxHelperAPI_h

@protocol ZZZZ <NSObject>

- (void)_testSelector;
- (void)_testSelectorWithString:(NSString*)str;
- (void)_testSelectorWithDictionary:(NSDictionary*)dict reply:(void(^)(NSString*))replyBlock;
- (void)_testSelectorWithDictionary:(NSDictionary*)dict reply1:(void(^)(NSString*))replyBlock reply2:(void(^)(NSString*))replyBlock;

@end

@protocol DetoxTestRunner <ZZZZ>

- (void)testSelector;
- (void)testSelectorWithString:(NSString*)str;
- (void)testSelectorWithDictionary:(NSDictionary*)dict reply:(void(^)(NSString*))replyBlock;
- (void)testSelectorWithDictionary:(NSDictionary*)dict reply1:(void(^)(NSString*))replyBlock reply2:(void(^)(NSString*))replyBlock;

@end

@protocol DetoxHelper

- (void)waitForIdleWithCompletionHandler:(dispatch_block_t)completionHandler;

@end

#endif /* DetoxHelperAPI_h */
