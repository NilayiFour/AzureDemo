//
//  ViewController.swift
//  AzureDemo
//
//  Created by iFour on 23/07/18.
//  Copyright © 2018 iFour Technolab Pvt. Ltd. All rights reserved.
//

import UIKit
import MSAL

class ViewController: UIViewController, UITextFieldDelegate, URLSessionDelegate {
//    let kTenantName = "kpmgb2c.onmicrosoft.com" // Your tenant name
    let kTenantName = "tagologicweb.onmicrosoft.com" // Your tenant name
//    let kClientID = "65b2faa1-6acd-4744-8e26-79904f881b0a" // Your client ID from the portal when you created your application
    let kClientID = "3ebaafb3-56ba-4062-8a7a-6d0bec5af762" // Your client ID from the portal when you created your application
    let kSignupOrSigninPolicy = "B2C_1A_SignUpOrSignInWithKmsi" // Your signup and sign-in policy you created in the portal
    let kEditProfilePolicy = "B2C_1A_ProfileEdit" // Your edit policy you created in the portal
//    let kGraphURI = "https://graph.microsoft.com/v1.0/me/" // This is your backend API that you've configured to accept your app's tokens
    let kGraphURI = "https://hmsnewapi.ifour-consultancy.net/User?objectId=6b14f8bb-6db5-4582-9cc0-4d1cddf0bd6e" // This is your backend API that you've configured to accept your app's tokens
//    let kScopes: [String] = ["https://kpmgb2c.onmicrosoft.com/notes/read"] // This is a scope that you've configured your backend API to look for.
    let kScopes: [String] = ["https://tagologicweb.onmicrosoft.com/hmsapitasks/read"] // This is a scope that you've configured your backend API to look for.

    // DO NOT CHANGE - This is the format of OIDC Token and Authorization endpoints for Azure AD B2C.
    let kEndpoint = "https://login.microsoftonline.com/tfp/%@/%@"
    
    var accessToken = String()
    var applicationContext = MSALPublicClientApplication.init()
    
    @IBOutlet weak var loggingText: UITextView!
    @IBOutlet weak var signoutButton: UIButton!
    
    // This button will invoke the call to the Microsoft Graph API. It uses the
    // built in Swift libraries to create a connection.
    
    //MARK:- UIViewController Lifecycle Methods Here....
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let kAuthority = String(format: kEndpoint, kTenantName, kSignupOrSigninPolicy)
        print(kAuthority)
        
        do {
            // Initialize a MSALPublicClientApplication with a given clientID and authority
            self.applicationContext = try MSALPublicClientApplication.init(clientId: kClientID, authority: kAuthority)
        }
        catch {
            self.loggingText.text = "Unable to create Application Context. Error: \(error)"
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if UserDefaults.standard.object(forKey: "token") != nil {
            let str: String = UserDefaults.standard.value(forKey: "token") as! String
            
            if str == "" {
                signoutButton.isEnabled = false;
            }
            else {
                self.accessToken = str
                signoutButton.isEnabled = true;
                
                self.getContentWithToken()
            }
        }
        else {
            signoutButton.isEnabled = false;
        }
    }
    
    //MARK:- Graph Button Click Event Method Here....
    @IBAction func callGraphButton(_ sender: UIButton) {
        do {
            // We check to see if we have a current signed-in user. If we don't, then we need to sign someone in.
            // We throw an interactionRequired so that we trigger the interactive sign-in.
            if  try self.applicationContext.users().isEmpty {
                throw NSError.init(domain: "MSALErrorDomain", code: MSALErrorCode.interactionRequired.rawValue, userInfo: nil)
            }
            else {
                // Acquire a token for an existing user silently
                try self.applicationContext.acquireTokenSilent(forScopes: self.kScopes, user: applicationContext.users().first) { (result, error) in
                    
                    if error == nil {
                        self.accessToken = (result?.accessToken)!
                        
                        DispatchQueue.main.async(){
                            self.loggingText.text = "Refreshing token silently)"
                            self.loggingText.text = "Refreshed Access token is \(self.accessToken)"
                            
                            self.signoutButton.isEnabled = true;
                        }
                        UserDefaults.standard.set(self.accessToken, forKey: "token")
                        UserDefaults.standard.synchronize()
                        
                        self.getContentWithToken()
                    }
                    else {
                        DispatchQueue.main.async(){
                            self.loggingText.text = "Could not acquire token silently: \(error ?? "No error information" as! Error)"
                        }
                    }
                }
            }
        }
        catch let error as NSError {
            // interactionRequired means we need to ask the user to sign in. This usually happens
            // when the user's Refresh Token is expired or if the user has changed their password
            // among other possible reasons.
            if error.code == MSALErrorCode.interactionRequired.rawValue {
                self.applicationContext.acquireToken(forScopes: self.kScopes) { (result, error) in
                    if error == nil {
                        self.accessToken = (result?.accessToken)!
                        
                        DispatchQueue.main.async(){
                            self.loggingText.text = "Access token is \(self.accessToken)"
                            self.signoutButton.isEnabled = true;
                        }
                        UserDefaults.standard.set(self.accessToken, forKey: "token")
                        UserDefaults.standard.synchronize()
                        
                        self.getContentWithToken()
                    }
                    else {
                        DispatchQueue.main.async(){
                            self.loggingText.text = "Could not acquire token: \(error ?? "No error information" as! Error)"
                        }
                    }
                }
            }
        }
        catch {
            // This is the catch all error.
            self.loggingText.text = "Unable to acquire token. Got error: \(error)"
        }
    }
    
    //MARK:- API call using Access Token Method Here....
    func getContentWithToken() {
        let sessionConfig = URLSessionConfiguration.default
        
        // Specify the Graph API endpoint
        let url = URL(string: kGraphURI)
        var request = URLRequest(url: url!)
        
        // Set the Authorization header for the request. We use Bearer tokens, so we specify Bearer + the token we got from the result
        request.setValue("Bearer \(self.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("9b2c00d9983d4c6d82448bec510b57ba", forHTTPHeaderField: "Ocp-Apim-Subscription-Key")

        let urlSession = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: OperationQueue.main)
        
        urlSession.dataTask(with: request) { data, response, error in
            let result: NSDictionary = try! JSONSerialization.jsonObject(with: data!, options: []) as! NSDictionary

            if result != nil {
                var arr: NSDictionary = NSDictionary()

                if ((result.value(forKey: "error") as? NSDictionary) != nil) {
                    arr = result.value(forKey: "error") as! NSDictionary
                    let str: String = arr.value(forKey: "code") as! String

                    if str == "InvalidAuthenticationToken" {
                        self.callGraphButton(UIButton())
                    }
                }
                else {
                    self.loggingText.text = result.debugDescription
                }
            }
            }.resume()
    }
    
    //MARK:- SignOut Button Click Event Method Here....
    @IBAction func signoutButton(_ sender: UIButton) {
        do {
            // Removes all tokens from the cache for this application for the provided user
            // first parameter:   The user to remove from the cache
            try self.applicationContext.remove(self.applicationContext.users().first)
            self.signoutButton.isEnabled = false;
            
            UserDefaults.standard.set("", forKey: "token")
            UserDefaults.standard.synchronize()
        }
        catch let error {
            self.loggingText.text = "Received error signing user out: \(error)"
        }
    }
    
    //MARK:- Memory Management Warning Method Here....
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
