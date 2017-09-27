/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

import MobileCoreServices
import SafariServices
import UIKit

class ActionViewController: UIViewController {
    
    var adblockPlus: AdblockPlusShared!
    var website: String?
    var components: URLComponents!
    
    @IBOutlet weak var descriptionField: UITextField!
    @IBOutlet weak var addressField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        adblockPlus = AdblockPlusShared.init()
        for item in extensionContext?.inputItems as! [NSExtensionItem] {
            guard let attachments = item.attachments  else { continue }
            for itemProvider in attachments as! [NSItemProvider] {
                let typeIdentifier = kUTTypePropertyList as String
                if itemProvider.hasItemConformingToTypeIdentifier(typeIdentifier) {
                    weak var weakSelf = self
                    itemProvider.loadItem(forTypeIdentifier: typeIdentifier,
                                          options: nil,
                                          completionHandler: { (item, error) in
                                            DispatchQueue.main.async {
                                                let preprocessingResults = item as! NSDictionary
                                                let results = preprocessingResults[NSExtensionJavaScriptPreprocessingResultsKey] as! NSDictionary
                                                let baseURI = results["baseURI"] as? String
                                                let hostname = baseURI! as NSString
                                                let whitelistedHostname = hostname.whitelistedHostname()
                                                weakSelf?.website = baseURI
                                                weakSelf?.addressField.text = whitelistedHostname
                                                weakSelf?.descriptionField.text = results["title"] as? String
                                            }
                    })
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.transition(with: self.view,
                          duration: 0.4,
                          options: .transitionCrossDissolve,
                          animations: {
                            self.view.isHidden = false
        },
                          completion: nil)
    }
    
    @IBAction func onCancelButtonTouched(_ sender: Any) {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        return
    }
    
    @IBAction func onDoneButtonTouched(_ sender: Any) {
        if self.website == nil {
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }
        
        let whitelistedSite = self.website! as NSString
        let whitelistedWebsite = whitelistedSite.whitelistedHostname()
        let time = Date.timeIntervalSinceReferenceDate
        components = URLComponents.init()
        components.scheme = "http"
        components.host = "localhost"
        components.path = String.init(format: "/invalidimage-%d.png", Int(time))
        components.query = String.init(format: "website=%@", whitelistedWebsite!)
        
        extensionContext?.completeRequest(returningItems: nil, completionHandler: { (expired) in
            self.completeAndExit()
        })
    }
    
    func completeAndExit() {
        // Session must be created with new identifier, see Apple documentation:
        // https://developer.apple.com/library/prerelease/ios/documentation/General/Conceptual/ExtensibilityPG/ExtensionScenarios.html
        // Section - Performing Uploads and Downloads
        // Because only one process can use a background session at a time,
        // you need to create a different background session for the containing app and each of its app extensions.
        // (Each background session should have a unique identifier.)
        let identifier = adblockPlus.generateBackgroundNotificationSessionConfigurationIdentifier()
        let session = adblockPlus.backgroundNotificationSession(withIdentifier: identifier,
                                                                delegate: nil)
        
        let url = components.url
        let task = session.downloadTask(with: url!)
        task.resume()
        session.finishTasksAndInvalidate()
        exit(0)
    }
    
}
