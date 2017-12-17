//
//  GCDBlackBox.swift
//  VirtualTourist
//
//  Created by Mauricio Cabreira on 14/12/17.
//  Copyright © 2017 Mauricio Cabreira. All rights reserved.
//

import Foundation
func performUIUpdatesOnMain(_ updates: @escaping () -> Void) {
  DispatchQueue.main.async {
    updates()
  }
}
