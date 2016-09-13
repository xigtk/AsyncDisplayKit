//
//  ASIndexedNodeContext.mm
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 2/28/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASIndexedNodeContext.h"
#import "ASEnvironmentInternal.h"
#import "ASCellNode.h"
#import "ASLayout.h"
#import "ASThread.h"

/**
 * The precursor to a cell node in a collection/table view.
 */

@interface ASIndexedNodeContext ()

/// A readwrite variant of the same public property.
@property (atomic, nullable, strong) ASCellNode *node;

@end

@implementation ASIndexedNodeContext {
  ASDN::Mutex _operationMutex;

  /// Guarded by _operationMutex
  BOOL _hasCreatedOperation;

  /// Guarded by _operationMutex
  BOOL _cancelled;

  /// Guarded by _operationMutex until op is created, then constant
  __weak NSOperation *_nodeMeasurementOperation;

  /// No mutex – only access inside operation
  ASCellNodeBlock _nodeBlock;

  // Input params – constant
  ASSizeRange _constrainedSize;
  ASEnvironmentTraitCollection _environmentTraitCollection;
}

+ (NSOperationQueue *)nodeMeasurementQueue
{
  static NSOperationQueue *nodeMeasurementQueue;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    nodeMeasurementQueue = [[NSOperationQueue alloc] init];
    nodeMeasurementQueue.name = @"org.AsyncDisplayKit.cellNodeMeasurementQueue";
    nodeMeasurementQueue.maxConcurrentOperationCount = [NSProcessInfo processInfo].processorCount * 2;
  });
  return nodeMeasurementQueue;
}

- (instancetype)initWithNodeBlock:(ASCellNodeBlock)nodeBlock
                        indexPath:(NSIndexPath *)indexPath
                  constrainedSize:(ASSizeRange)constrainedSize
       environmentTraitCollection:(ASEnvironmentTraitCollection)environmentTraitCollection
{
  NSAssert(nodeBlock != nil && indexPath != nil, @"Node block and index path must not be nil");
  self = [super init];
  if (self) {
    _nodeBlock = nodeBlock;
    _indexPath = indexPath;
    _constrainedSize = constrainedSize;
    _environmentTraitCollection = environmentTraitCollection;
  }
  return self;
}

- (void)dealloc
{
  [self cancelMeasurement];
}

#pragma mark - Public API

- (void)scheduleMeasurement
{
  ASDN::MutexLocker l(_operationMutex);
  if (_hasCreatedOperation || _cancelled) {
    return;
  }

  // Create operation
  __weak __typeof(self) weakSelf = self;
  NSOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
    [weakSelf measureCellNode];
  }];
  _nodeMeasurementOperation = operation;
  [[ASIndexedNodeContext nodeMeasurementQueue] addOperation:operation];
  _hasCreatedOperation = YES;
}

- (void)waitForMeasurement
{
  [self scheduleMeasurement];

  // No need to lock here. Operation is created above then constant.
  [_nodeMeasurementOperation waitUntilFinished];

  ASDisplayNodeAssert(self.isMeasurementCancelled || self.node != nil, @"After waiting, we should have a node or measurement should be cancelled.");
}

/// Note: This method must be dealloc-safe.
- (void)cancelMeasurement
{
  ASDN::MutexLocker l(_operationMutex);
  _cancelled = YES;
  [_nodeMeasurementOperation cancel];
}

AS_SYNTHESIZE_ATOMIC_GETTER(BOOL, isMeasurementCancelled, _cancelled, _operationMutex)

#pragma mark - Private API

/**
 * This method is executed once per context, to perform the measurement.
 */
- (void)measureCellNode
{
  NSOperation *operation = _nodeMeasurementOperation;
  // Allocate the node.
  ASCellNode *node = _nodeBlock();
  _nodeBlock = nil;

  if (node == nil) {
    ASDisplayNodeAssertNotNil(node, @"Node block created nil node. indexPath: %@", _indexPath);
    node = [[ASCellNode alloc] init]; // Fallback to avoid crash for production apps.
  }

  // Propagate environment state down.
  ASEnvironmentStatePropagateDown(node, _environmentTraitCollection);
  if (operation.isCancelled) {
    return;
  }

  // Measure the node.
  CGRect frame = CGRectZero;
  frame.size = [node layoutThatFits:_constrainedSize].size;
  node.frame = frame;

  // Set resulting node.
  self.node = node;
}

#pragma mark - Helpers

+ (NSArray<NSIndexPath *> *)indexPathsFromContexts:(NSArray<ASIndexedNodeContext *> *)contexts
{
  NSMutableArray *result = [NSMutableArray arrayWithCapacity:contexts.count];
  for (ASIndexedNodeContext *ctx in contexts) {
    [result addObject:ctx.indexPath];
  }
  return result;
}

@end
