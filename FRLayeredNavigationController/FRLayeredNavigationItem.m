/*
 * This file is part of FRLayeredNavigationController.
 *
 * Copyright (c) 2012, Johannes Weiß <weiss@tux4u.de>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * The name of the author may not be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "FRLayeredNavigationItem+Protected.h"
#import "FRLayerController+Protected.h"
#import "FRLayerController.h"
#import "FRLayerChromeView.h"
#import "FRLayeredNavigationControllerConstants.h"

@interface FRLayerSnappingPoint ()
- (id)initWithX:(CGFloat)x priority:(NSInteger)priority;
@end

@implementation FRLayerSnappingPoint

- (id)initWithX:(CGFloat)x priority:(NSInteger)priority {
    if ((self = [super init])) {
        self->_x = x;
        self->_priority = priority;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"FRLayerSnappingPoint { x=%f, priority=%d }", self.x, self.priority];
}

@synthesize x = _x;
@synthesize priority = _priority;
@end

@interface FRLayeredNavigationItem ()

@property (nonatomic, readwrite, weak) FRLayerController *layerController;
@property (nonatomic, readwrite) CGPoint initialViewPosition;
@property (nonatomic, readwrite) CGPoint currentViewPosition;
@property (nonatomic, readwrite) CGFloat currentWidth;
@property (nonatomic, readwrite) NSMutableSet *internalSnappingPoints;

@end

@implementation FRLayeredNavigationItem

- (id)init
{
    if ((self = [super init])) {
        self->_width = -1;
        self->_nextItemDistance = FRLayeredNavigationControllerNoNextItemDistance;
        self->_resizePriority = FRLayeredNavigationControllerResizeDefaultPriority;
        self->_rightMarginSnappingPriority = FRLayeredNavigationControllerRightMarginSnappingDefaultPriority;
        self->_hasChrome = YES;
        self->_displayShadow = YES;
        self.internalSnappingPoints = [NSMutableSet set];
    }

    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"FRLayeredNavigationItem { name=%@, initialViewPosition=%@, "
            @"currentViewPosition=%@, width=%f, currentWidth=%f, nextItemDistance=%f, title=%@, hasChrome=%d, "
            @"displayShadow=%d, snappingPoints=%@",
            self.name, NSStringFromCGPoint(self.initialViewPosition), NSStringFromCGPoint(self.currentViewPosition),
            self.width, self.currentWidth, self.nextItemDistance, self.title,
            self.hasChrome, self.displayShadow, self.internalSnappingPoints];
}

- (void)setLeftBarButtonItem:(UIBarButtonItem *)leftBarButtonItem
{
    self.layerController.chromeView.leftBarButtonItem = leftBarButtonItem;
}

- (UIBarButtonItem *)leftBarButtonItem
{
    return self.layerController.chromeView.leftBarButtonItem;
}

- (void)setRightBarButtonItem:(UIBarButtonItem *)rightBarButtonItem
{
    self.layerController.chromeView.rightBarButtonItem = rightBarButtonItem;
}

- (UIBarButtonItem *)rightBarButtonItem
{
    return self.layerController.chromeView.rightBarButtonItem;
}

- (void)addSnappingPointX:(CGFloat)x priority:(NSInteger)priority
{
    FRLayerSnappingPoint *p = [[FRLayerSnappingPoint alloc] initWithX:x
                                                             priority:priority];
    [self.internalSnappingPoints addObject:p];
}

- (NSSet *)snappingPoints
{
    NSMutableSet *set = [self.internalSnappingPoints mutableCopy];
    if (self.nextItemDistance >= 0) {
        FRLayerSnappingPoint *p = [[FRLayerSnappingPoint alloc]
                                   initWithX:self.nextItemDistance
                                    priority:FRLayeredNavigationControllerSnappingPointDefaultPriority];
        [set addObject:p];
    }
    return set;
}

@synthesize initialViewPosition = _initialViewPosition;
@synthesize currentViewPosition = _currentViewPosition;
@synthesize title = _title;
@synthesize titleView = _titleView;
@synthesize width = _width;
@synthesize resizePriority = _resizePriority;
@synthesize rightMarginSnappingPriority = _rightMarginSnappingPriority;
@synthesize nextItemDistance = _nextItemDistance;
@synthesize hasChrome = _hasChrome;
@synthesize displayShadow = _displayShadow;
@synthesize layerController = _layerController;
@synthesize internalSnappingPoints = _internalSnappingPoints;
@synthesize name = _name;
@end
