##Swift与JavaScript交互

###概述
iOS原生应用和web页面的交互大致上有这几种方法：

- iOS7之后的`JavaScriptCore`
- `拦截协议`
-  第三方框架`WebViewJavaScriptBridge` : 是基于拦截协议进行的封装，学习成本相对JavaScriptCore较高
-  iOS8之后的`WKWebView` : iOS8之后推出的，还没有成为主流使用。

###关于JavaScriptCore
涉及到的几种类型：

- JSContext:  JSContext是代表JS的执行环境，通过-evaluateScript:方法就可以执行JS代码
- JSValue: JSValue封装了JS与ObjC中的对应的类型，以及调用JS的API等
- JSExport:  JSExport是一个协议，遵守此协议，就可以定义我们自己的协议，在协议中声明的API都会在JS中暴露出来，才能调用

###Swift与JS交互方式
两种调用JS代码的方法：

1、直接调用JS代码

2、在Swift中通过JSContext注入模型，然后调用模型的方法

####直接调用JS代码
我们可以不通过模型来调用方法，也可以直接调用方法

```
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

```

这种方式是没有注入模型到JS中的。这种方式使用起来不太合适，通常在JS中有很多全局的函数，为了防止名字重名，使用模型的方式是最好不过了。通过我们协商好的模型名称，在JS中直接通过模型来调用我们在Swift中所定义的模型所公开的API。
注入模型的交互
####注入模型的交互
首先，我们需要先定义一个协议，而且这个协议必须要遵守JSExport协议。

All methods that should apply in Javascript,should be in the following protocol.

注意，这里必须使用`@objc`，因为JavaScriptCore库是ObjectiveC版本的。如果不加`@objc`，则调用无效果。

```
objc protocol JavaScriptSwiftDelegate: JSExport {
  func callSystemCamera();
  func showAlert(title: String, msg: String);
  func callWithDict(dict: [String: AnyObject])
  func jsCallObjcAndObjcCallJsWithDict(dict: [String: AnyObject]);
}
```

接下来，我们还需要定义一个模型:

```
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
        let dict = NSDictionary(dictionary: ["age": 18, "height": 168, "name": "lili"])
        jsParamFunc?.callWithArguments([dict])
    }
}
```

接下来，我们在controller中在webview加载完成的代理中，给JS注入模型:

```
func webViewDidFinishLoad(webView: UIWebView) {
    let context = webView.valueForKeyPath("documentView.webView.mainFrame.javaScriptContext") as? JSContext
    let model = JSObjCModel()
    model.controller = self
    model.jsContext = context
    self.jsContext = context
    
    // 这一步是将OCModel这个模型注入到JS中，在JS就可以通过OCModel调用我们公暴露的方法了。
   self.jsContext?.setObject(model, forKeyedSubscript: "OCModel")
    let url = NSBundle.mainBundle().URLForResource("test", withExtension: "html")
    self.jsContext?.evaluateScript(try? String(contentsOfURL: url!, encoding: NSUTF8StringEncoding));
    
    self.jsContext?.exceptionHandler = {
      (context, exception) in
         print("exception @", exception)
    }
  }
```

JSContext是通过webView的valueForKeyPath获取的，其路径为documentView.webView.mainFrame.javaScriptContext。
这样就可以获取到JS的context，然后为这个context注入模型对象。
先写两个JS方法：

```
function jsFunc() {
   	alert('Objective-C call js to show alert');
}
// 注意哦，如果JS写错，可能在OC调用JS方法时，都会出错哦。
var jsParamFunc = function(argument) {
  document.getElementById('jsParamFuncSpan').innerHTML = argument['name'];
}
```

这里定义了两个JS方法，一个是jsFunc，不带参数。
另一个是jsParamFunc，带一个参数。

当点击第一个按钮：Call ObjC system camera时，
通过OCModel.callSystemCamera()，就可以在HTML中通过JS调用OC的方法。
在Swift代码callSystemCamera方法体中，添加了以下两行代码，就是获取HTML中所定义的JS就去jsFunc，然后调用它。

```
let jsFunc = self.jsContext?.objectForKeyedSubscript("jsFunc");
jsFunc?.callWithArguments([]);
```
这样就可以在JS调用Siwft方法时，也让Swift反馈给JS。
注意：这里是通过objectForKeyedSubscript方法来获取变量jsFunc。
方法也是变量。看看下面传字典参数：

```
func jsCallObjcAndObjcCallJsWithDict(dict: [String : AnyObject]) {
    print("js call objc method: jsCallObjcAndObjcCallJsWithDict, args: %@", dict)
    
    let jsParamFunc = self.jsContext?.objectForKeyedSubscript("jsParamFunc");
    let dict = NSDictionary(dictionary: ["age": 18, "height": 168, "name": "lili"])
    jsParamFunc?.callWithArguments([dict])
  }
```

获取HTML中定义的jsParamFunc方法，然后调用它并传了一个字典作为参数。