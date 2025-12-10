/**
 * AutoClicker V2 - 修复版
 * 改进：
 * 1. 小窗口配置界面（不铺满屏幕）
 * 2. 点击开始后自动隐藏界面
 * 3. 正确点击主应用窗口
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// ========== 全局变量 ==========
static UIWindow *configWindow = nil;
static UIWindow *mainAppWindow = nil;

// ========== 小窗口配置界面 ==========

@interface AutoClickerConfigView : UIView <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *xTextField;
@property (nonatomic, strong) UITextField *yTextField;
@property (nonatomic, strong) UITextField *countTextField;
@property (nonatomic, strong) UITextField *intervalTextField;
@property (nonatomic, strong) UISwitch *infiniteSwitch;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *startButton;
@property (nonatomic, strong) UIButton *stopButton;
@property (nonatomic, strong) UIButton *minimizeButton;

@property (nonatomic, strong) NSTimer *clickTimer;
@property (nonatomic, assign) NSInteger currentClickCount;
@property (nonatomic, assign) NSInteger totalClicks;
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, assign) CGPoint clickPoint;

- (void)show;
- (void)hide;
@end

@implementation AutoClickerConfigView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    // 背景
    self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.95];
    self.layer.cornerRadius = 15;
    self.layer.borderWidth = 2;
    self.layer.borderColor = [UIColor orangeColor].CGColor;

    CGFloat padding = 15;
    CGFloat y = 15;
    CGFloat width = self.bounds.size.width - padding * 2;

    // 标题栏
    UIView *titleBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, 40)];
    titleBar.backgroundColor = [[UIColor orangeColor] colorWithAlphaComponent:0.3];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, 0, width - 60, 40)];
    titleLabel.text = @"🎯 自动点击";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [titleBar addSubview:titleLabel];

    // 最小化按钮
    self.minimizeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.minimizeButton.frame = CGRectMake(self.bounds.size.width - 40, 5, 30, 30);
    [self.minimizeButton setTitle:@"✕" forState:UIControlStateNormal];
    [self.minimizeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.minimizeButton.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [self.minimizeButton addTarget:self action:@selector(minimizeTapped) forControlEvents:UIControlEventTouchUpInside];
    [titleBar addSubview:self.minimizeButton];

    [self addSubview:titleBar];
    y = 50;

    // 坐标输入
    [self addLabel:@"坐标:" atY:y];
    y += 25;

    UIView *coordView = [[UIView alloc] initWithFrame:CGRectMake(padding, y, width, 35)];

    UILabel *xLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 5, 25, 25)];
    xLabel.text = @"X:";
    xLabel.textColor = [UIColor whiteColor];
    xLabel.font = [UIFont systemFontOfSize:14];
    [coordView addSubview:xLabel];

    self.xTextField = [self createTextField:CGRectMake(30, 0, width/2 - 50, 30) placeholder:@"100"];
    [coordView addSubview:self.xTextField];

    UILabel *yLabel = [[UILabel alloc] initWithFrame:CGRectMake(width/2 + 5, 5, 25, 25)];
    yLabel.text = @"Y:";
    yLabel.textColor = [UIColor whiteColor];
    yLabel.font = [UIFont systemFontOfSize:14];
    [coordView addSubview:yLabel];

    self.yTextField = [self createTextField:CGRectMake(width/2 + 35, 0, width/2 - 50, 30) placeholder:@"200"];
    [coordView addSubview:self.yTextField];

    [self addSubview:coordView];
    y += 45;

    // 点击次数
    [self addLabel:@"次数:" atY:y];
    y += 25;

    UIView *countView = [[UIView alloc] initWithFrame:CGRectMake(padding, y, width, 35)];

    self.countTextField = [self createTextField:CGRectMake(0, 0, width - 120, 30) placeholder:@"100"];
    [countView addSubview:self.countTextField];

    UILabel *infiniteLabel = [[UILabel alloc] initWithFrame:CGRectMake(width - 110, 5, 60, 25)];
    infiniteLabel.text = @"无限";
    infiniteLabel.textColor = [UIColor whiteColor];
    infiniteLabel.font = [UIFont systemFontOfSize:14];
    [countView addSubview:infiniteLabel];

    self.infiniteSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(width - 50, 0, 50, 30)];
    self.infiniteSwitch.transform = CGAffineTransformMakeScale(0.8, 0.8);
    [self.infiniteSwitch addTarget:self action:@selector(infiniteSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [countView addSubview:self.infiniteSwitch];

    [self addSubview:countView];
    y += 45;

    // 点击间隔
    [self addLabel:@"间隔(秒):" atY:y];
    y += 25;
    self.intervalTextField = [self createTextField:CGRectMake(padding, y, width, 30) placeholder:@"1.0"];
    [self addSubview:self.intervalTextField];
    y += 45;

    // 状态显示
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, y, width, 25)];
    self.statusLabel.text = @"待机中";
    self.statusLabel.textColor = [UIColor greenColor];
    self.statusLabel.font = [UIFont boldSystemFontOfSize:14];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    [self addSubview:self.statusLabel];
    y += 35;

    // 开始停止按钮
    UIView *buttonView = [[UIView alloc] initWithFrame:CGRectMake(padding, y, width, 40)];

    self.startButton = [self createButton:@"▶️"
                                     frame:CGRectMake(0, 0, width/2 - 5, 40)
                                    action:@selector(startClicking)];
    self.startButton.backgroundColor = [[UIColor greenColor] colorWithAlphaComponent:0.3];
    [buttonView addSubview:self.startButton];

    self.stopButton = [self createButton:@"⏹"
                                    frame:CGRectMake(width/2 + 5, 0, width/2 - 5, 40)
                                   action:@selector(stopClicking)];
    self.stopButton.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.3];
    self.stopButton.enabled = NO;
    [buttonView addSubview:self.stopButton];

    [self addSubview:buttonView];

    // 添加拖动手势
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self addGestureRecognizer:panGesture];
}

- (void)addLabel:(NSString *)text atY:(CGFloat)y {
    CGFloat padding = 15;
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(padding, y, self.bounds.size.width - padding * 2, 20)];
    label.text = text;
    label.textColor = [UIColor lightGrayColor];
    label.font = [UIFont systemFontOfSize:12];
    [self addSubview:label];
}

- (UITextField *)createTextField:(CGRect)frame placeholder:(NSString *)placeholder {
    UITextField *textField = [[UITextField alloc] initWithFrame:frame];
    textField.placeholder = placeholder;
    textField.textColor = [UIColor whiteColor];
    textField.borderStyle = UITextBorderStyleRoundedRect;
    textField.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.1];
    textField.keyboardType = UIKeyboardTypeDecimalPad;
    textField.delegate = self;
    textField.font = [UIFont systemFontOfSize:14];

    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissKeyboard)];
    toolbar.items = @[flexSpace, doneButton];
    textField.inputAccessoryView = toolbar;

    return textField;
}

- (UIButton *)createButton:(NSString *)title frame:(CGRect)frame action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = frame;
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    button.layer.cornerRadius = 8;
    button.layer.borderWidth = 1;
    button.layer.borderColor = [UIColor whiteColor].CGColor;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)dismissKeyboard {
    [self endEditing:YES];
}

- (void)infiniteSwitchChanged:(UISwitch *)sender {
    self.countTextField.enabled = !sender.isOn;
    if (sender.isOn) {
        self.countTextField.text = @"∞";
    } else {
        self.countTextField.text = @"100";
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.superview];
    CGRect newFrame = self.frame;
    newFrame.origin.x += translation.x;
    newFrame.origin.y += translation.y;
    self.frame = newFrame;
    [gesture setTranslation:CGPointZero inView:self.superview];
}

- (void)minimizeTapped {
    [self hide];
}

- (void)startClicking {
    if (self.xTextField.text.length == 0 || self.yTextField.text.length == 0) {
        [self showAlert:@"请输入坐标"];
        return;
    }

    if (!self.infiniteSwitch.isOn && self.countTextField.text.length == 0) {
        [self showAlert:@"请输入点击次数"];
        return;
    }

    if (self.intervalTextField.text.length == 0) {
        [self showAlert:@"请输入点击间隔"];
        return;
    }

    CGFloat x = [self.xTextField.text floatValue];
    CGFloat y = [self.yTextField.text floatValue];
    NSInteger count = self.infiniteSwitch.isOn ? -1 : [self.countTextField.text integerValue];
    CGFloat interval = [self.intervalTextField.text floatValue];

    if (interval < 0.1) {
        [self showAlert:@"间隔不能小于0.1秒"];
        return;
    }

    self.clickPoint = CGPointMake(x, y);
    self.currentClickCount = 0;
    self.totalClicks = count;
    self.isRunning = YES;
    self.startButton.enabled = NO;
    self.stopButton.enabled = YES;

    // 隐藏配置界面
    [self hide];

    // 开始定时点击
    self.clickTimer = [NSTimer scheduledTimerWithTimeInterval:interval repeats:YES block:^(NSTimer *timer) {
        if (!self.isRunning) {
            [timer invalidate];
            return;
        }

        [self performClick];

        self.currentClickCount++;

        if (self.totalClicks != -1 && self.currentClickCount >= self.totalClicks) {
            [self stopClicking];
        }
    }];

    NSLog(@"[AutoClicker] 开始 - 坐标:(%.0f, %.0f) 次数:%ld 间隔:%.1f秒", x, y, (long)count, interval);
}

- (void)stopClicking {
    self.isRunning = NO;

    if (self.clickTimer) {
        [self.clickTimer invalidate];
        self.clickTimer = nil;
    }

    self.startButton.enabled = YES;
    self.stopButton.enabled = NO;

    self.statusLabel.text = [NSString stringWithFormat:@"完成 (共%ld次)", (long)self.currentClickCount];
    self.statusLabel.textColor = [UIColor cyanColor];

    NSLog(@"[AutoClicker] 停止 (共点击 %ld 次)", (long)self.currentClickCount);
}

- (void)performClick {
    // 获取主应用窗口（不是配置窗口）
    UIWindow *targetWindow = mainAppWindow;

    if (!targetWindow) {
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window != configWindow && window.isKeyWindow) {
                targetWindow = window;
                mainAppWindow = window;
                break;
            }
        }
    }

    if (!targetWindow) {
        NSLog(@"[AutoClicker] 无法获取主窗口");
        return;
    }

    // 在主窗口上查找目标视图
    UIView *targetView = [targetWindow hitTest:self.clickPoint withEvent:nil];

    if (targetView) {
        if ([targetView isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)targetView;
            [button sendActionsForControlEvents:UIControlEventTouchUpInside];
            NSLog(@"[AutoClicker] 点击按钮: %@", button.titleLabel.text);
        } else {
            NSLog(@"[AutoClicker] 点击视图: %@", NSStringFromClass([targetView class]));
        }
    }

    // 视觉反馈
    [self showClickFeedbackAtPoint:self.clickPoint inWindow:targetWindow];

    // 更新状态（如果窗口可见）
    if (configWindow.hidden == NO) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.totalClicks == -1) {
                self.statusLabel.text = [NSString stringWithFormat:@"已点击 %ld 次", (long)self.currentClickCount];
            } else {
                self.statusLabel.text = [NSString stringWithFormat:@"%ld/%ld 次", (long)self.currentClickCount, (long)self.totalClicks];
            }
            self.statusLabel.textColor = [UIColor greenColor];
        });
    }
}

- (void)showClickFeedbackAtPoint:(CGPoint)point inWindow:(UIWindow *)window {
    UIView *feedbackView = [[UIView alloc] initWithFrame:CGRectMake(point.x - 20, point.y - 20, 40, 40)];
    feedbackView.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.5];
    feedbackView.layer.cornerRadius = 20;
    feedbackView.userInteractionEnabled = NO;
    [window addSubview:feedbackView];

    [UIView animateWithDuration:0.3 animations:^{
        feedbackView.alpha = 0;
        feedbackView.transform = CGAffineTransformMakeScale(1.5, 1.5);
    } completion:^(BOOL finished) {
        [feedbackView removeFromSuperview];
    }];
}

- (void)showAlert:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];

    UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    if (rootVC) {
        [rootVC presentViewController:alert animated:YES completion:nil];
    }
}

- (void)show {
    if (configWindow) {
        configWindow.hidden = NO;
    }
}

- (void)hide {
    if (configWindow) {
        configWindow.hidden = YES;
    }
}

- (void)dealloc {
    [self stopClicking];
}

@end

// ========== 悬浮按钮 ==========

static UIButton *floatingButton = nil;
static AutoClickerConfigView *configView = nil;

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 保存主应用窗口
        mainAppWindow = self;

        // 创建配置窗口（小窗口）
        CGFloat windowWidth = 320;
        CGFloat windowHeight = 380;
        CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
        CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;

        configWindow = [[UIWindow alloc] initWithFrame:CGRectMake((screenWidth - windowWidth) / 2,
                                                                   (screenHeight - windowHeight) / 2,
                                                                   windowWidth,
                                                                   windowHeight)];
        configWindow.windowLevel = UIWindowLevelAlert + 1;
        configWindow.backgroundColor = [UIColor clearColor];
        configWindow.hidden = YES;

        // 创建配置视图
        configView = [[AutoClickerConfigView alloc] initWithFrame:CGRectMake(0, 0, windowWidth, windowHeight)];
        [configWindow addSubview:configView];

        // 创建悬浮按钮
        floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
        floatingButton.frame = CGRectMake(screenWidth - 70, 100, 60, 60);
        floatingButton.backgroundColor = [[UIColor orangeColor] colorWithAlphaComponent:0.8];
        floatingButton.layer.cornerRadius = 30;
        [floatingButton setTitle:@"🎯" forState:UIControlStateNormal];
        floatingButton.titleLabel.font = [UIFont systemFontOfSize:30];

        [floatingButton addTarget:self action:@selector(toggleConfig) forControlEvents:UIControlEventTouchUpInside];

        UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleFloatingButtonPan:)];
        [floatingButton addGestureRecognizer:panGesture];

        [self addSubview:floatingButton];

        NSLog(@"[AutoClicker] 已加载 - 点击 🎯 打开配置");
    });
}

%new
- (void)toggleConfig {
    if (configWindow.hidden) {
        [configView show];
    } else {
        [configView hide];
    }
}

%new
- (void)handleFloatingButtonPan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self];
    CGRect newFrame = floatingButton.frame;
    newFrame.origin.x += translation.x;
    newFrame.origin.y += translation.y;

    CGFloat maxX = self.bounds.size.width - floatingButton.frame.size.width;
    CGFloat maxY = self.bounds.size.height - floatingButton.frame.size.height;

    newFrame.origin.x = MAX(0, MIN(newFrame.origin.x, maxX));
    newFrame.origin.y = MAX(20, MIN(newFrame.origin.y, maxY));

    floatingButton.frame = newFrame;
    [gesture setTranslation:CGPointZero inView:self];
}

%end

%ctor {
    NSLog(@"[AutoClicker] V2 已加载");
}
