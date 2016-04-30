//
//  ViewController.swift
//  JSAndSwift
//
//  Created by 刘康 on 16/4/14.
//  Copyright © 2016年 刘康. All rights reserved.
//

import UIKit
import JavaScriptCore

class ViewController: UIViewController, UIWebViewDelegate {
    
    @IBOutlet weak var webView: UIWebView!
    var jsContext: JSContext?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        evaluateScript()
        
        loadRequest()
        
    }
    
    func loadRequest() {
        let url = NSBundle.mainBundle().URLForResource("JSAndSwift", withExtension: "html")
        let request = NSURLRequest(URL: url!)
        self.webView.loadRequest(request)
    }
    
    func evaluateScript() {
        // 直接JS方法
        let context = JSContext()
        context.evaluateScript("var num = 8")
        context.evaluateScript("function double(value) {return value * 2}")
        // 调用并打印结果
        let result = context.evaluateScript("double(num)")
        print("result = \(result)")
        // 可通过下标来获取JS方法
        let doubleFunc = context.objectForKeyedSubscript("double")
        let double10Result = doubleFunc.callWithArguments(["10"])
        print("doubleFunc(10), result = \(double10Result.toString())")
    }
    
    // MARK: - UIWebViewDelegate
    func webViewDidFinishLoad(webView: UIWebView) {
        let context = webView.valueForKeyPath("documentView.webView.mainFrame.javaScriptContext") as? JSContext
        let model = SwiftJSModel()
        model.controller = self
        model.jsContext = context
        self.jsContext = context
        
        // 这一步是将SwiftJSModel这个模型注入到JS中，在JS就可以通过SwiftJSModel调用我们公暴露的方法了。
        self.jsContext?.setObject(model, forKeyedSubscript: "SwiftJSModel")
        let url = NSBundle.mainBundle().URLForResource("JSAndSwift", withExtension: "html")
        self.jsContext?.evaluateScript(try? String(contentsOfURL: url!, encoding: NSUTF8StringEncoding));
        
        self.jsContext?.exceptionHandler = {
            (context, exception) in
            print("exception @", exception)
        }
        
        
//        let jsParamFunc = self.jsContext?.objectForKeyedSubscript("jsParamFunc");
//        let dict = NSDictionary(dictionary: ["age": 28, "height": 168, "name": "刘康"])
//        jsParamFunc?.callWithArguments([dict])
        
    }

}

// JS调用原生方法，必须在JS中实现这些方法
@objc protocol JavaScriptSwiftDelegate: JSExport {
    func callSystemCamera();
    func showAlert(title: String, msg: String);
    func callWithDict(dict: [String: AnyObject])
    func jsCallObjcAndObjcCallJsWithDict(dict: [String: AnyObject]);
}

@objc class SwiftJSModel: NSObject, JavaScriptSwiftDelegate {
    weak var controller: UIViewController?
    weak var jsContext: JSContext?
    
    func callSystemCamera() {
        showAlert("JS调用Native", msg: "这里应该去调用摄像头");
        
        let jsFunc = self.jsContext?.objectForKeyedSubscript("jsFunc");
        jsFunc?.callWithArguments([]);
    }
    
    func showAlert(title: String, msg: String) {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            let alert = UIAlertController(title: title, message: msg, preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "ok", style: .Default, handler: nil))
            self.controller?.presentViewController(alert, animated: true, completion: nil)
        }
    }
    
    func callWithDict(dict: [String : AnyObject]) {
        print("JS call objc method: callWithDict, args: %@", dict)
        showAlert("JS调用Native方法：callWithDict", msg: "这里处理callWithDict")
    }
    
    func jsCallObjcAndObjcCallJsWithDict(dict: [String : AnyObject]) {
        print("js call objc method: jsCallObjcAndObjcCallJsWithDict, args: %@", dict)
        showAlert("JS调用Native方法：jsCallObjcAndObjcCallJsWithDict", msg: "dict:\(dict)")
        
        let jsParamFunc = self.jsContext?.objectForKeyedSubscript("jsParamFunc");
        let dict = NSDictionary(dictionary: ["age": 28, "height": 168, "name": "刘康"])
        jsParamFunc?.callWithArguments([dict])
    }
}

