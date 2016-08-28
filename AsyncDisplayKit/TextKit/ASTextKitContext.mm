//
//  ASTextKitContext.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASTextKitContext.h"
#import "ASLayoutManager.h"
#import "ASThread.h"

#include <memory>

@implementation ASTextKitContext
{
  // All TextKit operations (even non-mutative ones) must be executed serially.
  std::shared_ptr<ASDN::Mutex> __instanceLock__;
  
  NSLayoutManager *_layoutManager;
  NSTextStorage *_textStorage;
  NSTextContainer *_textContainer;
}

+ (nullable id)accessCacheWithBlock:(id(^)(NSMutableArray *))block
{
  static NSLock *lock;
  static dispatch_once_t onceToken;
  static NSMutableArray *contextCache;
  dispatch_once(&onceToken, ^{
    contextCache = [[NSMutableArray alloc] init];
    lock = [[NSLock alloc] init];
  });
  [lock lock];
  id result = block(contextCache);
  [lock unlock];
  return result;
}

+ (ASTextKitContext *)contextWithAttributedString:(NSAttributedString *)attributedString
                                    lineBreakMode:(NSLineBreakMode)lineBreakMode
                             maximumNumberOfLines:(NSUInteger)maximumNumberOfLines
                                   exclusionPaths:(NSArray *)exclusionPaths
                                  constrainedSize:(CGSize)constrainedSize
                            layoutManagerDelegate:(id<NSLayoutManagerDelegate>)layoutManagerDelegate
{
  ASTextKitContext * _Nullable cached = [self accessCacheWithBlock:^id(NSMutableArray *cache) {
    NSInteger count = cache.count;
    if (count == 0) {
      return nil;
    }
    NSInteger idx = count - 1;
    ASTextKitContext *result = cache[idx];
    [cache removeObjectAtIndex:idx];
    return result;
  }];
  if (cached != nil) {
    [cached configureWithAttributedString:attributedString lineBreakMode:lineBreakMode maximumNumberOfLines:maximumNumberOfLines exclusionPaths:exclusionPaths constrainedSize:constrainedSize layoutManagerDelegate:layoutManagerDelegate];
    return cached;
  } else {
    return [[ASTextKitContext alloc] initWithAttributedString:attributedString lineBreakMode:lineBreakMode maximumNumberOfLines:maximumNumberOfLines exclusionPaths:exclusionPaths constrainedSize:constrainedSize layoutManagerDelegate:layoutManagerDelegate];
  }
}

- (instancetype)initWithAttributedString:(NSAttributedString *)attributedString
                           lineBreakMode:(NSLineBreakMode)lineBreakMode
                    maximumNumberOfLines:(NSUInteger)maximumNumberOfLines
                          exclusionPaths:(NSArray *)exclusionPaths
                         constrainedSize:(CGSize)constrainedSize
                   layoutManagerDelegate:(id<NSLayoutManagerDelegate>)layoutManagerDelegate

{
  if (self = [super init]) {
    // Concurrently initialising TextKit components crashes (rdar://18448377) so we use a global lock.
    static ASDN::Mutex __staticMutex;
    ASDN::MutexLocker l(__staticMutex);
    
    __instanceLock__ = std::make_shared<ASDN::Mutex>();
    
    // Create the TextKit component stack with our default configuration.
    _textStorage = [[NSTextStorage alloc] init];
    _layoutManager = [[ASLayoutManager alloc] init];
    
    [_textStorage addLayoutManager:_layoutManager];
    _textContainer = [[NSTextContainer alloc] initWithSize:constrainedSize];
    [_layoutManager addTextContainer:_textContainer];
    [self configureWithAttributedString:attributedString lineBreakMode:lineBreakMode maximumNumberOfLines:maximumNumberOfLines exclusionPaths:exclusionPaths constrainedSize:constrainedSize layoutManagerDelegate:layoutManagerDelegate];
  }
  return self;
}

- (void)configureWithAttributedString:(NSAttributedString *)attributedString
                        lineBreakMode:(NSLineBreakMode)lineBreakMode
                 maximumNumberOfLines:(NSUInteger)maximumNumberOfLines
                       exclusionPaths:(NSArray *)exclusionPaths
                      constrainedSize:(CGSize)constrainedSize
                layoutManagerDelegate:(id<NSLayoutManagerDelegate>)layoutManagerDelegate
{
  if ([_textStorage isEqualToAttributedString:attributedString] == NO) {
    [_textStorage setAttributedString:attributedString];
  }
  _layoutManager.usesFontLeading = NO;
  _layoutManager.delegate = layoutManagerDelegate;
  // We want the text laid out up to the very edges of the container.
  _textContainer.lineFragmentPadding = 0;
  _textContainer.lineBreakMode = lineBreakMode;
  _textContainer.maximumNumberOfLines = maximumNumberOfLines;
  _textContainer.exclusionPaths = exclusionPaths;
  if (CGSizeEqualToSize(_textContainer.size, constrainedSize) == NO) {
    _textContainer.size = constrainedSize;
  }
}

- (void)markForReuse
{
  [ASTextKitContext accessCacheWithBlock:^id(NSMutableArray *cache) {
    [cache addObject:self];
    return nil;
  }];
}

- (CGSize)constrainedSize
{
  ASDN::MutexSharedLocker l(__instanceLock__);
  return _textContainer.size;
}

- (void)setConstrainedSize:(CGSize)constrainedSize
{
  ASDN::MutexSharedLocker l(__instanceLock__);
  _textContainer.size = constrainedSize;
}

- (void)performBlockWithLockedTextKitComponents:(void (^)(NSLayoutManager *,
                                                          NSTextStorage *,
                                                          NSTextContainer *))block
{
  ASDN::MutexSharedLocker l(__instanceLock__);
  if (block) {
    block(_layoutManager, _textStorage, _textContainer);
  }
}

@end
