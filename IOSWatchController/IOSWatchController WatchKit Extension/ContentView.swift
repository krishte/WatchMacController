//
//  ContentView.swift
//  IOSWatchController WatchKit Extension
//
//  Created by Tejas Krishnan on 30.01.22.
//

import SwiftUI
import Foundation
import WatchConnectivity
import CoreMotion

class InterfaceController: NSObject, WCSessionDelegate {
    
    // MARK: Outlets
    

    
    // MARK: Variables
    
    var wcSession : WCSession!
    
    // MARK: Overrides
    
//    override func awake(withContext context: Any?) {
//        super.awake(withContext: context)
//        
//    }
    
    func loadsession()
    {
        wcSession = WCSession.default
        wcSession.delegate = self
        wcSession.activate()
        
    }
    

    
//    override func didDeactivate() {
//        super.didDeactivate()
//    }
//    
    // MARK: WCSession Methods
    func swiperight() {
        print("kewl sent")
        let message = ["message":"Right"]

        wcSession.sendMessage(message, replyHandler: nil)

    }
    
    func swipeleft() {
        print("kewl sent")
        let message = ["message":"Left"]

        wcSession.sendMessage(message, replyHandler: nil)

    }
    
    func gyrosend(x:Double, y:Double, z:Double)
    {
        let message = ["message": (String(x) + "  " + String(y) + "  " + String(z))]
        wcSession.sendMessage(message, replyHandler: nil)
    }
//    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
//        print("kewl received")
//        linkedtext = message["message"] as! String
//        
//     
//        
//    }

    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
        // Code.
        
    }

}

struct ContentView: View {

    @State var messagetext = ""
    var model = InterfaceController()
    var motion = CMMotionManager()
    
    var body: some View {
        VStack
        {
//            Button(action:
//                    {
//                if (model.wcSession.isReachable)
//                {
//                    print("phone reachable")
//                }
//            })
//            {
//                Text("Update")
//            }
            Button(action:
                    {
                print("button pressed")
                model.swiperight()
            })
            {
                Text("Right")
            }
            Button(action:
                    {
                print("button pressed")
                model.swipeleft()
            })
            {
                Text("Left")
            }
            Button(action:{
                startGyros()
            })
            {
                Text("Start Gyro")
            }
            Button(action: {
                stopGyros()
            })
            {
                Text("Stop Gyro")
            }
        }.onAppear {
            model.loadsession()
        }
        
        
    }
    
    func startGyros() {
        if self.motion.isAccelerometerAvailable {
              self.motion.accelerometerUpdateInterval = 60.0 / 60.0  // 60 Hz
              self.motion.startAccelerometerUpdates()
            var storedaccx: Double = 0
              // Configure a timer to fetch the data.
              let timer = Timer(fire: Date(), interval: (1.0/60.0),
                    repeats: true, block: { (timer) in
                 // Get the accelerometer data.
                 if let data = self.motion.accelerometerData {
                    let x = data.acceleration.x
                    let y = data.acceleration.y
                    let z = data.acceleration.z
                     
                     if (x != storedaccx)
                     {
                         storedaccx = x
                         model.swipeleft()
                     }

                    // Use the accelerometer data in your app.
                 }
              })

              // Add the timer to the current run loop.
            RunLoop.current.add(timer, forMode: .default)
           }
//       if motion.isGyroAvailable {
//          self.motion.gyroUpdateInterval = 60 / 60.0
//          self.motion.startGyroUpdates()
//           var storedgyrox: Double = 0
//          // Configure a timer to fetch the accelerometer data.
//           let timer = Timer(fire: Date(), interval: (1.0/60.0),
//                 repeats: true, block: { (timer) in
//             // Get the gyro data.
//             if let data = self.motion.gyroData {
//                let x = data.rotationRate.x
//                let y = data.rotationRate.y
//                let z = data.rotationRate.z
//
//                 if (x != storedgyrox)
//                 {
//                     storedgyrox = x
//                     model.swipeleft()
//                 }
//                 //model.gyrosend(x: x, y: y, z: z)
//                // print(x, y, z)
//                // Use the gyroscope data in your app.
//             }
//          })
//
//          // Add the timer to the current run loop.
//           RunLoop.current.add(timer, forMode: .default)
       }
    

    func stopGyros() {
//       if self.timer != nil {
//          self.timer?.invalidate()
//          self.timer = nil
        motion.stopAccelerometerUpdates()
          //motion.stopGyroUpdates()
//       }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
