//
//  ViewController.m
//  CHTReactiveCocoaTest2
//
//  Created by cht on 16/7/6.
//  Copyright © 2016年 cht. All rights reserved.
//

#import "ViewController.h"
#import <AddressBook/AddressBook.h>
#import <ReactiveCocoa/ReactiveCocoa.h>
#import "RACEXTScope.h"

#define RWTwitterInstantDomain @"123456"
#define RWTwitterInstantErrorAccessDenied 123456


@interface ViewController ()<UIAlertViewDelegate>

@property (weak, nonatomic) IBOutlet UIButton *btn;

@end

@implementation ViewController{
    
    NSMutableArray *_peoples;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    @weakify(self)
    [[[_btn rac_signalForControlEvents:UIControlEventTouchUpInside]
    flattenMap:^RACStream *(id value) {
        
        @strongify(self)
        return [self requestAccessContact];
    }]
    subscribeNext:^(id x) {
        
        NSLog(@"abc");
        [self addContact];
        
    }error:^(NSError *error) {
        
        NSLog(@"%@",error.description);
        [self showAlertView];
    }];
    
}

- (RACSignal *)requestAccessContact{
    
    NSError *accessError = [NSError errorWithDomain:RWTwitterInstantDomain
                                               code:RWTwitterInstantErrorAccessDenied
                                           userInfo:nil];
    
    @weakify(self)
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        
        @strongify(self)
        ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
        if (status == kABAuthorizationStatusNotDetermined) {
            
            ABAddressBookRef addressBookRef = ABAddressBookCreateWithOptions(NULL, NULL);
            ABAddressBookRequestAccessWithCompletion(addressBookRef, ^(bool granted, CFErrorRef error){
                NSLog(@"granted:%d",granted);
                if (granted) {
                    //用户允许访问通讯录
                    
                    
                    [subscriber sendNext:nil];
                    [subscriber sendCompleted];
                    
                }

            });
        }else if(status == kABAuthorizationStatusAuthorized){
            
            [self addContact];
        }
        else {
            //Restricted OR Denied
            
            [subscriber sendError:accessError];
            
        }
        return nil;
    }];
}

- (void)showAlertView{
    
    NSString * title = @"請先允許此應用程式存取你的通訊錄";
    
    UIAlertView * al = [[UIAlertView alloc]initWithTitle:title message:nil delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"設定", nil];
    al.delegate = self;
    [al show];
}


//联系人操作
- (void)configAddressBook{
    
    NSArray *statuses = @[@"kABAuthorizationStatusNotDetermined",@"kABAuthorizationStatusRestricted",@"kABAuthorizationStatusDenied",@"kABAuthorizationStatusAuthorized"];
    ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
    
    NSLog(@"status : %@",statuses[status]);
    
    if (status == kABAuthorizationStatusAuthorized){
        CFErrorRef *error = NULL;
        ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, error);
        [self addContact];
        CFRelease(addressBook);
    }
    else if (status == kABAuthorizationStatusNotDetermined) {
        ABAddressBookRef addressBookRef = ABAddressBookCreateWithOptions(NULL, NULL);
        ABAddressBookRequestAccessWithCompletion(addressBookRef, ^(bool granted, CFErrorRef error){
            NSLog(@"granted:%d",granted);
            if (granted) {
                //用户允许访问通讯录
                CFErrorRef *error1 = NULL;
                ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, error1);
                [self addContact];
                CFRelease(addressBook);
                
            } else {
                
                //用户拒绝访问通讯录
                NSLog(@"user denied");
                
            }
        });
    }
    else {
        //Restricted OR Denied
        
        NSString * title = @"請先允許此應用程式存取你的通訊錄";
        
        UIAlertView * al = [[UIAlertView alloc]initWithTitle:title message:nil delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"設定", nil];
        al.delegate = self;
        [al show];
        
    }
}

//添加联系人
- (void)addContact{
    
    CFErrorRef *error1 = NULL;
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, error1);
    
    NSString * firstName = @"金刚狼";
    NSString * note = @"Added by Qfang App on 2016/07/05";
    NSString * phoneNum = @"13717115843";
    
    //电话存在，不存进通讯录
    if ([self isPhoneExist:phoneNum addressBook:addressBook]) {
        
        [self openWhatsApp];
        return;
    }
    
    //创建一条记录
    ABRecordRef recordRef= ABPersonCreate();
    ABRecordSetValue(recordRef, kABPersonFirstNameProperty, (__bridge CFTypeRef)(firstName), NULL);//添加名
    
    //kABPersonNoteProperty
    ABRecordSetValue(recordRef, kABPersonNoteProperty, (__bridge CFTypeRef)(note), NULL);//添加备注
    
    //号码
    ABMultiValueRef phone =ABMultiValueCreateMutable(kABMultiStringPropertyType);
    ABMultiValueAddValueAndLabel(phone, (__bridge CFTypeRef)(phoneNum),kABPersonPhoneMobileLabel, NULL);//添加移动号码0
    //⋯⋯ 添加多个号码
    
    ABRecordSetValue(recordRef, kABPersonPhoneProperty, phone, NULL);//写入全部号码进联系人
    
    //添加记录
    ABAddressBookAddRecord(addressBook, recordRef, NULL);
    
    //保存通讯录，提交更改
    ABAddressBookSave(addressBook, NULL);
    //释放资源
    CFRelease(recordRef);
    CFRelease(phone);
    CFRelease(addressBook);
}

- (void)openWhatsApp{
    
    NSURL *whatsappURL = [NSURL URLWithString:@"whatsapp://send?text=Hello%2C%20World!"];
    if ([[UIApplication sharedApplication] canOpenURL: whatsappURL]) {
        [[UIApplication sharedApplication] openURL: whatsappURL];
    }else{
        
        UIAlertView * al = [[UIAlertView alloc]initWithTitle:@"您的手機未安裝WhatsApp" message:nil delegate:self cancelButtonTitle:@"確定" otherButtonTitles:nil, nil];
        [al show];
    }
}

- (BOOL)isPhoneExist:(NSString *)phoneNum addressBook:(ABAddressBookRef)addressBook{
    
    CFArrayRef records;
    if (addressBook) {
        // 获取通讯录中全部联系人
        records = ABAddressBookCopyArrayOfAllPeople(addressBook);
    }
    for (int i=0; i<CFArrayGetCount(records); i++) {
        ABRecordRef record = CFArrayGetValueAtIndex(records, i);
        CFTypeRef items = ABRecordCopyValue(record, kABPersonPhoneProperty);
        CFArrayRef phoneNums = ABMultiValueCopyArrayOfAllValues(items);
        if (phoneNums) {
            for (int j=0; j<CFArrayGetCount(phoneNums); j++) {
                NSString *phone = (NSString*)CFArrayGetValueAtIndex(phoneNums, j);
                if ([phone isEqualToString:phoneNum]) {
                    return YES;
                }
            }
        }
    }
    return NO;
}

#pragma mark - alertView delegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    
    if (1 == buttonIndex) {
        
        NSURL * url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
        
        if([[UIApplication sharedApplication] canOpenURL:url]) {
            
            NSURL *url =[NSURL URLWithString:UIApplicationOpenSettingsURLString];
            [[UIApplication sharedApplication] openURL:url];
        }
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
