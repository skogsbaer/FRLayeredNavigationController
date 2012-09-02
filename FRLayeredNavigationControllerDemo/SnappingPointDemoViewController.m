//
//  SnappingPointDemoViewController.m
//  FRLayeredNavigationController
//
//  Created by Stefan Wehr on 31.08.12.
//
//

#import "SnappingPointDemoViewController.h"

#import "UIViewController+FRLayeredNavigationController.h"

@interface SnappingPointDemoViewController ()
@property (nonatomic, strong) UILabel *geoLabel;
@property (nonatomic, strong) UILabel *configLabel;
@property (nonatomic, strong) NSTimer *timer;
- (void)updateTexts;
@end

@implementation SnappingPointDemoViewController

@synthesize geoLabel = _geoLabel;
@synthesize configLabel = _configLabel;

- (void (^)(FRLayeredNavigationItem *item))configuration
{
    NSInteger index = self->_index;
    return (^(FRLayeredNavigationItem *navItem) {
        navItem.name = [NSString stringWithFormat:@"layer%d", index];
        switch (index) {
            case 0:
                navItem.width = 250;
                [navItem addSnappingPointX:20 priority:1];
                [navItem addSnappingPointX:200 priority:3];
                navItem.rightMarginSnappingPriority = 7;
                break;
            case 1:
                 navItem.width = 280;
                break;
            case 2:
                navItem.width = 230;
                [navItem addSnappingPointX:40 priority:2];
                [navItem addSnappingPointX:150 priority:4];
                navItem.rightMarginSnappingPriority = 8;
                navItem.resizePriority = 6;
                navItem.resizeOnMove = YES;
                break;
            case 3:
                navItem.width = 270;
                navItem.resizePriority = 9;
                navItem.resizeOnMove = YES;
                break;
            default:
                break;
        }
    });
}

- (BOOL)hasMaximumWidth
{
    switch (self->_index) {
        case 0:
            return NO;
        case 1:
            return NO;
        case 2:
            return YES;
        case 3:
            return YES;
        default:
            return NO;
    }
}

- (id)initWithIndex:(NSInteger)index
{
    self = [super initWithStyle: UITableViewStylePlain];
    if (self) {
        self->_index = index;
        self.title = [NSString stringWithFormat:@"Layer %d", index];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    UIColor *color = [UIColor whiteColor];
    switch (self->_index) {
        case 0:
            color = [UIColor magentaColor];
            break;
        case 1:
            color = [UIColor yellowColor];
            break;
        case 2:
            color = [UIColor purpleColor];
            break;
        case 3:
            color = [UIColor cyanColor];
            break;
    }
    self.view.backgroundColor = color;

    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                  target:self
                                                selector:@selector(updateTexts)
                                                userInfo:nil
                                                 repeats:YES];

}

- (void)viewDidUnload
{
    [super viewDidUnload];
    [self.timer invalidate];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (NSString *)geoText
{
    return [NSString stringWithFormat:@"%.0f (x)\n%.0f (width)",
            self.view.superview.frame.origin.x, self.view.superview.frame.size.width];
}

- (NSString *)configText
{
    FRLayeredNavigationItem *item = self.layeredNavigationItem;
    return [NSString stringWithFormat:@"%.0f (initViewPos)\n%.0f (curViewPos)\n%.0f (width)\n"
            @"%.0f (curWidth)\n%d (maxWidth)\nsnapPoints: %@",
            item.initialViewPosition.x, item.currentViewPosition.x, item.width, item.currentWidth,
            self.hasMaximumWidth, item.snappingPoints];
}

- (void)updateTexts
{
    self.geoLabel.text = self.geoText;
    self.configLabel.text = self.configText;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self updateTexts];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return 3;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row > 1) {
        return 500;
    } else {
        return 60;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];

    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }

    NSString *text;
    if (indexPath.row > 1) {
        text = self.configText;
        self.configLabel = cell.textLabel;
    } else if (indexPath.row == 1) {
        text = self.geoText;
        self.geoLabel = cell.textLabel;
    } else {
        text = @"Next";
    }
    cell.textLabel.text = text;
    cell.textLabel.numberOfLines = 0;
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    SnappingPointDemoViewController *vc = [[SnappingPointDemoViewController alloc] initWithIndex:(self->_index + 1)];
    [self.layeredNavigationController pushViewController:vc
                                               inFrontOf:self
                                            maximumWidth:[vc hasMaximumWidth]
                                                animated:YES
                                           configuration:[vc configuration]];
}

@end
