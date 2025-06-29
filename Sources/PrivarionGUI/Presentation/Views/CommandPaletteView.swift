//
//  CommandPaletteView.swift
//  PrivarionGUI
//
//  Created by AI Assistant on 2025-01-16.
//  Copyright © 2025 Privarion. All rights reserved.
//

import SwiftUI

/// VS Code-style Command Palette view for macOS 13+ compatibility
/// Provides quick access to all application commands and navigation
struct CommandPaletteView: View {
    
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedIndex: Int = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Header
            HStack {
                Image(systemName: "command")
                    .foregroundColor(.secondary)
                
                TextField("Type a command...", text: $appState.commandManager.searchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        executeSelectedCommand()
                    }
                    .onChange(of: appState.commandManager.searchText) { _ in
                        selectedIndex = 0
                    }
                
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding()
            
            Divider()
            
            // Commands List
            ScrollViewReader { proxy in
                List(Array(appState.commandManager.filteredCommands.enumerated()), id: \.element.id) { index, command in
                    CommandRowView(
                        command: command,
                        isSelected: index == selectedIndex
                    )
                    .id(index)
                    .onTapGesture {
                        executeCommand(command)
                    }
                }
                .listStyle(.plain)
                .onChange(of: selectedIndex) { newIndex in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
        .frame(width: 600, height: 400)
        .background(.regularMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .onAppear {
            selectedIndex = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: .keyboardInput)) { notification in
            handleKeyboardInput(notification)
        }
    }
    
    // MARK: - Private Methods
    
    private func executeSelectedCommand() {
        guard !appState.commandManager.filteredCommands.isEmpty,
              selectedIndex < appState.commandManager.filteredCommands.count else { return }
        
        let command = appState.commandManager.filteredCommands[selectedIndex]
        executeCommand(command)
    }
    
    private func executeCommand(_ command: Command) {
        appState.commandManager.executeCommand(command)
        dismiss()
    }
    
    private func handleKeyboardInput(_ notification: Notification) {
        guard let key = notification.userInfo?["key"] as? String else { return }
        
        switch key {
        case "ArrowUp":
            if selectedIndex > 0 {
                selectedIndex -= 1
            }
        case "ArrowDown":
            if selectedIndex < appState.commandManager.filteredCommands.count - 1 {
                selectedIndex += 1
            }
        case "Enter":
            executeSelectedCommand()
        case "Escape":
            dismiss()
        default:
            break
        }
    }
}

/// Individual command row in the palette
struct CommandRowView: View {
    
    let command: Command
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: command.category.icon)
                .foregroundColor(command.category.color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(command.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(command.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if let shortcut = command.shortcut {
                Text(shortcut)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let keyboardInput = Notification.Name("keyboardInput")
}

#Preview {
    CommandPaletteView()
        .environmentObject(AppState())
}
