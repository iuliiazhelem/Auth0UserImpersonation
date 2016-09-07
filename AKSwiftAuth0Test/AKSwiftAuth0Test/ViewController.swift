//
//  ViewController.swift
//  AKSwiftAuth0Test
//

import UIKit
import Lock

//Please use your Auth0 APIv2 token from https://auth0.com/docs/api/management/v2/tokens
let kAuth0APIv2Token = "Auth0APIv2Token"

//Please use your application data from https://manage.auth0.com/#/account/advanced
//section "Global Client Information"
let kGlobalClientId = "GlobalClientId"
let kGlobalClientSecret = "GlobalClientSecret"

//Please use your application data from https://auth0.com/docs/api/authentication
let kAuth0ClientSecret = "Auth0ClientSecret"
let kAuth0ClientId = "Auth0ClientId"
let kAuth0Domain = "Auth0Domain"

let kAuth0ConnectionType = "Username-Password-Authentication"
let kOpenURLProperty = "openURL"
let kAccessToken = "access_token"

class ViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {

    @IBOutlet weak var usersPickerView: UIPickerView!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var userIdLabel: UILabel!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    
    var pickerData:NSMutableArray = []
    var profile:A0UserProfile?
    var tokens:A0Token?
    var userList:NSArray?
    var selectedUser:String?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.usersPickerView.dataSource = self
        self.usersPickerView.delegate = self
    }
    
    // Add observing for "openURL" property of AppDelegate
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        let appDelegate:AppDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        let options = NSKeyValueObservingOptions([.New, .Old])
        appDelegate.addObserver(self, forKeyPath:kOpenURLProperty, options:options, context:nil);        
    }
  
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        let appDelegate:AppDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        appDelegate.removeObserver(self, forKeyPath: kOpenURLProperty)
    }
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        guard keyPath != nil else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
            return
        }
        
        let oldURL:NSURL? = change![NSKeyValueChangeOldKey] as? NSURL
        if let newURL = change![NSKeyValueChangeNewKey] as? NSURL {
            if (keyPath! == kOpenURLProperty) && !(oldURL == newURL) {
                self.loginAsWithURL(newURL)
            }
        }
    }
    
    // Step 1: Login to Auth0
    @IBAction func clickLoginButton(sender: AnyObject) {
        if (self.emailTextField.text?.characters.count < 1) {
            self.showMessage("Please eneter an email");
            return;
        }
        if (self.passwordTextField.text?.characters.count < 1) {
            self.showMessage("Please eneter a password");
            return;
        }
        
        let success = { (profile: A0UserProfile?, token: A0Token?) in
            self.tokens = token
            self.profile = profile
            self.showUserProfile(profile!)
        }
        let failure = { (error: NSError) in
            self.clearUserProfile()
            self.showMessage("Oops something went wrong: \(error)");
            print("Oops something went wrong: \(error)")
        }
        
        let email = self.emailTextField.text!;
        let password = self.passwordTextField.text!;
        let client = A0Lock.sharedLock().apiClient()
        let parameters = A0AuthParameters(dictionary: [A0ParameterConnection : kAuth0ConnectionType])
        
        //Login with email and password (Auth0 database connection)
        client.loginWithUsername(email, password: password, parameters: parameters, success: success, failure: failure)
    }
    
    // Step 2: Get list of available users for impersonation
    @IBAction func clickGetUserListButton(sender: AnyObject) {
        // GET request
        // We need url "https://<Auth0 Domain>//api/v2/users?include_totals=true&include_fields=true&search_engine=v2"
        // and header "Authorization : Bearer <kAuth0APIv2Token>"
        
        let userDomain = (NSBundle.mainBundle().infoDictionary![kAuth0Domain]) as! String
        let urlString = "https://\(userDomain)/api/v2/users?include_totals=true&include_fields=true&search_engine=v2"
        let url = NSURL(string: urlString)
        if let actualUrl = url {
            let request = NSMutableURLRequest(URL: actualUrl)
            request.HTTPMethod = "GET";
            let apiToken = (NSBundle.mainBundle().infoDictionary![kAuth0APIv2Token]) as! String
            request.allHTTPHeaderFields = ["Authorization" : "Bearer \(apiToken)"]
            
            NSURLSession.sharedSession().dataTaskWithRequest(request, completionHandler: {(data : NSData?, response : NSURLResponse?, error : NSError?) in
                
                // Check if data was received successfully
                if error == nil && data != nil {
                    do {
                        // Convert NSData to Dictionary where keys are of type String, and values are of any type
                        let json = try NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers) as! [String:AnyObject]
                        print("\(json)")
                        self.createUserList(json)
                    } catch {
                        let dataString = String(data: data!, encoding: NSUTF8StringEncoding)
                        print("Oops something went wrong: \(dataString)")
                    }
                } else {
                    print("Oops something went wrong: \(error)")
                }
            }).resume()
        } else {
            print("Incorrect url")
        }
    }
    
    // Step 3: Get bearer token for an impersonation
    @IBAction func clickImpersonateButton(sender: AnyObject) {
        // POST request
        // We need url "https://<Auth0 Domain>/oauth/token"
        // and header "content-type": "application/json"
        
        let headers = ["content-type": "application/json"]
        let clientId = (NSBundle.mainBundle().infoDictionary![kGlobalClientId]) as! String
        let clientSecrete = (NSBundle.mainBundle().infoDictionary![kGlobalClientSecret]) as! String
        let parameters = [
            "client_id": clientId,
            "client_secret": clientSecrete,
            "grant_type": "client_credentials"
        ]
        
        var postData:NSData = NSData()
        do {
            postData = try NSJSONSerialization.dataWithJSONObject(parameters, options:[])
        } catch let error as NSError {
            print(error.localizedDescription)
            return;
        }
        
        let userDomain = (NSBundle.mainBundle().infoDictionary!["Auth0Domain"]) as! String
        let request = NSMutableURLRequest(URL: NSURL(string: "https://\(userDomain)/oauth/token")!,
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
                    print("\(json)")
                    //Impersonate user
                    self.impersonateUserWithBearerToken(json[kAccessToken] as? String)
                } catch {
                    let dataString = String(data: data!, encoding: NSUTF8StringEncoding)
                    print("Oops something went wrong: \(dataString)")
                }
            } else {
                print("Oops something went wrong: \(error)")
            }
        }).resume()
    }
    
    // Step 4: Perform the impersonation for selected user (user_id) and get a link
    func impersonateUserWithBearerToken(bearerToken:String?) {
        // POST request
        // We need url "https://<Auth0 Domain>/users/<Selected_User_id>/impersonate"
        // and header "authorization": "Bearer <Bearer_Token>"

        if let actualToken = bearerToken {
            let headers = [
                "content-type": "application/json",
                "authorization": "Bearer \(actualToken)"
            ]
            let parameters = [
                "protocol": "oauth2",
                "impersonator_id": self.profile!.userId,
                "client_id": ((NSBundle.mainBundle().infoDictionary![kAuth0ClientId]) as! String),
                "response_type": "code"
            ]

            var postData:NSData = NSData()
            do {
                postData = try NSJSONSerialization.dataWithJSONObject(parameters, options:[])
            } catch let error as NSError {
                print(error.localizedDescription)
                return;
            }
            
            let userDomain = (NSBundle.mainBundle().infoDictionary![kAuth0Domain]) as! String
            let userId = self.selectedUser!.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.alphanumericCharacterSet());

            let request = NSMutableURLRequest(URL: NSURL(string: "https://\(userDomain)/users/\(userId!)/impersonate")!,
                                              cachePolicy: .UseProtocolCachePolicy,
                                              timeoutInterval: 10.0)
            request.HTTPMethod = "POST"
            request.allHTTPHeaderFields = headers
            request.HTTPBody = postData
            
             NSURLSession.sharedSession().dataTaskWithRequest(request, completionHandler: { (data, response, error) -> Void in
                // Check if data was received successfully
                if error == nil && data != nil {
                    let url = NSString(data: data!, encoding: NSUTF8StringEncoding)
                    self.openURLImpersonation(url as! String);
                } else {
                    print("Oops something went wrong: \(error)")
                }
             }).resume()
        }
    }
    
    // Step 5: Open the link for impersonation
    func openURLImpersonation(urlImpersonation:String) {
        UIApplication.sharedApplication().openURL(NSURL(string: urlImpersonation)!)
    }
    
    // Step 6: Fetch a token with the code
    func fetchTokenWithCode(code: String, callbackURL:String) {
        // POST request
        // We need url "https://<Auth0 Domain>/oauth/token"
        // and header "content-type": "application/json"
        
        let userDomain = (NSBundle.mainBundle().infoDictionary![kAuth0Domain]) as! String
        let clientId = (NSBundle.mainBundle().infoDictionary![kAuth0ClientId]) as! String
        let clientSecrete = (NSBundle.mainBundle().infoDictionary![kAuth0ClientSecret]) as! String
        
        let headers = ["content-type": "application/json"]
        let parameters = [
            "client_id": clientId,
            "client_secret": clientSecrete,
            "grant_type": "authorization_code",
            "redirect_uri": callbackURL,
            "code": code
        ]
        
        var postData:NSData = NSData()
        do {
            postData = try NSJSONSerialization.dataWithJSONObject(parameters, options:[])
        } catch let error as NSError {
            print(error.localizedDescription)
            return;
        }
        
        let request = NSMutableURLRequest(URL: NSURL(string: "https://\(userDomain)/oauth/token")!,
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
                    print("\(json)")
                    //Fetch user profile
                    self.fetchUserProfileWithAccessToken(json[kAccessToken] as? String)
                } catch {
                    let dataString = String(data: data!, encoding: NSUTF8StringEncoding)
                    print("Oops something went wrong: \(dataString)")
                }
            } else {
                print("Oops something went wrong: \(error)")
            }
        }).resume()
    }
    
    // Step 7: Get user profile for a new user
    func fetchUserProfileWithAccessToken(accessToken:String?) {
        // GET request
        // We need url "https://<Auth0 Domain>/userinfo/?access_token=<ACCESS_TOKEN>"

        if let actualAccessToken = accessToken {
            let userDomain = (NSBundle.mainBundle().infoDictionary!["Auth0Domain"]) as! String
            let url = NSURL(string: "https://\(userDomain)/userinfo?access_token=\(actualAccessToken)")
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
                            self.profile = A0UserProfile(dictionary:json);
                            self.showUserProfile(self.profile!)
                        } catch {
                            let dataString = String(data: data!, encoding: NSUTF8StringEncoding)
                            print("Oops something went wrong: \(dataString)")
                        }
                    } else {
                        print("Oops something went wrong: \(error)")
                    }
                }).resume()
            } else {
                print("Incorrect url")
            }
        }
    }
    
    // UIPickerViewDataSource delegate methods
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.pickerData.count
    }
    
    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return self.pickerData[row] as? String
    }
    
    func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let actualUser:NSDictionary = self.userList![row] as! NSDictionary
        self.selectedUser = actualUser["user_id"] as? String
    }

    // Internal methods
    func showMessage(message: String) {
        dispatch_async(dispatch_get_main_queue()) {
            let alert = UIAlertController(title: "Auth0", message: message, preferredStyle: UIAlertControllerStyle.Alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil))
            self.presentViewController(alert, animated: true, completion: nil)
        }
    }
    
    func showUserProfile(profile: A0UserProfile) {
        dispatch_async(dispatch_get_main_queue()) {
            self.usernameLabel.text = profile.name
            self.emailLabel.text = profile.email
            self.userIdLabel.text = profile.userId
        }
    }
    
    func clearUserProfile() {
        dispatch_async(dispatch_get_main_queue()) {
            self.usernameLabel.text = ""
            self.emailLabel.text = ""
            self.userIdLabel.text = ""
        }
    }
    
    func loginAsWithURL(url:NSURL) {
        let query = url.query!
        if query.rangeOfString("code=") != nil {
            let code = query[query.startIndex.advancedBy(5)..<query.endIndex]
            let absoluteUrl = url.absoluteString
            let redirectUrl = absoluteUrl[absoluteUrl.startIndex..<absoluteUrl.endIndex.advancedBy(-query.characters.count-1)]
            self.fetchTokenWithCode(code, callbackURL:redirectUrl)
            self.clearUserProfile();
            self.showMessage("NEW USER! Please check in section \"Current Connection\"")
        }
    }
    
    func createUserList(userList: NSDictionary) {
        self.userList = userList["users"] as? NSArray
        if let actualUserList = self.userList {
            self.pickerData.removeAllObjects()
            for user in actualUserList {
                let actualUser:NSDictionary = user as! NSDictionary
                self.pickerData.addObject(actualUser["name"]!)
            }
            dispatch_async(dispatch_get_main_queue()) {
                self.usersPickerView.reloadAllComponents()
            }
        }
    }
}
