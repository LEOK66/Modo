import SwiftUI

// MARK: - Tab Enum
public enum Tab: String, CaseIterable {
    case todos = "TODOs"
    case insights = "Insights"
}

// MARK: - Bottom Bar Component
public struct BottomBar: View {
    @Binding var selectedTab: Tab

    public init(selectedTab: Binding<Tab>) {
        self._selectedTab = selectedTab
    }

    public var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(UIColor.separator))
                .frame(height: 1)
            HStack(spacing: 64) {
                BottomBarItem(icon: "doc.text", label: Tab.todos.rawValue, isSelected: selectedTab == .todos) {
                    selectedTab = .todos
                }
                BottomBarItem(icon: "message", label: Tab.insights.rawValue, isSelected: selectedTab == .insights) {
                    selectedTab = .insights
                }
            }
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Bottom Bar Item Component
struct BottomBarItem: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .frame(minWidth: 72)
            .foregroundColor(isSelected ? Color(hexString: "7C3AED") : .primary)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color(hexString: "7C3AED").opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color(hexString: "7C3AED").opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
    }
}

// MARK: - Preview
#Preview {
    StatefulPreviewWrapper(Tab.todos) { selection in
        BottomBar(selectedTab: selection)
    }
}

