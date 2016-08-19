//
//  ASDataController+Subclasses.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#pragma once
#import <vector>

@class ASIndexedNodeContext;

typedef void (^ASDataControllerCompletionBlock)(NSArray<ASCellNode *> *nodes, NSArray<NSIndexPath *> *indexPaths);

@interface ASDataController (Subclasses)

#pragma mark - Internal editing & completed store querying

/**
 * Provides a collection of index paths for nodes of the given kind that are currently in the editing store
 */
- (NSArray *)indexPathsForEditingNodesOfKind:(NSString *)kind;

/**
 * Read-only access to the underlying editing nodes of the given kind
 */
- (NSMutableArray *)editingNodesOfKind:(NSString *)kind;

/**
 * Read only access to the underlying completed nodes of the given kind
 */
- (NSMutableArray *)completedNodesOfKind:(NSString *)kind;

/**
 * Ensure that next time `itemCountsFromDataSource` is called, new values are retrieved.
 *
 * This must be called on the main thread.
 */
- (void)invalidateDataSourceItemCounts;

/**
 * Returns the most recently gathered item counts from the data source. If the counts
 * have been invalidated, this synchronously queries the data source and saves the result.
 *
 * This must be called on the main thread.
 */
- (std::vector<NSInteger>)itemCountsFromDataSource;

#pragma mark - Node sizing

/**
 * Measure and layout the given nodes in optimized batches, constraining each to a given size in `constrainedSizeForNodeOfKind:atIndexPath:`.
 *
 * This method runs synchronously.
 * @param batchCompletion A handler to be run after each batch is completed. It is executed synchronously on the calling thread.
 */
- (void)batchLayoutNodesFromContexts:(NSArray<ASIndexedNodeContext *> *)contexts batchCompletion:(ASDataControllerCompletionBlock)batchCompletionHandler;

/**
 * Provides the size range for a specific node during the layout process.
 */
- (ASSizeRange)constrainedSizeForNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;

#pragma mark - Node & Section Insertion/Deletion API

/**
 * Inserts the given nodes of the specified kind into the backing store, calling completion on the main thread when the write finishes.
 */
- (void)insertNodes:(NSArray *)nodes ofKind:(NSString *)kind atIndexPaths:(NSArray *)indexPaths completion:(ASDataControllerCompletionBlock)completionBlock;

/**
 * Deletes the given nodes of the specified kind in the backing store, calling completion on the main thread when the deletion finishes.
 */
- (void)deleteNodesOfKind:(NSString *)kind atIndexPaths:(NSArray *)indexPaths completion:(ASDataControllerCompletionBlock)completionBlock;

/**
 * Inserts the given sections of the specified kind in the backing store, calling completion on the main thread when finished.
 */
- (void)insertSections:(NSMutableArray *)sections ofKind:(NSString *)kind atIndexSet:(NSIndexSet *)indexSet completion:(void (^)(NSArray *sections, NSIndexSet *indexSet))completionBlock;

/**
 * Deletes the given sections of the specified kind in the backing store, calling completion on the main thread when finished.
 */
- (void)deleteSectionsOfKind:(NSString *)kind atIndexSet:(NSIndexSet *)indexSet completion:(void (^)(NSIndexSet *indexSet))completionBlock;

@end
