//
//  Grid.swift
//  Memorize
//
//  Created by Amirala on 8/30/1399 AP.
//  Copyright © 1399 AP Amirala. All rights reserved.
//

import SwiftUI

extension Grid where Item: Identifiable, Item.ID == ID {
    init(_ items: [Item], viewForItem: @escaping (Item) -> ItemView) {
        self.init(items, id: \Item.id, viewForItem: viewForItem)
    }
}

struct Grid<Item, ID, ItemView>: View where ID: Hashable, ItemView: View {
    private var items: [Item]
    private var id: KeyPath<Item,ID>
    private var viewForItem: (Item) -> ItemView
    
    init(_ items: [Item], id: KeyPath<Item,ID>, viewForItem: @escaping (Item) -> ItemView) {
        self.items = items
        self.id = id
        self.viewForItem = viewForItem
    }
    
    //    var body: some View {
    //        GeometryReader { geometry in
    //            ForEach(items) { item in
    //                viewForItem(item)
    //                    .frame(width: GridLayout(itemCount: items.count, in: geometry.size).itemSize.width, height: GridLayout(itemCount: items.count, in: geometry.size).itemSize.height)
    //                    .position(GridLayout(itemCount: items.count, in: geometry.size).location(ofItemAt: item.id as! Int))
    //            }
    //        }
    //    }
    
    
    var body: some View {
        GeometryReader { geometry in
            self.body(for: GridLayout(itemCount: self.items.count, in: geometry.size))
        }
    }
    
    private func body(for layout: GridLayout) -> some View {
        ForEach(items, id: id) { item in
            self.body(for: item, in: layout)
        }
    }
    
    private func body(for item: Item, in layout: GridLayout) -> some View {
        let index = items.firstIndex(where: { item[keyPath: id] == $0[keyPath: id] } )
        return Group {
            if index != nil {
                viewForItem(item)
                    .frame(width: layout.itemSize.width, height: layout.itemSize.height)
                    .position(layout.location(ofItemAt: index!))
            }
        }
    }
}
