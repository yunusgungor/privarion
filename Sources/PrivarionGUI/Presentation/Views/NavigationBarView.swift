//
//  NavigationBarView.swift
//  PrivarionGUI
//
//  Created by AI Assistant on 2025-01-16.
//  Copyright © 2025 Privarion. All rights reserved.
//

import SwiftUI

/// Navigation bar with breadcrumbs and back/forward controls
/// Implements VS Code-style navigation UI for macOS
struct NavigationBarView: View {
    
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        HStack(spacing: 8) {
            // Back and Forward buttons
            HStack(spacing: 4) {
                Button {
                    appState.navigationManager.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .disabled(!appState.navigationManager.canGoBack)
                .help("Go Back")
                
                Button {
                    appState.navigationManager.goForward()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .disabled(!appState.navigationManager.canGoForward)
                .help("Go Forward")
            }
            
            Divider()
                .frame(height: 16)
            
            // Breadcrumbs
            BreadcrumbsView()
            
            Spacer()
            
            // Optional: Navigation search or additional controls
            HStack {
                // Quick navigation menu
                Menu {
                    ForEach(NavigationRoute.allCases, id: \.self) { route in
                        Button {
                            appState.navigationManager.navigateTo(route)
                        } label: {
                            Label(route.title, systemImage: route.icon)
                        }
                    }
                } label: {
                    Image(systemName: "location")
                        .font(.system(size: 12))
                }
                .menuStyle(.borderlessButton)
                .help("Quick Navigation")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
    }
}

/// Breadcrumbs component showing navigation hierarchy
struct BreadcrumbsView: View {
    
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(appState.navigationManager.breadcrumbs.enumerated()), id: \.element.id) { index, breadcrumb in
                HStack(spacing: 4) {
                    // Breadcrumb item
                    Button {
                        appState.navigationManager.navigateToBreadcrumb(breadcrumb)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: breadcrumb.icon)
                                .font(.system(size: 10))
                            Text(breadcrumb.title)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(breadcrumb.isLast ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Navigate to \(breadcrumb.title)")
                    
                    // Separator (except for last item)
                    if !breadcrumb.isLast {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(Color.secondary)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationBarView()
        .environmentObject(AppState())
        .padding()
}
