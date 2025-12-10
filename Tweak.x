/**
 * AutoClicker - 可配置的自动点击工具
 * 支持坐标输入、点击次数、频率、时长设置
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// ========== 配置界面 ==========

@interface AutoClickerConfigViewController : UIViewController <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *xTextField;
@property (nonatomic, strong) UITextField *yTextField;
@property (nonatomic, strong) UITextField *countTextField;
@property (nonatomic, strong) UITextField *intervalTextField;
@property (nonatomic, strong) UITextField *durationTextField;
@property (nonatomic, strong) UISwitch *infiniteSwitch;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *startButton;
@property (nonatomic, strong) UIButton *stopButton;
@property (nonatomic, strong) UIButton *getCoordButton;

@property (nonatomic, strong) NSTimer *clickTimer;
@property (nonatomic, assign) NSInteger currentClickCount;
@property (nonatomic, assign) BOOL isRunning;
@end

@implementation AutoClickerConfigViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.95];
    self.title = @"🎯 自动点击工具";

    CGFloat padding = 20;
    CGFloat y = 80;
    CGFloat width = self.view.bounds.size.width - padding * 2;

    // 标题
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, 40, width, 30)];
    titleLabel.text = @"🎯 自动点击工具";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:24];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:titleLabel];

    // 坐标输入
    [self addLabel:@"点击坐标:" atY:y];
    y += 30;

    UIView *coordView = [[UIView alloc] initWithFrame:CGRectMake(padding, y, width, 40)];

    UILabel *xLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, 30, 30)];
    xLabel.text = @"X:";
    xLabel.textColor = [UIColor whiteColor];
    [coordView addSubview:xLabel];

    self.xTextField = [self createTextField:CGRectMake(35, 5, width/2 - 60, 30) placeholder:@"100"];
    [coordView addSubview:self.xTextField];

    UILabel *yLabel = [[UILabel alloc] initWithFrame:CGRectMake(width/2 + 10, 10, 30, 30)];
    yLabel.text = @"Y:";
    yLabel.textColor = [UIColor whiteColor];
    [coordView addSubview:yLabel];

    self.yTextField = [self createTextField:CGRectMake(width/2 + 45, 5, width/2 - 60, 30) placeholder:@"200"];
    [coordView addSubview:self.yTextField];

    [self.view addSubview:coordView];
    y += 50;

    // 获取坐标按钮
    self.getCoordButton = [self createButton:@"📍 点击获取当前坐标"
                                        frame:CGRectMake(padding, y, width, 40)
                                       action:@selector(getCoordinatesTapped)];
    self.getCoordButton.backgroundColor = [[UIColor orangeColor] colorWithAlphaComponent:0.3];
    [self.view addSubview:self.getCoordButton];
    y += 60;

    // 点击次数
    [self addLabel:@"点击次数:" atY:y];
    y += 30;

    UIView *countView = [[UIView alloc] initWithFrame:CGRectMake(padding, y, width, 40)];

    self.countTextField = [self createTextField:CGRectMake(0, 5, width - 150, 30) placeholder:@"100"];
    [countView addSubview:self.countTextField];

    UILabel *infiniteLabel = [[UILabel alloc] initWithFrame:CGRectMake(width - 140, 10, 90, 30)];
    infiniteLabel.text = @"无限循环";
    infiniteLabel.textColor = [UIColor whiteColor];
    infiniteLabel.font = [UIFont systemFontOfSize:14];
    [countView addSubview:infiniteLabel];

    self.infiniteSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(width - 50, 5, 50, 30)];
    [self.infiniteSwitch addTarget:self action:@selector(infiniteSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [countView addSubview:self.infiniteSwitch];

    [self.view addSubview:countView];
    y += 60;

    // 点击频率
    [self addLabel:@"点击间隔 (秒):" atY:y];
    y += 30;
    self.intervalTextField = [self createTextField:CGRectMake(padding, y, width, 30) placeholder:@"1.0"];
    [self.view addSubview:self.intervalTextField];
    y += 50;

    // 点击时长
    [self addLabel:@"按住时长 (秒):" atY:y];
    y += 30;
    self.durationTextField = [self createTextField:CGRectMake(padding, y, width, 30) placeholder:@"0.1"];
    [self.view addSubview:self.durationTextField];
    y += 60;

    // 状态显示
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, y, width, 30)];
    self.statusLabel.text = @"状态: 待机中";
    self.statusLabel.textColor = [UIColor greenColor];
    self.statusLabel.font = [UIFont boldSystemFontOfSize:16];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.statusLabel];
    y += 50;

    // 开始按钮
    self.startButton = [self createButton:@"▶️ 开始"
                                     frame:CGRectMake(padding, y, width/2 - 10, 50)
                                    action:@selector(startClicking)];
    self.startButton.backgroundColor = [[UIColor greenColor] colorWithAlphaComponent:0.3];
    [self.view addSubview:self.startButton];

    // 停止按钮
    self.stopButton = [self createButton:@"⏹ 停止"
                                    frame:CGRectMake(padding + width/2 + 10, y, width/2 - 10, 50)
                                   action:@selector(stopClicking)];
    self.stopButton.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.3];
    self.stopButton.enabled = NO;
    [self.view addSubview:self.stopButton];
    y += 70;

    // 关闭按钮
    UIButton *closeButton = [self createButton:@"❌ 关闭"
                                          frame:CGRectMake(padding, y, width, 40)
                                         action:@selector(closeTapped)];
    closeButton.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.3];
    [self.view addSubview:closeButton];

    // 添加手势识别（用于获取坐标）
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    tapGesture.numberOfTapsRequired = 2; // 双击
    [self.view addGestureRecognizer:tapGesture];
}

- (void)addLabel:(NSString *)text atY:(CGFloat)y {
    CGFloat padding = 20;
    CGFloat width = self.view.bounds.size.width - padding * 2;
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(padding, y, width, 25)];
    label.text = text;
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:16];
    [self.view addSubview:label];
}

- (UITextField *)createTextField:(CGRect)frame placeholder:(NSString *)placeholder {
    UITextField *textField = [[UITextField alloc] initWithFrame:frame];
    textField.placeholder = placeholder;
    textField.textColor = [UIColor whiteColor];
    textField.borderStyle = UITextBorderStyleRoundedRect;
    textField.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.1];
    textField.keyboardType = UIKeyboardTypeDecimalPad;
    textField.delegate = self;

    // 添加工具栏（完成按钮）
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
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
    button.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    button.layer.cornerRadius = 8;
    button.layer.borderWidth = 1;
    button.layer.borderColor = [UIColor whiteColor].CGColor;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

- (void)infiniteSwitchChanged:(UISwitch *)sender {
    self.countTextField.enabled = !sender.isOn;
    if (sender.isOn) {
        self.countTextField.text = @"∞";
    } else {
        self.countTextField.text = @"100";
    }
}

- (void)handleTap:(UITapGestureRecognizer *)gesture {
    CGPoint point = [gesture locationInView:self.view];
    self.xTextField.text = [NSString stringWithFormat:@"%.0f", point.x];
    self.yTextField.text = [NSString stringWithFormat:@"%.0f", point.y];

    // 显示提示
    self.statusLabel.text = [NSString stringWithFormat:@"已获取坐标: (%.0f, %.0f)", point.x, point.y];
    self.statusLabel.textColor = [UIColor orangeColor];
}

- (void)getCoordinatesTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"📍 获取坐标"
                                                                   message:@"在主界面双击要点击的位置，坐标会自动填入。\n\n或者在此界面双击任意位置获取坐标。"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)startClicking {
    // 验证输入
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

    // 获取配置
    CGFloat x = [self.xTextField.text floatValue];
    CGFloat y = [self.yTextField.text floatValue];
    NSInteger count = self.infiniteSwitch.isOn ? -1 : [self.countTextField.text integerValue];
    CGFloat interval = [self.intervalTextField.text floatValue];

    if (interval < 0.1) {
        [self showAlert:@"点击间隔不能小于0.1秒"];
        return;
    }

    // 开始点击
    self.currentClickCount = 0;
    self.isRunning = YES;
    self.startButton.enabled = NO;
    self.stopButton.enabled = YES;

    CGPoint clickPoint = CGPointMake(x, y);

    self.clickTimer = [NSTimer scheduledTimerWithTimeInterval:interval repeats:YES block:^(NSTimer *timer) {
        if (!self.isRunning) {
            [timer invalidate];
            return;
        }

        // 执行点击
        [self simulateClickAtPoint:clickPoint];

        self.currentClickCount++;

        // 更新状态
        if (count == -1) {
            self.statusLabel.text = [NSString stringWithFormat:@"运行中: 已点击 %ld 次", (long)self.currentClickCount];
        } else {
            self.statusLabel.text = [NSString stringWithFormat:@"运行中: %ld/%ld 次", (long)self.currentClickCount, (long)count];
        }
        self.statusLabel.textColor = [UIColor greenColor];

        // 检查是否完成
        if (count != -1 && self.currentClickCount >= count) {
            [self stopClicking];
            self.statusLabel.text = [NSString stringWithFormat:@"完成: 共点击 %ld 次", (long)self.currentClickCount];
            self.statusLabel.textColor = [UIColor cyanColor];
        }
    }];

    NSLog(@"[AutoClicker] 开始自动点击 - 坐标:(%.0f, %.0f) 次数:%ld 间隔:%.1f秒", x, y, (long)count, interval);
}

- (void)stopClicking {
    self.isRunning = NO;

    if (self.clickTimer) {
        [self.clickTimer invalidate];
        self.clickTimer = nil;
    }

    self.startButton.enabled = YES;
    self.stopButton.enabled = NO;

    if (self.currentClickCount > 0) {
        self.statusLabel.text = [NSString stringWithFormat:@"已停止 (共点击 %ld 次)", (long)self.currentClickCount];
    } else {
        self.statusLabel.text = @"状态: 待机中";
    }
    self.statusLabel.textColor = [UIColor redColor];

    NSLog(@"[AutoClicker] 停止自动点击");
}

- (void)simulateClickAtPoint:(CGPoint)point {
    // 获取主窗口
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) {
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window.isKeyWindow) {
                keyWindow = window;
                break;
            }
        }
    }

    if (!keyWindow) {
        NSLog(@"[AutoClicker] 无法获取主窗口");
        return;
    }

    // 查找该坐标位置的视图
    UIView *targetView = [keyWindow hitTest:point withEvent:nil];

    if (targetView) {
        // 如果是按钮，直接触发
        if ([targetView isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)targetView;
            [button sendActionsForControlEvents:UIControlEventTouchUpInside];
            NSLog(@"[AutoClicker] 点击按钮: %@", button.titleLabel.text);
        } else {
            // 否则，发送触摸事件
            NSLog(@"[AutoClicker] 点击视图: %@", NSStringFromClass([targetView class]));
        }
    }

    // 视觉反馈（可选）
    [self showClickFeedbackAtPoint:point inWindow:keyWindow];
}

- (void)showClickFeedbackAtPoint:(CGPoint)point inWindow:(UIWindow *)window {
    // 创建一个圆形视图显示点击位置
    UIView *feedbackView = [[UIView alloc] initWithFrame:CGRectMake(point.x - 20, point.y - 20, 40, 40)];
    feedbackView.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.5];
    feedbackView.layer.cornerRadius = 20;
    feedbackView.userInteractionEnabled = NO;
    [window addSubview:feedbackView];

    // 动画消失
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
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)closeTapped {
    [self stopClicking];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)dealloc {
    [self stopClicking];
}

@end

// ========== 悬浮按钮 ==========

static UIButton *floatingButton = nil;

@interface UIWindow (AutoClicker)
- (void)showAutoClickerConfig;
@end

%hook UIWindow

%new
- (void)showAutoClickerConfig {
    AutoClickerConfigViewController *configVC = [[AutoClickerConfigViewController alloc] init];
    configVC.modalPresentationStyle = UIModalPresentationFullScreen;

    UIViewController *rootVC = self.rootViewController;
    if (rootVC) {
        [rootVC presentViewController:configVC animated:YES completion:nil];
    }
}

- (void)makeKeyAndVisible {
    %orig;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 创建悬浮按钮
        floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
        floatingButton.frame = CGRectMake([UIScreen mainScreen].bounds.size.width - 70, 100, 60, 60);
        floatingButton.backgroundColor = [[UIColor orangeColor] colorWithAlphaComponent:0.8];
        floatingButton.layer.cornerRadius = 30;
        [floatingButton setTitle:@"🎯" forState:UIControlStateNormal];
        floatingButton.titleLabel.font = [UIFont systemFontOfSize:30];

        // 添加点击事件
        [floatingButton addTarget:self action:@selector(showAutoClickerConfig) forControlEvents:UIControlEventTouchUpInside];

        // 添加拖动手势
        UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [floatingButton addGestureRecognizer:panGesture];

        [self addSubview:floatingButton];

        NSLog(@"[AutoClicker] 悬浮按钮已创建");
    });
}

%new
- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self];

    CGRect newFrame = floatingButton.frame;
    newFrame.origin.x += translation.x;
    newFrame.origin.y += translation.y;

    // 限制在屏幕范围内
    CGFloat maxX = self.bounds.size.width - floatingButton.frame.size.width;
    CGFloat maxY = self.bounds.size.height - floatingButton.frame.size.height;

    newFrame.origin.x = MAX(0, MIN(newFrame.origin.x, maxX));
    newFrame.origin.y = MAX(20, MIN(newFrame.origin.y, maxY));

    floatingButton.frame = newFrame;

    [gesture setTranslation:CGPointZero inView:self];
}

%end

// ========== 构造函数 ==========

%ctor {
    NSLog(@"[AutoClicker] 自动点击工具已加载 - 点击悬浮按钮 🎯 打开配置界面");
}
