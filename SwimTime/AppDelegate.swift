//
//  AppDelegate.swift
//  SwimTime
//
//  Created by Mick Mossman on 2/9/18.
//  Copyright © 2018 Mick Mossman. All rights reserved.
//

import UIKit
import RealmSwift
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
//<div>Icons made by <a href="https://www.flaticon.com/authors/roundicons"
    //https://stackoverflow.com/questions/34891743/realm-migrations-in-swift
    
    var window: UIWindow?
    
   
    
    //let realm = try! Realm()
    //let realm = try! Realm(configuration: config)
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        return true
    }
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        
        //doMigration()
        
        let seedDB = seedDatabase()


        seedDB.addGroups()
        seedDB.addInitSwimClub()
        seedDB.addtheseMembers(thisclubid:1)
        seedDB.addtheseMembers(thisclubid:2)
        seedDB.addThesePresetEvents()
        
        
        //checkExplorer()
        //addMembers()
        //checkSort()
        
        UIApplication.shared.applicationIconBadgeNumber = 0 //incase there was a badge
        return true
    }

    func doMigration() {
        let config = Realm.Configuration(
            // Set the new schema version. This must be greater than the previously used
            // version (if you've never set a schema version before, the version is 0).
            schemaVersion: 1,

            // Set the block which will be called automatically when opening a Realm with
            // a schema version lower than the one set above
            migrationBlock: { migration, oldSchemaVersion in

                if oldSchemaVersion < 1 {
                    migration.enumerateObjects(ofType: "SwimClub", {oldObject,newObject in
                        newObject?["webID"] = 0
                    })

                }
        }
        )
        Realm.Configuration.defaultConfiguration = config
        
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
        
        
        
        
        if let topController = UIApplication.shared.keyWindow?.rootViewController {
            
                if topController.children.count != 0 {
                
                    let vcArray = topController.children
                    
                    let lastVC = vcArray[vcArray.count-1]
                    
                    if lastVC.isMember(of: EventViewController.self) {
                        let vc  = lastVC as! EventViewController
                        if vc.timerOn {
                            
                            let myDefs = appUserDefaults()
                            if vc.isDualMeet {
                                myDefs.setRunningDualMeetId(dualMeetID: vc.selectedDualMeet.dualMeetID)
                            }else{
                               myDefs.setRunningDualMeetId(dualMeetID: 0)
                            }
                            myDefs.setRunningEventID(eventID: vc.currentEvent.eventID)
                            myDefs.setRunningEevntStopDate(stopDate: Date())
                            myDefs.setRunningEventSecondsStopped(clockseconds: vc.noSeconds)
                            vc.stopTimer()
                            UNUserNotificationCenter.current().requestAuthorization(options: [.badge]) { (granted, error) in
                                if error == nil {
                                    DispatchQueue.main.async(execute: {
                                        UIApplication.shared.applicationIconBadgeNumber = 1
                                    })
                                    
                                }
                            }
                            
                        }else{
                           UIApplication.shared.applicationIconBadgeNumber = 0
                        }
                        vc.navigationController?.popToRootViewController(animated: false)
                        
                        
                    }
                }

         }
        
        

    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    
    func applicationDidBecomeActive(_ application: UIApplication) {
        
        //need to pt this here. The main viewcontrollers viewwillappear and stuff doesnt fire correctly for what I want
        UIApplication.shared.applicationIconBadgeNumber = 0
        let myDefs = appUserDefaults()
        
        let runningEventID = myDefs.getRunningEventID()
        if runningEventID != 0 {
            
            if let topController = UIApplication.shared.keyWindow?.rootViewController {
                if topController.children.count == 1 {
                    let vc = topController.children[0] as! MainViewController
                        vc.performSegue(withIdentifier: "MainToEvent", sender: self)
                }
            }
            
        }
        
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    
    func checkSort() {
       /*this wokrs for sort by age
        let mems = realm.objects(Member.self).filter("dateOfBirth > vardate)
        
        let myList = mems.sorted(by: { $0.age() < $1.age()})
        
        for mem in myList {
        //for mem in array.sorted(by: { $0.age() > $1.age()}) {
            print(mem.memberName + " Age: \(mem.age())")
        }
         */
        
    }
    
    
}

