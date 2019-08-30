//
//  Loading.swift
//  MovieTrim
//
//  Created by cano on 2019/08/30.
//  Copyright © 2019 deskplate. All rights reserved.
//

import UIKit
import SVProgressHUD

class Loading {
    class func start(statusString: String! = nil) {
        SVProgressHUD.setDefaultMaskType(SVProgressHUDMaskType.black)
        SVProgressHUD.show(withStatus: statusString)
        SVProgressHUD.show()
    }
    class func stop() {
        SVProgressHUD.dismiss()
    }
}

