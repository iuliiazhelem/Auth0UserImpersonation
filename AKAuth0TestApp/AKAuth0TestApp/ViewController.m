//
//  ViewController.m
//  AKAuth0TestApp
//

#import "ViewController.h"
#import "AppDelegate.h"
#import <Lock/Lock.h>

//Please use your Auth0 APIv2 token from https://auth0.com/docs/api/management/v2/tokens
static NSString *kAuth0APIv2Token = @"eyJhbGciOiJIUz...........";

//Please use your application data from https://manage.auth0.com/#/account/advanced
//section "Global Client Information"
static NSString *kGlobalClientId = @"IuAb..........";
static NSString *kGlobalClientSecret = @"WtwgI.........";

//Please use your application data from https://auth0.com/docs/api/authentication
static NSString *kAppClientId = @"pj1N9W644zMIyI62UZqNIFnYCdsnwt9V";
static NSString *kAppClientSecret = @"Ioc...........";

//Please use your Auth0 Domain
static NSString *kAppRequestUrl = @"https://juliazhelem.eu.auth0.com";

static NSString *kAuth0ConnectionType = @"Username-Password-Authentication";
static NSString *kOpenURLProperty = @"openURL";
static NSString *kAccessToken = @"access_token";

@interface ViewController ()

@property (strong, nonatomic) A0UserProfile *profile;
@property (strong, nonatomic) NSMutableArray *pickerData;
@property (strong, nonatomic) NSMutableArray *userList;
@property (copy, nonatomic) NSString *selectedUser;

@property (weak, nonatomic) IBOutlet UITextField *emailTextField;
@property (weak, nonatomic) IBOutlet UITextField *passwordTextField;
- (IBAction)clickLoginButton:(id)sender;
@property (weak, nonatomic) IBOutlet UILabel *userName;
@property (weak, nonatomic) IBOutlet UILabel *userId;
@property (weak, nonatomic) IBOutlet UILabel *userEmail;
- (IBAction)clickGetUserList:(id)sender;
@property (weak, nonatomic) IBOutlet UIPickerView *usersPickerView;
- (IBAction)clickImpersonateButton:(id)sender;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.usersPickerView.dataSource = self;
    self.usersPickerView.delegate = self;
    
    self.pickerData = [NSMutableArray arrayWithCapacity:10];
}

- (void)viewWillAppear:(BOOL)animated {
    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    NSKeyValueObservingOptions kvoOptions = NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew;
    [appDelegate addObserver:self forKeyPath:kOpenURLProperty options:kvoOptions context:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [appDelegate removeObserver:self forKeyPath:kOpenURLProperty];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    NSURL *oldURL = change[NSKeyValueChangeOldKey];
    NSURL *newURL = change[NSKeyValueChangeNewKey];
    
    if ([keyPath isEqualToString:kOpenURLProperty] && newURL && ![oldURL isEqual:newURL]) {
        [self loginAsWithURL:newURL];
    }
}

- (void)loginAsWithURL:(NSURL *)url {
    NSString *query = url.query;
    if ([query containsString:@"code="]) {
        NSRange range = [query rangeOfString:@"code="];
        NSString *code = [query substringFromIndex:range.length];
        NSString *absoluteUrl = url.absoluteString;
        range = [absoluteUrl rangeOfString:@"?"];
        NSString *redirectUrl = [absoluteUrl substringToIndex:range.location];
        [self fetchTokenWithCode:code callbackURL:redirectUrl];
        [self clearTextFields];
    }
    
}

- (void)setProfile:(A0UserProfile *)profile {
    _profile = profile;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.userName.text = profile.name;
        self.userId.text = profile.userId;
        self.userEmail.text = profile.email;
    });
}

- (void)clearTextFields {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.emailTextField.text = @"";
        self.passwordTextField.text = @"";
    });
    [self showMessage:@"NEW USER! Please check in section \"Current Connection\""];
}

- (void)fetchTokenWithCode:(NSString *)code callbackURL:(NSString *)redirectURL {
    
    NSDictionary *headers = @{ @"content-type": @"application/json" };
    NSDictionary *body = @{ @"client_id": kAppClientId,
                            @"client_secret" : kAppClientSecret,
                            @"grant_type" : @"authorization_code",
                            @"redirect_uri" : redirectURL,
                            @"code" : code
                            };
    
    
    NSError *error;
    NSData *dataFromDict = [NSJSONSerialization dataWithJSONObject:body
                                                           options:0
                                                             error:&error];
    
    NSString *urlString = [NSString stringWithFormat:@"%@/oauth/token", kAppRequestUrl];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:10.0];
    [request setHTTPMethod:@"POST"];
    [request setAllHTTPHeaderFields:headers];
    [request setHTTPBody:dataFromDict];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request
                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                    if (error) {
                                                        NSLog(@"%@", error);
                                                    } else {
                                                        NSString *url = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                                                        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
                                                        
                                                        [self fetchUserProfileWithAccessToken:dict[kAccessToken]];
                                                    }
                                                }];
    [dataTask resume];
    
}

- (void)fetchUserProfileWithAccessToken:(NSString *)accessToken {
    
    NSString *urlString = [NSString stringWithFormat:@"%@/userinfo/?access_token=%@",kAppRequestUrl, accessToken];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:10.0];
    [request setHTTPMethod:@"GET"];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request
                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                    if (error) {
                                                        NSLog(@"%@", error);
                                                    } else {
                                                        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
                                                        NSLog(@"%@", dict);
                                                        self.profile = [[A0UserProfile alloc] initWithDictionary:dict];
                                                    }
                                                }];
    [dataTask resume];
    
}

- (IBAction)clickGetUserList:(id)sender {
    NSString *bearerToken = [NSString stringWithFormat:@"Bearer %@", kAuth0APIv2Token];
    NSDictionary *headers = @{ @"Authorization": bearerToken };
    
    NSString *urlString = [NSString stringWithFormat:@"%@/api/v2/users?include_totals=true&include_fields=true&search_engine=v2", kAppRequestUrl];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:10.0];
    [request setHTTPMethod:@"GET"];
    [request setAllHTTPHeaderFields:headers];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request
                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                    if (error) {
                                                        NSLog(@"%@", error);
                                                    } else {
                                                        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
                                                        NSLog(@"%@", httpResponse);
                                                        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
                                                        NSLog(@"%@", dict);
                                                        [self createUserList:dict];
                                                    }
                                                }];
    [dataTask resume];
}

- (void)createUserList:(NSDictionary *)userList {
    
    self.userList = [NSMutableArray arrayWithArray:userList[@"users"]];
    [self.pickerData removeAllObjects];
    for (NSDictionary *user in self.userList) {
        [self.pickerData addObject:user[@"name"]];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.usersPickerView reloadAllComponents];
    });
    
}

- (IBAction)clickImpersonateButton:(id)sender {
   
    //Getting bearer token
    NSDictionary *headers = @{ @"content-type": @"application/json" };
    NSDictionary *body = @{ @"client_id": kGlobalClientId,
                            @"client_secret" : kGlobalClientSecret,
                            @"grant_type" : @"client_credentials"
                            };
    
    
    NSError *error;
    NSData *dataFromDict = [NSJSONSerialization dataWithJSONObject:body
                                                           options:0
                                                             error:&error];
    
    NSString *urlString = [NSString stringWithFormat:@"%@/oauth/token", kAppRequestUrl];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:10.0];
    [request setHTTPMethod:@"POST"];
    [request setAllHTTPHeaderFields:headers];
    [request setHTTPBody:dataFromDict];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request
                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                    if (error) {
                                                        NSLog(@"%@", error);
                                                    } else {
                                                        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
                                                        NSLog(@"%@", dict);
                                                        //Impersonate user
                                                        [self impersonateUserWithBearerToken:dict[kAccessToken]];
                                                    }
                                                }];
    [dataTask resume];
    
}

- (void)impersonateUserWithBearerToken:(NSString *)bearerToken {
    
    NSString *token = [NSString stringWithFormat:@"Bearer %@", bearerToken];
    NSDictionary *headers = @{ @"content-type": @"application/json",
                               @"Authorization": token};
    
    NSDictionary *body = @{ @"protocol": @"oauth2",
                            @"impersonator_id" : self.profile.userId,
                            @"client_id" : kAppClientId,
                            @"response_type" : @"code"
                            };
    
    NSError *error;
    NSData *dataFromDict = [NSJSONSerialization dataWithJSONObject:body
                                                           options:0
                                                             error:&error];
    
    NSString *userId = [self.selectedUser stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet alphanumericCharacterSet]];
    NSString *urlString = [NSString stringWithFormat:@"%@/users/%@/impersonate", kAppRequestUrl, userId];
    NSURL *url = [NSURL URLWithString:urlString];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:10.0];
    [request setHTTPMethod:@"POST"];
    [request setAllHTTPHeaderFields:headers];
    [request setHTTPBody:dataFromDict];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request
                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                    if (error) {
                                                        NSLog(@"%@", error);
                                                    } else {
                                                        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
                                                        NSLog(@"%@", httpResponse);
                                                        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
                                                        NSLog(@"%@", dict);
                                                        NSString *url = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                                                        NSLog(@"URL : %@", url);
                                                        
                                                        [self openURLImpersonation:url];
                                                    }
                                                }];
    [dataTask resume];
    
}

- (void) openURLImpersonation:(NSString *)urlImpersonation {
    
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlImpersonation]];
}

- (IBAction)clickLoginButton:(id)sender {
    if (self.emailTextField.text.length < 1) {
        [self showMessage:@"You need to eneter email"];
        return;
    }
    if (self.passwordTextField.text.length < 1) {
        [self showMessage:@"You need to eneter password"];
        return;
    }
    
    NSString *email = self.emailTextField.text;
    NSString *password = self.passwordTextField.text;
    A0APIClient *client = [[A0Lock sharedLock] apiClient];
    A0APIClientAuthenticationSuccess success = ^(A0UserProfile *profile, A0Token *token) {
        self.profile = profile;
    };
    A0APIClientError error = ^(NSError *error){
        NSLog(@"Oops something went wrong: %@", error);
    };
    A0AuthParameters *params = [A0AuthParameters newDefaultParams];
    params[A0ParameterConnection] = kAuth0ConnectionType; // Or your configured DB connection
    [client loginWithUsername:email
                     password:password
                   parameters:params
                      success:success
                      failure:error];
}

- (void)showMessage:(NSString *)message
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Auth0" message:message preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
        [alertController addAction:ok];
        
        [self presentViewController:alertController animated:YES completion:nil];
    });
}

// The number of columns of data
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

// The number of rows of data
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return self.pickerData.count;
}

// The data to return for the row and component (column) that's being passed in
- (NSString*)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    return self.pickerData[row];
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    self.selectedUser = [self.userList[row] valueForKey:@"user_id" ];
}

@end
