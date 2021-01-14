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
    
    init(document: EmojiArtDocument) {
        self.document = document
        _chosenPalette = State(wrappedValue: self.document.defaultPalette)
    }
    
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
            }
            GeometryReader { geometry in
                ZStack {
                    Color.white.overlay(
                        OptionalImage(uiImage: document.backgroundImage)
                            .scaleEffect(selectedEmojis.isEmpty ? zoomScale : document.steadyStateZoomScale)
                            .offset(panOffset)
                            
                    )
                    .gesture(doubleTapToZoom(in: geometry.size).exclusively(before: deselectEmojisGesture()))
                    if isLoading {
                        Image(systemName: "hourglass").imageScale(.large).spinning()
                    } else {
                        ForEach(document.emojis) { emoji in
                            Text(emoji.text)
                                .contextMenu {
                                    Button(action: {
                                        deleteEmoji(emoji)
                                    }) {
                                        Text("Delete")
                                        Image(systemName: "trash")
                                    }
                                }
                                .border(Color.blue, width: selectedEmojis.contains(emoji) ? 2.0 : 0.0)
                                .font(animatableWithSize: emoji.fontSize * (selectedEmojis.contains(emoji) || selectedEmojis.isEmpty ? zoomScale : document.steadyStateZoomScale))
                                .position(position(for: emoji, in: geometry.size, zoomScale: selectedEmojis.isEmpty ? zoomScale : document.steadyStateZoomScale))
                                .offset(selectedEmojis.contains(emoji) ? gestureEmojiOffset * zoomScale : CGSize.zero)
                                .gesture(emojiToggleGesture(for: emoji))
                                .gesture(emojisReplacementGesture(initiatedOn: emoji))
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
                .navigationBarItems(leading: pickImage, trailing: Button(action: {
                    if let url = UIPasteboard.general.url, url != document.backgroundURL {
                        confirmBackgroundPaste = true
                    } else {
                        explainBackgroundPaste = true
                    }
                }, label: {
                    Image(systemName: "doc.on.clipboard").imageScale(.large)
                        .alert(isPresented: $explainBackgroundPaste) {
                            return Alert(
                                title: Text("Paste Background"),
                                message: Text("Copy the URL of an image to the clip board and touch this button to make it the background of your document."),
                                dismissButton: .default(Text("OK"))
                            )
                        }
                }))
            }
            .zIndex(-1)
        }
        .alert(isPresented: $confirmBackgroundPaste) {
            return Alert(
                title: Text("Paste Background"),
                message: Text("Replace your background with \(UIPasteboard.general.url?.absoluteString ?? "nothing")?."),
                primaryButton: .default(Text("OK")) {
                    document.backgroundURL = UIPasteboard.general.url
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    @State private var showImagePicker = false
    @State private var imagePickerSourceType = UIImagePickerController.SourceType.photoLibrary
    
    private var pickImage: some View {
        HStack {
            Image(systemName: "photo").imageScale(.large).foregroundColor(.accentColor).onTapGesture {
                imagePickerSourceType = .photoLibrary
                showImagePicker = true
            }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Image(systemName: "camera").imageScale(.large).foregroundColor(.accentColor).onTapGesture {
                    imagePickerSourceType = .camera
                    showImagePicker = true
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(sourceType: imagePickerSourceType) { image in
                if image != nil {
                    DispatchQueue.main.async {
                        document.backgroundURL = image!.storeInFilesystem()
                    }
                }
                showImagePicker = false
            }
        }
    }
    
    @State private var explainBackgroundPaste = false
    @State private var confirmBackgroundPaste = false

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
    
    @GestureState private var gestureZoomScale: CGFloat = 1.0
    
    private var zoomScale: CGFloat {
        document.steadyStateZoomScale * gestureZoomScale
    }
    
    private func zoomGesture() -> some Gesture {
        MagnificationGesture()
            .updating($gestureZoomScale) { lastestGestureScale, ourGestureStateInOut, transaction in
                ourGestureStateInOut = lastestGestureScale
            }
            .onEnded { finalGestureScale in
                if selectedEmojis.isEmpty {
                    document.steadyStateZoomScale *= finalGestureScale
                } else {
                    for emoji in selectedEmojis {
                        document.scaleEmoji(emoji, by: finalGestureScale)
                    }
                }
            }
    }
    
    @GestureState private var gesturePanOffset: CGSize = .zero
    
    private var panOffset: CGSize {
        (document.steadyStatePanOffset + gesturePanOffset) * zoomScale
    }
    
    private func panGesture() -> some Gesture {
        DragGesture()
            .updating($gesturePanOffset) { lastestDragGestureValue, gesturePanOffset, transaction in
                gesturePanOffset = lastestDragGestureValue.translation / zoomScale
            }
            .onEnded { finalDragGestureValue in
                document.steadyStatePanOffset = document.steadyStatePanOffset + (finalDragGestureValue.translation / zoomScale)
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
        if let image = image, size.width > 0, size.height > 0, size.height > 0, size.width > 0 {
            let vZoom = size.width / image.size.width
            let hZoom = size.height / image.size.height
            document.steadyStatePanOffset = .zero
            document.steadyStateZoomScale = min(vZoom, hZoom)
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
