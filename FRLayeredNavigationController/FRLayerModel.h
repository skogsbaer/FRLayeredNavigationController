//
//  FRLayerModel.h
//  FRLayeredNavigationController
//
//  Created by Stefan Wehr on 28.08.12.
//
//

#import <Foundation/Foundation.h>

#import "FRLayerController.h"

typedef NSArray FRLayerControllersOperations;

// Responsibilities:
// - Updates initialViewPosition, currentViewPosition and currentWidth
// - Does *not* model the fade-in/fade-out animations when pushing/popping a layer
@interface FRLayerModel : NSObject {
    @private
    NSMutableArray *_viewControllers;
    CGFloat _width;
}

- (NSArray *)layeredViewControllers;
- (FRLayerController *)rootLayerViewController;
- (FRLayerController *)topLayerViewController;
- (CGFloat)pushLayerController:(FRLayerController *)ctrl;
- (FRLayerController *)popLayerController;
- (void)setWidth:(CGFloat)width;
- (BOOL)areViewControllersMaximallyCompressed;

@end
