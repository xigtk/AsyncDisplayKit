//
//  LayoutExamplesViewController.m
//  Sample
//
//  Created by Hannah Troisi on 7/7/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  FACEBOOK BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
//  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "LayoutExamplesViewController.h"

@interface LayoutExamplesViewController () <ASCollectionDataSource, ASCollectionDelegate>
@end

@implementation LayoutExamplesViewController
{
    ASCollectionNode *_collectionNode;
}

#pragma mark - Lifecycle

- (instancetype)init
{
    UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
    _collectionNode = [[ASCollectionNode alloc] initWithCollectionViewLayout:flowLayout];
    
    self = [super initWithNode:_collectionNode];
    if (self == nil) { return self; }
    _collectionNode.dataSource = self;
    _collectionNode.delegate = self;
  
    return self;
}

#pragma mark - ASCollectionDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return 1;
}

//- (ASSizeRange)collectionView:(ASCollectionView *)collectionView constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath
//{
//}

- (ASCellNodeBlock)collectionView:(ASCollectionView *)collectionView nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return ^{
        ASCellNode *cellNode = [[ASCellNode alloc] init];
        cellNode.backgroundColor = [UIColor lightGrayColor];
      
        ASTextNode *textNodeOne = [[ASTextNode alloc] init];
        textNodeOne.attributedText = [[NSAttributedString alloc] initWithString:@"firstname lastname"];

      
        ASTextNode *textNodeTwo = [[ASTextNode alloc] init];
        textNodeTwo.attributedText = [[NSAttributedString alloc] initWithString:@"This is a longer text string."];

        ASTextNode *textNodeThree = [[ASTextNode alloc] init];
        textNodeThree.attributedText = [[NSAttributedString alloc] initWithString:@"2d"];
      
        ASNetworkImageNode *imageNode = [[ASNetworkImageNode alloc] init];
        imageNode.URL = [NSURL URLWithString:@"https://avatars0.githubusercontent.com/u/565251?v=3&s=400"];
      
        ASLayoutSpecBlock layoutSpecBlock = nil;
      
        // Picture with text overlay
        if (indexPath.row == 0) {
            [cellNode addSubnode:textNodeOne];
            [cellNode addSubnode:textNodeTwo];
            [cellNode addSubnode:textNodeThree];
            [cellNode addSubnode:imageNode];
          
            imageNode.preferredFrameSize = CGSizeMake(50, 50);
            imageNode.cornerRadius = 25;
        
             layoutSpecBlock = ^ASLayoutSpec *(ASDisplayNode * _Nonnull node, ASSizeRange constrainedSize) {
                ASStackLayoutSpec *verticalStack = [ASStackLayoutSpec verticalStackLayoutSpec];
                verticalStack.children = @[textNodeOne, textNodeTwo];
               
                ASLayoutSpec *spacer = [[ASLayoutSpec alloc] init];
                spacer.flexGrow = YES;
               
                ASStackLayoutSpec *horizontalStack = [ASStackLayoutSpec horizontalStackLayoutSpec];
                horizontalStack.children = @[imageNode, verticalStack, spacer, textNodeThree];
               
                UIEdgeInsets insets = UIEdgeInsetsMake(10, 10, 10, 10);
                ASInsetLayoutSpec *insetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:insets child:horizontalStack];
               
                return insetSpec;
            };
        } else if (indexPath.row == 1) {
        
        
        }
      
        cellNode.layoutSpecBlock = layoutSpecBlock;
        return cellNode;
    };
}


@end
