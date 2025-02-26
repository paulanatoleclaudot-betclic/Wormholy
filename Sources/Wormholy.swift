//
//  Wormholy.swift
//  Wormholy
//
//  Created by Paolo Musolino on {TODAY}.
//  Copyright © 2018 Wormholy. All rights reserved.
//

import Foundation
import UIKit

public class Wormholy: NSObject
{
    @available(*, deprecated, renamed: "ignoredHosts")
    @objc public static var blacklistedHosts: [String] {
        get { return CustomHTTPProtocol.ignoredHosts }
        set { CustomHTTPProtocol.ignoredHosts = newValue }
    }

    /// Hosts that will be ignored from being recorded
    ///
    @objc public static var ignoredHosts: [String] {
        get { return CustomHTTPProtocol.ignoredHosts }
        set { CustomHTTPProtocol.ignoredHosts = newValue }
    }

    /// Limit the logging count
    ///
    @objc public static var limit: NSNumber? {
        get { Storage.limit }
        set { Storage.limit = newValue }
    }

    @objc public static func swiftyLoad() {
        NotificationCenter.default.addObserver(forName: fireWormholy, object: nil, queue: nil) { (notification) in
            Wormholy.presentWormholyFlow()
        }
    }

    @objc public static func swiftyInitialize() {
        if self == Wormholy.self{
            Wormholy.enable(true)
        }
    }

    static func enable(_ enable: Bool){
        if enable{
            URLProtocol.registerClass(CustomHTTPProtocol.self)
        }
        else{
            URLProtocol.unregisterClass(CustomHTTPProtocol.self)
        }
    }

    @objc public static func enable(_ enable: Bool, sessionConfiguration: URLSessionConfiguration){

        // Runtime check to make sure the API is available on this version
        if sessionConfiguration.responds(to: #selector(getter: URLSessionConfiguration.protocolClasses)) && sessionConfiguration.responds(to: #selector(setter: URLSessionConfiguration.protocolClasses)){
            var urlProtocolClasses = sessionConfiguration.protocolClasses
            let protoCls = CustomHTTPProtocol.self

            guard urlProtocolClasses != nil else{
                return
            }

            let index = urlProtocolClasses?.firstIndex(where: { (obj) -> Bool in
                if obj == protoCls{
                    return true
                }
                return false
            })

            if enable && index == nil{
                urlProtocolClasses!.insert(protoCls, at: 0)
            }
            else if !enable && index != nil{
                urlProtocolClasses!.remove(at: index!)
            }
            sessionConfiguration.protocolClasses = urlProtocolClasses
        }
        else{
            print("[Wormholy] is only available when running on iOS9+")
        }
    }

    // MARK: - Navigation
    static func presentWormholyFlow(){
        guard UIViewController.currentViewController()?.isKind(of: WHBaseViewController.classForCoder()) == false && UIViewController.currentViewController()?.isKind(of: WHNavigationController.classForCoder()) == false else {
            return
        }
        let vc = RequestsViewController()
        vc.title = "Requests"
        let navVC = UINavigationController(rootViewController: vc)
        navVC.navigationBar.prefersLargeTitles = true
        navVC.modalPresentationStyle = .fullScreen
        UIViewController.currentViewController()?.present(navVC, animated: true, completion: nil)
    }

    @objc public static var wormholyFlow: UIViewController? {
        let vc = RequestsViewController()
        vc.title = "Requests"
        let navVC = UINavigationController(rootViewController: vc)
        navVC.navigationBar.prefersLargeTitles = true
        return navVC
    }

    @objc public static var shakeEnabled: Bool = {
        let key = "WORMHOLY_SHAKE_ENABLED"

        if let environmentVariable = ProcessInfo.processInfo.environment[key] {
            return environmentVariable != "NO"
        }

        let arguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
        if let arg = arguments[key] {
            switch arg {
            case let boolean as Bool: return boolean
            case let string as NSString: return string.boolValue
            case let number as NSNumber: return number.boolValue
            default: break
            }
        }

        return true
    }()

    static var origDefaultSessionConfiguration: IMP?
    static var origEphemeralSessionConfiguration: IMP?
}

extension Wormholy {

    public static func awake() {
        swizzleAction
        initializeAction
    }

    private static let initializeAction: Void = {
        swiftyLoad()
        swiftyInitialize()
    }()
}

extension Wormholy {
    typealias ClosureType = @convention(c) (AnyObject, Selector) -> URLSessionConfiguration

    private static let swizzleAction: Void = {
        swizzleDefaultConfiguration()
        swizzleEphemeralConfiguration()
    }()

    private static func swizzleDefaultConfiguration() {
        let origMethod = class_getClassMethod(URLSessionConfiguration.self, #selector(getter: URLSessionConfiguration.default))
        let swizzledMethod = class_getClassMethod(Wormholy.self, #selector(wormholyDefaultSessionConfiguration))

        if let origMeth = origMethod,
           let swizMeth = swizzledMethod {
            origDefaultSessionConfiguration = method_getImplementation(origMeth)
            method_exchangeImplementations(origMeth, swizMeth)
        }
    }

    private static func swizzleEphemeralConfiguration() {
        let origMethod = class_getClassMethod(URLSessionConfiguration.self, #selector(getter: URLSessionConfiguration.ephemeral))
        let swizzledMethod = class_getClassMethod(Wormholy.self, #selector(wormholyEphemeralSessionConfiguration))

        if let origMeth = origMethod,
           let swizMeth = swizzledMethod {
            origEphemeralSessionConfiguration = method_getImplementation(origMeth)
            method_exchangeImplementations(origMeth, swizMeth)
        }
    }

    @objc static func wormholyDefaultSessionConfiguration() -> URLSessionConfiguration {
        let origCall: ClosureType = unsafeBitCast(origDefaultSessionConfiguration, to: ClosureType.self)
        let config = origCall(URLSessionConfiguration.self, #selector(getter: URLSessionConfiguration.default))
        Self.enable(true, sessionConfiguration: config)
        return config
    }

    @objc static func wormholyEphemeralSessionConfiguration() -> URLSessionConfiguration {
        let origCall: ClosureType = unsafeBitCast(origEphemeralSessionConfiguration, to: ClosureType.self)
        let config = origCall(URLSessionConfiguration.self, #selector(getter: URLSessionConfiguration.ephemeral))
        Self.enable(true, sessionConfiguration: config)
        return config
    }
}
