//
//  EmojiArtDocumentView.swift
//  EmojiArt
//
//  Created by Amirala on 9/28/1399 AP.
//

import SwiftUI

struct EmojiArtDocumentView: View {
    @ObservedObject var document: EmojiArtDocument
    
    var body: some View {
        VStack {
            ScrollView(.horizontal) {
                HStack {
                    ForEach(EmojiArtDocument.palette.map { String($0) }, id: \.self) { emoji in
                        Text(emoji)
                            .font(Font.system(size: defaultEmojiSize))
                        
                    }
                }
            }
            .padding(.horizontal)
            Color.white.overlay(
                Group {
                    if document.backgroundImage != nil {
                        Image(uiImage: document.backgroundImage!)
                    }
                }
            )
                .edgesIgnoringSafeArea([.horizontal, .bottom])
                .onDrop(of: ["public.image"], isTargeted: nil) { providers, location in
                    return drop(providers: providers)
                }
        }
    }
    
    private func drop(providers: [NSItemProvider]) -> Bool {
        let found = providers.loadFirstObject(ofType: URL.self) { url in
            print("dropped \(url)")
            document.setBackgroundURL(url)
        }
        return found
    }
    
    private let defaultEmojiSize: CGFloat = 40
}
