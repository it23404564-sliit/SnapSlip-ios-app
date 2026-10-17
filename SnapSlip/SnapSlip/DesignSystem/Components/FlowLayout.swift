//
//  FlowLayout.swift
//  SnapSlip
//
//  A custom Layout that wraps children onto new lines like text. Used for the
//  category picker chips, which must reflow for any screen width, orientation
//  or Dynamic Type size.
//

import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = Spacing.s
    var lineSpacing: CGFloat = Spacing.s

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += lineHeight + lineSpacing
                x = bounds.minX
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

/// Category chips in a FlowLayout. The selected background glides between
/// chips with matchedGeometryEffect.
struct CategoryPickerGrid: View {
    @Binding var selection: ExpenseCategory
    @Namespace private var selectionNamespace

    var body: some View {
        FlowLayout {
            ForEach(ExpenseCategory.allCases) { category in
                let isSelected = category == selection
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { selection = category }
                } label: {
                    Label(category.displayName, systemImage: category.symbol)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, Spacing.m)
                        .padding(.vertical, Spacing.s)
                        .foregroundStyle(isSelected ? Color.white : category.color)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(category.color.gradient)
                                    .matchedGeometryEffect(id: "selected", in: selectionNamespace)
                            } else {
                                Capsule().fill(category.color.opacity(0.12))
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("category-\(category.rawValue)")
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}
