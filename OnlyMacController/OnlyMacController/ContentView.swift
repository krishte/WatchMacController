//
//  ContentView.swift
//  OnlyMacController
//
//  Created by Tejas Krishnan on 23.01.22.
//

import SwiftUI
import CoreData
import CocoaAsyncSocket
import GameController
import PythonKit


struct Message {
    
    // Json keys
    static let SENDER_KEY = "sender"
    static let MESSAGE_KEY = "message"
    static let TIMESTAMP_KEY = "timestamp"
    
    // Sender values
    static let SERVER_MSG_SENDER = "SERVER_MSG_SENDER"
    static let SERVER_NAME_SENDER = "SERVER_NAME_SENDER"
    
    let sender: String
    let message: String
    let timestamp: Date
    
    init(sender: String, message: String, timestamp: Date) {
        self.sender = sender
        self.message = message
        self.timestamp = timestamp
    }
    
    init(jsonData: Data) throws {
        var sender = ""
        var message = ""
        var timestamp = Date()
        if let dict = try JSONSerialization.jsonObject(with: jsonData, options: .mutableLeaves) as? NSDictionary {
            sender = dict[Message.SENDER_KEY] as? String ?? ""
            message = dict[Message.MESSAGE_KEY] as? String ?? ""
            if let interval = dict[Message.TIMESTAMP_KEY] as? TimeInterval {
                timestamp = Date(timeIntervalSince1970: interval / 1000)
            }
        }
        self.sender = sender
        self.message = message
        self.timestamp = timestamp
    }
    
    init(dict: Dictionary<String, Any>) {
        self.sender = dict[Message.SENDER_KEY] as? String ?? ""
        self.message = dict[Message.MESSAGE_KEY] as? String ?? ""
        if let interval = dict[Message.TIMESTAMP_KEY] as? TimeInterval {
            self.timestamp = Date(timeIntervalSince1970: interval)
        } else {
            self.timestamp = Date()
        }
    }
    
    func toDict() -> Dictionary<String, Any> {
        var dict = Dictionary<String, Any>()
        dict[Message.SENDER_KEY] = self.sender
        dict[Message.MESSAGE_KEY] = self.message
        dict[Message.TIMESTAMP_KEY] = (Int) (self.timestamp.timeIntervalSince1970 * 1000)
        return dict
    }
    
    func toJsonData() throws -> Data {
        return try JSONSerialization.data(withJSONObject: toDict(), options: .fragmentsAllowed)
    }
}

extension Array {
    static func messagesFromJsonData(_ jsonData: Data) throws -> [Message] {
        var messages: [Message] = []
        if let array = try JSONSerialization.jsonObject(with: jsonData, options: .mutableLeaves) as? NSArray {
            for case let dict as Dictionary<String, Any> in array {
                messages.append(Message(dict: dict))
            }
        }
        return messages
    }
    
    func messagesToJsonData() throws -> Data {
        var jsonArray: [Dictionary<String, Any>] = []
        for case let message as Message in self {
            jsonArray.append(message.toDict())
        }
        return try JSONSerialization.data(withJSONObject: jsonArray, options: .fragmentsAllowed)
    }
}

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    var stuff = ViewController()
    @ObservedObject var viewcontroller = ViewController()
    var body: some View {
        NavigationView {
            Button(action:
                    {
                let src = CGEventSource(stateID: .hidSystemState)
                let ctrl: UInt16 = 0x38
                let right: UInt16 = 0x15
                let cmdd = CGEvent(keyboardEventSource: src, virtualKey: ctrl, keyDown: true)
                let cmdu = CGEvent(keyboardEventSource: src, virtualKey: ctrl, keyDown: false)
                let spcd = CGEvent(keyboardEventSource: src, virtualKey: right, keyDown: true)
                let spcu = CGEvent(keyboardEventSource: src, virtualKey: right, keyDown: false)
  
                spcd?.flags = CGEventFlags.maskCommand;

                let loc = CGEventTapLocation.cghidEventTap
                cmdd?.flags = CGEventFlags.maskCommand
                cmdu?.flags = CGEventFlags.maskCommand
                spcd?.flags = CGEventFlags.maskCommand
                spcu?.flags = CGEventFlags.maskCommand

                cmdd?.post(tap: loc)
                spcd?.post(tap: loc)
                spcu?.post(tap: loc)
                cmdu?.post(tap: loc)
            })
            {
                Text("Simulate Keypress")
            }
            VStack
            {
                Text(viewcontroller.text)
//                
//                TextField("Message: ", text: $viewcontroller.textfieldtext)
                
//                Button(action:{
//
//
//                    viewcontroller.sendButtonTapped()
//
//                })
//                {
//                    Text("Send message")
//
//                }
                
                Button(action: {
                    viewcontroller.join()
                })
                {
                    Text(viewcontroller.joined ? "Close Socket" : "Open Socket")
                }
            }

        }.onAppear {
           // print(Python.version)
//            PythonLibrary.useLibrary(at: "/Library/Frameworks/Python.framework/Versions/3.9/lib/python3.9")
//            print(Python.version)
            
        }
    }


}

class ViewController: NSObject, ObservableObject {
    
    
    let namesQueue = DispatchQueue(label: "SocketNamesQueue", attributes: .concurrent)
    var names = [
        "Belgarion",
        "Ce'Nedra",
        "Belgarath",
        "Polgara",
        "Durnik",
        "Silk",
        "Velvet",
        "Poledra",
        "Beldaran",
        "Beldin",
        "Geran",
        "Mandorallen",
        "Hettar",
        "Adara",
        "Barak"
    ]
    var myName = ""
    var socketNames: [GCDAsyncSocket: String] = [:]
    
    let messagesArrayQueue = DispatchQueue(label: "CannonicalThreadQueue", attributes: .concurrent)
    var cannonicalThread: [Message] = []
    
    var netService: NetService?
    var socket: GCDAsyncSocket?
    let socketQueue = DispatchQueue(label: "SocketQueue")
    let clientArrayQueue = DispatchQueue(label: "ConnectedSocketsQueue", attributes: .concurrent)
    var connectedSockets: [GCDAsyncSocket] = []
    var netServiceBrowser: NetServiceBrowser?
    var serverAddresses: [Data]?
    
    var host = false
    var connected = false
    var joined = false
    var hostAfterTask: DispatchWorkItem?
    @Published var text: String = ""
    @Published var textfieldtext: String = ""
    
    var textfieldenabled: Bool = false
    var sendbuttonenabled: Bool = false

    func getName() -> String {
        return names.remove(at: Int(arc4random_uniform(UInt32(names.count))))
    }
    
    func putName(_ name: String) {
        names.append(name)
    }
    
    func join() {
        
        if joined {
            if host {
                stopHosting()
            } else {
                netServiceBrowser?.stop()
                socket?.disconnect()
                hostAfterTask?.cancel()
                socket = nil
                netService = nil
                serverAddresses = nil
            }
        } else {
            
            // Display connecting message
           

            text = "Connecting..."
     
            // Browse for an existing service
            startNetServiceBrowser()
            
            // After 3 seconds, if no service has been found, start one
            hostAfterTask = DispatchWorkItem {
                self.netServiceBrowser?.stop()
                self.startHosting()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: hostAfterTask!)
        }
        
        joined = !joined
    }
    
    func startNetServiceBrowser() {
        netServiceBrowser = NetServiceBrowser()
        netServiceBrowser?.delegate = self
        netServiceBrowser?.searchForServices(ofType: "_LocalNetworkingApp._tcp", inDomain: "local.")
    }
    
    func connectToNextAddress() {
        var done = false
        while (!done && serverAddresses?.count ?? 0 > 0) {
            if let addr = serverAddresses?.remove(at: 0) {
                do {
                    try socket?.connect(toAddress: addr)
                    done = true
                } catch let error {
                    print("ERROR: \(error)")
                }
            }
        }
        
        if !done {
            print("Unable to connect to any resolved address")
        }
    }
    
    func startHosting() {
        // Create the listen socket
        socket = GCDAsyncSocket(delegate: self, delegateQueue: socketQueue)
        do {
            try socket?.accept(onPort: 0)
        } catch let error {
            print("ERROR: \(error)")
            return
        }

        let port = socket!.localPort
        
        // Publish a NetService
        netService = NetService(domain: "local.", type: "_LocalNetworkingApp._tcp", name: "BelgariadChat", port: Int32(port))
        netService?.delegate = self
        netService?.publish()
        
        // Host mode on
        host = true
        
        // Get a name for the host
        myName = getName()
        
        // Reset text view
        text=""
        
        // Add a system message
        let message = Message(sender: Message.SERVER_MSG_SENDER, message: "\(myName) has started the chat", timestamp: Date())
        addMessage(message)
        
        // Initialize cannonical thread
        cannonicalThread = [message]
        
        // Enable chat
        textfieldenabled = true
        sendbuttonenabled = true
    }
    
    func stopHosting() {
        // Stop listening
        socket?.disconnect()
        
        netService?.stop()
        netService = nil
        
        // Remove the clients
        clientArrayQueue.async {
            for socket in self.connectedSockets {
                socket.disconnect()
            }
        }
        
        // Remove my name
        putName(myName)
        myName = ""
        
        // Disable chat
        textfieldenabled = false
        sendbuttonenabled = false
        
        // Reset
        cannonicalThread = []
        text=""
        socket = nil
        
        // Host mode off
        host = false
    }
    
    func addMessage(_ message: Message, fromSelf: Bool = false) {
        guard message.sender != Message.SERVER_NAME_SENDER else {
            return
        }
//        let attributedString = NSMutableAttributedString(attributedString: textView.attributedText)
//        var appending: NSMutableAttributedString
       
        if message.sender == Message.SERVER_MSG_SENDER {
            // print server message
//            let paragraphStyle = NSMutableParagraphStyle()
//            paragraphStyle.alignment = NSTextAlignment.center
//
//            appending = NSMutableAttributedString(string: message.message + "\n\n")
            
            text += message.message + "\n\n"
        } else {
            // print message
//            let paragraphStyle = NSMutableParagraphStyle()
//            paragraphStyle.alignment = fromSelf ? NSTextAlignment.right : NSTextAlignment.left
//
//            appending = NSMutableAttributedString(string: message.sender + "\n")
//
//            appending.append(NSMutableAttributedString(string: message.message + "\n\n"))
            text += message.sender + "\n" + message.message + "\n\n"
        }
       
//        attributedString.append(appending)
//        textView.attributedText = attributedString
        

    }
    



    
  func sendButtonTapped() {
        guard textfieldtext != "",
            connected || host else {
            return
        }
        
       // textView.resignFirstResponder()
        
        let message = Message(sender: myName, message: textfieldtext, timestamp: Date())
        var messageData: Data
        do {
            messageData = try message.toJsonData()
        } catch let error {
            print("ERROR: Couldn't serialize message \(error)")
            return
        }
        messageData.append(GCDAsyncSocket.crlfData())
        
        // Add the message to the text view
        addMessage(message, fromSelf: true)
        
        // Send the message over the network
        if host {
            messagesArrayQueue.async(flags: .barrier) {
                self.cannonicalThread.append(message)
            }
            
            clientArrayQueue.async {
                for client in self.connectedSockets {
                    client.write(messageData, withTimeout: -1, tag: 0)
                }
            }
        } else {
            socket?.write(messageData, withTimeout: -1, tag: 0)
        }
        
        textfieldtext = ""

    }
    
}

extension ViewController: NetServiceBrowserDelegate {
    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        print("ERROR: \(errorDict)")
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        hostAfterTask?.cancel()
        if netService == nil {
            netService = service
            netService?.delegate = self
            netService?.resolve(withTimeout: 5)
        }
    }
    
    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        print("NetServiceBrowser did stop search")
    }
}

extension ViewController: NetServiceDelegate {
    
    // Client
    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        print("NetService did not resolve: \(errorDict)")
    }
    
    func netServiceDidResolveAddress(_ sender: NetService) {
        if serverAddresses == nil {
            serverAddresses = sender.addresses
        }
        if socket == nil {
            socket = GCDAsyncSocket(delegate: self, delegateQueue: socketQueue)
            connectToNextAddress()
        }
    }
    
    // Host
    func netServiceDidPublish(_ sender: NetService) {
        print("Bonjour Service Published: domain(\(sender.domain)) type(\(sender.type)) name(\(sender.name)) port(\(sender.port))")
    }
    
    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        print("Failed to publish Bonjour Service domain(\(sender.domain)) type(\(sender.type)) name(\(sender.name))\n\(errorDict)")
    }
}

extension ViewController: GCDAsyncSocketDelegate {
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        print("Socket did connect to host \(host) on port \(port)")
        connected = true
    
        DispatchQueue.main.async {
            // Reset chat
            self.text=""
            
            // Enable chat
            self.textfieldenabled = true
            self.sendbuttonenabled = true
        }
        
        // Connected to host, start reading
        socket?.readData(to: GCDAsyncSocket.crlfData(), withTimeout: -1, tag: 0)
    }
    
    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        clientArrayQueue.async(flags: .barrier) {
            self.connectedSockets.append(newSocket)
        }
        
        // Give the new client a name
        var name = "Someone"
        namesQueue.sync(flags: .barrier) {
            name = getName()
            self.socketNames[newSocket] = name
        }
        
        // Send the client their name
        let nameMessage = Message(sender: Message.SERVER_NAME_SENDER, message: name, timestamp: Date())
        do {
            var messageData = try nameMessage.toJsonData()
            messageData.append(GCDAsyncSocket.crlfData())
            newSocket.write(messageData, withTimeout: -1, tag: 0)
        } catch let error {
            print("ERROR: \(error) - Couldn't serialize message \(nameMessage)")
        }
        
        // Send the client the cannonical thread
        messagesArrayQueue.async {
            for message in self.cannonicalThread {
                do {
                    var messageData = try message.toJsonData()
                    messageData.append(GCDAsyncSocket.crlfData())
                    newSocket.write(messageData, withTimeout: -1, tag: 0)
                } catch let error {
                    print("ERROR: \(error) - Couldn't serialize message \(message)")
                }
            }
        }
        
        // Send a system message alerting that a client has joined
        let message = Message(sender: Message.SERVER_MSG_SENDER, message: "\(name) has joined", timestamp: Date())
        messagesArrayQueue.async(flags: .barrier) {
            self.cannonicalThread.append(message)
        }

        do {
            var messageData = try message.toJsonData()
            messageData.append(GCDAsyncSocket.crlfData())
            clientArrayQueue.async {
                for client in self.connectedSockets {
                    client.write(messageData, withTimeout: -1, tag: 0)
                }
            }
        } catch let error {
            print("ERROR: \(error) - Couldn't serialize message \(message)")
        }
        
        DispatchQueue.main.async {
            self.addMessage(message)
        }
        
        // Wait for a message
        newSocket.readData(to: GCDAsyncSocket.crlfData(), withTimeout: -1, tag: 0)
    }
    
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        print("Socket did read data with tag \(tag)")
        
        if let string = String(data: data, encoding: .utf8) {
            print(string)
        }
        
        // Incoming message

        print(GCKeySpacebar)
        let messageData = data.dropLast(2)
        let message: Message
        do {
            message = try Message(jsonData: messageData)
        } catch let error {
            print("ERROR: Couldnt create Message from data \(error.localizedDescription)")
            return
        }
        
        if message.sender == Message.SERVER_NAME_SENDER {
            // Received name from the server
            guard !host else {
                print("ERROR: Why is the host getting sent a name?")
                return
            }
            myName = message.message
        }
        
        if (message.message == "Right")
        {
            //let np = Python.import("numpy")
//            print(Python.version)
//            let sys = Python.import("sys")
//            sys.path.append("/Users/krishte/Documents/")
//            let swiping = Python.import("swiping2")
//            swiping.swiperight2()
//
//            print("swiping right")
            let src = CGEventSource(stateID: .privateState)
            let ctrl: UInt = 0x38
            let right: UInt = 0x14
            let cmdd = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(ctrl), keyDown: true)
            let cmdu = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(ctrl), keyDown: false)
            let spcd = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(right), keyDown: true)
            let spcu = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(right), keyDown: false)

            spcd?.flags = CGEventFlags.maskCommand;

            let loc = CGEventTapLocation.cghidEventTap

            cmdd?.post(tap: loc)
            spcd?.post(tap: loc)
            spcu?.post(tap: loc)
            cmdu?.post(tap: loc)
        }
        else if (message.message == "Left")
        {
//            let sys = Python.import("sys")
//            sys.path.append("/Users/krishte/Documents/")
//            let swiping = Python.import("swiping")
//            swiping.swipeleft()
//
//            print("swiping left")
            let src = CGEventSource(stateID: .privateState)
            let ctrl: UInt = 0x38
            let right: UInt = 0x31
            let cmdd = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(ctrl), keyDown: true)
            let cmdu = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(ctrl), keyDown: false)
            let spcd = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(right), keyDown: true)
            let spcu = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(right), keyDown: false)

            spcd?.flags = CGEventFlags.maskCommand;

            let loc = CGEventTapLocation.cghidEventTap

            cmdd?.post(tap: loc)
            spcd?.post(tap: loc)
            spcu?.post(tap: loc)
            cmdu?.post(tap: loc)
        }
        DispatchQueue.main.async {
            self.addMessage(message)
        }
        
        if host {
            // Update the cannonical thread
            messagesArrayQueue.async {
                self.cannonicalThread.append(message)
            }
            
            // Forward the message to clients
            clientArrayQueue.async {
                for client in self.connectedSockets {
                    if client == sock {
                        // Don't send the message back to the client who sent it
                        continue
                    }
                        client.write(data, withTimeout: -1, tag: 0)
                }
            }
        }
        
        // Read the next message
        sock.readData(to: GCDAsyncSocket.crlfData(), withTimeout: -1, tag: 0)
    }
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        print("Socket did disconnect \(err?.localizedDescription ?? "")")
        if host {
            clientArrayQueue.async(flags: .barrier) {
                if let index = self.connectedSockets.firstIndex(of: sock) {
                    self.connectedSockets.remove(at: index)
                }
            }
            
            // Remove the name
            var name = "Someone"
            namesQueue.sync(flags: .barrier) {
                guard let innerName = socketNames[sock] else {
                    return
                }
                name = innerName
                putName(name)
                socketNames[sock] = nil
            }

            let message = Message(sender: Message.SERVER_MSG_SENDER, message: "\(name) has left", timestamp: Date())
            // Send a system message alerting that a client has left
            messagesArrayQueue.async(flags: .barrier) {
                self.cannonicalThread.append(message)
            }

            do {
                var messageData = try message.toJsonData()
                messageData.append(GCDAsyncSocket.crlfData())
                clientArrayQueue.async {
                    for client in self.connectedSockets {
                        client.write(messageData, withTimeout: -1, tag: 0)
                    }
                }
            } catch let error {
                print("ERROR: \(error) - Couldn't serialize message \(message)")
            }
            
            DispatchQueue.main.async {
                self.addMessage(message)
            }
            
        } else {
            // Reset
            connected = false
            joined = false
            socket = nil
            netService = nil
            serverAddresses = nil
            
            // Disable chat
            DispatchQueue.main.async {
                self.textfieldenabled = false
                self.sendbuttonenabled = false
            }
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
