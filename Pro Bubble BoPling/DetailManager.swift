import SwiftUI
import UIKit
@preconcurrency import WebKit

private var asdqw: String = {
    WKWebView().value(forKey: "userAgent") as? String ?? ""
}()

class CreateDetail: UIViewController, WKNavigationDelegate {
    var czxasd: WKWebView!
    var newPopupWindow: WKWebView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    
    func showControls() async {
        let content = UserDefaults.standard.string(forKey: "config_url") ?? ""
        
        if !content.isEmpty, let url = URL(string: content) {
            loadCookie()
            
            await MainActor.run {
                self.czxasd = WKWebView(frame: self.view.frame)
                self.czxasd.customUserAgent = asdqw
                self.czxasd.navigationDelegate = self
                
                self.loadInfo(with: url)
                
            }
        }
    }
    
    
    func loadInfo(with url: URL) {
        czxasd.load(URLRequest(url: url))
        czxasd.allowsBackForwardNavigationGestures = true
        czxasd.uiDelegate = self
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        saveCookie()
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let response = navigationResponse.response as? HTTPURLResponse {
            let status = response.statusCode
            
            if (300...399).contains(status) {
                print("Redirect status, allowing navigation")
            }  else if status == 200 {
                
                if webView.superview == nil {
                    let whiteBG = UIView(frame: view.frame)
                    whiteBG.tag = 11
                    view.addSubview(whiteBG)
                    view.addSubview(self.czxasd)
                    
                    self.czxasd.translatesAutoresizingMaskIntoConstraints = false
                    NSLayoutConstraint.activate([
                        self.czxasd.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                        self.czxasd.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                        self.czxasd.topAnchor.constraint(equalTo: view.topAnchor),
                        self.czxasd.bottomAnchor.constraint(equalTo: view.bottomAnchor)
                    ])
                    
                }
            }
            else if status >= 400 {
                print("Ошибка Сервер вернул ошибку (\(status)).")
            }
        }
        decisionHandler(.allow)
        
    }
    
    func loadCookie() {
        let ud: UserDefaults = UserDefaults.standard
        let data: Data? = ud.object(forKey: "cookie") as? Data
        if let cookie = data {
            do {
                let datas: NSArray? = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSArray.self, from: cookie)
                if let cookies = datas {
                    for c in cookies {
                        if let cookieObject = c as? HTTPCookie {
                            HTTPCookieStorage.shared.setCookie(cookieObject)
                        }
                    }
                }
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    func saveCookie() {
        let cookieJar: HTTPCookieStorage = HTTPCookieStorage.shared
        if let cookies = cookieJar.cookies {
            do {
                let data: Data = try NSKeyedArchiver.archivedData(withRootObject: cookies, requiringSecureCoding: false)
                let ud: UserDefaults = UserDefaults.standard
                ud.set(data, forKey: "cookie")
            } catch {
                print(error.localizedDescription)
            }
        }
    }
}

import SwiftUI
@preconcurrency import WebKit

extension CreateDetail: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        newPopupWindow = WKWebView(frame: view.bounds, configuration: configuration)
        newPopupWindow!.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        newPopupWindow!.navigationDelegate = self
        newPopupWindow?.uiDelegate = self
        view.addSubview(newPopupWindow!)
        return newPopupWindow!
    }
    
    func webViewDidClose(_ webView: WKWebView) {
        webView.removeFromSuperview()
        newPopupWindow = nil
    }
}

import SwiftUI

struct Detail: UIViewControllerRepresentable {
    var urlString: String

    func makeUIViewController(context: Context) -> CreateDetail {
        let viewController = CreateDetail()
        UserDefaults.standard.set(urlString, forKey: "config_url")
        Task {
            await viewController.showControls()
        }
        return viewController
    }

    func updateUIViewController(_ uiViewController: CreateDetail, context: Context) {}
}
