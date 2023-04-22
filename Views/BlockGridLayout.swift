//
//  BlockGridLayout.swift
//  Pulse
//
//  Created by Riccardo Persello on 10/04/23.
//

import SwiftUI

struct BlockGrid: Layout {
    let spacing: CGFloat
    let minimumBlockSize: CGFloat
    let maximumBlockSize: CGFloat
    let acceptableColumnCounts: [Int]
            
    init(
        spacing: CGFloat = 8,
        minimumBlockSize: CGFloat = 150,
        maximumBlockSize: CGFloat = 200,
        acceptableColumnCounts: [Int] = [1, 2, 3, 4, 5, 6]
    ) {
        self.spacing = spacing
        self.minimumBlockSize = minimumBlockSize
        self.maximumBlockSize = maximumBlockSize
        self.acceptableColumnCounts = acceptableColumnCounts
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        
        return buildProposals(subviews: subviews, width: proposal.width ?? 0).totalSize
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        
        let (layouts, _) = buildProposals(subviews: subviews, width: bounds.width)
        
        for layout in layouts {
            let origin = layout.rect.origin
            let translatedOrigin = CGPoint(
                x: origin.x + bounds.minX,
                y: origin.y + bounds.minY
            )
            let size = layout.rect.size
            let proposedSize = ProposedViewSize(size)
            
            layout.layout.place(at: translatedOrigin, proposal: proposedSize)
        }
    }
    
    private func buildProposals(subviews: Subviews, width: CGFloat) -> (
        layouts: [(layout: LayoutSubview, rect: CGRect)],
        totalSize: CGSize
    ) {
        var totalSize: CGSize = .zero
        var result: [(layout: LayoutSubview, rect: CGRect)] = []
        let (unit, columns) = self.getGridStructure(for: width, subviews: subviews)
        var cellState = GridFiller(width: columns)
        
        for subview in subviews {
            let blockSize = subview[BlockSize.self]
            let realSize = CGSize(
                width: unit * CGFloat(blockSize.width)
                + CGFloat(max(0, blockSize.width - 1)) * spacing,
                height: unit * CGFloat(blockSize.height)
                + CGFloat(max(0, blockSize.height - 1)) * spacing
            )
            
            // Get first free space.
            guard let freeCoordinate = cellState.getFirstAvailableSpace(
                from: (x: 0, y: 0),
                thatFits: blockSize
            ) else { continue }
            
            // Some cells are now occupied.
            cellState.markAsUsed(origin: freeCoordinate, size: blockSize)

            // Get the real coordinates for this subview.
            let x = (unit + spacing) * CGFloat(freeCoordinate.x)
            let y = (unit + spacing) * CGFloat(freeCoordinate.y)

            let rect = CGRect(
                origin: CGPoint(x: x, y: y),
                size: realSize
            )

            // Update maximum size by asking the view its real, final size.
            let computedSize = subview.sizeThatFits(ProposedViewSize(realSize))
            totalSize.height = max(totalSize.height, rect.minY + computedSize.height)
            totalSize.width = max(totalSize.width, rect.minX + computedSize.width)

            result.append((subview, rect))
        }
        
        return (layouts: result, totalSize: totalSize)
    }
    
    private func getGridStructure(for width: CGFloat, subviews: Subviews) -> (
        unit: CGFloat,
        columns: Int
    ) {
        
        guard !self.acceptableColumnCounts.isEmpty else {
            return (unit: maximumBlockSize, columns: 1)
        }
        
        let largestMinimum = getLargestOfMinimumSizes(of: subviews)
        let recomputedMinimumBlockSize = max(self.minimumBlockSize, largestMinimum)
        
        let potentialBlockSizes = self.acceptableColumnCounts.map { columnCount in
            let gutters = CGFloat(columnCount - 1) * spacing

            let remainingSpace = width - gutters
            return (unit: remainingSpace / CGFloat(columnCount), columns: columnCount)
        }.filter { result in
            return result.unit > recomputedMinimumBlockSize && result.unit < maximumBlockSize
        }
        
        if let largest = potentialBlockSizes.max(by: { a, b in
            a.columns < b.columns
        }) {
            return largest
        }
        
        // If we didn't find a suitable column size, return one of the two extreme cases.
        
        if width > CGFloat(acceptableColumnCounts.max()!) * maximumBlockSize {
            // Largest size.
            return (
                unit: maximumBlockSize,
                columns: acceptableColumnCounts.max()!
            )
        } else {
            // Smallest size.
            return (
                unit: recomputedMinimumBlockSize,
                columns: acceptableColumnCounts.min()!
            )
        }
    }
    
    /// For each subview, see which one has the larger minimum side. Returns the largest of the minimum sides.
    private func getLargestOfMinimumSizes(of subviews: Subviews) -> CGFloat {

        var result: CGFloat = .zero
        
        for subview in subviews {
            let minimumSize = subview.sizeThatFits(.zero)
            let blockSize = subview[BlockSize.self]
            
            let (width, height) = (minimumSize.width / CGFloat(blockSize.width), minimumSize.height / CGFloat(blockSize.height))
            
            result = max(result, max(width, height))
        }
        
        return result
    }
}

struct GridFiller {
    private var grid: [[Bool]]
    private var width: Int
    
    init(width: Int) {
        self.width = width
        self.grid = [Array(repeating: false, count: width)]
    }
    
    mutating func getFirstAvailableSpace(
        from origin: (x: Int, y: Int),
        thatFits size: (width: Int, height: Int)
    ) -> (x: Int, y: Int)? {
        
        guard size.width <= self.width else {
            return nil
        }
        
        // Try to iterate over all the existing cells and find one that fits the specified size.
        for row in 0...self.grid.endIndex {
            for col in 0..<self.width {
                if self.rectangle(ofSize: size, fitsIn: (x: col, y: row)) {
                    return (x: col, y: row)
                }
            }
        }
        
        // If it still can't fit a block, create a new line and use it.
        self.extendLength(to: self.grid.endIndex + 1)
        return (x: 0, y: self.grid.endIndex)
    }
    
    mutating func markAsUsed(
        origin: (x: Int, y: Int),
        size: (width: Int, height: Int)
    ) {
        let cols = origin.x..<origin.x + size.width
        let rows = origin.y..<origin.y + size.height
        
        for row in rows {
            extendLength(to: row)
            for col in cols {
                grid[row][col] = true
            }
        }
    }
    
    private mutating func rectangle(
        ofSize size: (width: Int, height: Int),
        fitsIn origin: (x: Int, y: Int)
    ) -> Bool {
        let cols = origin.x..<origin.x + size.width
        let rows = origin.y..<origin.y + size.height
        
        if cols.upperBound > self.width {
            return false
        }
        
        for row in rows {
            extendLength(to: row)
            for col in cols {
                if grid[row][col] == true {
                    return false
                }
            }
        }
        
        return true
    }
    
    private mutating func extendLength(to y: Int) {
        while y >= grid.endIndex {
            grid.append(Array(repeating: false, count: self.width))
        }
    }
}

struct BlockSize: LayoutValueKey {
    static let defaultValue: (width: Int, height: Int) = (width: 1, height: 1)
}

extension View {
    func blockSize(width: Int, height: Int) -> some View {
        layoutValue(key: BlockSize.self, value: (width, height))
    }
}
