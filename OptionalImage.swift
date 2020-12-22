//
//  OptionalImage.swift
//  EmojiArt
//
//  Created by Amirala on 10/1/1399 AP.
//

import SwiftUI

struct OptionalImage: View {
    var uiImage: UIImage?
    
    var body: some View {
        Group {
            if uiImage != nil {
                Image(uiImage: uiImage!)
            }
        }
    }
}
