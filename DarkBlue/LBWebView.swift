//
//  LBWebView.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/22.
//

import SwiftUI
import WebKit

#if os(iOS)
import UIKit
typealias ViewRepresentable = UIViewRepresentable
#elseif os(macOS)
import AppKit
typealias ViewRepresentable = NSViewRepresentable
#endif

struct LBWebView: View {
    let urlString: String
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            WebViewWrapper(url: URL(string: urlString)!)
                .iosNavigationInline()
                .lbNavigation(
                    left: { Button("Close") { presentationMode.wrappedValue.dismiss() } },
                    center: { Text("Learn More") },
                    right: { EmptyView() }
                )
        }
    }
}

struct WebViewWrapper: ViewRepresentable {
    let url: URL
#if os(iOS)
    func makeUIView(context: Context) -> WKWebView { WKWebView() }
    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.load(URLRequest(url: url))
    }
#elseif os(macOS)
    func makeNSView(context: Context) -> WKWebView { return WKWebView() }
    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.load(URLRequest(url: url))
    }
#endif
}
