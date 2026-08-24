#import "ViewController.h"
#import "RootSpawn.h"

@interface ViewController ()
@property UILabel *stateLabel;
@property UILabel *detailLabel;
@property UILabel *daemonStatusLabel;
@property UIButton *actionButton;
@property UIActivityIndicatorView *spinner;
@property BOOL otaDisabled;
@property BOOL statusKnown;
@end

@implementation ViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"OTA Toggle"; self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"AppIcon60x60@3x"]];
    icon.translatesAutoresizingMaskIntoConstraints = NO; icon.contentMode=UIViewContentModeScaleAspectFit; icon.layer.cornerRadius = 24; icon.clipsToBounds = YES;
    UIView *iconContainer=UIView.new; iconContainer.translatesAutoresizingMaskIntoConstraints=NO; [iconContainer addSubview:icon];
    self.stateLabel = UILabel.new; self.stateLabel.font = [UIFont systemFontOfSize:28 weight:UIFontWeightBold]; self.stateLabel.textAlignment = NSTextAlignmentCenter;
    self.detailLabel = UILabel.new; self.detailLabel.font = [UIFont systemFontOfSize:15]; self.detailLabel.textColor = UIColor.secondaryLabelColor; self.detailLabel.textAlignment = NSTextAlignmentCenter; self.detailLabel.numberOfLines = 0;
    self.daemonStatusLabel=UILabel.new; self.daemonStatusLabel.font=[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular]; self.daemonStatusLabel.textColor=UIColor.labelColor; self.daemonStatusLabel.numberOfLines=0; self.daemonStatusLabel.textAlignment=NSTextAlignmentLeft;
    self.actionButton = [UIButton buttonWithType:UIButtonTypeSystem]; self.actionButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]; self.actionButton.layer.cornerRadius = 14; self.actionButton.translatesAutoresizingMaskIntoConstraints = NO; [self.actionButton addTarget:self action:@selector(toggleTapped) forControlEvents:UIControlEventTouchUpInside];
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[iconContainer,self.stateLabel,self.detailLabel,self.daemonStatusLabel,self.actionButton,self.spinner]]; stack.axis = UILayoutConstraintAxisVertical; stack.alignment = UIStackViewAlignmentFill; stack.spacing = 18; stack.translatesAutoresizingMaskIntoConstraints = NO; [self.view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[[iconContainer.heightAnchor constraintEqualToConstant:112],[icon.widthAnchor constraintEqualToConstant:112],[icon.heightAnchor constraintEqualToConstant:112],[icon.centerXAnchor constraintEqualToAnchor:iconContainer.centerXAnchor],[icon.centerYAnchor constraintEqualToAnchor:iconContainer.centerYAnchor],[self.actionButton.heightAnchor constraintEqualToConstant:52],[stack.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:28],[stack.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-28],[stack.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-30]]];
    self.stateLabel.text=@"OTA Update Control";
    self.detailLabel.text=@"Check the current OTA daemon status before making a change.";
    self.daemonStatusLabel.text=@"Software Update daemon\nOTA Tasking Agent\nUpdate Services daemon\nNRD Update daemon";
    [self.actionButton setTitle:@"Check OTA Status" forState:UIControlStateNormal];
    self.actionButton.backgroundColor=UIColor.systemBlueColor;
    [self.actionButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [self refresh];
}
- (void)setBusy:(BOOL)busy { self.actionButton.enabled = !busy; busy ? [self.spinner startAnimating] : [self.spinner stopAnimating]; }
- (void)refresh {
    [self setBusy:YES];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0), ^{
        NSString *out=nil,*error=nil; int rc=OTASpawnHelper(@[@"status"],&out,&error);
        BOOL readable=(rc==0);
        NSArray *keys=@[@"com.apple.mobile.softwareupdated",@"com.apple.OTATaskingAgent",@"com.apple.softwareupdateservicesd",@"com.apple.mobile.NRDUpdated"];
        NSMutableDictionary *states=NSMutableDictionary.dictionary;
        for(NSString *line in [out componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
            NSRange separator=[line rangeOfString:@"="]; if(separator.location==NSNotFound) continue;
            states[[line substringToIndex:separator.location]]=[line substringFromIndex:separator.location+1];
        }
        BOOL allDisabled=YES,allEnabled=YES;
        NSMutableArray *statusLines=NSMutableArray.array;
        for(NSString *key in keys) {
            BOOL disabled=[states[key] isEqualToString:@"disabled"];
            allDisabled&=disabled; allEnabled&=!disabled;
            [statusLines addObject:[NSString stringWithFormat:@"%@ %@\n   %@",disabled?@"●":@"○",key,disabled?@"Disabled":@"Enabled"]];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setBusy:NO];
            if(!readable){ [self showError:error.length?error:@"Unable to read disabled.plist."]; return; }
            self.otaDisabled=allDisabled;
            self.statusKnown=YES;
            self.stateLabel.text=allDisabled?@"All Daemons Disabled":(allEnabled?@"All Daemons Enabled":@"Mixed OTA Status");
            self.detailLabel.text=@"Each daemon is shown separately below. Changes apply to all four and require a reboot.";
            self.daemonStatusLabel.text=[statusLines componentsJoinedByString:@"\n\n"];
            [self.actionButton setTitle:allDisabled?@"Enable All OTA Daemons":@"Disable All OTA Daemons" forState:UIControlStateNormal];
            self.actionButton.backgroundColor=allDisabled?UIColor.systemGreenColor:UIColor.systemRedColor;
            [self.actionButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        });
    });
}
- (void)toggleTapped {
    if(!self.statusKnown){ [self refresh]; return; }
    NSString *verb=self.otaDisabled?@"Enable":@"Disable"; UIAlertController *a=[UIAlertController alertControllerWithTitle:[verb stringByAppendingString:@" OTA Updates?"] message:@"This modifies launchd's disabled.plist. Reboot the device for the change to take effect." preferredStyle:UIAlertControllerStyleAlert]; [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]]; [a addAction:[UIAlertAction actionWithTitle:verb style:self.otaDisabled?UIAlertActionStyleDefault:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *x){ [self applyChange]; }]]; [self presentViewController:a animated:YES completion:nil];
}
- (void)applyChange { [self setBusy:YES]; NSString *command=self.otaDisabled?@"enable":@"disable"; dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0), ^{ NSString *out=nil,*err=nil; int rc=OTASpawnHelper(@[command],&out,&err); dispatch_async(dispatch_get_main_queue(), ^{ [self setBusy:NO]; if(rc){[self showError:err.length?err:out];return;} [self refresh]; UIAlertController *done=[UIAlertController alertControllerWithTitle:@"Saved" message:@"Reboot your device now to apply the change." preferredStyle:UIAlertControllerStyleAlert]; [done addAction:[UIAlertAction actionWithTitle:@"Later" style:UIAlertActionStyleCancel handler:nil]]; [done addAction:[UIAlertAction actionWithTitle:@"Reboot Now" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action){ [self rebootDevice]; }]]; [self presentViewController:done animated:YES completion:nil]; }); }); }
- (void)rebootDevice { dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0), ^{ NSString *out=nil,*err=nil; int rc=OTASpawnHelper(@[@"reboot"],&out,&err); if(rc) dispatch_async(dispatch_get_main_queue(), ^{ [self showError:err.length?err:@"Unable to reboot the device."]; }); }); }
- (void)showError:(NSString *)message { UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Operation Failed" message:message.length?message:@"Unknown error" preferredStyle:UIAlertControllerStyleAlert]; [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]]; [self presentViewController:a animated:YES completion:nil]; }
@end
