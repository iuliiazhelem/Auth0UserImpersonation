# Auth0UserImpersonation

This sample exposes how to use Lock for custom implementation of "Change Password" functionality.

NOTE: You can only change passwords for users signing in using Database connections. Users signing in using Social or Enterprise connections need to reset their passwords with the appropriate system.

For this you need to add the following to your `Podfile`:
```
pod 'Lock', '~> 1.24'
pod 'SimpleKeychain'
```

## Important Snippets

### Request a change password for the given user. Auth0 will send an email with a link to input a new password. 
```swift
A0Lock.sharedLock().apiClient().requestChangePasswordForUsername(self.emailTextField.text!,
    parameters: params, success: { () -> Void in
      print("We have just sent you an email.to reset your password")
    }, failure: {(error: NSError) in
      print("Oops something went wrong: \(error)")}
)
```

```Objective-C
[[[A0Lock sharedLock] apiClient] requestChangePasswordForUsername:self.emailTextField.text
  parameters:params
     success:^{
        NSLog(@"We have just sent you an email to reset your password");                          
     } failure:^(NSError * _Nonnull error) {
        NSLog(@"%@", error);
     }];
```

Before using the example, please make sure that you change some keys in the `Info.plist` file with your data:

##### Auth0 data from [Auth0 Dashboard](https://manage.auth0.com/#/applications):

- Auth0ClientId
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

For more information about reset password please check the following link:
* [Changing a User's Password](https://auth0.com/docs/connections/database/password-change)
