# Auth0UserImpersonation

This sample exposes how to implemet User impersonation.

Often administrators need to impersonate other users for testing or troubleshooting purposes. Using impersonation the administrators can login to an app as a specific user, see everything exactly as that user sees it, and do everything exactly as that user does it. Or you have two apps, app1 and app2, and you want to impersonate the users of app2.
Impersonation endpoint generates a link that can be used only once to log in as a specific user for troubleshooting purposes. 

For this you need to add the following to your `Podfile`:
```
pod 'Lock', '~> 1.24'
pod 'SimpleKeychain'
```

The main steps for the implementation of user impersonation are:

- Getting Auth0 APIv2 token as described [here](https://auth0.com/docs/api/management/v2/tokens)
- Getting Global Client credentials from [Dashboard](https://manage.auth0.com/#/account/advanced) , section "Global Client Information"
- Getting application Client Id and Client Secret from [Dashboard](https://auth0.com/docs/api/authentication)
- Login to your iOS application
- You may need to get list of available users for impersonation or you can see this list on [Dashboard](https://manage.auth0.com/#/users)
- Perform a impersonation for selected user (user_id) and get a link
- Open this link as "openURL"
- After opening the application, you need to exchange the code you received for a token
- You can use this token to call the Auth0 API and get additional information such as the user profile

## Important Snippets

### Step 1: Login with email and password (Auth0 database connection). 
```swift
let success = { (profile: A0UserProfile, token: A0Token) in
  print("User: \(profile)")
}
let failure = { (error: NSError) in
  print("Oops something went wrong: \(error)")
}
let parameters = A0AuthParameters(dictionary: [A0ParameterConnection : "Username-Password-Authentication"])
A0Lock.sharedLock().apiClient().loginWithUsername(email, password: password, parameters: parameters, success: success, failure: failure)
```

```Objective-C
void(^success)(A0UserProfile *, A0Token *) = ^(A0UserProfile *profile, A0Token *token) {
  NSLog(@"User: %@", profile);
};
void(^error)(NSError *) = ^(NSError *error) {
  NSLog(@"Oops something went wrong: %@", error);
};

A0AuthParameters *params = [A0AuthParameters newDefaultParams];
params[A0ParameterConnection] = @"Username-Password-Authentication"; // Or your configured DB connection
[[[A0Lock sharedLock] apiClient] loginWithUsername:email
                                          password:password
                                        parameters:params
                                           success:success
                                           failure:error];
```

### Step 2: Get list of available users for impersonation.
```swift
let urlString = "https://\(<AUTH0_DOMAIN>)/api/v2/users?include_totals=true&include_fields=true&search_engine=v2"
let url = NSURL(string: urlString)
if let actualUrl = url {
    let request = NSMutableURLRequest(URL: actualUrl)
    request.HTTPMethod = "GET";
    request.allHTTPHeaderFields = ["Authorization" : "Bearer \(<API_V2_TOKEN>)"]
            
    NSURLSession.sharedSession().dataTaskWithRequest(request, completionHandler: {(data : NSData?, response : NSURLResponse?, error : NSError?) in
        // Check if data was received successfully
        if error == nil && data != nil {
            do {
                // Convert NSData to Dictionary where keys are of type String, and values are of any type
                let json = try NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers) as! [String:AnyObject]
                print("\(json)")
            } catch {
                let dataString = String(data: data!, encoding: NSUTF8StringEncoding)
                print("Oops something went wrong: \(dataString)")
            }
        }
    }).resume()
}
```

```Objective-C
    NSString *bearerToken = [NSString stringWithFormat:@"Bearer %@", <API_V2_TOKEN>];
    NSDictionary *headers = @{ @"Authorization": bearerToken };
    
    NSString *urlString = [NSString stringWithFormat:@"https://%@/api/v2/users?include_totals=true&include_fields=true&search_engine=v2", <AUTH0_DOMAIN>];
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
                                                        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
                                                        NSLog(@"%@", dict);
                                                    }
                                                }];
    [dataTask resume];
```

### Step 3: Get bearer token for an impersonation
```Swift
let headers = ["content-type": "application/json"]
let parameters = [
    "client_id": <GLOBAL_CLIENT_ID>,
    "client_secret": <GLOBAL_CLIENT_SECRET>,
    "grant_type": "client_credentials"
]
        
var postData:NSData = NSData()
do {
    postData = try NSJSONSerialization.dataWithJSONObject(parameters, options:[])
} catch let error as NSError {
    print(error.localizedDescription)
    return;
}
        
let request = NSMutableURLRequest(URL: NSURL(string: "https://\(<AUTH0_DOMAIN>)/oauth/token")!,
                          cachePolicy: .UseProtocolCachePolicy,
                      timeoutInterval: 10.0)
request.HTTPMethod = "POST"
request.allHTTPHeaderFields = headers
request.HTTPBody = postData
        
NSURLSession.sharedSession().dataTaskWithRequest(request, completionHandler: { (data, response, error) -> Void in
    // Check if data was received successfully
    if error == nil && data != nil {
        do {
            // Convert NSData to Dictionary where keys are of type String, and values are of any type
            let json = try NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers) as! [String:AnyObject]
            print("\(json["access_token"])")
        } catch {
            let dataString = String(data: data!, encoding: NSUTF8StringEncoding)
            print("Oops something went wrong: \(dataString)")
        }
    }
}).resume()
```

```Objective-C
    NSDictionary *headers = @{ @"content-type": @"application/json" };
    NSDictionary *body = @{ @"client_id": <GLOBAL_CLIENT_ID>,
                            @"client_secret" : <GLOBAL_CLIENT_SECRET>,
                            @"grant_type" : @"client_credentials"
                            };
    NSError *error;
    NSData *dataFromDict = [NSJSONSerialization dataWithJSONObject:body
                                                           options:0
                                                             error:&error];
    
    NSString *urlString = [NSString stringWithFormat:@"https://%@/oauth/token", <AUTH0_DOMAIN>];
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
                                                        NSLog(@"%@", dict[@"access_token"]);
                                                    }
                                                }];
    [dataTask resume];
```

### Step 4: Perform the impersonation for selected user (user_id) and get a link
```Swift
let headers = [
    "content-type": "application/json",
    "authorization": "Bearer \(<BEARER_TOKEN>)"
]
let parameters = [
    "protocol": "oauth2",
    "impersonator_id": <CURRENT_USER_ID>,
    "client_id": <AUTH0_CLIENT_ID>,
    "response_type": "code"
]
var postData:NSData = NSData()
do {
    postData = try NSJSONSerialization.dataWithJSONObject(parameters, options:[])
} catch let error as NSError {
    print(error.localizedDescription)
    return;
}

let request = NSMutableURLRequest(URL: NSURL(string: "https://\(<AUTH0_DOMAIN>)/users/\(<SELECTED_USER_ID>)/impersonate")!,
                          cachePolicy: .UseProtocolCachePolicy,
                      timeoutInterval: 10.0)
request.HTTPMethod = "POST"
request.allHTTPHeaderFields = headers
request.HTTPBody = postData
            
NSURLSession.sharedSession().dataTaskWithRequest(request, completionHandler: { (data, response, error) -> Void in
    // Check if data was received successfully
    if error == nil && data != nil {
        let url = NSString(data: data!, encoding: NSUTF8StringEncoding)
    }
}).resume()
```

```Objective-C
    NSString *token = [NSString stringWithFormat:@"Bearer %@", <BAREAR_TOKEN>];
    NSDictionary *headers = @{ @"content-type": @"application/json",
                               @"Authorization": token};
    NSDictionary *body = @{ @"protocol": @"oauth2",
                            @"impersonator_id" : <CURRENT_USER_ID>,
                            @"client_id" : <AUTH0_CLIENT_ID>,
                            @"response_type" : @"code"
                            };
    
    NSError *error;
    NSData *dataFromDict = [NSJSONSerialization dataWithJSONObject:body
                                                           options:0
                                                             error:&error];
    
    NSString *urlString = [NSString stringWithFormat:@"https://%@/users/%@/impersonate", <AUTH0_DOMAIN>, <SELECTED_USER_ID>];
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
                                                        NSLog(@"URL : %@", url);
                                                    }
                                                }];
    [dataTask resume];
```

### Step 5: Fetch a token with the code
```Swift
let headers = ["content-type": "application/json"]
let parameters = [
        "client_id": <AUTH0_CLIENT_ID>,
    "client_secret": <AUTH0_CLIENT_SECRET>,
       "grant_type": "authorization_code",
     "redirect_uri": <REDIRECT_URI>,
             "code": <CODE>
        ]
        
var postData:NSData = NSData()
do {
    postData = try NSJSONSerialization.dataWithJSONObject(parameters, options:[])
} catch let error as NSError {
    print(error.localizedDescription)
    return;
}
        
let request = NSMutableURLRequest(URL: NSURL(string: "https://\(<AUTH0_DOMAIN>)/oauth/token")!,
                          cachePolicy: .UseProtocolCachePolicy,
                      timeoutInterval: 10.0)
request.HTTPMethod = "POST"
request.allHTTPHeaderFields = headers
request.HTTPBody = postData
        
NSURLSession.sharedSession().dataTaskWithRequest(request, completionHandler: { (data, response, error) -> Void in
    // Check if data was received successfully
    if error == nil && data != nil {
        do {
            // Convert NSData to Dictionary where keys are of type String, and values are of any type
            let json = try NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers) as! [String:AnyObject]
            print("\(json["access_token"])")
        } catch {
            let dataString = String(data: data!, encoding: NSUTF8StringEncoding)
            print("Oops something went wrong: \(dataString)")
        }
}).resume()
```

```Objective-C
    NSString *clientId = [NSBundle mainBundle].infoDictionary[kAuth0ClientId];
    NSString *clientSecret = [NSBundle mainBundle].infoDictionary[kAuth0ClientSecret];
    NSDictionary *headers = @{ @"content-type": @"application/json" };
    NSDictionary *body = @{ @"client_id": <AUTH0_CLIENT_ID>,
                            @"client_secret" : <AUTH0_CLIENT_SECRET>,
                            @"grant_type" : @"authorization_code",
                            @"redirect_uri" : <REDIRECT_URI>,
                            @"code" : <CODE>
                            };
    
    NSError *error;
    NSData *dataFromDict = [NSJSONSerialization dataWithJSONObject:body
                                                           options:0
                                                             error:&error];
    
    NSString *urlString = [NSString stringWithFormat:@"https://%@/oauth/token", <AUTH0_DOMAIN>];
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
                                                        NSLog(@"%@", dict[@"access_token"]);
                                                    }
                                                }];
    [dataTask resume];
```

### Step 6: Get user profile for a new user
```Swift
let url = NSURL(string: "https://\(<AUTH0_DOMAIN>)/userinfo?access_token=\(<ACCESS_TOKEN>)")
if let actualUrl = url {
    let request = NSMutableURLRequest(URL: actualUrl)
    request.HTTPMethod = "GET";
                
    NSURLSession.sharedSession().dataTaskWithRequest(request, completionHandler: {(data : NSData?, response : NSURLResponse?, error : NSError?) in
        // Check if data was received successfully
        if error == nil && data != nil {
            do {
                // Convert NSData to Dictionary where keys are of type String, and values are of any type
                let json = try NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers) as! [String:AnyObject]
                print("\(json)")
            } catch {
                let dataString = String(data: data!, encoding: NSUTF8StringEncoding)
                print("Oops something went wrong: \(dataString)")
            }
        }
    }).resume()
}
```

```Objective-C
    NSString *urlString = [NSString stringWithFormat:@"https://%@/userinfo/?access_token=%@",<AUTH0_DOMAIN>, <ACCESS_TOKEN>];
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
                                                    }
                                                }];
    [dataTask resume];
```


Before using the example, please make sure that you change some keys in the `Info.plist` file with your data:

##### Auth0 data from [Auth0 Dashboard](https://manage.auth0.com/#/applications):

- Auth0ClientId
- Auth0ClientSecret
- Auth0Domain
- CFBundleURLSchemes

```
<key>CFBundleTypeRole</key>
<string>None</string>
<key>CFBundleURLName</key>
<string>auth0</string>
<key>CFBundleURLSchemes</key>
<array>
<string>a0{CLIENT_ID}</string>
</array>
```
##### Global client data from [Dashboard](https://manage.auth0.com/#/account/advanced) , section "Global Client Information"

- GlobalClientId
- GlobalClientSecret

##### [Auth0 APIv2 token](https://auth0.com/docs/api/management/v2/tokens)

- Auth0APIv2Token

For more information about reset password please check the following link:
* [User impersonation](https://auth0.com/docs/user-profile/user-impersonation)
