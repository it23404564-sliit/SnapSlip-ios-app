//
//  ZoomableImageView.swift
//  SnapSlip
//
//  Full-screen receipt viewer built from gesture recognisers:
//  • pinch (MagnifyGesture) to zoom 1×–5×
//  • drag to pan while zoomed
//  • double-tap to toggle 2.5× zoom
//  • drag down (when not zoomed) to dismiss, with the background fading as you drag
//

import SwiftUI

struct ZoomableImageView: View {
    let image: UIImage
    var onDismiss: () -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var dismissOffset: CGFloat = 0

    private let dismissThreshold: CGFloat = 140

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                    .opacity(1 - min(abs(dismissOffset) / 400, 0.7))
                    .ignoresSafeArea()

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(x: offset.width, y: offset.height + dismissOffset)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .gesture(SimultaneousGesture(magnification, drag))
                    .onTapGesture(count: 2) { toggleZoom() }
                    .accessibilityLabel("Receipt image")
                    .accessibilityHint("Double-tap to zoom. Pinch to zoom further.")
                    .accessibilityAction(named: "Close") { onDismiss() }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding()
            .accessibilityLabel("Close")
        }
        .statusBarHidden()
    }

    private var magnification: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(max(lastScale * value.magnification, 1), 5)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1.01 {
                    withAnimation(.spring) { reset() }
                }
            }
    }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1 {
                    offset = CGSize(width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height)
                } else {
                    dismissOffset = value.translation.height
                }
            }
            .onEnded { value in
                if scale > 1 {
                    lastOffset = offset
                } else if abs(value.translation.height) > dismissThreshold
                            || abs(value.predictedEndTranslation.height) > dismissThreshold * 2 {
                    onDismiss()
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { dismissOffset = 0 }
                }
            }
    }

    private func toggleZoom() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if scale > 1 {
                reset()
            } else {
                scale = 2.5
                lastScale = 2.5
            }
        }
    }

    private func reset() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
        dismissOffset = 0
    }
}
