//
//  ASTableViewInternal.h
//  AsyncDisplayKit
//
//  Copyright (c) 2016-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASCollectionView.h>

@interface ASCollectionView (Internal)

/// Set YES and we'll log every time we call [super insertRows…] etc
@property (nonatomic) BOOL test_enableSuperUpdateCallLogging;

@end
