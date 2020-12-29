//
//  EmojiArtDocumentView.swift
//  EmojiArt
//
//  Created by Amirala on 9/28/1399 AP.
//

import SwiftUI

struct EmojiArtDocumentView: View {
    @ObservedObject var document: EmojiArtDocument
    
    @State private var chosenPalette: String = ""
    
    var body: some View {
        VStack {
            HStack {
                PaletteChooser(document: document, chosenPalette: $chosenPalette)
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(chosenPalette.map { String($0) }, id: \.self) { emoji in
                            Text(emoji)
                                .font(Font.system(size: defaultEmojiSize))
                                .onDrag { NSItemProvider(object: emoji as NSString) }
                        }
                    }
                }
                .onAppear { chosenPalette = document.defaultPalette }
            }
            GeometryReader { geometry in
                ZStack {
                    Color.white.overlay(
                        OptionalImage(uiImage: document.backgroundImage)
                            .scaleEffect(selectedEmojis.isEmpty ? zoomScale : steadyStateZoomScale)
                            .offset(panOffset)
                            
                    )
                    .gesture(doubleTapToZoom(in: geometry.size).exclusively(before: deselectEmojisGesture()))
                    if isLoading {
                        Image(systemName: "hourglass").imageScale(.large).spinning()
                    } else {
                        ForEach(document.emojis) { emoji in
                            Text(emoji.text)
                                .border(Color.blue, width: selectedEmojis.contains(emoji) ? 2.0 : 0.0)
                                .font(animatableWithSize: emoji.fontSize * (selectedEmojis.contains(emoji) || selectedEmojis.isEmpty ? zoomScale : steadyStateZoomScale))
                                .position(position(for: emoji, in: geometry.size, zoomScale: selectedEmojis.isEmpty ? zoomScale : steadyStateZoomScale))
                                .offset(selectedEmojis.contains(emoji) ? gestureEmojiOffset * zoomScale : CGSize.zero)
                                .gesture(emojiToggleGesture(for: emoji))
                                .gesture(emojisReplacementGesture(initiatedOn: emoji))
                                .contextMenu {
                                    Button(action: {
                                        deleteEmoji(emoji)
                                    }) {
                                        Text("Delete")
                                        Image(systemName: "trash")
                                    }
                                }
                        }
                    }
                    
                }
                .clipped()
                .gesture(panGesture())
                .gesture(zoomGesture())
                .edgesIgnoringSafeArea([.horizontal, .bottom])
                .onReceive(document.$backgroundImage) { image in
                    zoomToFit(image, in: geometry.size)
                }
                .onDrop(of: ["public.image", "public.text"], isTargeted: nil) { providers, location in
                    var location = geometry.convert(location, from: .global)
                    location = CGPoint(x: location.x - geometry.size.width/2, y: location.y - geometry.size.height/2)
                    location = CGPoint(x: location.x - panOffset.width, y: location.y - panOffset.height)
                    location = CGPoint(x: location.x / zoomScale, y: location.y / zoomScale)
                    return drop(providers: providers, at: location)
                }
            }
        }
    }
    
    var isLoading: Bool {
        document.backgroundURL != nil && document.backgroundImage == nil
    }
    
    private func deleteEmoji(_ emoji: EmojiArt.Emoji) {
        document.deleteEmoji(emoji)
    }
    
    private func deselectEmojisGesture() -> some Gesture {
        TapGesture(count: 1)
            .onEnded {
                selectedEmojis.removeAll()
            }
    }
    
    @State private var selectedEmojis = Set<EmojiArt.Emoji>()
    
    private func emojiToggleGesture(for emoji: EmojiArt.Emoji) -> some Gesture {
        TapGesture(count: 1)
            .onEnded {
                if selectedEmojis.contains(emoji) {
                    selectedEmojis.remove(emoji)
                } else {
                    selectedEmojis.insert(emoji)
                }
            }
    }
    
    @GestureState private var gestureEmojiOffset: CGSize = .zero
    
    private func emojisReplacementGesture(initiatedOn emoji: EmojiArt.Emoji) -> some Gesture {
        DragGesture()
            .updating($gestureEmojiOffset) { lastestDragGestureValue, gestureEmojiOffset, transaction in
                if selectedEmojis.contains(emoji) {
                    gestureEmojiOffset = lastestDragGestureValue.translation / zoomScale
                } else {
                    gestureEmojiOffset = .zero
                }
            }
            .onEnded { finalDragGestureValue in
                if selectedEmojis.contains(emoji) {
                    for emoji in selectedEmojis {
                        document.moveEmoji(emoji, by: finalDragGestureValue.translation / zoomScale)
                    }
                }
            }
    }
    
    @State private var steadyStateZoomScale: CGFloat = 1.0
    @GestureState private var gestureZoomScale: CGFloat = 1.0
    
    private var zoomScale: CGFloat {
        steadyStateZoomScale * gestureZoomScale
    }
    
    private func zoomGesture() -> some Gesture {
        MagnificationGesture()
            .updating($gestureZoomScale) { lastestGestureScale, ourGestureStateInOut, transaction in
                ourGestureStateInOut = lastestGestureScale
            }
            .onEnded { finalGestureScale in
                if selectedEmojis.isEmpty {
                    steadyStateZoomScale *= finalGestureScale
                } else {
                    for emoji in selectedEmojis {
                        document.scaleEmoji(emoji, by: finalGestureScale)
                    }
                }
            }
    }
    
    @State private var steadyStatePanOffset: CGSize = .zero
    @GestureState private var gesturePanOffset: CGSize = .zero
    
    private var panOffset: CGSize {
        (steadyStatePanOffset + gesturePanOffset) * zoomScale
    }
    
    private func panGesture() -> some Gesture {
        DragGesture()
            .updating($gesturePanOffset) { lastestDragGestureValue, gesturePanOffset, transaction in
                gesturePanOffset = lastestDragGestureValue.translation / zoomScale
            }
            .onEnded { finalDragGestureValue in
                steadyStatePanOffset = steadyStatePanOffset + (finalDragGestureValue.translation / zoomScale)
            }
    }
    
    private func doubleTapToZoom(in size: CGSize) -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                withAnimation {
                    zoomToFit(document.backgroundImage, in: size)
                }
            }
    }
    
    private func zoomToFit(_ image: UIImage?, in size: CGSize) {
        if let image = image, size.width > 0, size.height > 0 {
            let vZoom = size.width / image.size.width
            let hZoom = size.height / image.size.height
            steadyStatePanOffset = .zero
            steadyStateZoomScale = min(vZoom, hZoom)
        }
    }
    
    private func position(for emoji: EmojiArt.Emoji, in size: CGSize, zoomScale: CGFloat) -> CGPoint {
        var location = emoji.location
        location = CGPoint(x: location.x * zoomScale, y: location.y * zoomScale )
        location = CGPoint(x: location.x + size.width/2, y: location.y + size.height/2)
        location = CGPoint(x: location.x + panOffset.width, y: location.y + panOffset.height)
        return location
    }
    
    private func drop(providers: [NSItemProvider], at location: CGPoint) -> Bool {
        var found = providers.loadFirstObject(ofType: URL.self) { url in
            document.backgroundURL = url
        }
        if !found {
            found = providers.loadObjects(ofType: String.self) { string in
                document.addEmoji(string, at: location , size: defaultEmojiSize)
            }
        }
        return found
    }
    
    private let defaultEmojiSize: CGFloat = 40
}
