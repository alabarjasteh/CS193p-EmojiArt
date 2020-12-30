//
//  EmojiArtApp.swift
//  EmojiArt
//
//  Created by Amirala on 9/28/1399 AP.
//

import SwiftUI

@main
struct EmojiArtApp: App {
//    let store = EmojiArtDocumentStore(named: "Emoji Art")
//    store.addDocument()
//    store.addDocument(named: "Hello World")
    var body: some Scene {
        WindowGroup {
            EmojiArtDocumentChooser().environmentObject(EmojiArtDocumentStore(named: "Emoji Art"))
//            EmojiArtDocumentView(document: EmojiArtDocument())
        }
    }
}
