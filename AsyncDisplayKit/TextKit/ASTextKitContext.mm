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

+ (nullable id)accessCacheWithBlock:(id _Nullable(^)(NSCache *))block
{
  static NSLock *lock;
  static dispatch_once_t onceToken;
  static NSCache *contextCache;
  dispatch_once(&onceToken, ^{
    contextCache = [[NSCache alloc] init];
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
  ASTextKitContext * _Nullable cached = [self accessCacheWithBlock:^(NSCache *cache) {
    id key = attributedString ?: (id)kCFNull;
    ASTextKitContext *cached = [cache objectForKey:key];
    if (cached != nil) {
      [cache removeObjectForKey:key];
    }
    return cached;
  }];
  if (cached != nil) {
    [cached configureWithLineBreakMode:lineBreakMode maximumNumberOfLines:maximumNumberOfLines exclusionPaths:exclusionPaths constrainedSize:constrainedSize layoutManagerDelegate:layoutManagerDelegate];
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
    _textStorage = (attributedString ? [[NSTextStorage alloc] initWithAttributedString:attributedString] : [[NSTextStorage alloc] init]);
    _layoutManager = [[ASLayoutManager alloc] init];
    
    [_textStorage addLayoutManager:_layoutManager];
    _textContainer = [[NSTextContainer alloc] initWithSize:constrainedSize];
    [_layoutManager addTextContainer:_textContainer];
    [self configureWithLineBreakMode:lineBreakMode maximumNumberOfLines:maximumNumberOfLines exclusionPaths:exclusionPaths constrainedSize:constrainedSize layoutManagerDelegate:layoutManagerDelegate];
  }
  return self;
}

- (void)configureWithLineBreakMode:(NSLineBreakMode)lineBreakMode
              maximumNumberOfLines:(NSUInteger)maximumNumberOfLines
                    exclusionPaths:(NSArray *)exclusionPaths
                   constrainedSize:(CGSize)constrainedSize
             layoutManagerDelegate:(id<NSLayoutManagerDelegate>)layoutManagerDelegate
{
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
  id key = _textStorage.length > 0 ? [[NSAttributedString alloc] initWithAttributedString:_textStorage] : (id)kCFNull;
  [ASTextKitContext accessCacheWithBlock:^id _Nullable(NSCache *cache) {
    [cache setObject:self forKey:key];
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
