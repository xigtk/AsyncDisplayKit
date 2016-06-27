//
//  ASTableViewThrashTests.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 6/21/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

@import XCTest;
#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import "ASTableViewInternal.h"
#import "NSIndexSet+ASHelpers.h"

// Set to 1 to use UITableView and see if the issue still exists.
#define USE_UIKIT_REFERENCE 1

#if USE_UIKIT_REFERENCE
#define TableView UITableView
#define kCellReuseID @"ASThrashTestCellReuseID"
#else
#define TableView ASTableView
#endif

#define kInitialSectionCount 3
#define kInitialItemCount 3
#define kMinimumItemCount 5
#define kMinimumSectionCount 3
#define kFickleness 0.1
#define kThrashingIterationCount 100

static NSString *ASThrashArrayDescription(NSArray *array) {
  NSMutableString *str = [NSMutableString stringWithString:@"(\n"];
  NSInteger i = 0;
  for (id obj in array) {
    [str appendFormat:@"\t[%ld]: \"%@\",\n", i, obj];
    i += 1;
  }
  [str appendString:@")"];
  return str;
}

static volatile int32_t ASThrashTestItemNextID = 1;
@interface ASThrashTestItem: NSObject <NSSecureCoding>
@property (nonatomic, readonly) NSInteger itemID;
// Starts at version 1
@property (nonatomic, readonly) NSInteger version;

- (ASThrashTestItem *)itemByIncrementingVersion;
- (CGFloat)rowHeight;
@end

@implementation ASThrashTestItem

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (instancetype)init {
  self = [super init];
  if (self != nil) {
    _itemID = OSAtomicIncrement32(&ASThrashTestItemNextID);
    _version = 1;
  }
  return self;
}

- (ASThrashTestItem *)itemByIncrementingVersion {
  ASThrashTestItem *item = [[ASThrashTestItem alloc] init];
  item->_itemID = _itemID;
  item->_version = _version + 1;
  return item;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  self = [super init];
  if (self != nil) {
    _itemID = [aDecoder decodeIntegerForKey:@"itemID"];
    _version = [aDecoder decodeIntegerForKey:@"version"];
    NSAssert(_itemID > 0, @"Failed to decode %@", self);
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeInteger:_itemID forKey:@"itemID"];
  [aCoder encodeInteger:_version forKey:@"version"];
}

+ (NSMutableArray <ASThrashTestItem *> *)itemsWithCount:(NSInteger)count {
  NSMutableArray *result = [NSMutableArray arrayWithCapacity:count];
  for (NSInteger i = 0; i < count; i += 1) {
    [result addObject:[[ASThrashTestItem alloc] init]];
  }
  return result;
}

- (CGFloat)rowHeight {
  return (self.itemID + self.version) % 400 ?: 44;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<Item %lu v=%lu>", (unsigned long)_itemID, (unsigned long)_version];
}

- (BOOL)isEqual:(id)object {
  return [object isKindOfClass:[ASThrashTestItem class]] ? [object version] == self.version && [object itemID] == self.itemID : NO;
}

@end

@interface ASThrashTestSection: NSObject <NSCopying, NSSecureCoding>
@property (nonatomic, strong, readonly) NSMutableArray *items;
@property (nonatomic, readonly) NSInteger sectionID;
@property (nonatomic, readonly) NSInteger version;

- (CGFloat)headerHeight;
@end

static volatile int32_t ASThrashTestSectionNextID = 1;
@implementation ASThrashTestSection

/// Create an array of sections with the given count
+ (NSMutableArray <ASThrashTestSection *> *)sectionsWithCount:(NSInteger)count {
  NSMutableArray *result = [NSMutableArray arrayWithCapacity:count];
  for (NSInteger i = 0; i < count; i += 1) {
    [result addObject:[[ASThrashTestSection alloc] initWithCount:kInitialItemCount]];
  }
  return result;
}

- (instancetype)initWithCount:(NSInteger)count {
  self = [super init];
  if (self != nil) {
    _sectionID = OSAtomicIncrement32(&ASThrashTestSectionNextID);
    _version = 1;
    _items = [ASThrashTestItem itemsWithCount:count];
  }
  return self;
}

- (instancetype)init {
  return [self initWithCount:0];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  self = [super init];
  if (self != nil) {
    _items = [aDecoder decodeObjectOfClass:[NSArray class] forKey:@"items"];
    _sectionID = [aDecoder decodeIntegerForKey:@"sectionID"];
    _version = [aDecoder decodeIntegerForKey:@"version"];
    NSAssert(_sectionID > 0, @"Failed to decode %@", self);
  }
  return self;
}

- (ASThrashTestSection *)sectionByIncrementingVersion {
  ASThrashTestSection *sec = [self copy];
  sec->_version += 1;
  return sec;
}

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:_items forKey:@"items"];
  [aCoder encodeInteger:_sectionID forKey:@"sectionID"];
  [aCoder encodeInteger:_version forKey:@"version"];
}

- (CGFloat)headerHeight {
  return (self.sectionID + self.version) % 400 ?: 44;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<Section %lu v=%lu: itemCount=%lu, items=%@>", (unsigned long)_sectionID, (unsigned long)_version, (unsigned long)self.items.count, ASThrashArrayDescription(self.items)];
}

- (id)copyWithZone:(NSZone *)zone {
  ASThrashTestSection *copy = [[ASThrashTestSection alloc] init];
  copy->_sectionID = _sectionID;
  copy->_items = [_items mutableCopy];
  return copy;
}

- (BOOL)isEqual:(id)object {
  if ([object isKindOfClass:[ASThrashTestSection class]]) {
    ASThrashTestSection *section = (ASThrashTestSection *)object;
    return section.sectionID == _sectionID && section.version == _version;
  } else {
    return NO;
  }
}

@end

#if !USE_UIKIT_REFERENCE
@interface ASThrashTestNode: ASCellNode
@property (nonatomic, strong) ASThrashTestItem *item;
@end

@implementation ASThrashTestNode

@end
#endif

@interface ASThrashDataSource: NSObject
#if USE_UIKIT_REFERENCE
<UITableViewDataSource, UITableViewDelegate>
#else
<ASTableDataSource, ASTableDelegate>
#endif

@property (nonatomic, strong, readonly) UIWindow *window;
@property (nonatomic, strong, readonly) TableView *tableView;
@property (nonatomic, strong) NSArray <ASThrashTestSection *> *data;
@end


@implementation ASThrashDataSource

- (instancetype)initWithData:(NSArray <ASThrashTestSection *> *)data {
  self = [super init];
  if (self != nil) {
    _data = [[NSArray alloc] initWithArray:data copyItems:YES];
    _window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    _tableView = [[TableView alloc] initWithFrame:_window.bounds style:UITableViewStylePlain];
    [_window addSubview:_tableView];
#if USE_UIKIT_REFERENCE
    _tableView.dataSource = self;
    _tableView.delegate = self;
    [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:kCellReuseID];
#else
    _tableView.asyncDelegate = self;
    _tableView.asyncDataSource = self;
    [_tableView reloadDataImmediately];
#endif
    [_tableView layoutIfNeeded];
  }
  return self;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return self.data[section].items.count;
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return self.data.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
  return self.data[section].headerHeight;
}

#if USE_UIKIT_REFERENCE

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  return [tableView dequeueReusableCellWithIdentifier:kCellReuseID forIndexPath:indexPath];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  ASThrashTestItem *item = self.data[indexPath.section].items[indexPath.item];
  return item.rowHeight;
}

#else

- (ASCellNodeBlock)tableView:(ASTableView *)tableView nodeBlockForRowAtIndexPath:(NSIndexPath *)indexPath {
  ASThrashTestItem *item = self.data[indexPath.section].items[indexPath.item];
  return ^{
    ASThrashTestNode *node = [[ASThrashTestNode alloc] init];
    node.item = item;
    return node;
  };
}

#endif

@end


@implementation NSIndexSet (ASThrashHelpers)

- (NSArray <NSIndexPath *> *)indexPathsInSection:(NSInteger)section {
  NSMutableArray *result = [NSMutableArray arrayWithCapacity:self.count];
  [self enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
    [result addObject:[NSIndexPath indexPathForItem:idx inSection:section]];
  }];
  return result;
}

/// `insertMode` means that for each index selected, the max goes up by one.
/// count = NSNotFound means no count requirement.
+ (NSMutableIndexSet *)randomIndexesLessThan:(NSInteger)max probability:(float)probability insertMode:(BOOL)insertMode count:(NSInteger)count excludingIndexes:(NSIndexSet *)excludedIndexes {
  NSMutableIndexSet *indexes = [[NSMutableIndexSet alloc] init];
  if (count == 0) {
    return indexes;
  }
  
  u_int32_t cutoff = probability * 100;
  do {
    for (NSInteger i = 0; i < max; i++) {
      if (![excludedIndexes containsIndex:i] && arc4random_uniform(100) < cutoff) {
        [indexes addIndex:i];
        if (indexes.count == count) {
          return indexes;
        }
        if (insertMode) {
          max += 1;
        }
      }
    }
  } while (count != NSNotFound && indexes.count < count);
  return indexes;
}

@end

static NSInteger ASThrashUpdateCurrentSerializationVersion = 2;

@interface ASThrashUpdate : NSObject <NSSecureCoding>
@property (nonatomic, strong, readonly) NSArray<ASThrashTestSection *> *oldData;
@property (nonatomic, strong, readonly) NSMutableArray<ASThrashTestSection *> *data;
@property (nonatomic, strong, readonly) NSMutableIndexSet *deletedSectionIndexes;
@property (nonatomic, strong, readonly) NSMutableIndexSet *replacedSectionIndexes;
@property (nonatomic, strong, readonly) NSMutableIndexSet *insertedSectionIndexes;
@property (nonatomic, strong, readonly) NSMutableArray<ASThrashTestSection *> *insertedSections;
@property (nonatomic, strong, readonly) NSMutableArray<NSMutableIndexSet *> *deletedItemIndexes;
@property (nonatomic, strong, readonly) NSMutableDictionary<NSIndexPath *, id> *movedItemIndexPaths;
@property (nonatomic, strong, readonly) NSMutableDictionary<NSNumber *, id> *movedSectionIndexes;
@property (nonatomic, strong, readonly) NSMutableArray<NSMutableIndexSet *> *replacedItemIndexes;
@property (nonatomic, strong, readonly) NSMutableArray<NSMutableIndexSet *> *insertedItemIndexes;
@property (nonatomic, strong, readonly) NSMutableArray<NSMutableArray <ASThrashTestItem *> *> *insertedItems;

- (instancetype)initWithData:(NSArray<ASThrashTestSection *> *)data;

+ (ASThrashUpdate *)thrashUpdateWithBase64String:(NSString *)base64;
- (NSString *)base64Representation;
@end

@implementation ASThrashUpdate

- (instancetype)initWithData:(NSArray<ASThrashTestSection *> *)data {
  self = [super init];
  if (self != nil) {
    _data = [[NSMutableArray alloc] initWithArray:data copyItems:YES];
    _oldData = [[NSArray alloc] initWithArray:data copyItems:YES];
    
    _deletedItemIndexes = [NSMutableArray array];
    _replacedItemIndexes = [NSMutableArray array];
    _insertedItemIndexes = [NSMutableArray array];
    _insertedItems = [NSMutableArray array];
    _insertedSections = [NSMutableArray array];
    _movedItemIndexPaths = [NSMutableDictionary dictionary];
    _movedSectionIndexes = [NSMutableDictionary dictionary];
    
    // Randomly reload some items
    for (ASThrashTestSection *section in _data) {
      NSMutableIndexSet *indexes = [NSIndexSet randomIndexesLessThan:section.items.count probability:kFickleness insertMode:NO count:NSNotFound excludingIndexes:nil];
      NSArray *newItems = [[section.items objectsAtIndexes:indexes] valueForKey:@"itemByIncrementingVersion"];
      [section.items replaceObjectsAtIndexes:indexes withObjects:newItems];
      [_replacedItemIndexes addObject:indexes];
    }
    
    // Randomly replace some sections
    _replacedSectionIndexes = [NSIndexSet randomIndexesLessThan:_data.count probability:kFickleness insertMode:NO count:NSNotFound excludingIndexes:nil];
    NSMutableArray<ASThrashTestSection *> *replacingSections = [[_data objectsAtIndexes:_replacedSectionIndexes] valueForKey:@"sectionByIncrementingVersion"];
    
    [_data replaceObjectsAtIndexes:_replacedSectionIndexes withObjects:replacingSections];
    
    // Randomly delete some items
    [_data enumerateObjectsUsingBlock:^(ASThrashTestSection * _Nonnull section, NSUInteger idx, BOOL * _Nonnull stop) {
      // Don't delete items from reloaded sections
      if ([_replacedSectionIndexes containsIndex:idx] || section.items.count < kMinimumItemCount) {
        [_deletedItemIndexes addObject:[NSMutableIndexSet indexSet]];
        return;
      }
      
      NSMutableIndexSet *indexes = [NSIndexSet randomIndexesLessThan:section.items.count probability:kFickleness insertMode:NO count:NSNotFound excludingIndexes:nil];
      
      /// Cannot reload & delete the same item.
      [indexes removeIndexes:_replacedItemIndexes[idx]];
      
      // 50% chance of move rather than delete
      if (arc4random_uniform(100) < 50) {
        for (NSIndexPath *indexPath in [indexes indexPathsInSection:idx]) {
          _movedItemIndexPaths[indexPath] = [NSNull null];
        }
        [_deletedItemIndexes addObject:[NSMutableIndexSet indexSet]];
      } else {
        [_deletedItemIndexes addObject:indexes];
      }
      
      [section.items removeObjectsAtIndexes:indexes];
    }];
    
    // Randomly delete & move some sections
    NSMutableIndexSet *movedSectionIndexes = [NSIndexSet randomIndexesLessThan:_data.count probability:kFickleness insertMode:NO count:NSNotFound excludingIndexes:nil];
    if (_data.count >= kMinimumSectionCount) {
      _deletedSectionIndexes = [NSIndexSet randomIndexesLessThan:_data.count probability:kFickleness insertMode:NO count:NSNotFound excludingIndexes:nil];
    } else {
      _deletedSectionIndexes = [NSMutableIndexSet indexSet];
    }
    // We can't move sections that were deleted.
    [movedSectionIndexes removeIndexes:_deletedSectionIndexes];
    
    // We can't move sections that contain reloaded items due to rdar://27041784 . See `testReloadingRowInAMovedSection`.
    [_replacedItemIndexes enumerateObjectsUsingBlock:^(NSMutableIndexSet * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
      if (obj.count > 0) {
        [movedSectionIndexes removeIndex:idx];
      }
    }];
    
    // We can't move sections that were reloaded.
    [movedSectionIndexes removeIndexes:_replacedSectionIndexes];
    
    [movedSectionIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
      _movedSectionIndexes[@(idx)] = [NSNull null];
    }];

    // Cannot replace & delete the same section.
    [_deletedSectionIndexes removeIndexes:_replacedSectionIndexes];
    
    // Cannot delete/replace item in deleted/replaced section
    [_deletedSectionIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
      [_replacedItemIndexes[idx] removeAllIndexes];
      [_deletedItemIndexes[idx] removeAllIndexes];
    }];
    [_replacedSectionIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
      [_replacedItemIndexes[idx] removeAllIndexes];
      [_deletedItemIndexes[idx] removeAllIndexes];
    }];
    NSMutableIndexSet *allRemovedSections = [_deletedSectionIndexes mutableCopy];
    [allRemovedSections addIndexes:movedSectionIndexes];
    [_data removeObjectsAtIndexes:allRemovedSections];
    
    // Randomly insert some sections
    NSUInteger endSectionCount = _data.count;
    _insertedSectionIndexes = [NSIndexSet randomIndexesLessThan:(endSectionCount + 1) probability:kFickleness insertMode:YES count:NSNotFound excludingIndexes:nil];
    endSectionCount += _insertedSectionIndexes.count;
    NSIndexSet *moveToSectionIndexes = [NSIndexSet randomIndexesLessThan:(endSectionCount + 1) probability:kFickleness insertMode:YES count:_movedSectionIndexes.count excludingIndexes:_insertedSectionIndexes];
    
    {
      // Copy our "move-to" section indexes into the _movedSectionIndexes dict.
      NSArray *movedFromSectionIndexes = [_movedSectionIndexes allKeys];
      __block NSUInteger i = 0;
      [moveToSectionIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        _movedSectionIndexes[movedFromSectionIndexes[i]] = @(idx);
        i += 1;
      }];
    }
    endSectionCount += moveToSectionIndexes.count;
    
    // Create a combined array of inserted & moved-to sections
    NSMutableArray<ASThrashTestSection *> *allInsertedSections = [NSMutableArray arrayWithCapacity:endSectionCount];
    NSMutableIndexSet *allInsertedSectionIndexes = [NSMutableIndexSet indexSet];
    for (NSInteger i = 0; i < endSectionCount; i++) {
      if ([_insertedSectionIndexes containsIndex:i]) {
        // This section is new. Create one.
        ASThrashTestSection *section = [[ASThrashTestSection alloc] initWithCount:kInitialItemCount];
        [_insertedSections addObject:section];
        [allInsertedSections addObject:section];
        [allInsertedSectionIndexes addIndex:i];
      } else {
        // This section was moved. Find the old index.
        NSNumber *oldIndex = [[_movedSectionIndexes keysOfEntriesPassingTest:^(NSNumber * _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
          if ([obj integerValue] == i) {
            *stop = YES;
            return YES;
          }
          return NO;
        }] anyObject];
        if (oldIndex != nil) {
          ASThrashTestSection *section = _oldData[oldIndex.integerValue];
          [allInsertedSections addObject:[section copy]];
          [allInsertedSectionIndexes addIndex:i];
        }
      }
    }
    [_data insertObjects:allInsertedSections atIndexes:allInsertedSectionIndexes];
    
    // Randomly insert some items
    // Right now we put all moved items into the first surviving section.
    // In the future we could distribute them evenly or randomly.
    __block BOOL handledMovedItems = NO;
    [_data enumerateObjectsUsingBlock:^(ASThrashTestSection * _Nonnull section, NSUInteger sectionIndex, BOOL * _Nonnull stop) {
      // Only insert items into the old sections – not replaced/inserted sections.
      if (![_oldData containsObject:section]) {
        [_insertedItems addObject:[NSMutableArray array]];
        [_insertedItemIndexes addObject:[NSMutableIndexSet indexSet]];
        
      } else {
        NSInteger newItemCount = section.items.count;
        NSMutableIndexSet *newItemIndexes = [NSIndexSet randomIndexesLessThan:(newItemCount + 1) probability:kFickleness insertMode:YES count:NSNotFound excludingIndexes:nil];
        newItemCount += newItemIndexes.count;
        
        NSMutableIndexSet *movedToIndexes = nil;
        if (!handledMovedItems) {
          movedToIndexes = [NSIndexSet randomIndexesLessThan:(newItemCount + 1) probability:kFickleness insertMode:YES count:_movedItemIndexPaths.count excludingIndexes:newItemIndexes];
          
          // Copy our "move-to" index paths into the _movedItemIndexPaths dict.
          {
            NSArray *movedFromItemIndexPaths = [_movedItemIndexPaths allKeys];
            __block NSUInteger i = 0;
            [[movedToIndexes indexPathsInSection:sectionIndex] enumerateObjectsUsingBlock:^(NSIndexPath * _Nonnull toIndexPath, NSUInteger idx, BOOL * _Nonnull stop) {
              _movedItemIndexPaths[movedFromItemIndexPaths[i]] = toIndexPath;
              i += 1;
            }];
          }
          
          handledMovedItems = YES;
        } else {
          movedToIndexes = [NSMutableIndexSet indexSet];
        }
        
        newItemCount += movedToIndexes.count;
        NSMutableArray<ASThrashTestItem *> *allInsertedItems = [NSMutableArray arrayWithCapacity:newItemCount];
        NSMutableArray<ASThrashTestItem *> *newItems = [NSMutableArray arrayWithCapacity:newItemIndexes.count];
        NSMutableIndexSet *allInsertedIndexes = [NSMutableIndexSet indexSet];
        for (NSInteger i = 0; i < newItemCount; i++) {
          if ([newItemIndexes containsIndex:i]) {
            // If this is a new item, create one
            ASThrashTestItem *item = [[ASThrashTestItem alloc] init];
            [newItems addObject:item];
            [allInsertedItems addObject:item];
            [allInsertedIndexes addIndex:i];
          } else {
            // If this is a moved item, find the original item:
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:i inSection:sectionIndex];
            NSIndexPath *oldIndexPath = [[_movedItemIndexPaths keysOfEntriesPassingTest:^(NSIndexPath * _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
              if ([indexPath isEqual:obj]) {
                *stop = YES;
                return YES;
              }
              return NO;
            }] anyObject];
            if (oldIndexPath != nil) {
              ASThrashTestItem *item = _oldData[oldIndexPath.section].items[oldIndexPath.item];
              [allInsertedItems addObject:item];
              [allInsertedIndexes addIndex:i];
            }
          }
        }
        [section.items insertObjects:allInsertedItems atIndexes:allInsertedIndexes];
        [_insertedItems addObject:newItems];
        [_insertedItemIndexes addObject:newItemIndexes];
      }
      
      // Filter out redundant section moves as these cause issues inside UITableView
      [[_movedSectionIndexes copy] enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if ([self newSectionForOldSectionExcludingMove:[key integerValue]] == [obj integerValue]) {
          [_movedSectionIndexes removeObjectForKey:key];
        }
      }];
      
    }];
  }
  return self;
}

- (NSInteger)newSectionForOldSectionExcludingMove:(NSInteger)oldSection {
  NSMutableIndexSet *combinedDeletes = [_deletedSectionIndexes mutableCopy];
  NSMutableIndexSet *combinedInserts = [_insertedSectionIndexes mutableCopy];
  [_movedSectionIndexes enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
    if (key.integerValue != oldSection) {
      [combinedDeletes addIndex:key.integerValue];
      [combinedInserts addIndex:[obj integerValue]];
    }
  }];
  NSInteger result = oldSection;
  result -= [combinedDeletes countOfIndexesInRange:NSMakeRange(0, oldSection)];
  result += [combinedInserts as_indexChangeByInsertingItemsBelowIndex:result];
  return result;
}

+ (BOOL)supportsSecureCoding {
  return YES;
}

+ (ASThrashUpdate *)thrashUpdateWithBase64String:(NSString *)base64 {
  return [NSKeyedUnarchiver unarchiveObjectWithData:[[NSData alloc] initWithBase64EncodedString:base64 options:kNilOptions]];
}

- (NSString *)base64Representation {
  return [[NSKeyedArchiver archivedDataWithRootObject:self] base64EncodedStringWithOptions:kNilOptions];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  NSDictionary *dict = [self dictionaryWithValuesForKeys:@[
   @"oldData",
   @"data",
   @"deletedSectionIndexes",
   @"replacedSectionIndexes",
   @"insertedSectionIndexes",
   @"insertedSections",
   @"deletedItemIndexes",
   @"replacedItemIndexes",
   @"insertedItemIndexes",
   @"insertedItems",
   @"movedItemIndexPaths",
   @"movedSectionIndexes"
   ]];
  [aCoder encodeObject:dict forKey:@"_dict"];
  [aCoder encodeInteger:ASThrashUpdateCurrentSerializationVersion forKey:@"_version"];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  self = [super init];
  if (self != nil) {
    NSAssert(ASThrashUpdateCurrentSerializationVersion == [aDecoder decodeIntegerForKey:@"_version"], @"This thrash update was archived from a different version and can't be read. Sorry.");
    NSDictionary *dict = [aDecoder decodeObjectOfClass:[NSDictionary class] forKey:@"_dict"];
    [self setValuesForKeysWithDictionary:dict];
  }
  return self;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<ASThrashUpdate %p:\nOld data: %@\nDeleted items: %@\nDeleted sections: %@\nMoved items: %@\nMoved sections: %@\nReplaced items: %@\nReplaced sections: %@\nInserted items: %@\nInserted sections: %@\nNew data: %@>", self, ASThrashArrayDescription(_oldData), ASThrashArrayDescription(_deletedItemIndexes), _deletedSectionIndexes, _movedItemIndexPaths, _movedSectionIndexes, ASThrashArrayDescription(_replacedItemIndexes), _replacedSectionIndexes, ASThrashArrayDescription(_insertedItemIndexes), _insertedSectionIndexes, ASThrashArrayDescription(_data)];
}

- (NSString *)logFriendlyBase64Representation {
  return [NSString stringWithFormat:@"\n\n**********\nBase64 Representation:\n**********\n%@\n**********\nEnd Base64 Representation\n**********", self.base64Representation];
}

@end

@interface ASTableViewThrashTests: XCTestCase
@end

@implementation ASTableViewThrashTests {
  // The current update, which will be logged in case of a failure.
  ASThrashUpdate *_update;
  BOOL _failed;
}

#pragma mark Overrides

- (void)tearDown {
  if (_failed && _update != nil) {
    NSLog(@"Failed update %@: %@", _update, _update.logFriendlyBase64Representation);
  }
  _failed = NO;
  _update = nil;
}

// NOTE: Despite the documentation, this is not always called if an exception is caught.
- (void)recordFailureWithDescription:(NSString *)description inFile:(NSString *)filePath atLine:(NSUInteger)lineNumber expected:(BOOL)expected {
  _failed = YES;
  [super recordFailureWithDescription:description inFile:filePath atLine:lineNumber expected:expected];
}

#pragma mark Test Methods

- (void)testInitialDataRead {
  ASThrashDataSource *ds = [[ASThrashDataSource alloc] initWithData:[ASThrashTestSection sectionsWithCount:kInitialSectionCount]];
  [self verifyDataSource:ds];
}

/// Replays the Base64 representation of an ASThrashUpdate from "ASThrashTestRecordedCase" file
- (void)testRecordedThrashCase {
  NSURL *caseURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"ASThrashTestRecordedCase" withExtension:nil subdirectory:@"TestResources"];
  NSString *base64 = [NSString stringWithContentsOfURL:caseURL encoding:NSUTF8StringEncoding error:NULL];
  
  _update = [ASThrashUpdate thrashUpdateWithBase64String:base64];
  if (_update == nil) {
    return;
  }
  
  ASThrashDataSource *ds = [[ASThrashDataSource alloc] initWithData:_update.oldData];
#if !USE_UIKIT_REFERENCE
  ds.tableView.test_enableSuperUpdateCallLogging = YES;
#endif
  [self applyUpdate:_update toDataSource:ds];
  [self verifyDataSource:ds];
}

- (void)testThrashingWildly {
  for (NSInteger i = 0; i < kThrashingIterationCount; i++) {
    [self setUp];
    ASThrashDataSource *ds = [[ASThrashDataSource alloc] initWithData:[ASThrashTestSection sectionsWithCount:kInitialSectionCount]];
    _update = [[ASThrashUpdate alloc] initWithData:ds.data];
    
    [self applyUpdate:_update toDataSource:ds];
    [self verifyDataSource:ds];
    [self tearDown];
  }
}

#if USE_UIKIT_REFERENCE

/**
 This is a bug in UIKit where table view will throw an exception if you reload a row
 and move its section during the same update. rdar://27041784
 */
- (void)testReloadingARowInAMovedSection {
  ASThrashDataSource *ds = [[ASThrashDataSource alloc] initWithData:[ASThrashTestSection sectionsWithCount:2]];
  [ds.tableView beginUpdates];
  [ds.tableView reloadRowsAtIndexPaths:@[ [NSIndexPath indexPathForItem:0 inSection:1] ] withRowAnimation:UITableViewRowAnimationNone];
  [ds.tableView moveSection:1 toSection:0];
  XCTAssertThrows([ds.tableView endUpdates]);
  [self verifyDataSource:ds];
}

/**
 
 */
- (void)testReloadingARowInSectionThatIsMovedBecauseOfOtherMoves {
  ASThrashDataSource *ds = [[ASThrashDataSource alloc] initWithData:[ASThrashTestSection sectionsWithCount:3]];
  [ds.tableView beginUpdates];
  [ds.tableView reloadRowsAtIndexPaths:@[ [NSIndexPath indexPathForItem:0 inSection:1] ] withRowAnimation:UITableViewRowAnimationNone];
  [ds.tableView moveSection:0 toSection:2];
  XCTAssertThrows([ds.tableView endUpdates]);
  [self verifyDataSource:ds];
}

/**
 This verifies UIKit behavior where an exception is generated if you reload and move the same section.
 It's not _quite_ a bug, since you should probably just delete the section and insert a section
 somewhere else.
 */
- (void)testMovingAndReloadingASection {
  ASThrashDataSource *ds = [[ASThrashDataSource alloc] initWithData:[ASThrashTestSection sectionsWithCount:2]];
  [ds.tableView beginUpdates];
  [ds.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
  [ds.tableView moveSection:1 toSection:0];
  XCTAssertThrows([ds.tableView endUpdates]);
  [self verifyDataSource:ds];
}

#endif

#pragma mark Helpers

- (void)applyUpdate:(ASThrashUpdate *)update toDataSource:(ASThrashDataSource *)dataSource {
  TableView *tableView = dataSource.tableView;
  
  [tableView beginUpdates];
  dataSource.data = update.data;
  
  [tableView insertSections:update.insertedSectionIndexes withRowAnimation:UITableViewRowAnimationNone];
  
  [tableView deleteSections:update.deletedSectionIndexes withRowAnimation:UITableViewRowAnimationNone];
  
  [tableView reloadSections:update.replacedSectionIndexes withRowAnimation:UITableViewRowAnimationNone];
  
  [update.movedItemIndexPaths enumerateKeysAndObjectsUsingBlock:^(NSIndexPath * _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
    ASDisplayNodeAssert([obj isKindOfClass:[NSIndexPath class]], @"No destination index path given for item move from %@", key);
    [tableView moveRowAtIndexPath:key toIndexPath:obj];
  }];
  
  [update.movedSectionIndexes enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
    ASDisplayNodeAssert([obj isKindOfClass:[NSNumber class]], @"No destination index given for section move from %@", key);
    [tableView moveSection:key.integerValue toSection:[obj integerValue]];
  }];
  
  [update.insertedItemIndexes enumerateObjectsUsingBlock:^(NSMutableIndexSet * _Nonnull indexes, NSUInteger idx, BOOL * _Nonnull stop) {
    NSArray *indexPaths = [indexes indexPathsInSection:idx];
    [tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
  }];
  
  [update.deletedItemIndexes enumerateObjectsUsingBlock:^(NSMutableIndexSet * _Nonnull indexes, NSUInteger sec, BOOL * _Nonnull stop) {
    NSArray *indexPaths = [indexes indexPathsInSection:sec];
    [tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
  }];
  
  [update.replacedItemIndexes enumerateObjectsUsingBlock:^(NSMutableIndexSet * _Nonnull indexes, NSUInteger sec, BOOL * _Nonnull stop) {
    NSArray *indexPaths = [indexes indexPathsInSection:sec];
    [tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
  }];
  @try {
    [tableView endUpdates];
#if !USE_UIKIT_REFERENCE
    [tableView waitUntilAllUpdatesAreCommitted];
#endif
  } @catch (NSException *exception) {
    _failed = YES;
    @throw exception;
  }
}

- (void)verifyDataSource:(ASThrashDataSource *)ds {
  TableView *tableView = ds.tableView;
  NSArray <ASThrashTestSection *> *data = [ds data];
  XCTAssertEqual(data.count, tableView.numberOfSections);
  for (NSInteger i = 0; i < tableView.numberOfSections; i++) {
    XCTAssertEqual([tableView numberOfRowsInSection:i], data[i].items.count);
    XCTAssertEqual([tableView rectForHeaderInSection:i].size.height, data[i].headerHeight);
    
    for (NSInteger j = 0; j < [tableView numberOfRowsInSection:i]; j++) {
      NSIndexPath *indexPath = [NSIndexPath indexPathForItem:j inSection:i];
      ASThrashTestItem *item = data[i].items[j];
#if USE_UIKIT_REFERENCE
      XCTAssertEqual([tableView rectForRowAtIndexPath:indexPath].size.height, item.rowHeight);
#else
      ASThrashTestNode *node = (ASThrashTestNode *)[tableView nodeForRowAtIndexPath:indexPath];
      XCTAssertEqualObjects(node.item, item, @"Wrong node at index path %@", indexPath);
#endif
    }
  }
}

@end
