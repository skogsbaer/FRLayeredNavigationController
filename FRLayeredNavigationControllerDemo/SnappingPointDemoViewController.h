//
//  SnappingPointDemoViewController.h
//  FRLayeredNavigationController
//
//  Created by Stefan Wehr on 31.08.12.
//
//

#import <UIKit/UIKit.h>

#import "FRLayeredNavigationItem.h"

@interface SnappingPointDemoViewController : UITableViewController {
    @private
    NSInteger _index;
    UILabel *_geoLabel;
    UILabel *_configLabel;
}

- (id)initWithIndex:(NSInteger)index;

- (void (^)(FRLayeredNavigationItem *item))configuration;
- (BOOL)hasMaximumWidth;

@end
