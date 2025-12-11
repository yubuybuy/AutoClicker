/**
 * AutoClicker V3.7 - 网络拦截版
 * 新增：
 * 1. Hook NSURLSession 拦截所有网络请求
 * 2. 实时显示领券相关请求（URL、Headers、Body）
 * 3. 显示响应数据
 * 4. 绕过 SSL Pinning（在 APP 内部拦截）
 * 5. 为抢券功能做准备
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// ========== 全局变量 ==========
static UIWindow *configWindow = nil;
static UIWindow *mainAppWindow = nil;
static BOOL isCapturingCoordinate = NO; // 是否正在获取坐标模式

// ========== 透明点击捕获层 ==========
@interface CoordinateCaptureView : UIView
@property (nonatomic, copy) void(^onCoordinateCaptured)(CGPoint point);
@end

@implementation CoordinateCaptureView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.3];

        // 添加提示标签
        UILabel *hintLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 100, frame.size.width, 80)];
        hintLabel.text = @"📍 点击获取坐标\n\n点击屏幕任意位置\n坐标将自动填入";
        hintLabel.numberOfLines = 0;
        hintLabel.textAlignment = NSTextAlignmentCenter;
        hintLabel.textColor = [UIColor whiteColor];
        hintLabel.font = [UIFont boldSystemFontOfSize:20];
        [self addSubview:hintLabel];

        // 添加取消按钮
        UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
        cancelButton.frame = CGRectMake((frame.size.width - 100) / 2, frame.size.height - 100, 100, 44);
        [cancelButton setTitle:@"取消" forState:UIControlStateNormal];
        [cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        cancelButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
        cancelButton.layer.cornerRadius = 8;
        cancelButton.layer.borderWidth = 2;
        cancelButton.layer.borderColor = [UIColor whiteColor].CGColor;
        [cancelButton addTarget:self action:@selector(cancelTapped) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:cancelButton];
    }
    return self;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self];

    if (self.onCoordinateCaptured) {
        self.onCoordinateCaptured(point);
    }

    [self removeFromSuperview];
    isCapturingCoordinate = NO;
}

- (void)cancelTapped {
    [self removeFromSuperview];
    isCapturingCoordinate = NO;
}

@end

// ========== 小窗口配置界面 ==========

@interface AutoClickerConfigView : UIView <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *xTextField;
@property (nonatomic, strong) UITextField *yTextField;
@property (nonatomic, strong) UITextField *rangeTextField;  // 新增：范围半径
@property (nonatomic, strong) UITextField *countTextField;
@property (nonatomic, strong) UITextField *intervalTextField;
@property (nonatomic, strong) UISwitch *infiniteSwitch;
@property (nonatomic, strong) UISwitch *randomSwitch;  // 新增：是否随机
@property (nonatomic, strong) UISwitch *networkMonitorSwitch;  // 新增：网络监控开关
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *debugLabel;  // 新增：调试信息
@property (nonatomic, strong) UITextView *networkLogView;  // 新增：网络日志显示
@property (nonatomic, strong) UIButton *startButton;
@property (nonatomic, strong) UIButton *stopButton;
@property (nonatomic, strong) UIButton *captureButton;  // 新增：获取坐标按钮
@property (nonatomic, strong) UIButton *minimizeButton;
@property (nonatomic, strong) UIButton *clearLogButton;  // 新增：清空日志按钮

@property (nonatomic, strong) NSTimer *clickTimer;
@property (nonatomic, assign) NSInteger currentClickCount;
@property (nonatomic, assign) NSInteger totalClicks;
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, assign) CGPoint clickPoint;
@property (nonatomic, assign) CGFloat clickRange;  // 新增：点击范围

- (void)show;
- (void)hide;
- (void)showDebugInfo:(NSString *)info;  // 新增：显示调试信息
- (void)logNetworkRequest:(NSString *)log;  // 新增：记录网络请求
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
    titleLabel.text = @"🎯 自动点击 V3.7";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [titleBar addSubview:titleLabel];

    // 关闭按钮
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
    y += 40;

    // 获取坐标按钮
    self.captureButton = [self createButton:@"📍 点击获取坐标"
                                       frame:CGRectMake(padding, y, width, 35)
                                      action:@selector(captureCoordinateTapped)];
    self.captureButton.backgroundColor = [[UIColor blueColor] colorWithAlphaComponent:0.3];
    self.captureButton.titleLabel.font = [UIFont systemFontOfSize:14];
    [self addSubview:self.captureButton];
    y += 45;

    // 点击范围
    [self addLabel:@"范围 (0=精确点击):" atY:y];
    y += 25;

    UIView *rangeView = [[UIView alloc] initWithFrame:CGRectMake(padding, y, width, 35)];

    self.rangeTextField = [self createTextField:CGRectMake(0, 0, width - 120, 30) placeholder:@"0"];
    [rangeView addSubview:self.rangeTextField];

    UILabel *randomLabel = [[UILabel alloc] initWithFrame:CGRectMake(width - 110, 5, 60, 25)];
    randomLabel.text = @"随机";
    randomLabel.textColor = [UIColor whiteColor];
    randomLabel.font = [UIFont systemFontOfSize:14];
    [rangeView addSubview:randomLabel];

    self.randomSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(width - 50, 0, 50, 30)];
    self.randomSwitch.transform = CGAffineTransformMakeScale(0.8, 0.8);
    [self.randomSwitch addTarget:self action:@selector(randomSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [rangeView addSubview:self.randomSwitch];

    [self addSubview:rangeView];
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
    y += 30;

    // 调试信息显示
    self.debugLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, y, width, 50)];
    self.debugLabel.text = @"调试信息";
    self.debugLabel.textColor = [UIColor yellowColor];
    self.debugLabel.font = [UIFont systemFontOfSize:10];
    self.debugLabel.textAlignment = NSTextAlignmentLeft;
    self.debugLabel.numberOfLines = 3;
    self.debugLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self addSubview:self.debugLabel];
    y += 55;

    // 网络监控开关
    [self addLabel:@"🌐 网络监控（抓包）:" atY:y];
    y += 25;

    UIView *networkMonitorView = [[UIView alloc] initWithFrame:CGRectMake(padding, y, width, 35)];

    UILabel *monitorLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 5, width - 70, 25)];
    monitorLabel.text = @"开启后会拦截所有网络请求";
    monitorLabel.textColor = [UIColor cyanColor];
    monitorLabel.font = [UIFont systemFontOfSize:11];
    [networkMonitorView addSubview:monitorLabel];

    self.networkMonitorSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(width - 50, 0, 50, 30)];
    self.networkMonitorSwitch.transform = CGAffineTransformMakeScale(0.8, 0.8);
    [self.networkMonitorSwitch addTarget:self action:@selector(networkMonitorSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [networkMonitorView addSubview:self.networkMonitorSwitch];

    [self addSubview:networkMonitorView];
    y += 40;

    // 网络日志显示区域
    self.networkLogView = [[UITextView alloc] initWithFrame:CGRectMake(padding, y, width, 120)];
    self.networkLogView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    self.networkLogView.textColor = [UIColor greenColor];
    self.networkLogView.font = [UIFont fontWithName:@"Menlo" size:9];
    self.networkLogView.editable = NO;
    self.networkLogView.layer.cornerRadius = 5;
    self.networkLogView.layer.borderWidth = 1;
    self.networkLogView.layer.borderColor = [UIColor cyanColor].CGColor;
    self.networkLogView.text = @"[网络监控]\n等待拦截请求...\n\n提示：\n1. 打开开关\n2. 手动领券\n3. 查看请求信息";
    [self addSubview:self.networkLogView];
    y += 125;

    // 清空日志按钮
    self.clearLogButton = [self createButton:@"清空日志"
                                       frame:CGRectMake(padding, y, width, 30)
                                      action:@selector(clearNetworkLog)];
    self.clearLogButton.backgroundColor = [[UIColor purpleColor] colorWithAlphaComponent:0.3];
    self.clearLogButton.titleLabel.font = [UIFont systemFontOfSize:14];
    [self addSubview:self.clearLogButton];
    y += 40;

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

- (void)randomSwitchChanged:(UISwitch *)sender {
    self.rangeTextField.enabled = !sender.isOn;
    if (sender.isOn) {
        self.rangeTextField.text = @"50";  // 默认随机范围
    } else {
        self.rangeTextField.text = @"0";
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

- (void)captureCoordinateTapped {
    // 隐藏配置窗口
    [self hide];

    isCapturingCoordinate = YES;

    // 在主窗口上添加捕获层
    if (mainAppWindow) {
        CoordinateCaptureView *captureView = [[CoordinateCaptureView alloc] initWithFrame:mainAppWindow.bounds];

        __weak typeof(self) weakSelf = self;
        captureView.onCoordinateCaptured = ^(CGPoint point) {
            // 填入坐标
            weakSelf.xTextField.text = [NSString stringWithFormat:@"%.0f", point.x];
            weakSelf.yTextField.text = [NSString stringWithFormat:@"%.0f", point.y];

            // 重新显示配置窗口
            [weakSelf show];

            // 更新状态
            weakSelf.statusLabel.text = [NSString stringWithFormat:@"已获取: (%.0f, %.0f)", point.x, point.y];
            weakSelf.statusLabel.textColor = [UIColor cyanColor];
        };

        [mainAppWindow addSubview:captureView];
    }
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
    CGFloat range = self.rangeTextField.text.length > 0 ? [self.rangeTextField.text floatValue] : 0;
    NSInteger count = self.infiniteSwitch.isOn ? -1 : [self.countTextField.text integerValue];
    CGFloat interval = [self.intervalTextField.text floatValue];

    if (interval < 0.1) {
        [self showAlert:@"间隔不能小于0.1秒"];
        return;
    }

    self.clickPoint = CGPointMake(x, y);
    self.clickRange = range;
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

    NSLog(@"[AutoClicker] V3 开始 - 坐标:(%.0f, %.0f) 范围:%.0f 次数:%ld 间隔:%.1f秒",
          x, y, range, (long)count, interval);
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

    // 计算实际点击位置（如果有范围，则随机偏移）
    CGPoint actualPoint = self.clickPoint;

    if (self.clickRange > 0) {
        // 在范围内随机偏移
        CGFloat randomX = ((CGFloat)arc4random() / UINT32_MAX) * self.clickRange * 2 - self.clickRange;
        CGFloat randomY = ((CGFloat)arc4random() / UINT32_MAX) * self.clickRange * 2 - self.clickRange;

        actualPoint.x += randomX;
        actualPoint.y += randomY;

        // 确保不超出屏幕范围
        actualPoint.x = MAX(0, MIN(actualPoint.x, targetWindow.bounds.size.width));
        actualPoint.y = MAX(0, MIN(actualPoint.y, targetWindow.bounds.size.height));
    }

    // 模拟真实的触摸事件
    [self simulateTouchAtPoint:actualPoint inWindow:targetWindow];

    NSLog(@"[AutoClicker] 点击位置: (%.0f, %.0f)", actualPoint.x, actualPoint.y);

    // 视觉反馈
    [self showClickFeedbackAtPoint:actualPoint inWindow:targetWindow];

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

- (void)simulateTouchAtPoint:(CGPoint)point inWindow:(UIWindow *)window {
    // 查找该位置的视图
    UIView *targetView = [window hitTest:point withEvent:nil];

    if (!targetView) {
        [self showDebugInfo:@"❌ 未找到目标视图"];
        return;
    }

    NSString *viewClass = NSStringFromClass([targetView class]);
    [self showDebugInfo:[NSString stringWithFormat:@"🎯 找到: %@", viewClass]];

    // ========== 方法1：UIControl 及其子类（UIButton, UISwitch 等）==========
    if ([targetView isKindOfClass:[UIControl class]]) {
        UIControl *control = (UIControl *)targetView;

        // 获取所有 target-action 对
        NSSet *allTargets = [control allTargets];

        if (allTargets.count > 0) {
            BOOL executed = NO;
            for (id target in allTargets) {
                // 获取该 target 对应的所有 actions
                NSArray *actions = [control actionsForTarget:target
                                            forControlEvent:UIControlEventTouchUpInside];

                for (NSString *actionString in actions) {
                    SEL action = NSSelectorFromString(actionString);

                    [self showDebugInfo:[NSString stringWithFormat:@"✅ UIControl: %@", actionString]];

                    // 调用 action
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    if ([target respondsToSelector:action]) {
                        // 有些 action 需要 sender 参数
                        NSMethodSignature *signature = [target methodSignatureForSelector:action];
                        if (signature.numberOfArguments == 2) {
                            // 只有 self 和 _cmd，无参数
                            [target performSelector:action];
                        } else if (signature.numberOfArguments == 3) {
                            // 有 sender 参数
                            [target performSelector:action withObject:control];
                        }
                        executed = YES;
                    }
                    #pragma clang diagnostic pop
                }
            }
            if (executed) return;
        } else {
            [self showDebugInfo:[NSString stringWithFormat:@"⚠️ UIControl 无 action"]];
        }
    }

    // ========== 方法2：尝试 UIAccessibility 激活 ==========
    // 检查视图是否支持辅助功能激活
    if ([targetView respondsToSelector:@selector(accessibilityActivate)]) {
        BOOL activated = [targetView accessibilityActivate];
        if (activated) {
            [self showDebugInfo:@"✅ accessibilityActivate"];
            return;
        } else {
            [self showDebugInfo:@"⚠️ accessibilityActivate 失败"];
        }
    }

    // ========== 方法3：手势识别器 ==========
    if (targetView.gestureRecognizers.count > 0) {
        for (UIGestureRecognizer *gesture in targetView.gestureRecognizers) {
            if ([gesture isKindOfClass:[UITapGestureRecognizer class]]) {
                UITapGestureRecognizer *tapGesture = (UITapGestureRecognizer *)gesture;

                if (tapGesture.enabled) {
                    // 获取手势的所有 target-action
                    NSArray *targets = [tapGesture valueForKey:@"_targets"];

                    for (id targetActionPair in targets) {
                        // 每个元素是 UIGestureRecognizerTarget 对象
                        id target = [targetActionPair valueForKey:@"_target"];
                        SEL action = NSSelectorFromString([targetActionPair valueForKey:@"_action"]);

                        if (target && action) {
                            [self showDebugInfo:[NSString stringWithFormat:@"✅ 手势: %@", NSStringFromSelector(action)]];

                            #pragma clang diagnostic push
                            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                            if ([target respondsToSelector:action]) {
                                [target performSelector:action withObject:tapGesture];
                            }
                            #pragma clang diagnostic pop

                            return; // 成功执行
                        }
                    }
                }
            }
        }
        [self showDebugInfo:@"⚠️ 有手势但无法触发"];
    }

    // ========== 方法4：尝试直接在视图上调用常见的点击方法 ==========
    NSArray *commonMethods = @[@"handleTap:", @"onTap:", @"didTap", @"tap", @"onClick:", @"click"];
    for (NSString *methodName in commonMethods) {
        SEL method = NSSelectorFromString(methodName);
        if ([targetView respondsToSelector:method]) {
            [self showDebugInfo:[NSString stringWithFormat:@"✅ 方法: %@", methodName]];
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [targetView performSelector:method withObject:nil];
            #pragma clang diagnostic pop
            return;
        }
    }

    // ========== 方法5：向上查找父视图，寻找 Cell（关键！）==========
    // 对于电商 APP，商品图片通常在 Cell 里，需要触发 Cell 的选中
    UIView *currentView = targetView;
    while (currentView) {
        // 检查是否是 UITableViewCell
        if ([currentView isKindOfClass:[UITableViewCell class]]) {
            UITableViewCell *cell = (UITableViewCell *)currentView;
            UITableView *tableView = (UITableView *)cell.superview;

            // 有些 tableView 的 cell 在 superview.superview
            if (![tableView isKindOfClass:[UITableView class]]) {
                tableView = (UITableView *)tableView.superview;
            }

            if ([tableView isKindOfClass:[UITableView class]]) {
                NSIndexPath *indexPath = [tableView indexPathForCell:cell];

                if (!indexPath) {
                    [self showDebugInfo:@"⚠️ indexPath 为空"];
                    currentView = currentView.superview;
                    continue;
                }

                if (!tableView.delegate) {
                    [self showDebugInfo:@"⚠️ delegate 为空"];
                    currentView = currentView.superview;
                    continue;
                }

                // 检查 delegate 是否响应该方法
                if (![tableView.delegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)]) {
                    [self showDebugInfo:@"⚠️ delegate 不响应 didSelect"];
                    currentView = currentView.superview;
                    continue;
                }

                [self showDebugInfo:[NSString stringWithFormat:@"🔵 尝试 Cell: %ld-%ld", (long)indexPath.section, (long)indexPath.row]];

                // 使用 try-catch 保护，避免崩溃
                dispatch_async(dispatch_get_main_queue(), ^{
                    @try {
                        // 再次检查有效性（异步执行时可能已经改变）
                        if (tableView.delegate && indexPath) {
                            [tableView.delegate tableView:tableView didSelectRowAtIndexPath:indexPath];

                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self showDebugInfo:@"✅ Cell 点击成功"];
                            });
                        }
                    } @catch (NSException *exception) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self showDebugInfo:[NSString stringWithFormat:@"❌ 异常: %@", exception.name]];
                        });
                        NSLog(@"[AutoClicker] 捕获异常: %@ - %@", exception.name, exception.reason);
                    }
                });
                return;
            }
        }

        // 检查是否是 UICollectionViewCell
        if ([currentView isKindOfClass:[UICollectionViewCell class]]) {
            UICollectionViewCell *cell = (UICollectionViewCell *)currentView;
            UICollectionView *collectionView = (UICollectionView *)cell.superview;

            // 有些 collectionView 的 cell 在 superview.superview
            if (![collectionView isKindOfClass:[UICollectionView class]]) {
                collectionView = (UICollectionView *)collectionView.superview;
            }

            if ([collectionView isKindOfClass:[UICollectionView class]]) {
                NSIndexPath *indexPath = [collectionView indexPathForCell:cell];

                if (!indexPath) {
                    [self showDebugInfo:@"⚠️ indexPath 为空"];
                    currentView = currentView.superview;
                    continue;
                }

                if (!collectionView.delegate) {
                    [self showDebugInfo:@"⚠️ delegate 为空"];
                    currentView = currentView.superview;
                    continue;
                }

                // 检查 delegate 是否响应该方法
                if (![collectionView.delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) {
                    [self showDebugInfo:@"⚠️ delegate 不响应 didSelect"];
                    currentView = currentView.superview;
                    continue;
                }

                [self showDebugInfo:[NSString stringWithFormat:@"🔵 尝试 Cell: %ld-%ld", (long)indexPath.section, (long)indexPath.item]];

                // 使用 try-catch 保护，避免崩溃
                dispatch_async(dispatch_get_main_queue(), ^{
                    @try {
                        // 再次检查有效性（异步执行时可能已经改变）
                        if (collectionView.delegate && indexPath) {
                            [collectionView.delegate collectionView:collectionView didSelectItemAtIndexPath:indexPath];

                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self showDebugInfo:@"✅ Cell 点击成功"];
                            });
                        }
                    } @catch (NSException *exception) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self showDebugInfo:[NSString stringWithFormat:@"❌ 异常: %@", exception.name]];
                        });
                        NSLog(@"[AutoClicker] 捕获异常: %@ - %@", exception.name, exception.reason);
                    }
                });
                return;
            }
        }

        // 向上查找父视图
        currentView = currentView.superview;
    }

    // ========== 方法6：检查父视图的手势识别器 ==========
    // 有些视图的手势在父视图上
    currentView = targetView.superview;
    int depth = 0;
    while (currentView && depth < 5) {  // 最多向上查找5层
        if (currentView.gestureRecognizers.count > 0) {
            for (UIGestureRecognizer *gesture in currentView.gestureRecognizers) {
                if ([gesture isKindOfClass:[UITapGestureRecognizer class]]) {
                    UITapGestureRecognizer *tapGesture = (UITapGestureRecognizer *)gesture;

                    if (tapGesture.enabled) {
                        NSArray *targets = [tapGesture valueForKey:@"_targets"];

                        for (id targetActionPair in targets) {
                            id target = [targetActionPair valueForKey:@"_target"];
                            SEL action = NSSelectorFromString([targetActionPair valueForKey:@"_action"]);

                            if (target && action) {
                                [self showDebugInfo:[NSString stringWithFormat:@"✅ 父视图手势: %@", NSStringFromSelector(action)]];

                                #pragma clang diagnostic push
                                #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                                if ([target respondsToSelector:action]) {
                                    [target performSelector:action withObject:tapGesture];
                                }
                                #pragma clang diagnostic pop

                                return;
                            }
                        }
                    }
                }
            }
        }

        currentView = currentView.superview;
        depth++;
    }

    // ========== 最终失败：显示父视图链帮助诊断 ==========
    NSMutableString *parentChain = [NSMutableString stringWithString:viewClass];
    UIView *parent = targetView.superview;
    int chainDepth = 0;
    while (parent && chainDepth < 3) {
        [parentChain appendFormat:@"\n↑ %@", NSStringFromClass([parent class])];
        parent = parent.superview;
        chainDepth++;
    }

    [self showDebugInfo:[NSString stringWithFormat:@"❌ 无法点击\n%@", parentChain]];
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

- (void)showDebugInfo:(NSString *)info {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.debugLabel.text = info;
        NSLog(@"[AutoClicker] %@", info);
    });
}

- (void)networkMonitorSwitchChanged:(UISwitch *)sender {
    if (sender.isOn) {
        [self logNetworkRequest:@"[网络监控] 已开启\n正在拦截所有网络请求...\n"];
        NSLog(@"[AutoClicker] 网络监控已开启");
    } else {
        [self logNetworkRequest:@"[网络监控] 已关闭"];
        NSLog(@"[AutoClicker] 网络监控已关闭");
    }
}

- (void)clearNetworkLog {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.networkLogView.text = @"[日志已清空]\n等待拦截新的请求...\n";
    });
}

- (void)logNetworkRequest:(NSString *)log {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *timestamp = [NSString stringWithFormat:@"[%@] ", [[NSDate date] descriptionWithLocale:nil]];
        NSString *newLog = [NSString stringWithFormat:@"%@%@\n", timestamp, log];

        // 限制日志长度，避免占用太多内存
        NSString *currentLog = self.networkLogView.text;
        if (currentLog.length > 10000) {
            currentLog = [currentLog substringFromIndex:currentLog.length - 5000];
        }

        self.networkLogView.text = [currentLog stringByAppendingString:newLog];

        // 自动滚动到底部
        if (self.networkLogView.text.length > 0) {
            NSRange bottom = NSMakeRange(self.networkLogView.text.length - 1, 1);
            [self.networkLogView scrollRangeToVisible:bottom];
        }

        NSLog(@"[AutoClicker-Network] %@", log);
    });
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
        CGFloat windowHeight = 760;  // 增加高度以容纳网络监控
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

        NSLog(@"[AutoClicker] V3.6 已加载 - 防崩溃加固版");
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

// ========== 网络请求拦截 ==========

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    // 检查是否开启网络监控
    if (configView && configView.networkMonitorSwitch.isOn) {
        NSString *url = request.URL.absoluteString;
        NSString *method = request.HTTPMethod ?: @"GET";

        // 过滤领券相关请求
        BOOL isCouponRelated = [url containsString:@"coupon"] ||
                                [url containsString:@"领券"] ||
                                [url containsString:@"receive"] ||
                                [url containsString:@"claim"];

        if (isCouponRelated) {
            // 构建详细日志
            NSMutableString *log = [NSMutableString string];
            [log appendFormat:@"🔥 [领券请求]\n"];
            [log appendFormat:@"Method: %@\n", method];
            [log appendFormat:@"URL: %@\n", url];

            // Headers
            if (request.allHTTPHeaderFields.count > 0) {
                [log appendString:@"\nHeaders:\n"];
                for (NSString *key in request.allHTTPHeaderFields) {
                    [log appendFormat:@"  %@: %@\n", key, request.allHTTPHeaderFields[key]];
                }
            }

            // Body
            if (request.HTTPBody) {
                NSString *bodyString = [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding];
                if (bodyString) {
                    [log appendFormat:@"\nBody:\n%@\n", bodyString];
                } else {
                    [log appendFormat:@"\nBody: (二进制数据 %lu bytes)\n", (unsigned long)request.HTTPBody.length];
                }
            }

            [log appendString:@"════════════════\n"];

            // 显示在界面上
            [configView logNetworkRequest:log];
        }

        // 拦截响应 - 创建包装的 completion handler
        void (^wrappedHandler)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
            if (isCouponRelated && data) {
                NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                if (responseString) {
                    [configView logNetworkRequest:[NSString stringWithFormat:@"📥 [响应]\n%@\n════════════════\n", responseString]];
                }
            }

            // 调用原始回调
            if (completionHandler) {
                completionHandler(data, response, error);
            }
        };

        return %orig(request, wrappedHandler);
    }

    return %orig;
}

%end

%hook NSURLConnection

+ (NSData *)sendSynchronousRequest:(NSURLRequest *)request returningResponse:(NSURLResponse **)response error:(NSError **)error {
    // 检查是否开启网络监控
    if (configView && configView.networkMonitorSwitch.isOn) {
        NSString *url = request.URL.absoluteString;

        if ([url containsString:@"coupon"] || [url containsString:@"receive"]) {
            [configView logNetworkRequest:[NSString stringWithFormat:@"🔄 [同步请求] %@\n", url]];
        }
    }

    return %orig;
}

%end

%ctor {
    NSLog(@"[AutoClicker] V3.7 已加载 - 网络拦截版");
}
